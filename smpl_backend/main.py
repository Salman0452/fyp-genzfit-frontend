from __future__ import annotations
"""
main.py -- GenZFit SMPL-X Avatar Generation Backend
Run: uvicorn main:app --reload --host 0.0.0.0 --port 8000
Endpoints:
    GET  /health             -> server health + SMPL-X availability
    POST /generate-avatar    -> generate a textured SMPL-X avatar, return .glb
Fully offline -- no external avatar APIs.
"""

import logging, os, tempfile
from pathlib import Path
from typing import Optional

<<<<<<< HEAD
from dotenv import load_dotenv
=======
import numpy as np
>>>>>>> e57436bc2c891e4c1d767e91cd244c0499b0c7f9
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel, Field

<<<<<<< HEAD
from models.request_models import (
    GenerateAvatarRequest,
    GenerateAvatarResponse,
    HealthResponse,
)
from services.landmark_mapper import extract_proportions
from services.beta_converter import measurements_to_betas, betas_to_description
from services.mesh_generator import generate_mesh, _SMPLX_AVAILABLE
=======
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
>>>>>>> e57436bc2c891e4c1d767e91cd244c0499b0c7f9

# --- Paths ---
SMPLX_MODEL_DIR = Path(__file__).parent / "models" / "smplx"
UV_OBJ_PATH     = Path(__file__).parent / "uv" / "smplx_uv.obj"
UV_TEXTURE_PATH = Path(__file__).parent / "uv" / "smplx_uv.png"

# --- SMPL-X availability check at startup ---
_SMPLX_AVAILABLE = False
_smplx_module    = None
try:
    import smplx
    import torch
    _smplx_module    = smplx
    _SMPLX_AVAILABLE = SMPLX_MODEL_DIR.exists()
    if _SMPLX_AVAILABLE:
        logger.info("SMPL-X ready. Model dir: %s", SMPLX_MODEL_DIR)
    else:
        logger.warning("smplx installed but model dir not found: %s", SMPLX_MODEL_DIR)
except ImportError as exc:
    logger.warning("smplx/torch not installed (%s).", exc)

# --- FastAPI app ---
app = FastAPI(
    title="GenZFit SMPL-X Avatar Backend",
    description="Generates textured 3D body avatars using SMPL-X. Fully offline.",
    version="2.0.0",
)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])

# --- Pydantic models ---
class AvatarRequest(BaseModel):
    """
    POST /generate-avatar request body.
    body_measurements keys (all cm): chest, waist, hips, shoulder_width,
    arm_length, leg_length, neck, thigh, calf. camelCase variants also accepted.
    """
    gender: str   = Field("neutral", description="male | female | neutral")
    height: float = Field(..., ge=100.0, le=250.0, description="Height in cm")
    weight: float = Field(..., ge=20.0,  le=300.0, description="Weight in kg")
    body_measurements: Optional[dict] = Field(None, description="Anthropometric measurements in cm")

class HealthResponse(BaseModel):
    status: str; smplx_available: bool; model_dir_exists: bool; uv_files_exist: bool

# --- Health endpoint ---
@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    """Return server health and component availability."""
    return HealthResponse(
        status="ok", smplx_available=_SMPLX_AVAILABLE,
        model_dir_exists=SMPLX_MODEL_DIR.exists(),
        uv_files_exist=(UV_OBJ_PATH.exists() and UV_TEXTURE_PATH.exists()),
    )

# --- Main generate-avatar endpoint ---
@app.post("/generate-avatar", response_class=Response,
    responses={
        200: {"content": {"model/gltf-binary": {}}, "description": "Binary .glb file"},
        503: {"description": "SMPL-X not available"},
    })
