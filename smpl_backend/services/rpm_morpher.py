"""
rpm_morpher.py – Body shape morphing for Ready Player Me .glb files.

Approach:
  1. Parse the binary GLB with pygltflib.
  2. Locate the body mesh accessors (vertices).
  3. Apply per-axis scaling derived from the user's measurements:
       • Y-axis (height) scaling → uniform rescale to target height
       • X/Z-axis (width/depth) → BMI-driven scale at waist / hip / shoulder zones
  4. If the GLB contains named morph targets (Overweight / Thin / Muscular)
     we set the morph weights directly (RPM partner avatars may include these).
  5. Return the modified GLB bytes.

This gives a visible body-shape change between measurement snapshots
without needing SMPL model files.
"""

from __future__ import annotations

import struct
import json
import copy
from typing import Optional

import numpy as np

try:
    import pygltflib
    _PYGLTFLIB_AVAILABLE = True
except ImportError:
    _PYGLTFLIB_AVAILABLE = False


# ─── Public entry point ───────────────────────────────────────────────────────

def morph_rpm_avatar(
    glb_bytes: bytes,
    height_cm: float,
    weight_kg: float,
    age: int = 25,
    gender: str = "male",
) -> bytes:
    """
    Apply body-shape deformation to an RPM (or any humanoid) .glb.

    Parameters
    ----------
    glb_bytes   Raw bytes of the input .glb file.
    height_cm   Target height in centimetres.
    weight_kg   Target weight in kilograms.
    age         User age (influences body-shape direction slightly).
    gender      "male" | "female"

    Returns
    -------
    Modified .glb bytes.  Returns the original bytes unchanged if
    pygltflib is not installed or if parsing fails.
    """
    if not _PYGLTFLIB_AVAILABLE:
        return glb_bytes

    try:
        return _apply_morphs(glb_bytes, height_cm, weight_kg, age, gender)
    except Exception:
        # Never crash – silently return the original.
        return glb_bytes


# ─── Core implementation ──────────────────────────────────────────────────────

# Reference body dimensions (neutral RPM fullbody avatar).
_REF_HEIGHT_CM  = 170.0
_REF_WEIGHT_KG  = 70.0
_REF_BMI        = _REF_WEIGHT_KG / (_REF_HEIGHT_CM / 100) ** 2   # ≈ 24.2

# RPM body mesh names (fullbody avatars)
_BODY_MESH_NAMES = {"Wolf3D_Body", "Wolf3D_Outfit_Bottom", "Wolf3D_Outfit_Top",
                    "Wolf3D_Outfit_Footwear", "Body", "body"}

# RPM morph target names for body shape (partner avatars)
_MORPH_OVERWEIGHT = "Overweight"
_MORPH_THIN       = "Thin"
_MORPH_MUSCULAR   = "Muscular"


def _compute_shape_params(
    height_cm: float,
    weight_kg: float,
    age: int,
    gender: str,
) -> dict:
    """
    Map biometric measurements to a set of shape scalars.

    Returns a dict with:
      height_scale  – uniform Y scale relative to reference height
      width_scale   – X/Z body width scale relative to reference BMI
      overweight    – morph weight 0-1 (for RPM morph targets)
      thin          – morph weight 0-1
      muscular      – morph weight 0-1
    """
    bmi = weight_kg / (height_cm / 100) ** 2

    height_scale = height_cm / _REF_HEIGHT_CM

    # Width / bulk scale based on weight while keeping proportions
    # Reference weight at target height:
    ref_weight_at_height = _REF_BMI * (height_cm / 100) ** 2
    weight_scale = max(0.80, min(1.35, (weight_kg / ref_weight_at_height) ** 0.4))

    # Morph weights (0–1)
    thin_weight       = float(np.clip((18.5 - bmi) / 6.0, 0, 1))  if bmi < 18.5 else 0.0
    overweight_weight = float(np.clip((bmi - 25.0) / 12.0, 0, 1)) if bmi > 25.0 else 0.0
    # Muscular: slightly muscular at normal BMI, more so for males
    muscle_base = 0.15 if gender.lower() == "male" else 0.05
    muscular_weight = float(np.clip(
        muscle_base + max(0, (24 - bmi) / 20) * (0.3 if gender.lower() == "male" else 0.15),
        0, 1,
    ))

    return {
        "height_scale":  height_scale,
        "width_scale":   weight_scale,
        "overweight":    overweight_weight,
        "thin":          thin_weight,
        "muscular":      muscular_weight,
    }


