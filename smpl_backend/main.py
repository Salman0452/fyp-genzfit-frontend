from __future__ import annotations
"""
main.py -- GenZFit SMPL-X Avatar Generation Backend
Run: uvicorn main:app --reload --host 0.0.0.0 --port 8000
Endpoints:
    GET  /health             -> server health + SMPL-X availability
    POST /generate-avatar    -> generate a textured SMPL-X avatar, return .glb base64
Fully offline -- no external avatar APIs.
"""

import base64, json, logging, os, tempfile
from datetime import date, datetime
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

# User preferences store  { user_id: { ...preferences } }
_user_preferences: dict = {}

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

class UserPreferences(BaseModel):
    model_config = ConfigDict(protected_namespaces=())
    user_id: str
    # Workout preferences
    workout_location: str = Field("gym", description="gym | home | outdoor")
    fitness_level: str = Field("intermediate", description="beginner | intermediate | advanced")
    workout_days_per_week: int = Field(5, ge=1, le=7)
    workout_duration_minutes: int = Field(45, ge=15, le=120)
    available_equipment: list = Field(default=[], description="barbell | dumbbells | cables | machines | bench | squat_rack | resistance_bands | pull_up_bar | yoga_mat")
    disliked_exercises: list = Field(default=[], description="Exercises user dislikes or cannot do")
    injury_limitations: list = Field(default=[], description="e.g. ['bad knees', 'shoulder injury']")
    # Diet preferences
    dietary_restrictions: list = Field(default=[], description="e.g. ['no pork', 'lactose intolerant', 'vegetarian']")
    food_allergies: list = Field(default=[], description="e.g. ['nuts', 'shellfish']")
    cuisine_preference: str = Field("pakistani", description="pakistani | mixed | continental")
    meals_per_day: int = Field(4, ge=3, le=6)
    disliked_foods: list = Field(default=[], description="Foods user dislikes")
    # Health data
    goal: str = Field("fitness", description="weight_loss | muscle_gain | fitness | endurance")
    age: int = Field(25, ge=10, le=100)
    height_cm: float = Field(170.0)
    weight_kg: float = Field(70.0)
    gender: str = Field("male")
    health_conditions: list = Field(default=[], description="e.g. ['diabetes', 'hypertension']")

class AIRecommendationRequest(BaseModel):
    model_config = ConfigDict(protected_namespaces=())
    user_id: str
    request_type: str = Field(..., description="daily_meals | daily_exercises | weekly_meals | weekly_exercises")
    yesterday_meals_completed: int = 0
    yesterday_meals_total: int = 0
    yesterday_exercises_completed: int = 0
    yesterday_exercises_total: int = 0
    skipped_meals: list = Field(default=[])
    favorite_meals: list = Field(default=[])
    favorite_exercises: list = Field(default=[])
    recent_meals: list = Field(default=[])
    recent_exercises: list = Field(default=[])
    # Inline user preferences — sent by Flutter so backend needs no persistent store
    preferences: Optional[dict] = Field(default=None, description="Full UserPreferences dict sent from Flutter/Firestore")

class ProgressAnalysisRequest(BaseModel):
    model_config = ConfigDict(protected_namespaces=())
    user_id: str
    daily_nutrition: list = Field(
        default=[],
        description='''List of 7 days, each:
        {
          "date": "2026-03-01",
          "calories_consumed": 1850,
          "protein": 120,
          "carbs": 200,
          "fats": 65,
          "meals_completed": 3,
          "meals_total": 4,
          "exercises_completed": 3,
          "exercises_total": 4,
          "calories_burned": 320
        }'''
    )
    current_measurements: dict = Field(
        default={},
        description='''
        {
          "weight": 75.0,
          "chest": 98.0,
          "waist": 82.0,
          "hips": 92.0,
          "shoulders": 110.0,
          "thigh": 55.0,
          "date": "2026-03-01"
        }'''
    )
    previous_measurements: dict = Field(
        default={},
        description="Same structure as current, 2 weeks ago"
    )
    goal: str = "fitness"
    fitness_level: str = "intermediate"
    workout_location: str = "gym"