def generate_avatar(req: AvatarRequest) -> Response:
    """
    Generate a SMPL-X body avatar from body measurements.
    Pipeline: measurements -> betas -> SMPL-X mesh -> scale -> UV texture -> .glb
    Returns binary .glb with Content-Type: model/gltf-binary.
    Response header X-Betas contains the 10 computed beta values.
    """
    if not _SMPLX_AVAILABLE:
        raise HTTPException(status_code=503, detail=(
            "SMPL-X not available. Install smplx+torch and place "
            "SMPLX_MALE.pkl / SMPLX_FEMALE.pkl / SMPLX_NEUTRAL.pkl in models/smplx/"
        ))
    logger.info("Generating avatar: gender=%s height=%.1f weight=%.1f",
                req.gender, req.height, req.weight)
    betas    = _measurements_to_betas(req.height, req.weight, req.gender, req.body_measurements or {})
    verts, faces = _run_smplx(betas, req.gender)
    verts    = _scale_to_height(verts, req.height)
    glb      = _build_textured_glb(verts, faces)
    logger.info("GLB %.1f KB done.", len(glb)/1024)
    return Response(
        content=glb,
        media_type="model/gltf-binary",
        headers={
            "Content-Disposition":           "attachment; filename=\"avatar.glb\"",
            "X-Betas":                       ",".join(f"{b:.4f}" for b in betas),
            "Access-Control-Expose-Headers": "X-Betas",
        },
    )

# --- Step 1: measurements -> betas ---
def _measurements_to_betas(height_cm, weight_kg, gender, m) -> list:
    """
    Heuristic conversion of body measurements to 10 SMPL-X beta shape params.
    beta[0]=height, beta[1]=BMI/volume, beta[2]=shoulders, beta[3]=hips,
    beta[4]=chest, beta[5]=waist, beta[6]=arm, beta[7]=leg, beta[8]=neck, beta[9]=thigh.
    """
    b = [0.0] * 10
    ref_h = {"male": 173.0, "female": 160.0, "neutral": 167.0}.get(gender.lower(), 167.0)
    b[0]  = (height_cm - ref_h) / 5.0
    bmi   = weight_kg / (height_cm / 100.0) ** 2
    b[1]  = (bmi - 22.0) / 3.0
    def _g(k1, k2=""):
        v = m.get(k1) or (m.get(k2) if k2 else None)
        return float(v) if v is not None else None
    sw = _g("shoulder_width","shoulderWidth")
    if sw:  b[2] = (sw  - (42 if gender=="male" else 38)) / 4.0
    hp = _g("hips")
    if hp:  b[3] = (hp  - (90 if gender=="male" else 96)) / 6.0
    ch = _g("chest")
    if ch:  b[4] = (ch  - (98 if gender=="male" else 88)) / 6.0
    wa = _g("waist")
    if wa:  b[5] = (wa  - (82 if gender=="male" else 74)) / 5.0
    ar = _g("arm_length","armLength")
    if ar:  b[6] = (ar  - 65.0) / 4.0
    lg = _g("leg_length","legLength")
    if lg:  b[7] = (lg  - 95.0) / 5.0
    nk = _g("neck")
    if nk:  b[8] = (nk  - 38.0) / 3.0
    th = _g("thigh")
    if th:  b[9] = (th  - 56.0) / 4.0
    return [max(-3.0, min(3.0, x)) for x in b]

# --- Step 2: SMPL-X forward pass ---
def _run_smplx(betas, gender):
    """
    Load SMPL-X from SMPLX_MODEL_DIR (SMPLX_MALE.pkl / SMPLX_FEMALE.pkl / SMPLX_NEUTRAL.pkl)
    and run a T-pose forward pass.
    Returns (vertices: float32 N x 3, faces: int32 F x 3) -- positions in metres.
    """
    import torch
    g = gender.lower()
    if g not in ("male","female","neutral"): g = "neutral"
    model = _smplx_module.create(
        model_path=str(SMPLX_MODEL_DIR), model_type="smplx", gender=g,
        use_pca=False, num_betas=10, batch_size=1, flat_hand_mean=True,
    ).to(torch.device("cpu"))
    with torch.no_grad():
        out = model(betas=torch.tensor([betas], dtype=torch.float32), return_verts=True)
    return out.vertices.detach().cpu().numpy().squeeze(), model.faces.astype(np.int32)

# --- Step 3: scale to target height ---
def _scale_to_height(v, h_cm):
    """Scale vertices so bounding-box height == h_cm; place feet at y=0."""
    cur = float(v[:,1].max() - v[:,1].min())
    if cur < 1e-6: return v
    v = v * ((h_cm / 100.0) / cur)
    v[:,1] -= v[:,1].min()
    return v

