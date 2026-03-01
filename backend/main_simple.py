# -*- coding: utf-8 -*-
"""
GenzFit Avatar Backend — Ready Player Me edition
=================================================
The heavy 3D generation is now handled by Ready Player Me (client-side).
This backend is a thin service that:
  1. Receives the RPM avatar GLB URL from the Flutter app
  2. Saves it (with metadata) to Cloudinary / local JSON store
  3. Returns the history list for the timeline strip
"""

import json
import os
import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ── Optional Cloudinary ───────────────────────────────────────────────────────
storage_service = None
try:
    from services.cloudinary_storage import CloudinaryStorageService
    cn = os.getenv("CLOUDINARY_CLOUD_NAME", "")
    ak = os.getenv("CLOUDINARY_API_KEY", "")
    as_ = os.getenv("CLOUDINARY_API_SECRET", "")
    if cn and ak and as_:
        storage_service = CloudinaryStorageService(cn, ak, as_)
        logger.info("✅ Cloudinary storage ready")
    else:
        logger.warning("⚠️  Cloudinary not configured — metadata stored locally")
except Exception as e:
    logger.warning("⚠️  Cloudinary unavailable: %s", e)

# ── Local fallback: JSON file store ──────────────────────────────────────────
_LOCAL_STORE = os.path.join(os.path.dirname(__file__), "_avatar_store.json")

def _read_store() -> dict:
    if os.path.exists(_LOCAL_STORE):
        with open(_LOCAL_STORE) as f:
            return json.load(f)
    return {}

def _write_store(data: dict):
    with open(_LOCAL_STORE, "w") as f:
        json.dump(data, f, indent=2)

def _save_local(user_id: str, entry: dict):
    store = _read_store()
    if user_id not in store:
        store[user_id] = []
    store[user_id].insert(0, entry)
    _write_store(store)

# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="GenzFit Avatar API",
    description="Ready Player Me avatar storage & history",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Pydantic models ───────────────────────────────────────────────────────────
class SaveAvatarRequest(BaseModel):
    user_id: str
    rpm_model_url: str
    rpm_thumbnail_url: str = ""
    height: Optional[float] = None
    weight: Optional[float] = None
    gender: Optional[str] = "male"
    measurements: Optional[dict] = {}

class SaveAvatarResponse(BaseModel):
    model_config = {"protected_namespaces": ()}

    success: bool
    user_id: str
    model_url: str
    thumbnail_url: str
    message: str

# ── Endpoints ─────────────────────────────────────────────────────────────────
@app.get("/")
async def root():
    return {
        "status": "healthy",
        "service": "GenzFit Avatar API (RPM edition)",
        "version": "2.0.0",
        "storage": "cloudinary" if storage_service else "local-json",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "storage": "cloudinary" if storage_service else "local-json",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

@app.post("/api/v1/avatar/save", response_model=SaveAvatarResponse)
async def save_avatar(req: SaveAvatarRequest):
    """Save the RPM avatar URL after user finishes customisation."""
    logger.info("Saving RPM avatar for user %s  url=%s", req.user_id, req.rpm_model_url)

    entry = {
        "model_url":     req.rpm_model_url,
        "thumbnail_url": req.rpm_thumbnail_url or "",
        "height":        req.height,
        "weight":        req.weight,
        "gender":        req.gender,
        "measurements":  req.measurements or {},
        "version":       "rpm",
        "day":           0,
        "created_at":    datetime.now(timezone.utc).isoformat(),
    }

    if storage_service:
        try:
            await storage_service.save_avatar_metadata(user_id=req.user_id, metadata=entry)
        except Exception as e:
            logger.error("Cloudinary save failed: %s — falling back to local", e)
            _save_local(req.user_id, entry)
    else:
        _save_local(req.user_id, entry)

    return SaveAvatarResponse(
        success=True,
        user_id=req.user_id,
        model_url=req.rpm_model_url,
        thumbnail_url=req.rpm_thumbnail_url or "",
        message="Avatar saved successfully",
    )

@app.get("/api/v1/avatar/latest/{user_id}")
async def get_latest_avatar(user_id: str):
    """Return the most recently saved avatar for a user."""
    if storage_service:
        try:
            history = await storage_service.get_physique_history(user_id, limit=1)
            if history:
                e = history[0]
                return {"success": True, "model_url": e.get("model_url", ""), "thumbnail_url": e.get("thumbnail_url", "")}
        except Exception as e:
            logger.warning("Cloudinary fetch failed: %s", e)

    store = _read_store()
    entries = store.get(user_id, [])
    if not entries:
        return {"success": False, "model_url": "", "thumbnail_url": ""}
    return {"success": True, "model_url": entries[0].get("model_url", ""), "thumbnail_url": entries[0].get("thumbnail_url", "")}

@app.get("/api/v1/avatar/history/{user_id}")
async def get_avatar_history(user_id: str, limit: int = 30):
    """Return all saved avatars for a user (newest first)."""
    avatars = []

    if storage_service:
        try:
            history = await storage_service.get_physique_history(user_id, limit=limit)
            for e in history:
                avatars.append({
                    "model_url":     e.get("model_url", ""),
                    "thumbnail_url": e.get("thumbnail_url", ""),
                    "day":           e.get("day", 0),
                    "version":       e.get("version", "rpm"),
                    "weight":        e.get("weight"),
                    "created_at":    e.get("created_at", ""),
                })
            return {"success": True, "user_id": user_id, "avatars": avatars}
        except Exception as e:
            logger.warning("Cloudinary history fetch failed: %s", e)

    store = _read_store()
    for e in store.get(user_id, [])[:limit]:
        avatars.append({
            "model_url":     e.get("model_url", ""),
            "thumbnail_url": e.get("thumbnail_url", ""),
            "day":           e.get("day", 0),
            "version":       e.get("version", "rpm"),
            "weight":        e.get("weight"),
            "created_at":    e.get("created_at", ""),
        })

    return {"success": True, "user_id": user_id, "avatars": avatars}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main_simple:app", host="0.0.0.0", port=8000, reload=True)