# --- Health endpoint ---
@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(
        status="ok", smplx_available=_SMPLX_AVAILABLE,
        model_dir_exists=(SMPLX_MODEL_DIR / "smplx").exists(),
        uv_files_exist=(UV_OBJ_PATH.exists() and UV_TEXTURE_PATH.exists()),
        cloudinary_enabled=_CLOUDINARY_ENABLED,
    )

# --- User preferences endpoints ---
@app.post("/user-preferences")
def save_user_preferences(prefs: UserPreferences):
    """Save user preferences for AI personalization."""
    _user_preferences[prefs.user_id] = prefs.dict()
    logger.info("Saved preferences for user %s", prefs.user_id)
    return {"status": "saved", "user_id": prefs.user_id}

@app.get("/user-preferences/{user_id}")
def get_user_preferences(user_id: str):
    """Get user preferences."""
    prefs = _user_preferences.get(user_id)
    if not prefs:
        raise HTTPException(
            status_code=404,
            detail="Preferences not found for this user"
        )
    return prefs

# --- AI plan generation endpoint ---
@app.post("/generate-ai-plan")
def generate_ai_plan(req: AIRecommendationRequest):
    """
    Generate personalized diet/exercise plan using Groq.
    Uses user preferences as system prompt for deep personalization.
    Preferences are sent inline by Flutter (read from Firestore), so
    no persistent backend store is required.
    """
    # Priority: inline preferences from Flutter > in-memory cache > defaults
    if req.preferences:
        prefs_data = req.preferences
        logger.info("Using inline preferences for user %s (goal=%s, location=%s)",
                    req.user_id,
                    prefs_data.get('goal', '?'),
                    prefs_data.get('workout_location', '?'))
    else:
        prefs_data = _user_preferences.get(req.user_id, {})
        if prefs_data:
            logger.info("Using cached preferences for user %s", req.user_id)
        else:
            logger.warning("No preferences found for user %s — using defaults", req.user_id)

    prefs = UserPreferences(
        user_id=req.user_id,
        **{k: v for k, v in prefs_data.items() if k != "user_id"}
    ) if prefs_data else UserPreferences(user_id=req.user_id)

    system_prompt = _build_compact_system_prompt(prefs)

    groq_api_key = os.getenv("GROQ_API_KEY", "")
    if not groq_api_key:
        raise HTTPException(status_code=500, detail="GROQ_API_KEY not found in environment")

    from groq import Groq
    client = Groq(api_key=groq_api_key)

    def _call_groq(prompt: str, max_tokens: int = 700) -> str:
        response = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user",   "content": prompt},
            ],
            temperature=0.3,
            max_tokens=max_tokens,
        )
        return response.choices[0].message.content

    try:
        # ── Weekly plans: single compact call (lowest token usage) ────────────
        if req.request_type == "weekly_meals":
            user_prompt = _build_weekly_meal_prompt(req, prefs)
            content = _call_groq(user_prompt, max_tokens=1100)
            logger.info("Groq response for %s: %d chars", req.request_type, len(content))
            return {"status": "ok", "content": content, "request_type": req.request_type}

        if req.request_type == "weekly_exercises":
            user_prompt = _build_weekly_exercise_prompt(req, prefs)
            content = _call_groq(user_prompt, max_tokens=1100)
            logger.info("Groq response for %s: %d chars", req.request_type, len(content))
            return {"status": "ok", "content": content, "request_type": req.request_type}

        # ── Daily plans: single call as before ────────────────────────────────
        if req.request_type == "daily_meals":
            user_prompt = _build_daily_meal_prompt(req, prefs)
        elif req.request_type == "daily_exercises":
            user_prompt = _build_daily_exercise_prompt(req, prefs)
        else:
            raise HTTPException(status_code=400, detail=f"Unknown request_type: {req.request_type}")

        content = _call_groq(user_prompt, max_tokens=700)
        logger.info("Groq response for %s: %d chars", req.request_type, len(content))
        return {"status": "ok", "content": content, "request_type": req.request_type}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("Groq API error: %s", e)
        raise HTTPException(status_code=500, detail=f"Groq error: {e}")


# --- AI prompt helper functions ---

