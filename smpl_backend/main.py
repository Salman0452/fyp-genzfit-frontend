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

import numpy as np
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel, Field, ConfigDict

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# --- Paths ---
SMPLX_MODEL_DIR = Path(__file__).parent / "models"
UV_OBJ_PATH     = Path(__file__).parent / "models" / "uv" / "smplx_uv.obj"
UV_TEXTURE_PATH = Path(__file__).parent / "models" / "uv" / "smplx_uv.png"
CACHE_DIR       = Path(os.getenv("CACHE_DIR", str(Path(__file__).parent / "cache" / "glb")))
CACHE_DIR.mkdir(parents=True, exist_ok=True)

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
    body_measurements: Optional[dict] = Field(None, description="Anthropometric measurements in cm")

class AvatarResponse(BaseModel):
    model_config = ConfigDict(protected_namespaces=())
    user_id: str
    model_base64: str
    betas: list
    body_measurements: dict
    pipeline: str
    message: str = "OK"

class HealthResponse(BaseModel):
    model_config = ConfigDict(protected_namespaces=())
    status: str
    smplx_available: bool
    model_dir_exists: bool
    uv_files_exist: bool

# --- Health endpoint ---
@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(
        status="ok", smplx_available=_SMPLX_AVAILABLE,
        model_dir_exists=(SMPLX_MODEL_DIR / "smplx").exists(),
        uv_files_exist=(UV_OBJ_PATH.exists() and UV_TEXTURE_PATH.exists()),
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
        glb = _build_textured_glb(verts, faces)
        pipeline = "SMPL-X"
    else:
        from services.mesh_generator import generate_mesh
        glb = generate_mesh(betas=betas, height_cm=req.height, gender=req.gender,
                            measurements={**meas, "weight": req.weight})
        pipeline = "geometric-fallback"

    # Cache
    if req.user_id:
        cache_key = f"{req.user_id}_{snap_date}"
        glb_path  = CACHE_DIR / f"{cache_key}.glb"
        glb_path.write_bytes(glb)
        snap = {"date": snap_date, "betas": betas, "measurements": meas, "glb_path": str(glb_path)}
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
        message=f"Avatar generated using {pipeline} pipeline.",
    )

@app.get("/avatar/{user_id}/history")
def get_avatar_history(user_id: str):
    return [{"date": s["date"], "betas": s["betas"], "measurements": s["measurements"]}
            for s in _avatar_store.get(user_id, [])]

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
        model_path=str(SMPLX_MODEL_DIR), model_type="smplx", gender=g,  # models/ parent; smplx.create() finds smplx/ subfolder automatically
        use_pca=False, num_betas=10, batch_size=1, flat_hand_mean=True,
    ).to(torch.device("cpu"))
    with torch.no_grad():
        out = model(betas=torch.tensor([betas], dtype=torch.float32), return_verts=True)
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

def _build_textured_glb(verts, faces) -> bytes:
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
    mat = trimesh.visual.material.SimpleMaterial(image=tex)
    vis = trimesh.visual.TextureVisuals(uv=nuv2, material=mat)
    return trimesh.Trimesh(vertices=nv2, faces=nf, visual=vis, process=False)

def _build_vertex_colour_mesh(verts, faces):
    import trimesh
    mesh = trimesh.Trimesh(vertices=verts, faces=faces, process=False)
    mesh.visual.vertex_colors = np.tile([210,160,120,255], (len(verts),1)).astype(np.uint8)
    return mesh
