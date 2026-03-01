"""
Pydantic models for API requests and responses
"""

from pydantic import BaseModel, Field
from typing import Dict, List, Optional
from datetime import datetime


class NutritionData(BaseModel):
    """Nutrition tracking data"""
    carbs: float = Field(..., description="Total carbohydrates consumed in grams")
    protein: float = Field(..., description="Total protein consumed in grams")
    fats: float = Field(..., description="Total fats consumed in grams")
    caloriesBurned: float = Field(0, description="Calories burned through exercise")


class AvatarGenerationRequest(BaseModel):
    """Request model for avatar generation"""
    user_id: str = Field(..., alias="userId", description="User ID")
    height: float = Field(..., gt=0, description="Height in cm")
    weight: float = Field(..., gt=0, description="Weight in kg")
    age: int = Field(25, description="Age in years")
    gender: str = Field("male", description="Gender: male or female")
    body_fat_percentage: float = Field(15.0, alias="bodyFatPercentage", description="Body fat percentage")
    ml_kit_landmarks: Optional[Dict] = Field(None, alias="mlKitLandmarks", description="ML Kit pose landmarks")
    measurements: Optional[Dict] = Field(
        None,
        description="Body measurements: {chest, waist, hips} in cm"
    )
    skin_tone: Optional[str] = Field(
        "medium",
        alias="skinTone",
        description="Skin tone: light | medium | tan | dark"
    )
    clothing_style: Optional[str] = Field(
        "athletic",
        alias="clothingStyle",
        description="Clothing style: athletic | casual | formal"
    )
    hair_color: Optional[str] = Field(
        "black",
        alias="hairColor",
        description="Hair colour: black | brown | blonde"
    )
    clothing_colors: Optional[Dict[str, str]] = Field(
        None,
        alias="clothingColors",
        description="Legacy field — kept for compatibility"
    )
    
    class Config:
        populate_by_name = True  # Allow both snake_case and camelCase


class PhysiqueUpdateRequest(BaseModel):
    """Request model for physique update"""
    user_id: str = Field(..., alias="userId", description="User ID")
    current_day: int = Field(..., alias="currentDay", gt=0, description="Current day number")
    current_weight: float = Field(..., alias="currentWeight", gt=0, description="Current weight in kg")
    current_body_fat_percentage: float = Field(..., alias="currentBodyFatPercentage", description="Current body fat %")
    nutrition_data: Dict = Field(..., alias="nutritionData", description="Nutrition data (calories, protein, carbs, fats)")
    exercise_data: Dict = Field(default_factory=dict, alias="exerciseData", description="Exercise data (calories_burned)")
    gender: str = Field("male", description="Gender")
    current_height: Optional[float] = Field(None, alias="currentHeight", description="Height in cm")
    age: Optional[int] = Field(None, description="Age in years")
    skin_tone: Optional[str] = Field("medium", alias="skinTone")
    clothing_style: Optional[str] = Field("athletic", alias="clothingStyle")
    clothing_colors: Optional[Dict[str, str]] = Field(
        None,
        alias="clothingColors",
        description="Legacy field — kept for compatibility"
    )
    
    class Config:
        populate_by_name = True


class AvatarResponse(BaseModel):
    """Response model for avatar generation"""
    success: bool
    user_id: str = Field(..., alias="userId")
    model_url: str = Field(..., alias="modelUrl", description="URL to 3D model (GLB format)")
    thumbnail_url: str = Field(..., alias="thumbnailUrl", description="URL to avatar thumbnail")
    initial_measurements: Optional[Dict] = Field(None, alias="initialMeasurements", description="Initial body measurements")
    message: str = Field(..., description="Status message")
    
    class Config:
        populate_by_name = True


class PhysiqueUpdateResponse(BaseModel):
    """Response model for physique update"""
    success: bool
    user_id: str = Field(..., alias="userId")
    model_url: str = Field(..., alias="modelUrl", description="URL to updated 3D model")
    thumbnail_url: str = Field(..., alias="thumbnailUrl", description="URL to updated thumbnail")
    updated_measurements: Dict = Field(..., alias="updatedMeasurements", description="Updated body measurements")
    changes: Dict = Field(..., description="Body composition changes")
    message: str
    day: int
    
    class Config:
        populate_by_name = True


class ProgressSnapshot(BaseModel):
    """Single progress snapshot"""
    day: int
    modelUrl: str
    thumbnailUrl: str
    weight: float
    bodyFatPercentage: float


class ProgressAnalysisResponse(BaseModel):
    """Response model for progress analysis"""
    success: bool
    user_id: str = Field(..., alias="userId")
    total_days: int = Field(..., alias="totalDays")
    history: List[Dict]
    summary: Dict
    
    class Config:
        populate_by_name = True


class ErrorResponse(BaseModel):
    """Error response model"""
    status: str = "error"
    message: str
    detail: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)
