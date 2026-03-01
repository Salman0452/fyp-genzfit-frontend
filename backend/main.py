"""
GenzFit 3D Avatar Backend API
FastAPI application for dynamic 3D avatar generation and morphing
"""

from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Dict, List, Optional
import uvicorn
from datetime import datetime
import logging

try:
    from services.smpl_avatar_generator import SMPLAvatarGenerator as AvatarGenerator
    logger_init = logging.getLogger(__name__)
    logger_init.info("✅ Using SMPL-based avatar generator")
except Exception as _smpl_err:
    from services.avatar_generator import AvatarGenerator   # type: ignore
    logger_init = logging.getLogger(__name__)
    logger_init.warning("⚠️  SMPL generator unavailable (%s); falling back to trimesh.", _smpl_err)

from services.body_morpher import BodyMorpher
from services.nutrition_calculator import NutritionCalculator
from services.storage_service import StorageService
from models.avatar_models import (
    AvatarGenerationRequest,
    PhysiqueUpdateRequest,
    AvatarResponse,
    PhysiqueUpdateResponse,
    ProgressAnalysisResponse
)
from utils.firebase_admin import initialize_firebase
from config.settings import get_settings

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize settings
settings = get_settings()

# Initialize Firebase
initialize_firebase()

# Create FastAPI app
app = FastAPI(
    title="GenzFit Avatar API",
    description="Dynamic 3D Avatar Generation & Morphing System",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize services
avatar_generator = AvatarGenerator()
body_morpher = BodyMorpher()
nutrition_calculator = NutritionCalculator()
storage_service = StorageService()


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "GenzFit Avatar API",
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/health")
async def health_check():
    """Detailed health check"""
    return {
        "status": "healthy",
        "services": {
            "avatar_generator": "operational",
            "body_morpher": "operational",
            "nutrition_calculator": "operational",
            "storage": "operational"
        }
    }


@app.post("/api/v1/avatar/generate", response_model=AvatarResponse)
async def generate_avatar(
    request: AvatarGenerationRequest,
    background_tasks: BackgroundTasks
):
    """
    Generate a new 3D avatar from body measurements and ML Kit landmarks
    
    Args:
        request: Avatar generation request with measurements and landmarks
        
    Returns:
        AvatarResponse with model URL and metadata
    """
    try:
        logger.info(f"Generating avatar for user: {request.userId}")
        
        # Validate measurements
        if request.height <= 0 or request.weight <= 0:
            raise HTTPException(
                status_code=400,
                detail="Invalid height or weight values"
            )
        
        # Generate 3D mesh from measurements (SMPL or trimesh fallback)
        mesh_data = avatar_generator.create_from_measurements(
            height=request.height,
            weight=request.weight,
            body_measurements=request.measurements or {},
            ml_landmarks=request.landmarks or {},
            gender=request.gender,
            skin_tone=request.skinTone or "medium",
            clothing_style=request.clothingStyle or "athletic",
        )

        # Textures are baked in during creation; apply_textures is a no-op for SMPL
        textured_mesh = avatar_generator.apply_textures(
            mesh_data,
            skin_tone=request.skinTone or "medium",
            clothing_style=request.clothingStyle or "athletic",
        )
        
        # Export to GLB format
        model_url = await storage_service.upload_avatar_model(
            mesh=textured_mesh,
            user_id=request.userId,
            version="initial"
        )
        
        # Generate thumbnail
        thumbnail_url = await storage_service.generate_thumbnail(
            mesh=textured_mesh,
            user_id=request.userId
        )
        
        # Save to Firestore in background
        background_tasks.add_task(
            storage_service.save_avatar_metadata,
            user_id=request.userId,
            model_url=model_url,
            thumbnail_url=thumbnail_url,
            measurements=request.measurements
        )
        
        logger.info(f"Avatar generated successfully for user: {request.userId}")
        
        return AvatarResponse(
            userId=request.userId,
            modelUrl=model_url,
            thumbnailUrl=thumbnail_url,
            status="success",
            message="Avatar generated successfully",
            metadata={
                "height": request.height,
                "weight": request.weight,
                "gender": request.gender,
                "generatedAt": datetime.utcnow().isoformat()
            }
        )
        
    except ValueError as e:
        logger.error(f"Validation error: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Error generating avatar: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to generate avatar: {str(e)}")


@app.post("/api/v1/avatar/update-physique", response_model=PhysiqueUpdateResponse)
async def update_avatar_physique(
    request: PhysiqueUpdateRequest,
    background_tasks: BackgroundTasks
):
    """
    Update avatar physique based on nutrition and exercise progress
    
    Args:
        request: Physique update request with nutrition data
        
    Returns:
        PhysiqueUpdateResponse with updated model URL and changes
    """
    try:
        logger.info(f"Updating physique for user: {request.userId}")
        
        # Calculate body changes from nutrition
        body_changes = nutrition_calculator.calculate_body_changes(
            baseline_weight=request.baselineWeight,
            carbs_consumed=request.nutrition.carbs,
            protein_consumed=request.nutrition.protein,
            fats_consumed=request.nutrition.fats,
            calories_burned=request.nutrition.caloriesBurned,
            days_elapsed=request.daysElapsed,
            gender=request.gender,
            activity_level=request.activityLevel
        )
        
        # Get existing avatar data
        existing_avatar = await storage_service.get_avatar_data(request.userId)
        
        if not existing_avatar:
            raise HTTPException(
                status_code=404,
                detail="Avatar not found. Please generate initial avatar first."
            )
        
        # Morph existing avatar with calculated changes
        morphed_mesh = body_morpher.apply_physique_changes(
            original_mesh=existing_avatar['mesh_data'],
            weight_change=body_changes['weight_change'],
            muscle_gain=body_changes['muscle_gain'],
            fat_loss=body_changes['fat_loss'],
            body_fat_percentage=body_changes['body_fat_percentage']
        )
        
        # Export updated model
        updated_model_url = await storage_service.upload_avatar_model(
            mesh=morphed_mesh,
            user_id=request.userId,
            version=f"day_{request.daysElapsed}"
        )
        
        # Generate new thumbnail
        updated_thumbnail_url = await storage_service.generate_thumbnail(
            mesh=morphed_mesh,
            user_id=request.userId
        )
        
        # Save progress history in background
        background_tasks.add_task(
            storage_service.save_physique_history,
            user_id=request.userId,
            model_url=updated_model_url,
            body_changes=body_changes,
            day=request.daysElapsed
        )
        
        logger.info(f"Physique updated successfully for user: {request.userId}")
        
        return PhysiqueUpdateResponse(
            userId=request.userId,
            updatedModelUrl=updated_model_url,
            thumbnailUrl=updated_thumbnail_url,
            status="success",
            message="Avatar physique updated successfully",
            changes={
                "weightChange": body_changes['weight_change'],
                "muscleGain": body_changes['muscle_gain'],
                "fatLoss": body_changes['fat_loss'],
                "bodyFatPercentage": body_changes['body_fat_percentage'],
                "bmi": body_changes['bmi']
            },
            daysTracked=request.daysElapsed
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating physique: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to update physique: {str(e)}")


@app.get("/api/v1/avatar/progress/{user_id}", response_model=ProgressAnalysisResponse)
async def get_progress_analysis(user_id: str):
    """
    Get detailed progress analysis with avatar history
    
    Args:
        user_id: User ID
        
    Returns:
        Progress analysis with timeline and predictions
    """
    try:
        logger.info(f"Fetching progress for user: {user_id}")
        
        # Get progress history
        history = await storage_service.get_physique_history(user_id)
        
        if not history:
            raise HTTPException(
                status_code=404,
                detail="No progress history found for this user"
            )
        
        # Analyze progress trends
        analysis = nutrition_calculator.analyze_progress_trends(history)
        
        # Generate predictions
        predictions = nutrition_calculator.predict_future_progress(
            current_data=history[-1],
            trend=analysis['trend']
        )
        
        return ProgressAnalysisResponse(
            userId=user_id,
            totalDays=len(history),
            currentStats=analysis['current_stats'],
            progressTrend=analysis['trend'],
            predictions=predictions,
            avatarTimeline=[
                {
                    "day": entry['day'],
                    "modelUrl": entry['model_url'],
                    "thumbnailUrl": entry['thumbnail_url'],
                    "weight": entry['weight'],
                    "bodyFatPercentage": entry['body_fat_percentage']
                }
                for entry in history
            ]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching progress: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch progress: {str(e)}")


@app.delete("/api/v1/avatar/{user_id}")
async def delete_avatar(user_id: str):
    """Delete avatar and all associated data"""
    try:
        await storage_service.delete_avatar(user_id)
        return {"status": "success", "message": "Avatar deleted successfully"}
    except Exception as e:
        logger.error(f"Error deleting avatar: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to delete avatar: {str(e)}")


@app.post("/api/v1/avatar/compare")
async def compare_avatars(user_id: str, day1: int, day2: int):
    """
    Compare two avatar states from different days
    
    Args:
        user_id: User ID
        day1: First day number
        day2: Second day number
        
    Returns:
        Comparison data with visual differences
    """
    try:
        comparison = await storage_service.compare_avatar_states(
            user_id=user_id,
            day1=day1,
            day2=day2
        )
        
        return {
            "userId": user_id,
            "comparison": comparison,
            "status": "success"
        }
        
    except Exception as e:
        logger.error(f"Error comparing avatars: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to compare avatars: {str(e)}")


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG,
        log_level="info"
    )