def _build_compact_system_prompt(prefs: UserPreferences) -> str:
    restrictions = ", ".join(prefs.dietary_restrictions) if prefs.dietary_restrictions else "none"
    allergies = ", ".join(prefs.food_allergies) if prefs.food_allergies else "none"
    disliked_foods = ", ".join(str(x) for x in prefs.disliked_foods) if prefs.disliked_foods else "none"
    disliked_exercises = ", ".join(prefs.disliked_exercises) if prefs.disliked_exercises else "none"
    injuries = ", ".join(prefs.injury_limitations) if prefs.injury_limitations else "none"

    return f"""You are a strict JSON generator for fitness plans.
Return only valid JSON. No markdown, no extra text.
Keep values short to save tokens.

User profile:
- Goal: {prefs.goal}
- Fitness level: {prefs.fitness_level}
- Workout location: {prefs.workout_location}
- Workout days/week: {prefs.workout_days_per_week}
- Workout duration: {prefs.workout_duration_minutes} min
- Cuisine: {prefs.cuisine_preference}
- Meals/day: {prefs.meals_per_day}
- Dietary restrictions: {restrictions}
- Allergies: {allergies}
- Disliked foods: {disliked_foods}
- Disliked exercises: {disliked_exercises}
- Injury limits: {injuries}

Never include restricted/allergy/disliked items.
Keep descriptions tiny (or empty string).
Prefer short names and compact arrays."""

def _build_system_prompt(prefs: UserPreferences) -> str:
    equipment_str       = ", ".join(prefs.available_equipment)  if prefs.available_equipment  else "bodyweight only"
    restrictions_str    = ", ".join(prefs.dietary_restrictions) if prefs.dietary_restrictions else "none"
    allergies_str       = ", ".join(prefs.food_allergies)       if prefs.food_allergies       else "none"
    injuries_str        = ", ".join(prefs.injury_limitations)   if prefs.injury_limitations   else "none"
    disliked_ex_str     = ", ".join(prefs.disliked_exercises)   if prefs.disliked_exercises   else "none"
    disliked_food_str   = ", ".join(str(f) for f in prefs.disliked_foods) if prefs.disliked_foods else "none"
    health_cond_str     = ", ".join(prefs.health_conditions)    if prefs.health_conditions    else "none"
    bmi = prefs.weight_kg / ((prefs.height_cm / 100) ** 2)

    home_rule     = "- ONLY suggest exercises that can be done at HOME without gym equipment" if prefs.workout_location == "home" else ""
    gym_rule      = "- User has gym access. Use barbells, dumbbells, cables, machines as available" if prefs.workout_location == "gym" else ""
    disliked_rule = f"- NEVER suggest: {disliked_ex_str}" if prefs.disliked_exercises else ""
    injury_rule   = f"- Avoid exercises that stress: {injuries_str}" if prefs.injury_limitations else ""
    veg_rule      = "- User is vegetarian. NO meat, chicken, fish in any meal" if "vegetarian" in prefs.dietary_restrictions else ""
    pork_rule     = "- NO pork or pork products in any meal" if "no pork" in prefs.dietary_restrictions else ""
    lactose_rule  = "- User is lactose intolerant. No milk, cheese, heavy dairy" if "lactose intolerant" in prefs.dietary_restrictions else ""
    allergy_rule  = f"- STRICT ALLERGY: Never include {allergies_str}" if prefs.food_allergies else ""
    food_rule     = f"- Never suggest: {disliked_food_str}" if prefs.disliked_foods else ""
    diabetes_rule = "- Diabetic user: low glycemic index foods, avoid refined sugar" if "diabetes" in prefs.health_conditions else ""
    cal_target    = (
        "1500-1800 calories/day for weight loss" if prefs.goal == "weight_loss"
        else "2200-2800 calories/day for muscle gain" if prefs.goal == "muscle_gain"
        else "1800-2200 calories/day for maintenance"
    )
    cuisine_note  = "Pakistani/Desi foods using local ingredients" if prefs.cuisine_preference == "pakistani" else "mixed international cuisines"

    return f"""You are an expert personal fitness trainer and nutritionist.
You are creating a personalized plan for a specific user.
Always respond with valid JSON only — no markdown, no extra text.

═══ USER PROFILE ═══
Goal: {prefs.goal}
Age: {prefs.age} years
Gender: {prefs.gender}
Height: {prefs.height_cm} cm
Weight: {prefs.weight_kg} kg
BMI: {bmi:.1f}
Fitness Level: {prefs.fitness_level}
Health Conditions: {health_cond_str}

═══ WORKOUT PREFERENCES ═══
Location: {prefs.workout_location}
Available Equipment: {equipment_str}
Workout Days Per Week: {prefs.workout_days_per_week}
Preferred Duration: {prefs.workout_duration_minutes} minutes per session
Injury Limitations: {injuries_str}
Disliked Exercises: {disliked_ex_str}

═══ CRITICAL EXERCISE RULES ═══
{home_rule}
{gym_rule}
{disliked_rule}
{injury_rule}
- Match difficulty to {prefs.fitness_level} level
- Keep each session under {prefs.workout_duration_minutes} minutes

═══ DIET PREFERENCES ═══
Cuisine: {prefs.cuisine_preference}
Meals Per Day: {prefs.meals_per_day}
Dietary Restrictions: {restrictions_str}
Food Allergies: {allergies_str}
Disliked Foods: {disliked_food_str}

═══ CRITICAL DIET RULES ═══
{veg_rule}
{pork_rule}
{lactose_rule}
{allergy_rule}
{food_rule}
{diabetes_rule}
- Cuisine focus: {cuisine_note}
- Calorie target: {cal_target}
"""


