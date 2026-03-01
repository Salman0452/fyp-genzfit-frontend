from pydantic import BaseModel, Field
from typing import Optional, Dict, List


class LandmarkPoint(BaseModel):
    x: float
    y: float
    z: float
    likelihood: float = 1.0


class GenerateAvatarRequest(BaseModel):
    """Request body for POST /generate-avatar"""

    # User identity
    user_id: str
    date: Optional[str] = None  # ISO date string, e.g. "2026-03-01"

    # Core biometrics (required)
    height: float = Field(..., description="Height in cm")
    weight: float = Field(..., description="Weight in kg")
    age: int = Field(..., ge=10, le=100)
    gender: str = Field(..., pattern="^(male|female)$")

    # ML Kit landmarks (optional – improves shape accuracy when provided)
    landmarks: Optional[Dict[str, LandmarkPoint]] = None

    # Pre-computed anthropometric measurements from Flutter side (optional)
    measurements: Optional[Dict[str, float]] = None

    # Texture preference
    skin_tone: Optional[str] = Field(
        default="medium",
        description="Skin tone: light | medium | dark | brown",
    )
    show_muscles: bool = True


class BetaValues(BaseModel):
    """SMPL / SMPL-X shape parameters (10 betas)"""

    betas: List[float] = Field(..., min_length=10, max_length=10)


class GenerateAvatarResponse(BaseModel):
    """Response from POST /generate-avatar"""
    model_config = {'protected_namespaces': ()}

    user_id: str
    model_url: Optional[str] = None  # URL to download .glb (when hosted)
    model_base64: Optional[str] = None  # base64-encoded .glb bytes (when embedded)
    betas: List[float]
    body_measurements: Dict[str, float]
    generation_time_ms: float
    message: str = "OK"


class ProgressSnapshotRequest(BaseModel):
    """Compare any two dates' stored beta parameters"""

    user_id: str
    date_a: str
    date_b: str


class HealthResponse(BaseModel):
    status: str
    smplx_available: bool
    gpu_available: bool
