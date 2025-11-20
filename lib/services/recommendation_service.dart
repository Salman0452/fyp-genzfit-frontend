import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/recommendation_model.dart';
import '../models/user_model.dart';
import '../models/measurement_model.dart';

class RecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  late final String _apiKey;

  RecommendationService() {
    _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      throw Exception('GROQ_API_KEY not found in .env file');
    }
  }

  // Generate personalized meal recommendations
  Future<List<MealRecommendation>> generateMealRecommendations({
    required UserModel user,
    required MeasurementModel? latestMeasurement,
    int count = 5,
  }) async {
    try {
      final prompt = _buildMealPrompt(user, latestMeasurement, count);
      final response = await _callGroqAPI(prompt);
      
      // Parse the JSON response
      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']') + 1;
      
      if (jsonStart == -1 || jsonEnd == 0) {
        throw Exception('Invalid JSON response from AI');
      }
      
      final jsonText = response.substring(jsonStart, jsonEnd);
      final List<dynamic> mealsJson = json.decode(jsonText);
      
      return mealsJson
          .map((meal) => MealRecommendation.fromMap(meal as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error generating meal recommendations: $e');
      // Return default recommendations on error
      return _getDefaultMealRecommendations(user.goals);
    }
  }

  // Generate personalized exercise recommendations
  Future<List<ExerciseRecommendation>> generateExerciseRecommendations({
    required UserModel user,
    required MeasurementModel? latestMeasurement,
    int count = 5,
  }) async {
    try {
      final prompt = _buildExercisePrompt(user, latestMeasurement, count);
      final response = await _callGroqAPI(prompt);
      
      // Parse the JSON response
      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']') + 1;
      
      if (jsonStart == -1 || jsonEnd == 0) {
        throw Exception('Invalid JSON response from AI');
      }
      
      final jsonText = response.substring(jsonStart, jsonEnd);
      final List<dynamic> exercisesJson = json.decode(jsonText);
      
      return exercisesJson
          .map((exercise) => ExerciseRecommendation.fromMap(exercise as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error generating exercise recommendations: $e');
      // Return default recommendations on error
      return _getDefaultExerciseRecommendations(user.goals);
    }
  }

  // Call Groq API
  Future<String> _callGroqAPI(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse(_groqApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a professional fitness and nutrition expert. Always respond with valid JSON only, no additional text.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 2000,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Groq API error: ${response.statusCode} - ${response.body}');
      }

      final data = json.decode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      return content;
    } catch (e) {
      print('Error calling Groq API: $e');
      rethrow;
    }
  }

  // Save recommendations to Firestore
  Future<void> saveRecommendation({
    required String userId,
    required RecommendationType type,
    required String title,
    required String description,
    required Map<String, dynamic> details,
    Map<String, dynamic>? basedOnMeasurements,
  }) async {
    try {
      final recommendation = Recommendation(
        id: '',
        userId: userId,
        type: type,
        title: title,
        description: description,
        details: details,
        generatedAt: DateTime.now(),
        basedOnMeasurements: basedOnMeasurements,
      );

      await _firestore.collection('recommendations').add(recommendation.toMap());
    } catch (e) {
      print('Error saving recommendation: $e');
      rethrow;
    }
  }

  // Get user's recommendations
  Stream<List<Recommendation>> getUserRecommendations(String userId) {
    return _firestore
        .collection('recommendations')
        .where('userId', isEqualTo: userId)
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recommendation.fromFirestore(doc))
            .toList());
  }

  // Delete recommendation
  Future<void> deleteRecommendation(String recommendationId) async {
    try {
      await _firestore.collection('recommendations').doc(recommendationId).delete();
    } catch (e) {
      print('Error deleting recommendation: $e');
      rethrow;
    }
  }

  // Build meal recommendation prompt
  String _buildMealPrompt(UserModel user, MeasurementModel? measurement, int count) {
    final bmi = measurement?.bmi ?? 0;
    final goal = user.goals ?? 'fitness';
    
    return '''
You are a professional nutritionist. Generate $count personalized meal recommendations for a user with the following profile:

User Profile:
- Goal: $goal
- Height: ${measurement?.height ?? 'Unknown'} cm
- Weight: ${measurement?.weight ?? 'Unknown'} kg
- BMI: ${bmi.toStringAsFixed(1)}
- Body Measurements: ${measurement?.estimatedMeasurements ?? {}}

Requirements:
1. Provide meals suitable for their goal (weight loss, weight gain, or fitness maintenance)
2. Include variety (breakfast, lunch, dinner, snacks)
3. Calculate appropriate calorie counts
4. Include macronutrient breakdown (protein, carbs, fats in grams)
5. Use simple, accessible ingredients

Return ONLY a valid JSON array with this exact structure (no additional text):
[
  {
    "name": "Meal Name",
    "description": "Brief description of the meal",
    "calories": 450,
    "ingredients": ["ingredient1", "ingredient2", "ingredient3"],
    "mealType": "breakfast|lunch|dinner|snack",
    "macros": {
      "protein": 30,
      "carbs": 45,
      "fats": 15
    }
  }
]
''';
  }

  // Build exercise recommendation prompt
  String _buildExercisePrompt(UserModel user, MeasurementModel? measurement, int count) {
    final goal = user.goals ?? 'fitness';
    final bmi = measurement?.bmi ?? 0;
    
    return '''
You are a professional fitness trainer. Generate $count personalized exercise recommendations for a user with the following profile:

User Profile:
- Goal: $goal
- Height: ${measurement?.height ?? 'Unknown'} cm
- Weight: ${measurement?.weight ?? 'Unknown'} kg
- BMI: ${bmi.toStringAsFixed(1)}
- Body Measurements: ${measurement?.estimatedMeasurements ?? {}}

Requirements:
1. Provide exercises suitable for their goal (weight loss, weight gain, or fitness maintenance)
2. Mix cardio and strength training appropriately
3. Include proper sets and reps
4. Specify difficulty level
5. Target different muscle groups
6. Include exercise duration

Return ONLY a valid JSON array with this exact structure (no additional text):
[
  {
    "name": "Exercise Name",
    "description": "How to perform this exercise with proper form",
    "sets": 3,
    "reps": 12,
    "durationMinutes": 15,
    "difficulty": "beginner|intermediate|advanced",
    "targetMuscles": ["muscle1", "muscle2"],
    "videoUrl": null
  }
]
''';
  }

  // Default meal recommendations (fallback)
  List<MealRecommendation> _getDefaultMealRecommendations(String? goal) {
    return [
      MealRecommendation(
        name: 'Protein Oatmeal Bowl',
        description: 'Hearty oatmeal with protein powder, berries, and nuts',
        calories: 350,
        ingredients: ['Oats', 'Protein powder', 'Berries', 'Almonds', 'Honey'],
        mealType: 'breakfast',
        macros: {'protein': 25, 'carbs': 45, 'fats': 10},
      ),
      MealRecommendation(
        name: 'Grilled Chicken Salad',
        description: 'Fresh greens with grilled chicken, vegetables, and olive oil dressing',
        calories: 400,
        ingredients: ['Chicken breast', 'Mixed greens', 'Tomatoes', 'Cucumber', 'Olive oil'],
        mealType: 'lunch',
        macros: {'protein': 35, 'carbs': 20, 'fats': 18},
      ),
      MealRecommendation(
        name: 'Salmon with Sweet Potato',
        description: 'Baked salmon with roasted sweet potato and broccoli',
        calories: 500,
        ingredients: ['Salmon fillet', 'Sweet potato', 'Broccoli', 'Lemon', 'Herbs'],
        mealType: 'dinner',
        macros: {'protein': 40, 'carbs': 45, 'fats': 20},
      ),
    ];
  }

  // Default exercise recommendations (fallback)
  List<ExerciseRecommendation> _getDefaultExerciseRecommendations(String? goal) {
    return [
      ExerciseRecommendation(
        name: 'Push-ups',
        description: 'Classic bodyweight exercise for chest, shoulders, and triceps',
        sets: 3,
        reps: 15,
        durationMinutes: 10,
        difficulty: 'beginner',
        targetMuscles: ['Chest', 'Shoulders', 'Triceps'],
      ),
      ExerciseRecommendation(
        name: 'Squats',
        description: 'Fundamental lower body exercise for legs and glutes',
        sets: 3,
        reps: 12,
        durationMinutes: 10,
        difficulty: 'beginner',
        targetMuscles: ['Quadriceps', 'Glutes', 'Hamstrings'],
      ),
      ExerciseRecommendation(
        name: 'Plank',
        description: 'Core strengthening exercise for abs and stability',
        sets: 3,
        reps: 1,
        durationMinutes: 5,
        difficulty: 'beginner',
        targetMuscles: ['Core', 'Abs', 'Lower back'],
      ),
    ];
  }
}
