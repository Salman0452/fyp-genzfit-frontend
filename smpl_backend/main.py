"""
main.py – GenZFit SMPL Avatar Generation Backend
─────────────────────────────────────────────────
Run:
    uvicorn main:app --reload --host 0.0.0.0 --port 8000

Endpoints:
    GET  /health
    POST /generate-avatar   → returns GLB as base64 + beta values
    GET  /avatar/{user_id}  → latest stored avatar metadata
    GET  /avatar/{user_id}/history → all avatar snapshots
"""

from __future__ import annotations

import base64
import json
import os
import time
from datetime import datetime, date
from pathlib import Path
from typing import Dict, List, Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response

from models.request_models import (
    GenerateAvatarRequest,
    GenerateAvatarResponse,
    HealthResponse,
)
from services.landmark_mapper import extract_proportions
from services.beta_converter import measurements_to_betas, betas_to_description
from services.mesh_generator import generate_mesh, _SMPLX_AVAILABLE

load_dotenv()

# ─── App setup ────────────────────────────────────────────────────────────────

app = FastAPI(
    title="GenZFit Avatar Backend",
    description="SMPL 3D body avatar generation API",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # Flutter dev: all origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── In-memory avatar store (replace with Firestore / DB for production) ──────
# Structure: { user_id: [ { date, betas, measurements, model_url }, … ] }
_avatar_store: Dict[str, List[dict]] = {}

# Directory for cached GLB files
CACHE_DIR = Path(os.getenv("CACHE_DIR", "./cache/glb"))
CACHE_DIR.mkdir(parents=True, exist_ok=True)


# ─── Routes ───────────────────────────────────────────────────────────────────

@app.get("/health", response_model=HealthResponse)
def health():
    try:
        import torch
        gpu = torch.cuda.is_available()
    except ImportError:
        gpu = False

    return HealthResponse(
        status="ok",
        smplx_available=_SMPLX_AVAILABLE,
        gpu_available=gpu,
    )


@app.post("/generate-avatar", response_model=GenerateAvatarResponse)
async def generate_avatar(req: GenerateAvatarRequest):
    t0 = time.perf_counter()

    # ── 1. Extract landmark proportions ───────────────────────────────────
    lm_proportions: dict = {}
    if req.landmarks:
        lm_dict = {k: v.model_dump() for k, v in req.landmarks.items()}
        lm_proportions = extract_proportions(lm_dict, req.height, req.weight)

    # ── 2. Compute anthropometric measurements ────────────────────────────
    measurements = dict(req.measurements or {})
    if not measurements:
        measurements = _fallback_measurements(req.height, req.weight, req.gender)

    # ── 3. Convert to SMPL betas ──────────────────────────────────────────
    betas = measurements_to_betas(
        height=req.height,
        weight=req.weight,
        age=req.age,
        gender=req.gender,
        measurements=measurements,
        landmark_proportions=lm_proportions,
    )

    # ── 4. Generate GLB mesh ──────────────────────────────────────────────
    try:
        glb_bytes = generate_mesh(
            betas=betas,
            height_cm=req.height,
            gender=req.gender,
            skin_tone=req.skin_tone or "medium",
            show_muscles=req.show_muscles,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Mesh generation failed: {exc}")

    # ── 5. Cache GLB and build URL ─────────────────────────────────────────
    snap_date = req.date or date.today().isoformat()
    cache_key = f"{req.user_id}_{snap_date}"
    glb_path  = CACHE_DIR / f"{cache_key}.glb"
    glb_path.write_bytes(glb_bytes)

    # ── 6. Store snapshot metadata ────────────────────────────────────────
    snapshot = {
        "date":         snap_date,
        "betas":        betas,
        "measurements": measurements,
        "glb_path":     str(glb_path),
    }
    user_history = _avatar_store.setdefault(req.user_id, [])
    # remove existing entry for same date
    _avatar_store[req.user_id] = [s for s in user_history if s["date"] != snap_date]
    _avatar_store[req.user_id].append(snapshot)
    _avatar_store[req.user_id].sort(key=lambda s: s["date"])

    elapsed_ms = (time.perf_counter() - t0) * 1000

    return GenerateAvatarResponse(
        user_id=req.user_id,
        model_base64=base64.b64encode(glb_bytes).decode("utf-8"),
        betas=betas,
        body_measurements=measurements,
        generation_time_ms=round(elapsed_ms, 1),
        message=f"Avatar generated using {'SMPL-X' if _SMPLX_AVAILABLE else 'capsule-mesh'} pipeline. "
                f"Body shape: {betas_to_description(betas, req.gender)}.",
    )


@app.get("/avatar/{user_id}")
def get_latest_avatar(user_id: str):
    history = _avatar_store.get(user_id, [])
    if not history:
        raise HTTPException(status_code=404, detail="No avatar found for this user.")
    return history[-1]


@app.get("/avatar/{user_id}/history")
def get_avatar_history(user_id: str):
    history = _avatar_store.get(user_id, [])
    # Return metadata only (no glb_path)
    return [
        {
            "date":         s["date"],
            "betas":        s["betas"],
            "measurements": s["measurements"],
        }
        for s in history
    ]


@app.get("/avatar/{user_id}/{snap_date}/glb")
def download_glb(user_id: str, snap_date: str):
    """Stream a cached GLB file for a specific date."""
    history = _avatar_store.get(user_id, [])
    snapshot = next((s for s in history if s["date"] == snap_date), None)
    if snapshot is None:
        raise HTTPException(status_code=404, detail="Snapshot not found.")

    glb_path = Path(snapshot["glb_path"])
    if not glb_path.exists():
        raise HTTPException(status_code=404, detail="GLB file not found in cache.")

    return Response(
        content=glb_path.read_bytes(),
        media_type="model/gltf-binary",
        headers={"Content-Disposition": f'attachment; filename="{user_id}_{snap_date}.glb"'},
    )


# ─── Helper: simple anthropometric fallback ───────────────────────────────────

def _fallback_measurements(height: float, weight: float, gender: str) -> dict:
    """Rough anthropometric formulas; used when Flutter doesn't send measurements."""
    bmi = weight / ((height / 100) ** 2)
    isMale = gender.lower() == "male"

    chest  = height * (0.565 if isMale else 0.535) * (1 + max(0, bmi - 22) * 0.008)
    waist  = height * (0.46  if isMale else 0.42)  * (1 + max(0, bmi - 22) * 0.012)
    hips   = height * (0.53  if isMale else 0.56)  * (1 + max(0, bmi - 22) * 0.010)
    shoulder = height * (0.26 if isMale else 0.24)
    arm_len  = height * (0.39 if isMale else 0.38)
    inseam   = height * (0.46 if isMale else 0.45)
    thigh    = 50 + (weight - 70) * 0.2 if isMale else 52 + (weight - 60) * 0.25

    return {
        "chest":         round(chest,    1),
        "waist":         round(waist,    1),
        "hips":          round(hips,     1),
        "shoulderWidth": round(shoulder, 1),
        "armLength":     round(arm_len,  1),
        "inseam":        round(inseam,   1),
        "thigh":         round(max(thigh, 38.0), 1),
    }