def _build_daily_meal_prompt(req: AIRecommendationRequest, prefs: UserPreferences) -> str:
    day_names = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
    today = day_names[datetime.now().weekday()]

    yesterday_rate = 0
    if req.yesterday_meals_total > 0:
        yesterday_rate = int(req.yesterday_meals_completed / req.yesterday_meals_total * 100)

    adaptive = ""
    if req.yesterday_meals_total > 0:
        if yesterday_rate < 50:
            adaptive = f"User only completed {yesterday_rate}% of meals yesterday. Suggest simpler, quicker meals today."
        elif yesterday_rate >= 80:
            adaptive = f"User completed {yesterday_rate}% of meals yesterday. Great motivation! Can suggest variety."
    if req.skipped_meals:
        adaptive += f" User skipped: {', '.join(req.skipped_meals)}. Avoid similar meals."

    favorites = f"User enjoys: {', '.join(req.favorite_meals)}" if req.favorite_meals else ""
    avoid     = f"MUST AVOID (shown in last 30 days): {', '.join(req.recent_meals)}" if req.recent_meals else ""

    snack1 = "- 1 Mid-morning snack (150-200 cal)" if prefs.meals_per_day >= 4 else ""
    snack2 = "- 1 Afternoon snack (150-200 cal)"   if prefs.meals_per_day >= 5 else ""

    return f"""Generate {prefs.meals_per_day} compact meals for TODAY ({today}).

ADAPTIVE CONTEXT:
{adaptive}
{favorites}
{avoid}

Generate exactly {prefs.meals_per_day} meals:
- 1 Breakfast (350-450 cal)
{snack1}
- 1 Lunch (450-600 cal)
{snack2}
- 1 Dinner (400-550 cal)

Return ONLY a JSON array using compact keys:
[
    {{"n": "meal name", "d": "", "c": 400, "i": "ingredient1,ingredient2", "t": "breakfast", "p": 25, "ca": 45, "f": 12}}
]"""


