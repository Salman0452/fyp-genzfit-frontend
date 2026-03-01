"""
mesh_generator.py
─────────────────
Generates a 3D body mesh from SMPL beta values.

Strategy (in priority order):
  1. SMPL-X Python package  – highest quality, requires model files from
       https://smpl-x.is.tue.mpg.de  (free academic registration)
  2. trimesh capsule mesh    – fallback using geometric primitives.
"""

from __future__ import annotations

import io
import math
import os
import struct
import tempfile
from pathlib import Path
from typing import List, Optional, Tuple

import numpy as np
import trimesh
from trimesh import transformations

# ─── SMPL-X availability detection ────────────────────────────────────────────
try:
    import torch
    import smplx as _smplx_module

    _SMPLX_AVAILABLE = True
except ImportError:          # noqa: BLE001
    _SMPLX_AVAILABLE = False

# Path where SMPL-X model files are placed
SMPLX_MODEL_PATH = Path(os.getenv("SMPLX_MODEL_PATH", str(Path(__file__).parent.parent / "models")))


# ─── Public API ───────────────────────────────────────────────────────────────

def generate_mesh(
    betas: List[float],
    height_cm: float,
    gender: str,
    skin_tone: str = "medium",
    show_muscles: bool = True,
    measurements: Optional[dict] = None,
) -> bytes:
    """
    Generate a GLB body mesh.

    Priority:
      1. SMPL-X (if package + model files present)
      2. Capsule/cylinder fallback

    Returns raw GLB bytes.
    """

    # ── Tier 1: SMPL-X ────────────────────────────────────────────────────
    if _SMPLX_AVAILABLE and (SMPLX_MODEL_PATH / "smplx").exists():
        return _generate_smplx_glb(betas, height_cm, gender, skin_tone, show_muscles)

    # ── Tier 2: Capsule fallback ───────────────────────────────────────────
    return _generate_capsule_glb(betas, height_cm, gender, skin_tone, show_muscles)


# ─── SMPL-X path ──────────────────────────────────────────────────────────────

def _generate_smplx_glb(
    betas: List[float],
    height_cm: float,
    gender: str,
    skin_tone: str,
    show_muscles: bool,
) -> bytes:
    """Use the official SMPL-X package to generate a clothed-skin mesh."""

    import torch

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    smplx_gender = "male" if gender == "male" else "female"
    model_folder = str(SMPLX_MODEL_PATH)

    model = _smplx_module.create(
        model_folder,
        model_type="smplx",
        gender=smplx_gender,
        use_pca=False,
        num_betas=10,
        batch_size=1,
    ).to(device)

    beta_tensor = torch.tensor([betas], dtype=torch.float32).to(device)
    output = model(betas=beta_tensor, return_verts=True)

    vertices = output.vertices.detach().cpu().numpy().squeeze()   # (N, 3)
    faces    = model.faces.astype(np.int32)                       # (F, 3)

    # Scale to match provided height
    current_height = vertices[:, 1].max() - vertices[:, 1].min()
    target_height  = height_cm / 100.0
    if current_height > 1e-6:
        scale = target_height / current_height
        vertices = vertices * scale

    # Centre at origin, stand upright
    vertices[:, 1] -= vertices[:, 1].min()

    mesh = trimesh.Trimesh(vertices=vertices, faces=faces, process=False)
    _apply_vertex_colors(mesh, skin_tone, show_muscles)

    return _export_glb(mesh)


# ─── Capsule fallback ─────────────────────────────────────────────────────────

