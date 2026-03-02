from __future__ import annotations
"""
main.py -- GenZFit SMPL-X Avatar Generation Backend
Run: uvicorn main:app --reload --host 0.0.0.0 --port 8000
Endpoints:
    GET  /health             -> server health + SMPL-X availability
    POST /generate-avatar    -> generate a textured SMPL-X avatar, return .glb base64
Fully offline -- no external avatar APIs.
"""

import base64, logging, os, tempfile
from datetime import date
from pathlib import Path
from typing import Optional

import cloudinary
import cloudinary.uploader

import numpy as np
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel, Field, ConfigDict

load_dotenv()

# --- Cloudinary configuration ---
cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
    secure=True,
)
_CLOUDINARY_ENABLED = bool(
    os.getenv("CLOUDINARY_CLOUD_NAME")
    and os.getenv("CLOUDINARY_API_KEY")
    and os.getenv("CLOUDINARY_API_SECRET")
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# --- Paths ---
SMPLX_MODEL_DIR = Path(__file__).parent / "models"
UV_OBJ_PATH     = Path(__file__).parent / "models" / "uv" / "smplx_uv.obj"
UV_TEXTURE_PATH = Path(__file__).parent / "models" / "uv" / "smplx_uv.png"
CACHE_DIR       = Path(os.getenv("CACHE_DIR", str(Path(__file__).parent / "cache" / "glb")))
CACHE_DIR.mkdir(parents=True, exist_ok=True)

# Skin tone palette (RGBA, sRGB)
SKIN_TONES: dict[str, list[int]] = {
    "light":  [255, 220, 185, 255],
    "medium": [210, 168, 130, 255],
    "brown":  [180, 120,  80, 255],
    "dark":   [110,  70,  45, 255],
}

# In-memory snapshot store {user_id: [{date, betas, measurements, glb_path}]}
_avatar_store: dict = {}

# --- SMPL-X availability check at startup ---
_SMPLX_AVAILABLE = False
_smplx_module    = None
try:
    import smplx
    import torch
    _smplx_module    = smplx
    _SMPLX_AVAILABLE = (SMPLX_MODEL_DIR / "smplx").exists()
    if _SMPLX_AVAILABLE:
        logger.info("SMPL-X ready. Model dir: %s", SMPLX_MODEL_DIR / "smplx")
    else:
        logger.warning("smplx installed but model dir not found: %s", SMPLX_MODEL_DIR / "smplx")
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
    model_config = ConfigDict(protected_namespaces=())
    user_id: str
    date: Optional[str]   = None
    gender: str           = Field("neutral", description="male | female | neutral")
    height: float         = Field(..., ge=100.0, le=250.0, description="Height in cm")
    weight: float         = Field(..., ge=20.0,  le=300.0, description="Weight in kg")
    skin_tone: str        = Field("medium", description="light | medium | brown | dark")
    body_measurements: Optional[dict] = Field(None, description="Anthropometric measurements in cm")

class AvatarResponse(BaseModel):
    model_config = ConfigDict(protected_namespaces=())
    user_id: str
    model_base64: str
    betas: list
    body_measurements: dict
    pipeline: str
    glb_url: Optional[str] = None   # Cloudinary public URL (None if upload skipped)
    message: str = "OK"

class HealthResponse(BaseModel):
    model_config = ConfigDict(protected_namespaces=())
    status: str
    smplx_available: bool
    model_dir_exists: bool
    uv_files_exist: bool
    cloudinary_enabled: bool

# --- Health endpoint ---
@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(
        status="ok", smplx_available=_SMPLX_AVAILABLE,
        model_dir_exists=(SMPLX_MODEL_DIR / "smplx").exists(),
        uv_files_exist=(UV_OBJ_PATH.exists() and UV_TEXTURE_PATH.exists()),
        cloudinary_enabled=_CLOUDINARY_ENABLED,
    )

# --- Main generate-avatar endpoint ---
@app.post("/generate-avatar", response_model=AvatarResponse)
def generate_avatar(req: AvatarRequest) -> AvatarResponse:
    snap_date = req.date or date.today().isoformat()
    meas = req.body_measurements or _fallback_measurements(req.height, req.weight, req.gender)
    betas = _measurements_to_betas(req.height, req.weight, req.gender, meas)

    if _SMPLX_AVAILABLE:
        verts, faces = _run_smplx(betas, req.gender)
        verts = _scale_to_height(verts, req.height)
        glb = _build_textured_glb(verts, faces, req.skin_tone, req.gender)
        pipeline = "SMPL-X"
    else:
        from services.mesh_generator import generate_mesh
        glb = generate_mesh(betas=betas, height_cm=req.height, gender=req.gender,
                            skin_tone=req.skin_tone,
                            measurements={**meas, "weight": req.weight})
        pipeline = "geometric-fallback"

    # Upload to Cloudinary (raw resource so .glb is preserved)
    glb_url: Optional[str] = None
    if req.user_id and _CLOUDINARY_ENABLED:
        try:
            public_id = f"genzfit_avatars/{req.user_id}/{snap_date}"
            upload_result = cloudinary.uploader.upload(
                glb,
                resource_type="raw",
                public_id=public_id,
                overwrite=True,
                format="glb",
            )
            glb_url = upload_result.get("secure_url")
            logger.info("GLB uploaded to Cloudinary: %s", glb_url)
        except Exception as exc:
            logger.warning("Cloudinary upload failed (%s); continuing without URL.", exc)

    # Cache locally (fallback / backup)
    if req.user_id:
        cache_key = f"{req.user_id}_{snap_date}"
        glb_path  = CACHE_DIR / f"{cache_key}.glb"
        glb_path.write_bytes(glb)
        snap = {
            "date": snap_date,
            "betas": betas,
            "measurements": meas,
            "glb_path": str(glb_path),
            "glb_url": glb_url,
        }
        history = _avatar_store.setdefault(req.user_id, [])
        _avatar_store[req.user_id] = [s for s in history if s["date"] != snap_date]
        _avatar_store[req.user_id].append(snap)
        _avatar_store[req.user_id].sort(key=lambda s: s["date"])

    logger.info("GLB %.1f KB done via %s.", len(glb)/1024, pipeline)
    return AvatarResponse(
        user_id=req.user_id or "",
        model_base64=base64.b64encode(glb).decode(),
        betas=betas,
        body_measurements=meas,
        pipeline=pipeline,
        glb_url=glb_url,
        message=f"Avatar generated using {pipeline} pipeline.",
    )

@app.get("/avatar/{user_id}/history")
def get_avatar_history(user_id: str):
    return [
        {
            "date": s["date"],
            "betas": s["betas"],
            "measurements": s["measurements"],
            "glb_url": s.get("glb_url"),
        }
        for s in _avatar_store.get(user_id, [])
    ]

@app.get("/avatar/{user_id}/{snap_date}/glb")
def download_glb(user_id: str, snap_date: str):
    history = _avatar_store.get(user_id, [])
    snap = next((s for s in history if s["date"] == snap_date), None)
    if not snap:
        raise HTTPException(status_code=404, detail="Snapshot not found.")
    p = Path(snap["glb_path"])
    if not p.exists():
        raise HTTPException(status_code=404, detail="GLB file not found in cache.")
    return Response(content=p.read_bytes(), media_type="model/gltf-binary",
                    headers={"Content-Disposition": f'attachment; filename="{user_id}_{snap_date}.glb"'})

# --- helpers ---
def _measurements_to_betas(height_cm, weight_kg, gender, m) -> list:
    b = [0.0] * 10
    ref_h = {"male": 173.0, "female": 160.0, "neutral": 167.0}.get(gender.lower(), 167.0)
    b[0]  = (height_cm - ref_h) / 5.0
    bmi   = weight_kg / (height_cm / 100.0) ** 2
    b[1]  = (bmi - 22.0) / 3.0
    def _g(k1, k2=""):
        v = m.get(k1) or (m.get(k2) if k2 else None)
        return float(v) if v is not None else None
    sw = _g("shoulder_width","shoulderWidth")
    if sw: b[2] = (sw - (42 if gender=="male" else 38)) / 4.0
    hp = _g("hips")
    if hp: b[3] = (hp - (90 if gender=="male" else 96)) / 6.0
    ch = _g("chest")
    if ch: b[4] = (ch - (98 if gender=="male" else 88)) / 6.0
    wa = _g("waist")
    if wa: b[5] = (wa - (82 if gender=="male" else 74)) / 5.0
    ar = _g("arm_length","armLength")
    if ar: b[6] = (ar - 65.0) / 4.0
    lg = _g("leg_length","legLength")
    if lg: b[7] = (lg - 95.0) / 5.0
    nk = _g("neck")
    if nk: b[8] = (nk - 38.0) / 3.0
    th = _g("thigh")
    if th: b[9] = (th - 56.0) / 4.0
    return [max(-3.0, min(3.0, x)) for x in b]

def _fallback_measurements(height, weight, gender) -> dict:
    bmi = weight / (height/100)**2
    m = gender.lower() == "male"
    return {
        "chest":         round(height*(0.565 if m else 0.535)*(1+max(0,bmi-22)*0.008), 1),
        "waist":         round(height*(0.46  if m else 0.42) *(1+max(0,bmi-22)*0.012), 1),
        "hips":          round(height*(0.53  if m else 0.56) *(1+max(0,bmi-22)*0.010), 1),
        "shoulderWidth": round(height*(0.26  if m else 0.24), 1),
        "armLength":     round(height*(0.39  if m else 0.38), 1),
        "inseam":        round(height*(0.46  if m else 0.45), 1),
        "thigh":         round(max((50+(weight-70)*0.2) if m else (52+(weight-60)*0.25), 38.0), 1),
    }

def _run_smplx(betas, gender):
    import torch
    g = gender.lower()
    if g not in ("male","female","neutral"): g = "neutral"
    model = _smplx_module.create(
        model_path=str(SMPLX_MODEL_DIR), model_type="smplx", gender=g,
        use_pca=False, num_betas=10, batch_size=1, flat_hand_mean=True,
    ).to(torch.device("cpu"))

    # ── Natural pose: arms lowered toward body ───────────────────────────────
    # SMPL-X body_pose has 21 joints × 3 axis-angle values = 63 floats.
    # Joint indices (0-based): 16=left shoulder, 17=right shoulder
    #                           18=left elbow,   19=right elbow
    # Positive Z-rotation lowers the left arm; negative Z lowers the right.
    body_pose = torch.zeros(1, 63, dtype=torch.float32)
    # Left shoulder — rotate arm DOWN toward body
    body_pose[0, 16*3 + 2] =  1.2   # left  shoulder Z
    body_pose[0, 16*3 + 1] =  0.2   # left  shoulder Y (slight forward)
    # Right shoulder — MIRROR of left (opposite sign on Z and Y)
    body_pose[0, 17*3 + 2] = -1.2   # right shoulder Z
    body_pose[0, 17*3 + 1] = -0.2   # right shoulder Y (slight forward)
    # Left elbow — natural slight bend
    body_pose[0, 18*3 + 2] =  0.3   # left  elbow Z
    # Right elbow — MIRROR of left
    body_pose[0, 19*3 + 2] = -0.3   # right elbow Z
    # Wrists — straighten
    body_pose[0, 20*3 + 2] = -0.1   # left  wrist Z
    body_pose[0, 21*3 + 2] =  0.1   # right wrist Z
    # ────────────────────────────────────────────────────────────────────────

    with torch.no_grad():
        out = model(
            betas=torch.tensor([betas], dtype=torch.float32),
            body_pose=body_pose,
            return_verts=True,
        )
    return out.vertices.detach().cpu().numpy().squeeze(), model.faces.astype(np.int32)

def _scale_to_height(v, h_cm):
    cur = float(v[:,1].max() - v[:,1].min())
    if cur < 1e-6: return v
    v = v * ((h_cm/100.0) / cur)
    v[:,1] -= v[:,1].min()
    return v

def _parse_uv_obj(path):
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

def _build_textured_glb(verts, faces, skin_tone: str = "medium", gender: str = "neutral") -> bytes:
    import trimesh
    # smplx_uv.png is a UV wireframe map (nearly black, max≈51/255).
    # We always use vertex-colour rendering with the requested skin tone.
    mesh = _build_vertex_colour_mesh(verts, faces, skin_tone, gender)
    with tempfile.NamedTemporaryFile(suffix=".glb", delete=False) as tmp:
        tp = tmp.name
    try:
        mesh.export(tp, file_type="glb")
        return Path(tp).read_bytes()
    finally:
        try: os.unlink(tp)
        except: pass

def _build_uv_mesh(verts, faces):
    import trimesh
    from PIL import Image
    vt, fv, fvt = _parse_uv_obj(UV_OBJ_PATH)
    nv, nuv = len(verts), len(vt)
    ok = ((fv[:,0]<nv)&(fv[:,1]<nv)&(fv[:,2]<nv)
         &(fvt[:,0]<nuv)&(fvt[:,1]<nuv)&(fvt[:,2]<nuv))
    fv, fvt = fv[ok], fvt[ok]
    n = len(fv)
    nv2  = verts[fv.reshape(-1)]
    nuv2 = vt[fvt.reshape(-1)]
    nf   = np.arange(n*3, dtype=np.int32).reshape(n,3)
    nuv2[:,1] = 1.0 - nuv2[:,1]
    tex = Image.open(UV_TEXTURE_PATH).convert("RGBA")
    # Warm skin-tone diffuse so the material reads correctly under any lighting
    mat = trimesh.visual.material.SimpleMaterial(
        image=tex,
        diffuse=[210, 160, 120, 255],   # warm medium skin tone
        ambient=[180, 130, 100, 255],
    )
    vis = trimesh.visual.TextureVisuals(uv=nuv2, material=mat)
    return trimesh.Trimesh(vertices=nv2, faces=nf, visual=vis, process=False)

def _build_vertex_colour_mesh(verts, faces, skin_tone: str = "medium", gender: str = "neutral"):
    import trimesh
    color = np.array(SKIN_TONES.get(skin_tone, SKIN_TONES["medium"]), dtype=np.uint8)
    n = len(verts)
    colors = np.tile(color, (n, 1)).astype(np.uint8)
    colors = _apply_face_details(verts, colors, skin_tone, gender)
    mesh = trimesh.Trimesh(vertices=verts, faces=faces, process=False)
    mesh.visual = trimesh.visual.ColorVisuals(
        mesh=mesh,
        vertex_colors=colors,
    )
    return mesh


# Face-region colour palette — each skin tone has 4 anatomical zones
_FACE_COLORS: dict = {
    "light": {
        "base":       [255, 220, 185, 255],
        "eye_socket": [220, 185, 155, 255],
        "lips":       [210, 140, 130, 255],
        "nose":       [245, 210, 175, 255],
    },
    "medium": {
        "base":       [210, 168, 130, 255],
        "eye_socket": [175, 130, 100, 255],
        "lips":       [180, 100,  90, 255],
        "nose":       [220, 175, 138, 255],
    },
    "brown": {
        "base":       [180, 120,  80, 255],
        "eye_socket": [145,  90,  55, 255],
        "lips":       [150,  75,  65, 255],
        "nose":       [190, 130,  88, 255],
    },
    "dark": {
        "base":       [110,  70,  45, 255],
        "eye_socket": [ 80,  48,  28, 255],
        "lips":       [ 90,  50,  45, 255],
        "nose":       [120,  78,  50, 255],
    },
}


def _apply_face_details(
    mesh_vertices: np.ndarray,
    colors: np.ndarray,
    skin_tone: str,
    gender: str,
) -> np.ndarray:
    """
    Paint face/head vertices with anatomically correct zone colours.
    Identifies face zones purely from 3D vertex positions (Y=height, Z=forward).
    """
    fc = _FACE_COLORS.get(skin_tone, _FACE_COLORS["medium"])
    v  = mesh_vertices

    y_min   = float(v[:, 1].min())
    y_max   = float(v[:, 1].max())
    y_range = y_max - y_min
    if y_range < 1e-6:
        return colors

    # ── 1. Head region: top 15% of total mesh height ────────────────────────────
    head_mask = v[:, 1] > (y_min + y_range * 0.85)
    if not head_mask.any():
        return colors

    # ── 2. Face region: head verts on the front face (+Z side) ─────────────────
    # Use p75 of head-Z to cut away back-of-head; ears sit wide on X, not deep on Z
    z_p75     = float(np.percentile(v[head_mask, 2], 75))
    face_mask = head_mask & (v[:, 2] > z_p75)
    if not face_mask.any():
        return colors

    # ── 3. Normalise Y within the face region ────────────────────────────────
    face_verts   = v[face_mask]
    y_face_min   = float(face_verts[:, 1].min())
    y_face_max   = float(face_verts[:, 1].max())
    y_face_range = y_face_max - y_face_min
    if y_face_range < 1e-6:
        return colors

    # y_norm: 0 = chin, 1 = forehead (applied to ALL vertices; only face_mask ones used)
    y_norm = (v[:, 1] - y_face_min) / y_face_range

    # x_thresh derived from face verts' own X spread — excludes ear verts (filtered by Z)
    x_face_half = float(np.percentile(np.abs(face_verts[:, 0]), 90))  # robust half-width
    x_thresh    = x_face_half * 0.55   # central column ≈ nose + inner eye

    # ── 4. Sub-region masks ─────────────────────────────────────────────────
    # Eye sockets: upper face (sparse band), all lateral positions
    eye_mask = (
        face_mask
        & (y_norm > 0.55) & (y_norm < 0.85)
    )
    # Lips: lower face, narrow central column (below nose)
    lip_mask = (
        face_mask
        & (y_norm > 0.12) & (y_norm < 0.30)
        & (np.abs(v[:, 0]) < x_thresh * 1.5)
    )
    # Nose: mid face, tightest central column
    nose_mask = (
        face_mask
        & (y_norm > 0.30) & (y_norm < 0.58)
        & (np.abs(v[:, 0]) < x_thresh * 0.8)
    )

    # Eyebrow: above eyes, lateral band (slightly darker than skin)
    EYEBROW_COLORS = {
        "light":  [ 80,  55,  35, 255],
        "medium": [ 60,  40,  25, 255],
        "brown":  [ 45,  28,  15, 255],
        "dark":   [ 25,  15,   8, 255],
    }
    eyebrow_mask = (
        face_mask
        & (y_norm > 0.76) & (y_norm < 0.84)
        & (np.abs(v[:, 0]) > x_thresh * 0.8)
        & (np.abs(v[:, 0]) < x_thresh * 2.0)
    )

    # Sclera (white of eye): forward-facing, lateral to nose, within eye band
    z_face_mean = float(v[face_mask, 2].mean())
    sclera_mask = (
        face_mask
        & (y_norm > 0.58) & (y_norm < 0.76)
        & (np.abs(v[:, 0]) > x_thresh * 1.0)
        & (np.abs(v[:, 0]) < x_thresh * 2.2)
        & (v[:, 2] > z_face_mean * 1.05)
    )

    # Pupil/iris: tighter central eye zone, most forward verts
    pupil_mask = (
        face_mask
        & (y_norm > 0.61) & (y_norm < 0.73)
        & (np.abs(v[:, 0]) > x_thresh * 1.2)
        & (np.abs(v[:, 0]) < x_thresh * 1.8)
        & (v[:, 2] > z_face_mean * 1.08)
    )

    # ── 5. Paint: base face first, then overwrite sub-regions ──────────────────
    colors[face_mask]    = np.array(fc["base"],       dtype=np.uint8)
    colors[eye_mask]     = np.array(fc["eye_socket"], dtype=np.uint8)
    colors[lip_mask]     = np.array(fc["lips"],       dtype=np.uint8)
    colors[nose_mask]    = np.array(fc["nose"],       dtype=np.uint8)
    colors[eyebrow_mask] = np.array(EYEBROW_COLORS.get(skin_tone, EYEBROW_COLORS["medium"]), dtype=np.uint8)
    colors[sclera_mask]  = np.array([245, 245, 245, 255], dtype=np.uint8)
    colors[pupil_mask]   = np.array([ 40,  30,  20, 255], dtype=np.uint8)

    logger.debug(
        "Face details: head=%d face=%d eye=%d lip=%d nose=%d eyebrow=%d sclera=%d pupil=%d verts",
        head_mask.sum(), face_mask.sum(), eye_mask.sum(),
        lip_mask.sum(), nose_mask.sum(), eyebrow_mask.sum(),
        sclera_mask.sum(), pupil_mask.sum(),
    )
    return colors