def _build_daily_exercise_prompt(req: AIRecommendationRequest, prefs: UserPreferences) -> str:
    day_names = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
    today     = day_names[datetime.now().weekday()]
    day_index = datetime.now().weekday()

    muscle_groups = [
        "Chest + Triceps",
        "Back + Biceps",
        "Legs + Core",
        "Shoulders + Abs",
        "Full Body Cardio",
        "Arms + Core (Light)",
        "Active Recovery / Stretching",
    ]
    todays_focus = muscle_groups[day_index]

    yesterday_rate = 0
    if req.yesterday_exercises_total > 0:
        yesterday_rate = int(req.yesterday_exercises_completed / req.yesterday_exercises_total * 100)

    adaptive = ""
    if req.yesterday_exercises_total > 0:
        if yesterday_rate < 50:
            adaptive = f"User struggled yesterday ({yesterday_rate}%). Keep it simple today."
        elif yesterday_rate >= 80:
            adaptive = f"User crushed it yesterday ({yesterday_rate}%)! Can push harder today."

    favorites = f"User enjoys: {', '.join(req.favorite_exercises)}" if req.favorite_exercises else ""
    avoid     = f"MUST AVOID (done in last 30 days): {', '.join(req.recent_exercises)}" if req.recent_exercises else ""
    num_ex    = 4 if day_index < 6 else 2

    return f"""Generate {num_ex} compact exercises for TODAY ({today}).

TODAY'S FOCUS: {todays_focus}
ADAPTIVE CONTEXT:
{adaptive}
{favorites}
{avoid}

Generate exactly {num_ex} exercises targeting {todays_focus}.
Each exercise must fit within {prefs.workout_duration_minutes} minutes total.

Return ONLY a JSON array using compact keys:
[
    {{"n": "exercise name", "d": "", "s": 3, "r": 12, "du": 10, "di": "intermediate", "m": "chest,triceps"}}
]"""


def _build_weekly_meal_prompt(req: AIRecommendationRequest, prefs: UserPreferences) -> str:
    avoid = f"Avoid recent meals: {', '.join(req.recent_meals)}" if req.recent_meals else ""
    return f"""Generate a full weekly meal plan in one compact JSON object.

Days required: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday.
Meals/day: {prefs.meals_per_day}
{avoid}

For each day, include meal array with compact meal objects.
Meal object keys:
- n: name
- d: description (keep empty string if possible)
- c: calories
- i: comma-separated ingredients string
- t: mealType (breakfast|snack|lunch|dinner)
- p: protein
- ca: carbs
- f: fats

Return ONLY JSON object format:
{{
    "Monday": [{{"n":"...","d":"","c":400,"i":"egg,oats","t":"breakfast","p":25,"ca":40,"f":12}}],
    "Tuesday": [],
    "Wednesday": [],
    "Thursday": [],
    "Friday": [],
    "Saturday": [],
    "Sunday": []
}}"""


def _build_weekly_exercise_prompt(req: AIRecommendationRequest, prefs: UserPreferences) -> str:
    avoid = f"Avoid recent exercises: {', '.join(req.recent_exercises)}" if req.recent_exercises else ""
    equipment = ', '.join(prefs.available_equipment) if prefs.available_equipment else 'bodyweight only'

    return f"""Generate a full weekly exercise plan in one compact JSON object.

Days required: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday.
Workout days/week: {prefs.workout_days_per_week}. Remaining days should be [].
Fitness level: {prefs.fitness_level}
Duration/session: {prefs.workout_duration_minutes} minutes
Equipment: {equipment}
{avoid}

Exercise object keys:
- n: name
- d: description (keep empty string if possible)
- s: sets
- r: reps
- du: durationMinutes
- di: difficulty
- m: comma-separated target muscles

Return ONLY JSON object format:
{{
    "Monday": [{{"n":"...","d":"","s":3,"r":12,"du":10,"di":"intermediate","m":"chest,triceps"}}],
    "Tuesday": [],
    "Wednesday": [],
    "Thursday": [],
    "Friday": [],
    "Saturday": [],
    "Sunday": []
}}"""


def _build_single_day_meal_prompt(day: str, req: AIRecommendationRequest, prefs: UserPreferences) -> str:
    avoid = f"MUST AVOID (already seen recently): {', '.join(req.recent_meals)}" if req.recent_meals else ""
    snack1 = "- 1 Mid-morning snack (150-200 cal)" if prefs.meals_per_day >= 4 else ""
    snack2 = "- 1 Afternoon snack (150-200 cal)"   if prefs.meals_per_day >= 5 else ""

    return f"""Generate {prefs.meals_per_day} meals for {day}.

{avoid}

Generate exactly {prefs.meals_per_day} meals:
- 1 Breakfast (350-450 cal, high protein)
{snack1}
- 1 Lunch (450-600 cal, balanced)
{snack2}
- 1 Dinner (350-500 cal, lighter)

Cuisine focus: {prefs.cuisine_preference}.

Return ONLY a JSON array (no keys, no wrapping object):
[{{"name": "Meal Name", "description": "short description", "calories": 400, "ingredients": ["item1"], "mealType": "breakfast", "macros": {{"protein": 30, "carbs": 40, "fats": 10}}}}]"""


