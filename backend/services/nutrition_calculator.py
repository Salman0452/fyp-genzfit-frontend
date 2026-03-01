"""
Nutrition Calculator Service
Calculates body composition changes from nutrition and exercise data
"""

import numpy as np
from typing import Dict, List, Tuple
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)


class NutritionCalculator:
    """Calculates body changes from nutrition tracking"""
    
    def __init__(self):
        """Initialize nutrition calculator with metabolic constants"""
        self.constants = {
            "calories_per_kg_fat": 7700,
            "calories_per_kg_muscle": 1000,  # With adequate protein
            "protein_per_kg_muscle": 800,     # grams
            "max_muscle_gain_per_week": {
                "beginner": 0.25,    # kg
                "intermediate": 0.15,
                "advanced": 0.05
            },
            "max_fat_loss_per_week": 1.0,    # kg (healthy rate)
            "bmr_factor": {
                "male": 10,
                "female": 9
            }
        }
        
    def calculate_bmr(
        self,
        weight: float,
        height: float,
        age: int,
        gender: str
    ) -> float:
        """
        Calculate Basal Metabolic Rate using Mifflin-St Jeor Equation
        
        Args:
            weight: Weight in kg
            height: Height in cm
            age: Age in years
            gender: "male" or "female"
            
        Returns:
            BMR in calories/day
        """
        # Mifflin-St Jeor Equation
        if gender == "male":
            bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5
        else:
            bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161
            
        return bmr
    
    def calculate_tdee(
        self,
        bmr: float,
        activity_level: str = "moderate"
    ) -> float:
        """
        Calculate Total Daily Energy Expenditure
        
        Args:
            bmr: Basal Metabolic Rate
            activity_level: Activity level
            
        Returns:
            TDEE in calories/day
        """
        activity_multipliers = {
            "sedentary": 1.2,      # Little to no exercise
            "light": 1.375,        # Exercise 1-3 days/week
            "moderate": 1.55,      # Exercise 3-5 days/week
            "active": 1.725,       # Exercise 6-7 days/week
            "very_active": 1.9     # Hard exercise daily
        }
        
        multiplier = activity_multipliers.get(activity_level, 1.55)
        tdee = bmr * multiplier
        
        return tdee
    
    def calculate_body_changes(
        self,
        baseline_weight: float,
        carbs_consumed: float,
        protein_consumed: float,
        fats_consumed: float,
        calories_burned: float,
        days_elapsed: int,
        gender: str = "male",
        activity_level: str = "moderate",
        height: float = 170,
        age: int = 25
    ) -> Dict:
        """
        Calculate comprehensive body composition changes
        
        Args:
            baseline_weight: Starting weight in kg
            carbs_consumed: Total carbs in grams
            protein_consumed: Total protein in grams
            fats_consumed: Total fats in grams
            calories_burned: Calories burned through exercise
            days_elapsed: Number of days tracked
            gender: "male" or "female"
            activity_level: Activity level string
            height: Height in cm
            age: Age in years
            
        Returns:
            Dict with detailed body composition changes
        """
        logger.info(
            f"Calculating changes: weight={baseline_weight}kg, "
            f"protein={protein_consumed}g, days={days_elapsed}"
        )
        
        # Calculate total calories consumed
        calories_from_carbs = carbs_consumed * 4
        calories_from_protein = protein_consumed * 4
        calories_from_fats = fats_consumed * 9
        total_calories_consumed = (
            calories_from_carbs + 
            calories_from_protein + 
            calories_from_fats
        )
        
        # Calculate maintenance calories
        bmr = self.calculate_bmr(baseline_weight, height, age, gender)
        tdee = self.calculate_tdee(bmr, activity_level)
        maintenance_calories = tdee * days_elapsed
        
        # Net calorie balance
        net_calories = total_calories_consumed - maintenance_calories - calories_burned
        
        logger.info(
            f"Calorie balance: consumed={total_calories_consumed:.0f}, "
            f"maintenance={maintenance_calories:.0f}, "
            f"burned={calories_burned:.0f}, net={net_calories:.0f}"
        )
        
        # Calculate muscle gain potential
        muscle_gain = self._calculate_muscle_gain(
            protein_consumed=protein_consumed,
            days_elapsed=days_elapsed,
            baseline_weight=baseline_weight,
            net_calories=net_calories,
            training_level="beginner"  # Can be parameterized
        )
        
        # Calculate fat change
        # Subtract calories used for muscle building
        calories_for_muscle = muscle_gain * self.constants["calories_per_kg_muscle"]
        remaining_calories = net_calories - calories_for_muscle
        
        if remaining_calories < 0:
            # Calorie deficit = fat loss
            fat_loss = abs(remaining_calories) / self.constants["calories_per_kg_fat"]
        else:
            # Calorie surplus = fat gain
            fat_loss = -remaining_calories / self.constants["calories_per_kg_fat"]
        
        # Apply realistic limits
        max_fat_loss = self.constants["max_fat_loss_per_week"] * (days_elapsed / 7)
        fat_loss = np.clip(fat_loss, -max_fat_loss * 0.5, max_fat_loss)
        
        # Calculate total weight change
        weight_change = muscle_gain - fat_loss
        new_weight = baseline_weight + weight_change
        
        # Calculate body fat percentage
        body_fat_percentage = self._estimate_body_fat_percentage(
            weight=new_weight,
            gender=gender,
            muscle_mass=muscle_gain
        )
        
        # Calculate BMI
        height_m = height / 100
        bmi = new_weight / (height_m ** 2)
        
        # Calculate lean body mass
        lean_mass = new_weight * (1 - body_fat_percentage / 100)
        
        logger.info(
            f"Results: muscle_gain={muscle_gain:.2f}kg, "
            f"fat_loss={fat_loss:.2f}kg, weight_change={weight_change:.2f}kg"
        )
        
        return {
            "weight_change": round(weight_change, 2),
            "muscle_gain": round(muscle_gain, 2),
            "fat_loss": round(fat_loss, 2),
            "new_weight": round(new_weight, 2),
            "body_fat_percentage": round(body_fat_percentage, 1),
            "bmi": round(bmi, 1),
            "lean_body_mass": round(lean_mass, 2),
            "calories_balance": round(net_calories, 0),
            "protein_per_day": round(protein_consumed / days_elapsed, 1),
            "carbs_per_day": round(carbs_consumed / days_elapsed, 1),
            "fats_per_day": round(fats_consumed / days_elapsed, 1)
        }
    
    def _calculate_muscle_gain(
        self,
        protein_consumed: float,
        days_elapsed: int,
        baseline_weight: float,
        net_calories: float,
        training_level: str = "beginner"
    ) -> float:
        """Calculate realistic muscle gain"""
        
        # Protein requirements: 1.6-2.2g per kg body weight
        protein_per_day = protein_consumed / days_elapsed
        optimal_protein = baseline_weight * 2.0  # 2g/kg (high end)
        
        # Protein efficiency ratio (0 to 1)
        protein_ratio = min(protein_per_day / optimal_protein, 1.0)
        
        # Maximum genetic potential
        max_gain_per_week = self.constants["max_muscle_gain_per_week"][training_level]
        max_gain_total = max_gain_per_week * (days_elapsed / 7)
        
        # Calorie surplus helps muscle growth
        # Need surplus for optimal muscle gain
        if net_calories > 0:
            calorie_factor = min(net_calories / 10000, 1.0)  # Cap at 10k surplus
        else:
            calorie_factor = 0.3  # Can still gain muscle in deficit (newbie gains)
        
        # Actual muscle gain
        muscle_gain = max_gain_total * protein_ratio * calorie_factor
        
        # Ensure non-negative
        muscle_gain = max(0, muscle_gain)
        
        return muscle_gain
    
    def _estimate_body_fat_percentage(
        self,
        weight: float,
        gender: str,
        muscle_mass: float = 0
    ) -> float:
        """
        Estimate body fat percentage
        Simplified estimation - in production, use more sophisticated methods
        """
        # Average body fat percentages
        avg_bf = {
            "male": 18.0,
            "female": 25.0
        }
        
        base_bf = avg_bf.get(gender, 18.0)
        
        # Adjust based on muscle gain
        # More muscle = lower BF%
        bf_reduction = muscle_mass * 2  # Each kg muscle reduces BF by ~2%
        
        estimated_bf = base_bf - bf_reduction
        
        # Clamp to realistic ranges
        min_bf = 5 if gender == "male" else 12
        max_bf = 40
        
        return np.clip(estimated_bf, min_bf, max_bf)
    
    def analyze_progress_trends(
        self,
        history: List[Dict]
    ) -> Dict:
        """
        Analyze progress trends from historical data
        
        Args:
            history: List of progress snapshots
            
        Returns:
            Trend analysis with statistics
        """
        if not history:
            return {
                "trend": "insufficient_data",
                "current_stats": {}
            }
        
        # Extract time series data
        days = [entry["day"] for entry in history]
        weights = [entry.get("weight", 0) for entry in history]
        bf_percentages = [entry.get("body_fat_percentage", 0) for entry in history]
        
        # Calculate trends
        weight_trend = self._calculate_trend(days, weights)
        bf_trend = self._calculate_trend(days, bf_percentages)
        
        # Current stats
        current = history[-1]
        
        # Calculate rates of change
        if len(history) > 1:
            days_diff = days[-1] - days[0]
            weight_change_per_week = (weights[-1] - weights[0]) / (days_diff / 7)
            bf_change_per_week = (bf_percentages[-1] - bf_percentages[0]) / (days_diff / 7)
        else:
            weight_change_per_week = 0
            bf_change_per_week = 0
        
        return {
            "trend": self._classify_trend(weight_trend, bf_trend),
            "current_stats": {
                "weight": current.get("weight", 0),
                "body_fat_percentage": current.get("body_fat_percentage", 0),
                "day": current["day"]
            },
            "weight_trend": weight_trend,
            "bf_trend": bf_trend,
            "weight_change_per_week": round(weight_change_per_week, 2),
            "bf_change_per_week": round(bf_change_per_week, 2),
            "total_days": len(history)
        }
    
    def _calculate_trend(self, x: List, y: List) -> str:
        """Calculate trend direction"""
        if len(x) < 2:
            return "stable"
        
        # Simple linear regression
        x_array = np.array(x)
        y_array = np.array(y)
        
        slope = np.polyfit(x_array, y_array, 1)[0]
        
        if abs(slope) < 0.01:
            return "stable"
        elif slope > 0:
            return "increasing"
        else:
            return "decreasing"
    
    def _classify_trend(self, weight_trend: str, bf_trend: str) -> str:
        """Classify overall fitness trend"""
        if weight_trend == "increasing" and bf_trend == "decreasing":
            return "excellent_bulking"  # Gaining muscle, losing fat
        elif weight_trend == "decreasing" and bf_trend == "decreasing":
            return "good_cutting"  # Losing weight and fat
        elif weight_trend == "stable" and bf_trend == "decreasing":
            return "recomposition"  # Body recomposition
        elif weight_trend == "increasing" and bf_trend == "increasing":
            return "poor_bulking"  # Gaining too much fat
        elif weight_trend == "stable":
            return "maintenance"
        else:
            return "needs_adjustment"
    
    def predict_future_progress(
        self,
        current_data: Dict,
        trend: str,
        weeks_ahead: int = 4
    ) -> Dict:
        """
        Predict future progress based on current trends
        
        Args:
            current_data: Current body stats
            trend: Current trend classification
            weeks_ahead: Number of weeks to predict
            
        Returns:
            Predicted future stats
        """
        current_weight = current_data.get("weight", 70)
        current_bf = current_data.get("body_fat_percentage", 20)
        
        # Trend-based projections
        trend_projections = {
            "excellent_bulking": {
                "weight_per_week": 0.3,
                "bf_per_week": -0.5
            },
            "good_cutting": {
                "weight_per_week": -0.5,
                "bf_per_week": -0.8
            },
            "recomposition": {
                "weight_per_week": 0,
                "bf_per_week": -0.5
            },
            "maintenance": {
                "weight_per_week": 0,
                "bf_per_week": 0
            }
        }
        
        projection = trend_projections.get(trend, {
            "weight_per_week": 0,
            "bf_per_week": 0
        })
        
        predicted_weight = current_weight + (projection["weight_per_week"] * weeks_ahead)
        predicted_bf = current_bf + (projection["bf_per_week"] * weeks_ahead)
        
        # Clamp to realistic values
        predicted_bf = np.clip(predicted_bf, 5, 40)
        predicted_weight = max(40, predicted_weight)  # Min 40kg
        
        return {
            "weeks_ahead": weeks_ahead,
            "predicted_weight": round(predicted_weight, 1),
            "predicted_bf_percentage": round(predicted_bf, 1),
            "confidence": "medium",  # Could calculate based on data variance
            "recommendation": self._generate_recommendation(trend)
        }
    
    def _generate_recommendation(self, trend: str) -> str:
        """Generate recommendation based on trend"""
        recommendations = {
            "excellent_bulking": "Great progress! Continue current nutrition and training.",
            "good_cutting": "Effective fat loss. Monitor energy levels and adjust if needed.",
            "recomposition": "Excellent body recomposition. Keep protein high and training consistent.",
            "poor_bulking": "Consider reducing calorie surplus to minimize fat gain.",
            "maintenance": "Stable progress. Consider adjusting goals if desired.",
            "needs_adjustment": "Progress unclear. Review nutrition and training consistency."
        }
        
        return recommendations.get(trend, "Keep tracking progress consistently.")
    
    def calculate_macro_targets(
        self,
        weight: float,
        goal: str,
        activity_level: str = "moderate"
    ) -> Dict:
        """
        Calculate optimal macronutrient targets
        
        Args:
            weight: Current weight in kg
            goal: "cut", "maintain", or "bulk"
            activity_level: Activity level
            
        Returns:
            Daily macro targets
        """
        # Protein: 2g per kg (high for muscle preservation)
        protein = weight * 2.0
        
        # Calculate calorie target
        bmr = self.calculate_bmr(weight, 170, 25, "male")  # Use defaults
        tdee = self.calculate_tdee(bmr, activity_level)
        
        calorie_adjustments = {
            "cut": -500,      # 500 cal deficit
            "maintain": 0,
            "bulk": 300       # 300 cal surplus
        }
        
        target_calories = tdee + calorie_adjustments.get(goal, 0)
        
        # Fats: 25-30% of calories
        fat_calories = target_calories * 0.275
        fats = fat_calories / 9
        
        # Carbs: Remaining calories
        protein_calories = protein * 4
        fat_calories = fats * 9
        carb_calories = target_calories - protein_calories - fat_calories
        carbs = carb_calories / 4
        
        return {
            "calories": round(target_calories, 0),
            "protein": round(protein, 0),
            "carbs": round(carbs, 0),
            "fats": round(fats, 0),
            "goal": goal,
            "activity_level": activity_level
        }


# Standalone testing
if __name__ == "__main__":
    calc = NutritionCalculator()
    
    # Test body changes calculation
    changes = calc.calculate_body_changes(
        baseline_weight=75,
        carbs_consumed=6000,   # 300g/day for 20 days
        protein_consumed=3000,  # 150g/day
        fats_consumed=1400,     # 70g/day
        calories_burned=8000,
        days_elapsed=20,
        gender="male"
    )
    
    print("Body Composition Changes:")
    for key, value in changes.items():
        print(f"  {key}: {value}")
    
    # Test macro targets
    print("\nMacro Targets for Cutting:")
    targets = calc.calculate_macro_targets(weight=75, goal="cut")
    for key, value in targets.items():
        print(f"  {key}: {value}")