def _generate_capsule_glb(
    betas: List[float],
    height_cm: float,
    gender: str,
    skin_tone: str,
    show_muscles: bool,
) -> bytes:
    """
    Build a stylised human body from geometric primitives using trimesh.
    Proportions are driven by the SMPL beta parameters.

    Segment heights and widths are derived from canonical anthropometric
    proportions (as fractions of total height) with beta-driven offsets.
    """

    h = height_cm / 100.0   # total height in metres

    # ── proportion multipliers from betas ─────────────────────────────────
    # β₀ = overall size (already captured by h)
    # β₁ = fatness / volume multiplier
    # β₃ = upper-body muscle
    # β₄ = shoulder breadth
    # β₅ = hip width
    # β₇ = thigh thickness

    fat   = 1.0 + float(np.clip(betas[1], -1.5, 2.5)) * 0.08
    muscl = 1.0 + float(np.clip(betas[3], -1.5, 2.5)) * 0.06
    shld  = 1.0 + float(np.clip(betas[4], -2.0, 3.0)) * 0.05
    hips_ = 1.0 + float(np.clip(betas[5], -1.5, 2.5)) * (0.04 if gender == "female" else 0.02)
    thgh  = 1.0 + float(np.clip(betas[7], -1.5, 2.5)) * 0.06

    gender_hip = 1.10 if gender == "female" else 1.0
    gender_sh  = 1.08 if gender == "male"   else 1.0

    # ── canonical segment dimensions (fraction of total height) ──────────
    segments = _build_body_segments(h, fat, muscl, shld * gender_sh, hips_ * gender_hip, thgh, gender)

    # ── assemble mesh ─────────────────────────────────────────────────────
    mesh = _assemble_mesh(segments)
    _apply_vertex_colors(mesh, skin_tone, show_muscles)

    return _export_glb(mesh)


def _build_body_segments(h, fat, muscl, shld, hips, thgh, gender) -> list:
    """
    Returns list of (trimesh.Trimesh, transform_matrix) to be combined.
    Origin (0,0,0) is at the floor.
    """

    parts = []

    # ── proportional heights from crown ─────────────────────────────────
    # Human body ~7.5 head-heights tall.  Typical fractions from sole:
    #  Sole → ankle top      :  0.04
    #  Ankle top → knee      :  0.23  (shin)
    #  Knee → hip            :  0.28  (thigh)
    #  Hip → navel           :  0.10  (lower torso)
    #  Navel → shoulders     :  0.20  (upper torso)
    #  Shoulders → chin      :  0.07  (neck)
    #  Chin → crown (head)   :  0.13

    sole_y     = 0.0
    ankle_y    = h * 0.04
    knee_y     = h * (0.04 + 0.23)
    hip_y      = h * (0.04 + 0.23 + 0.28)
    navel_y    = h * (0.04 + 0.23 + 0.28 + 0.10)
    shoulder_y = h * (0.04 + 0.23 + 0.28 + 0.10 + 0.20)
    chin_y     = h * (0.04 + 0.23 + 0.28 + 0.10 + 0.20 + 0.07)
    crown_y    = h

    # ── waist & chest radii ───────────────────────────────────────────────
    r_ankle  = h * 0.030 * fat
    r_knee   = h * 0.040 * fat
    r_thigh  = h * 0.072 * thgh * fat
    r_hip    = h * 0.088 * hips * fat
    r_waist  = h * 0.068 * fat
    r_chest  = h * 0.092 * muscl * fat
    r_shld   = h * 0.092 * shld * muscl
    r_neck   = h * 0.030
    r_head   = h * 0.120

    # Arm dimensions
    r_upper_arm = h * 0.040 * muscl * fat
    r_forearm   = h * 0.033 * fat
    arm_upper_len = h * 0.19
    arm_fore_len  = h * 0.16

    def capsule(r1, r2, length, transform):
        """Create a tapered cylinder (frustum) mesh."""
        mesh = trimesh.creation.cone(radius=r1, height=length * 0.001)
        # trimesh doesn't have frustum; use cylinder and scale
        cyl = trimesh.creation.cylinder(radius=(r1 + r2) / 2, height=length, sections=24)
        cyl.apply_transform(transform)
        return cyl

    def cyl(r, length, transform):
        mesh = trimesh.creation.cylinder(radius=r, height=length, sections=24)
        mesh.apply_transform(transform)
        return mesh

    def sphere(r, center):
        s = trimesh.creation.icosphere(subdivisions=3, radius=r)
        s.apply_translation(center)
        return s

    # ── lower legs (both) ─────────────────────────────────────────────────
    shin_h = knee_y - ankle_y
    for sx in [-1, 1]:
        xoff = shld * h * 0.065 * 0.60
        T = transformations.translation_matrix(
            [sx * xoff, ankle_y + shin_h / 2, 0]
        )
        parts.append(cyl(r_ankle * 1.25, shin_h, T))

    # ── upper legs (both) ─────────────────────────────────────────────────
    thigh_h = hip_y - knee_y
    for sx in [-1, 1]:
        xoff = shld * h * 0.065 * 0.75
        T = transformations.translation_matrix(
            [sx * xoff, knee_y + thigh_h / 2, 0]
        )
        parts.append(cyl(r_thigh, thigh_h, T))

    # ── hips / pelvis ─────────────────────────────────────────────────────
    hip_h = navel_y - hip_y
    T = transformations.translation_matrix([0, hip_y + hip_h / 2, 0])
    pelvis = cyl(r_hip, hip_h, T)
    parts.append(pelvis)

    # ── upper torso ───────────────────────────────────────────────────────
    torso_h = shoulder_y - navel_y
    T = transformations.translation_matrix([0, navel_y + torso_h / 2, 0])
    torso = cyl(r_chest, torso_h, T)
    parts.append(torso)

    # ── neck ──────────────────────────────────────────────────────────────
    neck_h = chin_y - shoulder_y
    T = transformations.translation_matrix([0, shoulder_y + neck_h / 2, 0])
    parts.append(cyl(r_neck, neck_h, T))

    # ── head ──────────────────────────────────────────────────────────────
    head_ctr = [0, chin_y + r_head * 0.8, 0]
    parts.append(sphere(r_head, head_ctr))

    # ── arms ──────────────────────────────────────────────────────────────
    for sx in [-1, 1]:
        x_shld = sx * r_shld
        y_shld = shoulder_y - arm_upper_len * 0.05

        # upper arm (hang down from shoulder)
        T_ua = transformations.translation_matrix(
            [x_shld * 1.5, y_shld - arm_upper_len / 2, 0]
        )
        parts.append(cyl(r_upper_arm, arm_upper_len, T_ua))

        # forearm
        elbow_y = y_shld - arm_upper_len
        T_fa = transformations.translation_matrix(
            [x_shld * 1.5, elbow_y - arm_fore_len / 2, 0]
        )
        parts.append(cyl(r_forearm, arm_fore_len, T_fa))

    return parts