# Muscle group rotation for each day of the week (index 0=Mon … 6=Sun)
_MUSCLE_SPLITS = [
    {"focus": "Chest + Triceps",             "exercises": 4},
    {"focus": "Back + Biceps",               "exercises": 4},
    {"focus": "Legs + Core",                 "exercises": 4},
    {"focus": "Shoulders + Abs",             "exercises": 4},
    {"focus": "Full Body / HIIT Cardio",     "exercises": 4},
    {"focus": "Arms + Core (Light)",         "exercises": 3},
    {"focus": "Active Recovery / Stretching","exercises": 2},
]
_ALL_DAYS = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]


def _build_single_day_exercise_prompt(day: str, req: AIRecommendationRequest, prefs: UserPreferences) -> str:
    avoid = f"MUST AVOID (done recently): {', '.join(req.recent_exercises)}" if req.recent_exercises else ""
    equipment = ', '.join(prefs.available_equipment) if prefs.available_equipment else 'bodyweight only'

    day_idx     = _ALL_DAYS.index(day)
    workout_days = prefs.workout_days_per_week  # e.g. 5

    # Days 0 … workout_days-1 are workout days; the rest are rest days
    is_rest = day_idx >= workout_days

    if is_rest:
        return f"""Today ({day}) is a REST DAY.
Return ONLY an empty JSON array: []"""

    split     = _MUSCLE_SPLITS[day_idx % len(_MUSCLE_SPLITS)]
    focus     = split["focus"]
    ex_count  = split["exercises"]

    return f"""Generate {ex_count} exercises for {day} — focus: {focus}.

{avoid}

Rules:
- Difficulty: {prefs.fitness_level}
- Session duration: {prefs.workout_duration_minutes} min total
- Equipment: {equipment}

Return ONLY a JSON array (no wrapping object):
[{{"name": "Exercise Name", "description": "how to perform", "sets": 3, "reps": 12, "durationMinutes": 10, "difficulty": "{prefs.fitness_level}", "targetMuscles": ["{focus.split(' + ')[0]}"]}}]"""


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

    # Arms down naturally
    body_pose[0, 12*3 + 2] = -1.2   # left shoulder Z: down
    body_pose[0, 13*3 + 2] =  1.2   # right shoulder Z: down

    # Shoulder shape — very small value only
    body_pose[0, 12*3 + 0] = -0.08  # left shoulder X
    body_pose[0, 13*3 + 0] =  0.08  # right shoulder X

    # Elbow
    body_pose[0, 15*3 + 2] =  0.1   # left elbow
    body_pose[0, 16*3 + 2] = -0.1   # right elbow

    # Wrist — only set ONCE
    body_pose[0, 17*3 + 2] = -0.05
    body_pose[0, 18*3 + 2] =  0.05
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


