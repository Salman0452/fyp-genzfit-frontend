import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.1-8b-instant'; // Groq's Llama model

  // Generate personalized fitness suggestions
  Future<String?> getPersonalizedSuggestions({
    required String name,
    required int age,
    required String gender,
    required double weight,
    required double height,
    required String fitnessGoal,
  }) async {
    try {
      // Calculate BMI
      final heightInMeters = height / 100;
      final bmi = weight / (heightInMeters * heightInMeters);

      // Create personalized prompt
      final prompt = '''
You are a professional fitness coach and nutritionist. You are helping a client named $name.

Client Profile:
- Age: $age years
- Gender: $gender
- Weight: $weight kg
- Height: $height cm
- BMI: ${bmi.toStringAsFixed(1)}
- Fitness Goal: $fitnessGoal

Based on this profile, provide:
1. A personalized fitness assessment
2. Specific workout recommendations (with exercises)
3. Nutrition advice
4. Weekly workout plan outline
5. Motivational tips

Keep the response concise, practical, and encouraging. Use bullet points for clarity.
''';

      final response = await _sendMessage(prompt);
      return response;
    } catch (e) {
      return 'Error generating suggestions: ${e.toString()}';
    }
  }

  // Chat with AI (general conversation)
  Future<String?> chat(String userMessage, {Map<String, dynamic>? userProfile}) async {
    try {
      String systemContext = 'You are a helpful fitness coach and nutritionist assistant.';
      
      if (userProfile != null) {
        systemContext += '''
        
The user you're helping has the following profile:
- Name: ${userProfile['name']}
- Age: ${userProfile['age']} years
- Gender: ${userProfile['gender']}
- Weight: ${userProfile['weight']} kg
- Height: ${userProfile['height']} cm
- Fitness Goal: ${userProfile['fitnessGoal']}

Use this context to provide personalized advice.
''';
      }

      final response = await _sendMessage(
        userMessage,
        systemContext: systemContext,
      );
      return response;
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  // Core API call to Groq
  Future<String?> _sendMessage(String message, {String? systemContext}) async {
    try {
      final messages = <Map<String, String>>[];
      
      if (systemContext != null) {
        messages.add({
          'role': 'system',
          'content': systemContext,
        });
      }
      
      messages.add({
        'role': 'user',
        'content': message,
      });

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return content;
      } else {
        return 'API Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Network Error: ${e.toString()}';
    }
  }

  // Get workout plan
  Future<String?> getWorkoutPlan({
    required String fitnessGoal,
    required int age,
    required String gender,
  }) async {
    final prompt = '''
Create a detailed 7-day workout plan for:
- Goal: $fitnessGoal
- Age: $age years
- Gender: $gender

Include:
- Daily exercises with sets and reps
- Rest days
- Warm-up and cool-down routines
- Progressive difficulty

Format it clearly for each day of the week.
''';

    return await _sendMessage(prompt);
  }

  // Get meal plan
  Future<String?> getMealPlan({
    required String fitnessGoal,
    required double weight,
    required int age,
  }) async {
    final prompt = '''
Create a healthy meal plan for:
- Goal: $fitnessGoal
- Current Weight: $weight kg
- Age: $age years

Provide:
- Daily calorie target
- Macronutrient breakdown
- Sample meals for breakfast, lunch, dinner, and snacks
- Hydration advice
- Foods to include and avoid

Keep it practical and easy to follow.
''';

    return await _sendMessage(prompt);
  }

  // Get exercise tips
  Future<String?> getExerciseTips(String exerciseName) async {
    final prompt = '''
Provide detailed tips for performing the exercise: $exerciseName

Include:
- Proper form and technique
- Common mistakes to avoid
- Breathing pattern
- Muscle groups targeted
- Variations for different fitness levels
- Safety precautions

Be concise but thorough.
''';

    return await _sendMessage(prompt);
  }
}
