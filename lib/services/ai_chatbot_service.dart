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
    
    String context = '''
You are GenZFit AI Coach, a knowledgeable and supportive fitness assistant. You provide personalized fitness advice, workout plans, nutrition guidance, and motivation.

User Profile:
- Name: ${user.name}
- Goal: ${user.goals ?? 'Not specified'}
''';

    if (measurement != null) {
      context += '''
- Height: ${measurement.height.toStringAsFixed(1)} cm
- Weight: ${measurement.weight.toStringAsFixed(1)} kg
- BMI: ${measurement.bmi.toStringAsFixed(1)} (${measurement.bmiCategory})
''';

      if (measurement.estimatedMeasurements.isNotEmpty) {
        context += '\nBody Measurements:\n';
        measurement.estimatedMeasurements.forEach((key, value) {
          context += '- ${key}: ${value.toStringAsFixed(1)} cm\n';
        });
      }
    }

    context += '''

Guidelines:
- Be encouraging and supportive
- Provide actionable, specific advice
- Consider the user's goal and current measurements
- If asked about medical conditions, advise consulting a healthcare professional
- Keep responses concise but informative
- Use a friendly, conversational tone
- Suggest exercises appropriate for their fitness level

Now, please respond to the user's message.
''';

    return context;
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
      'What exercises should I do today?',
      'Create a meal plan for me',
      'How can I stay motivated?',
    ];

    if (measurement != null) {
      if (user.goals == 'weightLoss') {
        prompts.addAll([
          'What\'s the best cardio for weight loss?',
          'How many calories should I eat?',
        ]);
      } else if (user.goals == 'weightGain') {
        prompts.addAll([
          'What protein-rich foods should I eat?',
          'Best exercises for muscle building?',
        ]);
      } else if (user.goals == 'fitness') {
        prompts.addAll([
          'How to improve my endurance?',
          'What\'s a balanced workout routine?',
        ]);
      }
    }

    return prompts;
  }
}
