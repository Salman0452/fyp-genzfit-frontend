"""
landmark_mapper.py
──────────────────
Converts ML Kit Pose Detection landmarks (33 keypoints) into normalised
body-shape ratios, which are then fed to beta_converter.py.

ML Kit landmark names used (from PoseLandmarkType):
  nose, leftEye, rightEye, leftEar, rightEar,
  leftShoulder, rightShoulder,
  leftElbow, rightElbow,
  leftWrist, rightWrist,
  leftHip, rightHip,
  leftKnee, rightKnee,
  leftAnkle, rightAnkle
"""

from __future__ import annotations

import math
from typing import Dict, Optional


# ─── helpers ──────────────────────────────────────────────────────────────────

def _dist(a: dict, b: dict) -> float:
    """Euclidean distance between two landmark dicts {x, y, z}."""
    return math.sqrt(
        (a["x"] - b["x"]) ** 2
        + (a["y"] - b["y"]) ** 2
        + (a.get("z", 0) - b.get("z", 0)) ** 2
    )


def _midpoint(a: dict, b: dict) -> dict:
    return {
        "x": (a["x"] + b["x"]) / 2,
        "y": (a["y"] + b["y"]) / 2,
        "z": (a.get("z", 0) + b.get("z", 0)) / 2,
    }


def _confidence(lm: dict) -> float:
    return lm.get("likelihood", 1.0)


# ─── main extractor ───────────────────────────────────────────────────────────

def extract_proportions(
    landmarks: Dict[str, dict],
    height_cm: float,
    weight_kg: float,
) -> Dict[str, float]:
    """
    Returns a dict of normalised proportions that describe body shape.
    All distances are expressed as fractions of the full-body pixel span
    (nose-to-ankle), so they are resolution-independent.

    Keys returned:
      shoulder_width_ratio   – inter-shoulder / body_span
      hip_width_ratio        – inter-hip / body_span
      torso_ratio            – shoulder_mid-to-hip_mid / body_span
      left_upper_arm_ratio
      left_forearm_ratio
      left_thigh_ratio
      left_shin_ratio
      shoulder_hip_ratio     – shoulder_width / hip_width  (V-taper)
      waist_rib_factor       – estimated waist proportionality
    """

    lm = landmarks  # shorthand

    # ── require these for a meaningful result ──────────────────────────────
    required = [
        "leftShoulder", "rightShoulder",
        "leftHip", "rightHip",
        "nose",
        "leftAnkle",  "rightAnkle",
    ]
    for key in required:
        if key not in lm or _confidence(lm[key]) < 0.3:
            # Not enough pose data – return empty so the caller falls back to
            # anthropometric-only computation.
            return {}

    # ── body span (full height proxy in pixels) ───────────────────────────
    ankle_mid = _midpoint(lm["leftAnkle"], lm["rightAnkle"])
    body_span = _dist(lm["nose"], ankle_mid)

    if body_span < 1e-6:
        return {}

    def ratio(a_key: str, b_key: str) -> Optional[float]:
        a, b = lm.get(a_key), lm.get(b_key)
        if a is None or b is None:
            return None
        if _confidence(a) < 0.3 or _confidence(b) < 0.3:
            return None
        return _dist(a, b) / body_span

    props: Dict[str, float] = {}

    # ── width ratios ───────────────────────────────────────────────────────
    sw = ratio("leftShoulder", "rightShoulder")
    hw = ratio("leftHip", "rightHip")

    if sw:
        props["shoulder_width_ratio"] = sw
    if hw:
        props["hip_width_ratio"] = hw
    if sw and hw and hw > 1e-6:
        props["shoulder_hip_ratio"] = sw / hw   # V-taper indicator

    # ── torso length ──────────────────────────────────────────────────────
    sh_mid = _midpoint(lm["leftShoulder"], lm["rightShoulder"])
    hip_mid = _midpoint(lm["leftHip"], lm["rightHip"])
    props["torso_ratio"] = _dist(sh_mid, hip_mid) / body_span

    # ── arm segments ──────────────────────────────────────────────────────
    for side_prefix, sh, el, wr in [
        ("left", "leftShoulder", "leftElbow", "leftWrist"),
        ("right", "rightShoulder", "rightElbow", "rightWrist"),
    ]:
        ua = ratio(sh, el)
        fa = ratio(el, wr)
        if ua:
            props[f"{side_prefix}_upper_arm_ratio"] = ua
        if fa:
            props[f"{side_prefix}_forearm_ratio"] = fa

    # ── leg segments ──────────────────────────────────────────────────────
    for side_prefix, hip, knee, ankle in [
        ("left", "leftHip", "leftKnee", "leftAnkle"),
        ("right", "rightHip", "rightKnee", "rightAnkle"),
    ]:
        th = ratio(hip, knee)
        sh_ = ratio(knee, ankle)
        if th:
            props[f"{side_prefix}_thigh_ratio"] = th
        if sh_:
            props[f"{side_prefix}_shin_ratio"] = sh_

    # ── symmetry score ────────────────────────────────────────────────────
    # A well-lit full-body photo has near-perfect bilateral symmetry.
    # We use this as a proxy for pose quality.
    sym_pairs = [
        ("left_upper_arm_ratio", "right_upper_arm_ratio"),
        ("left_forearm_ratio",   "right_forearm_ratio"),
        ("left_thigh_ratio",     "right_thigh_ratio"),
        ("left_shin_ratio",      "right_shin_ratio"),
    ]
    sym_scores = []
    for k_l, k_r in sym_pairs:
        if k_l in props and k_r in props and props[k_r] > 1e-6:
            ratio_val = props[k_l] / props[k_r]
            # score close to 1.0 → symmetric
            sym_scores.append(1.0 - abs(ratio_val - 1.0))
    if sym_scores:
        props["symmetry_score"] = sum(sym_scores) / len(sym_scores)

    return props