# ─────────────────────────────────────────────────────────────────────────────
# Progress Analysis Endpoint
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/analyze-progress")
def analyze_progress(req: ProgressAnalysisRequest):
    """
    Analyze user's weekly progress using AI.
    Returns insights, estimated body changes, and recommendations.
    """
    # Calculate totals from daily_nutrition
    total_calories = sum(d.get('calories_consumed', 0) for d in req.daily_nutrition)
    total_protein  = sum(d.get('protein', 0) for d in req.daily_nutrition)
    total_carbs    = sum(d.get('carbs', 0) for d in req.daily_nutrition)
    total_fats     = sum(d.get('fats', 0) for d in req.daily_nutrition)
    total_burned   = sum(d.get('calories_burned', 0) for d in req.daily_nutrition)

    meals_done  = sum(d.get('meals_completed', 0) for d in req.daily_nutrition)
    meals_total = sum(d.get('meals_total', 0) for d in req.daily_nutrition)
    ex_done     = sum(d.get('exercises_completed', 0) for d in req.daily_nutrition)
    ex_total    = sum(d.get('exercises_total', 0) for d in req.daily_nutrition)

    meal_rate = int(meals_done / meals_total * 100) if meals_total > 0 else 0
    ex_rate   = int(ex_done / ex_total * 100) if ex_total > 0 else 0

    avg_daily_calories = int(total_calories / max(len(req.daily_nutrition), 1))
    calorie_balance    = total_calories - total_burned

    # Measurement changes
    meas_changes = {}
    if req.current_measurements and req.previous_measurements:
        for key in ['weight', 'chest', 'waist', 'hips', 'shoulders', 'thigh']:
            cur  = req.current_measurements.get(key, 0)
            prev = req.previous_measurements.get(key, 0)
            if cur and prev:
                meas_changes[key] = round(cur - prev, 1)

    # Build AI prompt
    system_prompt = """You are an expert fitness coach and nutritionist.
Analyze the user's weekly fitness data and provide honest,
motivating insights. Always respond with valid JSON only."""

    user_prompt = f"""Analyze this user's weekly fitness progress:

GOAL: {req.goal}
FITNESS LEVEL: {req.fitness_level}

WEEKLY NUTRITION:
- Total calories consumed: {total_calories} kcal
- Average daily calories: {avg_daily_calories} kcal
- Total protein: {total_protein}g
- Total carbs: {total_carbs}g
- Total fats: {total_fats}g
- Calories burned from exercise: {total_burned} kcal
- Net calorie balance: {calorie_balance} kcal

COMPLETION RATES:
- Meal plan: {meal_rate}% ({meals_done}/{meals_total} meals)
- Exercise plan: {ex_rate}% ({ex_done}/{ex_total} exercises)

MEASUREMENT CHANGES (current vs 2 weeks ago):
{meas_changes if meas_changes else "No previous measurements to compare"}

DAILY BREAKDOWN:
{req.daily_nutrition}

Based on this data, provide analysis in this exact JSON:
{{
  "overall_score": 85,
  "grade": "A",
  "headline": "Strong week! Keep pushing 💪",

  "nutrition_analysis": {{
    "summary": "2-3 sentence nutrition assessment",
    "protein_status": "adequate|low|high",
    "calorie_status": "deficit|surplus|maintenance",
    "estimated_fat_change_kg": -0.3,
    "tip": "One specific nutrition tip"
  }},

  "exercise_analysis": {{
    "summary": "2-3 sentence exercise assessment",
    "intensity_feedback": "good|too_easy|too_hard",
    "estimated_muscle_impact": "slight gain|maintenance|loss",
    "tip": "One specific exercise tip"
  }},

  "body_changes": {{
    "weight_change_kg": -0.3,
    "fat_change_kg": -0.4,
    "muscle_change_kg": 0.1,
    "estimated_measurements": {{
      "chest_change_cm": 0.5,
      "waist_change_cm": -0.8,
      "shoulders_change_cm": 0.3,
      "thigh_change_cm": 0.2
    }},
    "confidence": "low|medium|high",
    "note": "Honest disclaimer about estimation accuracy"
  }},

  "streak_feedback": "Motivating message about consistency",

  "next_week_focus": [
    "Specific actionable tip 1",
    "Specific actionable tip 2",
    "Specific actionable tip 3"
  ],

  "avatar_should_update": true,
  "avatar_update_reason": "Why avatar should reflect changes"
}}"""

    try:
        from groq import Groq
        client = Groq(api_key=os.getenv("GROQ_API_KEY", ""))
        response = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user",   "content": user_prompt},
            ],
            temperature=0.4,
            max_tokens=2000,
        )
        content = response.choices[0].message.content

        # Clean JSON
        import re
        match = re.search(r'\{.*\}', content, re.DOTALL)
        if match:
            import json as json_lib
            analysis = json_lib.loads(match.group())
        else:
            raise ValueError("No JSON found in response")

        return {
            "status": "ok",
            "analysis": analysis,
            "computed_stats": {
                "total_calories": total_calories,
                "total_protein": total_protein,
                "total_carbs": total_carbs,
                "total_fats": total_fats,
                "total_burned": total_burned,
                "meal_completion_rate": meal_rate,
                "exercise_completion_rate": ex_rate,
                "calorie_balance": calorie_balance,
                "measurement_changes": meas_changes,
            }
        }
    except Exception as e:
        logger.error("Progress analysis error: %s", e)
        raise HTTPException(
            status_code=500,
            detail=f"Analysis error: {e}"
        )