# --- UV OBJ parser ---
def _parse_uv_obj(path):
    """
    Parse smplx_uv.obj. Returns (vt, face_v_idx, face_vt_idx) all 0-indexed.
    vt: (U,2) float32 UV coords. face_v_idx: (F,3) vertex idx. face_vt_idx: (F,3) UV idx.
    """
    vt_r, fv_r, fvt_r = [], [], []
    with open(path) as f:
        for line in f:
            t = line.strip().split()
            if not t or t[0]=="#": continue
            if t[0]=="vt": vt_r.append([float(t[1]),float(t[2])])
            elif t[0]=="f":
                vi, vti = [], []
                for tok in t[1:4]:
                    p=tok.split("/")
                    vi.append(int(p[0])-1)
                    vti.append(int(p[1])-1 if len(p)>1 and p[1] else 0)
                fv_r.append(vi); fvt_r.append(vti)
    return (np.array(vt_r,dtype=np.float32),
            np.array(fv_r,dtype=np.int32),
            np.array(fvt_r,dtype=np.int32))

# --- Build textured GLB ---
def _build_textured_glb(verts, faces) -> bytes:
    """
    Build a trimesh with skin texture and export as .glb bytes.
    Texture preference: UV map (smplx_uv.obj + smplx_uv.png) > vertex colour fallback.
    """
    import trimesh
    mesh = None
    if UV_OBJ_PATH.exists() and UV_TEXTURE_PATH.exists():
        try:
            mesh = _build_uv_mesh(verts, faces)
            logger.info("UV texture applied.")
        except Exception as e:
            logger.warning("UV texture failed (%s); using vertex-colour fallback.", e)
    if mesh is None:
        mesh = _build_vertex_colour_mesh(verts, faces)
    with tempfile.NamedTemporaryFile(suffix=".glb", delete=False) as tmp:
        tp = tmp.name
    try:
        mesh.export(tp, file_type="glb")
        return Path(tp).read_bytes()
    finally:
        try: os.unlink(tp)
        except: pass

<<<<<<< HEAD
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

    pipeline = "SMPL-X" if _SMPLX_AVAILABLE else "capsule-mesh"

    return GenerateAvatarResponse(
        user_id=req.user_id,
        model_base64=base64.b64encode(glb_bytes).decode("utf-8"),
        betas=betas,
        body_measurements=measurements,
        generation_time_ms=round(elapsed_ms, 1),
        message=f"Avatar generated using {pipeline} pipeline. "
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
=======
def _build_uv_mesh(verts, faces):
    """
    Apply UV texture from smplx_uv.obj + smplx_uv.png.
    Expands vertex array so every face-corner is unique (handles UV seam splits).
    Steps: parse UV OBJ -> expand -> flip V axis -> attach PNG via SimpleMaterial.
    """
    import trimesh
    from PIL import Image
    vt, fv, fvt = _parse_uv_obj(UV_OBJ_PATH)
    nv, nuv = len(verts), len(vt)
    ok = ((fv[:,0]<nv)&(fv[:,1]<nv)&(fv[:,2]<nv)
         &(fvt[:,0]<nuv)&(fvt[:,1]<nuv)&(fvt[:,2]<nuv))
    fv, fvt = fv[ok], fvt[ok]
    n = len(fv)
    nv2  = verts[fv.reshape(-1)]   # (F*3, 3)
    nuv2 = vt[fvt.reshape(-1)]     # (F*3, 2)
    nf   = np.arange(n*3, dtype=np.int32).reshape(n,3)
    nuv2[:,1] = 1.0 - nuv2[:,1]    # flip V axis: OBJ->OpenGL convention
    tex = Image.open(UV_TEXTURE_PATH).convert("RGBA")
    mat = trimesh.visual.material.SimpleMaterial(image=tex)
    vis = trimesh.visual.TextureVisuals(uv=nuv2, material=mat)
    return trimesh.Trimesh(vertices=nv2, faces=nf, visual=vis, process=False)

def _build_vertex_colour_mesh(verts, faces):
    """Fallback: paint all vertices with medium skin tone RGBA (210,160,120,255)."""
    import trimesh
    mesh = trimesh.Trimesh(vertices=verts, faces=faces, process=False)
    mesh.visual.vertex_colors = np.tile([210,160,120,255], (len(verts),1)).astype(np.uint8)
    return mesh

>>>>>>> e57436bc2c891e4c1d767e91cd244c0499b0c7f9