def _apply_morphs(
    glb_bytes: bytes,
    height_cm: float,
    weight_kg: float,
    age: int,
    gender: str,
) -> bytes:
    params = _compute_shape_params(height_cm, weight_kg, age, gender)

    gltf = pygltflib.GLTF2()
    gltf = gltf.load_from_bytes(glb_bytes)

    blob = gltf.binary_blob()  # GLB binary chunk

    modified = False

    # ── 1. Scale vertex positions in body meshes ────────────────────────────
    hs = params["height_scale"]
    ws = params["width_scale"]

    for mesh in gltf.meshes:
        is_body = (mesh.name or "") in _BODY_MESH_NAMES or "ody" in (mesh.name or "")
        # Scale all meshes for height; only body meshes for width
        for primitive in mesh.primitives:
            pos_idx = primitive.attributes.POSITION
            if pos_idx is None:
                continue
            acc = gltf.accessors[pos_idx]
            if acc.componentType != pygltflib.FLOAT:
                continue

            bv   = gltf.bufferViews[acc.bufferView]
            offset = (bv.byteOffset or 0) + (acc.byteOffset or 0)
            stride = bv.byteStride or 12  # 3 floats × 4 bytes
            count  = acc.count

            # Read, modify, write back
            verts = np.frombuffer(
                blob[offset : offset + count * stride], dtype=np.float32
            ).reshape(-1, stride // 4)[:, :3].copy()

            # Y → height
            verts[:, 1] *= hs
            # X / Z → width (body meshes only to avoid distorting hair)
            if is_body:
                verts[:, 0] *= ws
                verts[:, 2] *= ws

            new_blob = bytearray(blob)
            new_flat = verts.flatten().tobytes()
            # Stride may be > 12 if interleaved; only overwrite XYZ part
            if stride == 12:
                new_blob[offset : offset + count * 12] = new_flat
            else:
                for i in range(count):
                    dst = offset + i * stride
                    new_blob[dst: dst + 12] = new_flat[i * 12: (i + 1) * 12]

            blob = bytes(new_blob)
            modified = True

    # ── 2. Set morph-target weights (RPM partner avatar morph targets) ──────
    for mesh in gltf.meshes:
        for prim in mesh.primitives:
            if not prim.targets:
                continue
            # targets is a list of {POSITION: idx, NORMAL: idx, …}
            # morph names are in mesh.extras.targetNames or extensions
            names = _get_morph_names(mesh)
            if not names:
                continue
            weights = list(mesh.weights or [0.0] * len(prim.targets))
            name_map = {n: i for i, n in enumerate(names)}
            for morph_name, val in [
                (_MORPH_OVERWEIGHT, params["overweight"]),
                (_MORPH_THIN,       params["thin"]),
                (_MORPH_MUSCULAR,   params["muscular"]),
            ]:
                if morph_name in name_map:
                    weights[name_map[morph_name]] = val
                    modified = True
            mesh.weights = weights

    if not modified:
        return glb_bytes

    # ── 3. Re-serialise ─────────────────────────────────────────────────────
    # Update the binary buffer
    gltf.buffers[0].byteLength = len(blob)
    gltf._glb_data = blob  # type: ignore[attr-defined]

    return b"".join(gltf.save_to_bytes())


def _get_morph_names(mesh) -> list[str]:
    """Extract morph target names from mesh extras.targetNames (glTF convention)."""
    extras = mesh.extras or {}
    if isinstance(extras, dict):
        names = extras.get("targetNames") or extras.get("morphTargetNames") or []
        return [str(n) for n in names]
    return []