def _assemble_mesh(parts: list) -> trimesh.Trimesh:
    """Combine all body parts into a single mesh."""
    combined = trimesh.util.concatenate(parts)
    # Merge close vertices for a cleaner mesh
    combined.merge_vertices()
    return combined


# ─── Vertex colouring ─────────────────────────────────────────────────────────

# Skin tone RGBA values
_SKIN_TONES = {
    "light":  np.array([255, 224, 196, 255], dtype=np.uint8),
    "medium": np.array([210, 160, 120, 255], dtype=np.uint8),
    "brown":  np.array([165, 105,  75, 255], dtype=np.uint8),
    "dark":   np.array([100,  65,  40, 255], dtype=np.uint8),
}

_MUSCLE_HIGHLIGHT = np.array([200, 130, 100, 255], dtype=np.uint8)


def _apply_vertex_colors(mesh: trimesh.Trimesh, skin_tone: str, show_muscles: bool):
    """Paint vertex colours to approximate skin with subtle muscle highlights."""
    base_color = _SKIN_TONES.get(skin_tone, _SKIN_TONES["medium"])
    n = len(mesh.vertices)
    colors = np.tile(base_color, (n, 1))

    if show_muscles:
        # Highlight vertices on the arms/chest area with slightly reddish tone
        # "Arms" are roughly at |x| > 0.15 m on a 1.7 m tall mesh
        verts = mesh.vertices
        max_y  = verts[:, 1].max()
        mask_arm = (
            (np.abs(verts[:, 0]) > max_y * 0.10)
            & (verts[:, 1] > max_y * 0.50)
            & (verts[:, 1] < max_y * 0.85)
        )
        colors[mask_arm] = np.clip(
            colors[mask_arm].astype(int) * 0.90 + _MUSCLE_HIGHLIGHT * 0.10,
            0, 255,
        ).astype(np.uint8)

    mesh.visual.vertex_colors = colors


# ─── GLB export ───────────────────────────────────────────────────────────────

def _export_glb(mesh: trimesh.Trimesh) -> bytes:
    """Export trimesh as GLB bytes."""
    with tempfile.NamedTemporaryFile(suffix=".glb", delete=False) as tmp:
        tmp_path = tmp.name

    try:
        mesh.export(tmp_path, file_type="glb")
        with open(tmp_path, "rb") as f:
            return f.read()
    finally:
        Path(tmp_path).unlink(missing_ok=True)
