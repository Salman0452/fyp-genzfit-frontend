import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:genzfit/models/user_model.dart';
import 'package:genzfit/models/measurement_model.dart';

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      role: map['role'] ?? 'user',
      content: map['content'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}

class AIChatbotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _apiKey;
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  AIChatbotService({required String apiKey}) : _apiKey = apiKey;

  /// Get conversation history for a user
  Future<List<ChatMessage>> getConversationHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chatbot_history')
          .doc(userId)
          .collection('conversations')
          .orderBy('timestamp', descending: false)
          .limit(50) // Limit to last 50 messages
          .get();

      return snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting conversation history: $e');
      return [];
    }
  }

  /// Save a message to conversation history
  Future<void> saveMessage(String userId, ChatMessage message) async {
    try {
      await _firestore
          .collection('chatbot_history')
          .doc(userId)
          .collection('conversations')
          .add(message.toMap());
    } catch (e) {
      print('Error saving message: $e');
    }
  }

  /// Get user's latest measurement data
  Future<MeasurementModel?> getLatestMeasurement(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('measurements')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return MeasurementModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      print('Error getting latest measurement: $e');
      return null;
    }
  }

  /// Build context prompt from user data
  Future<String> _buildContextPrompt(String userId, UserModel user) async {
    final measurement = await getLatestMeasurement(userId);
    
    // Get user's recommendations (meals and exercises)
    final recommendations = await _getRecommendations(userId);
    
    // Get user's progress history
    final progressHistory = await _getProgressHistory(userId);
    
    String context = '''
You are GenZFit AI Coach, a highly knowledgeable and supportive personal fitness and nutrition assistant. You have complete access to the user's fitness profile and should provide personalized, data-driven advice.

=== USER PROFILE ===
Name: ${user.name}
Email: ${user.email}
Primary Goal: ${user.goals ?? 'Not specified'}
Account Created: ${user.createdAt.toString().split(' ')[0]}
''';

    if (measurement != null) {
      context += '''

=== CURRENT BODY MEASUREMENTS (as of ${measurement.date.toString().split(' ')[0]}) ===
Height: ${measurement.height.toStringAsFixed(1)} cm (${(measurement.height / 2.54 / 12).toStringAsFixed(1)} ft)
Weight: ${measurement.weight.toStringAsFixed(1)} kg (${(measurement.weight * 2.20462).toStringAsFixed(1)} lbs)
BMI: ${measurement.bmi.toStringAsFixed(1)} - Category: ${measurement.bmiCategory}
''';

      if (measurement.estimatedMeasurements.isNotEmpty) {
        context += '\n=== DETAILED BODY MEASUREMENTS ===\n';
        measurement.estimatedMeasurements.forEach((key, value) {
          final formattedKey = key.replaceAllMapped(
            RegExp(r'([A-Z])'),
            (match) => ' ${match.group(0)}',
          ).trim();
          context += '${formattedKey.substring(0, 1).toUpperCase()}${formattedKey.substring(1)}: ${value.toStringAsFixed(1)} cm\n';
        });
      }

      if (measurement.notes != null && measurement.notes!.isNotEmpty) {
        context += '\nUser Notes: ${measurement.notes}\n';
      }
    }

    // Add recommendations if available
    if (recommendations['meals'] != null && recommendations['meals'].isNotEmpty) {
      context += '\n=== CURRENT MEAL PLAN ===\n';
      final meals = recommendations['meals'] as List;
      for (int i = 0; i < meals.length && i < 3; i++) {
        context += '${i + 1}. ${meals[i]}\n';
      }
    }

    if (recommendations['exercises'] != null && recommendations['exercises'].isNotEmpty) {
      context += '\n=== CURRENT EXERCISE PLAN ===\n';
      final exercises = recommendations['exercises'] as List;
      for (int i = 0; i < exercises.length && i < 5; i++) {
        context += '${i + 1}. ${exercises[i]}\n';
      }
    }

    // Add progress tracking
    if (progressHistory.isNotEmpty) {
      context += '\n=== PROGRESS TRACKING (Last ${progressHistory.length} measurements) ===\n';
      for (var record in progressHistory) {
        final date = record['date'];
        final weight = record['weight'];
        final bmi = record['bmi'];
        context += 'Date: $date - Weight: ${weight}kg, BMI: $bmi\n';
      }
      
      if (progressHistory.length > 1) {
        final firstWeight = progressHistory.last['weight'];
        final currentWeight = progressHistory.first['weight'];
        final weightChange = currentWeight - firstWeight;
        context += '\nTotal Weight Change: ${weightChange > 0 ? '+' : ''}${weightChange.toStringAsFixed(1)} kg\n';
      }
    }

    context += '''

=== YOUR ROLE & CAPABILITIES ===
- Analyze the user's measurements and provide personalized fitness advice
- Track their progress over time and celebrate achievements
- Suggest appropriate exercises based on their goal (${user.goals ?? 'general fitness'})
- Recommend meal plans and nutrition strategies
- Adjust recommendations based on their BMI category (${measurement?.bmiCategory ?? 'Unknown'})
- Provide motivation and encouragement
- Answer questions about workouts, nutrition, and health

=== GUIDELINES ===
✓ Be encouraging and supportive, especially when discussing body measurements
✓ Provide specific, actionable advice based on their data
✓ Reference their measurements when giving recommendations
✓ Track and acknowledge their progress
✓ Adjust difficulty based on their current fitness level
✓ If asked about medical conditions, advise consulting a healthcare professional
✓ Keep responses concise but informative (2-4 paragraphs max)
✓ Use a friendly, conversational tone
✓ Celebrate small wins and progress milestones

=== IMPORTANT ===
You have access to all user data above. Use it to provide personalized, data-driven advice. Always consider their goal, current measurements, and progress when responding.

Now, please respond to the user's message with personalized fitness guidance.
''';

    return context;
  }

  /// Get user's latest recommendations
  Future<Map<String, dynamic>> _getRecommendations(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('recommendations')
          .where('userId', isEqualTo: userId)
          .orderBy('generatedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return {};

      final data = snapshot.docs.first.data();
      return {
        'meals': data['mealPlan'] ?? data['meals'] ?? [],
        'exercises': data['exercisePlan'] ?? data['exercises'] ?? [],
      };
    } catch (e) {
      print('Error getting recommendations: $e');
      return {};
    }
  }

  /// Get user's progress history
  Future<List<Map<String, dynamic>>> _getProgressHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('measurements')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(5)
          .get();

      return snapshot.docs.map((doc) {
        final measurement = MeasurementModel.fromFirestore(doc);
        return {
          'date': measurement.date.toString().split(' ')[0],
          'weight': measurement.weight,
          'bmi': double.parse(measurement.bmi.toStringAsFixed(1)),
        };
      }).toList();
    } catch (e) {
      print('Error getting progress history: $e');
      return [];
    }
  }

  /// Send a message and get AI response
  Future<String> sendMessage({
    required String userId,
    required UserModel user,
    required String message,
  }) async {
    try {
      // Save user message
      final userMessage = ChatMessage(
        role: 'user',
        content: message,
        timestamp: DateTime.now(),
      );
      await saveMessage(userId, userMessage);

      // Get conversation history
      final history = await getConversationHistory(userId);
      
      // Build context
      final contextPrompt = await _buildContextPrompt(userId, user);
      
      // Build messages array for Groq API
      final messages = <Map<String, String>>[];
      
      // Add system context
      messages.add({
        'role': 'system',
        'content': contextPrompt,
      });
      
      // Add conversation history (last 10 messages for context)
      final recentHistory = history.length > 10 
          ? history.sublist(history.length - 10) 
          : history;
      
      for (var msg in recentHistory) {
        messages.add({
          'role': msg.role,
          'content': msg.content,
        });
      }

      // Add current message
      messages.add({
        'role': 'user',
        'content': message,
      });

      // Call Groq API
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 1024,
          'top_p': 0.95,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'] as String;

        // Save AI response
        final assistantMessage = ChatMessage(
          role: 'assistant',
          content: aiResponse,
          timestamp: DateTime.now(),
        );
        await saveMessage(userId, assistantMessage);

        return aiResponse;
      } else {
        print('Groq API error: ${response.statusCode} - ${response.body}');
        return 'Sorry, I couldn\'t generate a response. Please try again.';
      }
    } catch (e) {
      print('Error sending message to AI: $e');
      return 'Sorry, I encountered an error. Please try again later.';
    }
  }

  /// Clear conversation history
  Future<void> clearHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chatbot_history')
          .doc(userId)
          .collection('conversations')
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error clearing history: $e');
    }
  }

  /// Get suggested prompts based on user data
  Future<List<String>> getSuggestedPrompts(String userId, UserModel user) async {
    final measurement = await getLatestMeasurement(userId);
    
    List<String> prompts = [
      'How am I progressing towards my goal?',
      'Analyze my current measurements',
      'What should I focus on this week?',
    ];

    if (measurement != null) {
      if (user.goals == 'weightLoss') {
        prompts.addAll([
          'Create a calorie deficit meal plan for me',
          'What cardio exercises suit my BMI of ${measurement.bmi.toStringAsFixed(1)}?',
          'How can I speed up my weight loss safely?',
        ]);
      } else if (user.goals == 'weightGain') {
        prompts.addAll([
          'High-protein meals for muscle building',
          'Best strength training for my body type',
          'How much should I eat to gain muscle?',
        ]);
      } else if (user.goals == 'fitness') {
        prompts.addAll([
          'Design a balanced workout routine for me',
          'How to improve my overall fitness level?',
          'What exercises target my weak areas?',
        ]);
      }

      // Add BMI-specific prompts
      if (measurement.bmiCategory == 'Underweight') {
        prompts.add('Safe ways to increase my weight');
      } else if (measurement.bmiCategory == 'Overweight' || measurement.bmiCategory == 'Obese') {
        prompts.add('Exercises for my current weight');
      }
    } else {
      prompts.addAll([
        'How do I get started with fitness?',
        'What measurements should I track?',
      ]);
    }

    return prompts.take(6).toList();
  }
}
