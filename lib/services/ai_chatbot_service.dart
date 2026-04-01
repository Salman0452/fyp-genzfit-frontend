import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';
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
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';

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

  /// Fetch today's meals from Firestore
  Future<Map<String, dynamic>> _getTodaysMeals(String userId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('meals')
          .where('dateTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
          .orderBy('dateTime', descending: false)
          .get();

      double totalCalories = 0;
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFats = 0;
      List<String> mealsList = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final mealName = data['mealName'] ?? 'Unknown';
        final mealType = data['mealType'] ?? 'meal';
        final calories = (data['calories'] as num?)?.toDouble() ?? 0;
        final protein = (data['protein'] as num?)?.toDouble() ?? 0;
        final carbs = (data['carbs'] as num?)?.toDouble() ?? 0;
        final fats = (data['fats'] as num?)?.toDouble() ?? 0;

        totalCalories += calories;
        totalProtein += protein;
        totalCarbs += carbs;
        totalFats += fats;

        mealsList.add(
          '$mealType: $mealName (${calories.toStringAsFixed(0)}cal, ${protein.toStringAsFixed(1)}g protein)',
        );
      }

      return {
        'meals': mealsList,
        'totalCalories': totalCalories,
        'totalProtein': totalProtein,
        'totalCarbs': totalCarbs,
        'totalFats': totalFats,
      };
    } catch (e) {
      print('Error fetching today\'s meals: $e');
      return {
        'meals': [],
        'totalCalories': 0,
        'totalProtein': 0,
        'totalCarbs': 0,
        'totalFats': 0,
      };
    }
  }

  /// Fetch today's exercises from Firestore
  Future<Map<String, dynamic>> _getTodaysExercises(String userId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('exercises')
          .where('dateTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
          .orderBy('dateTime', descending: false)
          .get();

      double totalDuration = 0;
      int totalCalories = 0;
      List<String> exercisesList = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final exerciseName = data['exerciseName'] ?? 'Unknown';
        final category = data['category'] ?? 'general';
        final duration = (data['duration'] as num?)?.toDouble() ?? 0;
        final calories = (data['calories'] as num?)?.toInt() ?? 0;
        final sets = data['sets'] ?? 0;
        final reps = data['reps'] ?? 0;

        totalDuration += duration;
        totalCalories += calories;

        final details = sets > 0 && reps > 0
            ? '$sets×$reps'
            : '${duration.toStringAsFixed(0)}min';
        exercisesList.add(
          '$exerciseName ($category): $details, ${calories}cal burned',
        );
      }

      return {
        'exercises': exercisesList,
        'totalDuration': totalDuration,
        'totalCalories': totalCalories,
      };
    } catch (e) {
      print('Error fetching today\'s exercises: $e');
      return {
        'exercises': [],
        'totalDuration': 0,
        'totalCalories': 0,
      };
    }
  }

  /// Build context prompt from user data (optimized for token efficiency)
  Future<String> _buildContextPrompt(String userId, UserModel user) async {
    final measurement = await getLatestMeasurement(userId);
    final todaysMeals = await _getTodaysMeals(userId);
    final todaysExercises = await _getTodaysExercises(userId);

    // Compact context to reduce token usage
    String context =
        '''You are GenZFit AI Coach - fitness & nutrition advisor only.
Refuse non-fitness topics. Be encouraging, specific, data-driven.

USER: ${user.name} | Goal: ${user.goals ?? 'fitness'}''';

    if (measurement != null) {
      context +=
          '''\nMEASUREMENTS: Height ${measurement.height.toStringAsFixed(0)}cm | Weight ${measurement.weight.toStringAsFixed(1)}kg | BMI ${measurement.bmi.toStringAsFixed(1)} (${measurement.bmiCategory})''';
    }

    // Add TODAY'S MEALS
    final mealsData = todaysMeals;
    if ((mealsData['meals'] as List).isNotEmpty) {
      context += '\nMEALS: ';
      for (var meal in (mealsData['meals'] as List)) {
        context += '$meal | ';
      }
      context += '''
Totals: ${(mealsData['totalCalories'] as num).toStringAsFixed(0)}cal | P: ${(mealsData['totalProtein'] as num).toStringAsFixed(0)}g | C: ${(mealsData['totalCarbs'] as num).toStringAsFixed(0)}g | F: ${(mealsData['totalFats'] as num).toStringAsFixed(0)}g''';
    }

    // Add TODAY'S EXERCISES
    final exercisesData = todaysExercises;
    if ((exercisesData['exercises'] as List).isNotEmpty) {
      context += '\nEXERCISES: ';
      for (var exercise in (exercisesData['exercises'] as List)) {
        context += '$exercise | ';
      }
      context +=
          '''\nTotals: ${(exercisesData['totalDuration'] as num).toStringAsFixed(0)}min | ${exercisesData['totalCalories']}cal''';
    }

    return context;
  }

  /// Send a message and get AI response
  Future<String> sendMessage({
    required String userId,
    required UserModel user,
    required String message,
  }) async {
    try {
      // Validate API key before making request
      if (_apiKey.isEmpty) {
        print('❌ ERROR: GROQ_API_KEY is not configured in .env file');
        return 'AI Service Error: API key not configured. Please contact support.';
      }

      // Validate API key format
      if (!_apiKey.startsWith('gsk_')) {
        print('❌ ERROR: API key does not start with "gsk_"');
        print(
            '🔑 API key starts with: ${_apiKey.substring(0, min(_apiKey.length, 10))}');
        return 'Configuration Error: Invalid API key format. Please verify your Groq API key.';
      }

      // Check for whitespace or special characters
      if (_apiKey.contains(' ') ||
          _apiKey.contains('\n') ||
          _apiKey.contains('\t')) {
        print('❌ ERROR: API key contains whitespace or special characters');
        return 'Configuration Error: API key contains invalid characters (spaces/newlines). Please clean your .env file.';
      }

      // Log API key info for debugging
      print('📤 Sending message to Groq API...');
      print('🔑 API Key length: ${_apiKey.length} chars');
      print(
          '🔑 API Key first 20 chars: ${_apiKey.substring(0, min(_apiKey.length, 20))}');
      print(
          '🔑 API Key last 10 chars: ${_apiKey.substring(max(0, _apiKey.length - 10))}');

      // Save user message
      final userMessage = ChatMessage(
        role: 'user',
        content: message,
        timestamp: DateTime.now(),
      );
      await saveMessage(userId, userMessage);

      // Get conversation history
      final history = await getConversationHistory(userId);

      // Build context with today's meals and exercises
      final contextPrompt = await _buildContextPrompt(userId, user);
      print('📝 System prompt length: ${contextPrompt.length} characters');

      // Build messages array for Groq API
      final messages = <Map<String, String>>[];

      // Add system context
      messages.add({
        'role': 'system',
        'content': contextPrompt,
      });

      // Add conversation history (last 5 messages for token efficiency)
      final recentHistory =
          history.length > 5 ? history.sublist(history.length - 5) : history;

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

      print('📨 Total messages in context: ${messages.length}');

      // Prepare request body
      final requestBody = jsonEncode({
        'model': 'llama-3.1-8b-instant',
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 1024,
        'top_p': 0.95,
      });
      print('📤 Request body size: ${requestBody.length} bytes');

      // Call Groq API with timeout and better error handling
      http.Response response;
      try {
        response = await http
            .post(
              Uri.parse(_baseUrl),
              headers: {
                'Authorization': 'Bearer $_apiKey',
                'Content-Type': 'application/json',
              },
              body: requestBody,
            )
            .timeout(
              const Duration(seconds: 45),
              onTimeout: () => throw TimeoutException(
                  'Groq API request timed out after 45 seconds'),
            );
      } on SocketException catch (e) {
        print('❌ SOCKET ERROR: $e');
        return 'Network Error: Unable to connect to Groq API. Please check your internet connection and try again.';
      } catch (e) {
        if (e is TimeoutException) {
          print('❌ TIMEOUT: $e');
          return 'Request Timeout: The Groq API took too long to respond. Please try again in a moment.';
        }
        print('❌ REQUEST ERROR: $e');
        if (e.toString().contains('Connection closed')) {
          return 'Connection Error: The server closed the connection. This might be due to rate limiting. Please wait a moment and try again.';
        }
        rethrow;
      }

      print('📥 Groq API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'] as String;
        print('✅ AI Response generated (${aiResponse.length} characters)');

        // Save AI response
        final assistantMessage = ChatMessage(
          role: 'assistant',
          content: aiResponse,
          timestamp: DateTime.now(),
        );
        await saveMessage(userId, assistantMessage);

        return aiResponse;
      } else if (response.statusCode == 401) {
        print('❌ ERROR 401: Invalid API key');
        print('📋 Response body: ${response.body}');
        return 'Authentication Error: Your Groq API key is invalid or expired. Please regenerate it at groq.com and update the .env file.';
      } else if (response.statusCode == 429) {
        print('❌ ERROR 429: Rate limit exceeded');
        return 'Rate Limit: Too many requests. Please wait a moment and try again.';
      } else if (response.statusCode == 400) {
        print('❌ ERROR 400: Bad request - ${response.body}');
        return 'Request Error: The message format was invalid. Please try again.';
      } else {
        print('❌ ERROR ${response.statusCode}: ${response.body}');
        return 'Server Error: Groq API returned status ${response.statusCode}. Please try again later.';
      }
    } catch (e) {
      print('❌ EXCEPTION Error sending message to AI: $e');

      // Better error categorization
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('connection closed') ||
          errorStr.contains('connection reset')) {
        return 'Connection Closed: The server closed the connection. This might be a temporary service issue. Please try again in a moment.';
      } else if (errorStr.contains('socket') ||
          errorStr.contains('connection refused')) {
        return 'Network Error: Unable to connect to Groq API. Please check your internet connection and try again.';
      } else if (errorStr.contains('timeout')) {
        return 'Timeout Error: The request took too long. Please try again.';
      } else if (errorStr.contains('handshake') ||
          errorStr.contains('certificate')) {
        return 'SSL Error: Security certificate issue. Please try again or contact support.';
      }

      return 'Unexpected Error: $e';
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
  Future<List<String>> getSuggestedPrompts(
      String userId, UserModel user) async {
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
      } else if (measurement.bmiCategory == 'Overweight' ||
          measurement.bmiCategory == 'Obese') {
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
