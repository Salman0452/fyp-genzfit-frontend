import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UserPreferencesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://192.168.10.14:8000';

  // ── Save preferences to backend AND Firestore ──────────────────────────────
  Future<void> savePreferences({
    required String userId,
    required Map<String, dynamic> preferences,
  }) async {
    // 1. Persist to Firestore (survives app restarts)
    await _firestore
        .collection('user_preferences')
        .doc(userId)
        .set(preferences, SetOptions(merge: true));

    // 2. Sync to in-memory backend store
    try {
      await http.post(
        Uri.parse('$_backendUrl/user-preferences'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, ...preferences}),
      );
    } catch (e) {
      // Backend sync is best-effort; Firestore is source of truth
      print('⚠️ Backend preferences sync failed (will retry on next load): $e');
    }
  }

  // ── Load preferences: Firestore first, then sync to backend ───────────────
  Future<Map<String, dynamic>?> loadPreferences(String userId) async {
    try {
      final doc =
          await _firestore.collection('user_preferences').doc(userId).get();

      if (!doc.exists || doc.data() == null) return null;

      final prefs = doc.data()!;

      // Sync to backend so AI calls work
      try {
        await http.post(
          Uri.parse('$_backendUrl/user-preferences'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'user_id': userId, ...prefs}),
        );
        print('✅ Preferences synced to backend for user $userId');
      } catch (e) {
        print('⚠️ Backend preferences sync failed: $e');
      }

      return prefs;
    } catch (e) {
      print('❌ Error loading preferences: $e');
      return null;
    }
  }

  // ── Check if preferences exist in Firestore ────────────────────────────────
  Future<bool> hasPreferences(String userId) async {
    try {
      final doc =
          await _firestore.collection('user_preferences').doc(userId).get();
      return doc.exists && doc.data() != null;
    } catch (_) {
      return false;
    }
  }

  // ── Build the default preferences map for a new user ──────────────────────
  static Map<String, dynamic> defaultPreferences() {
    return {
      'workout_location': 'gym',
      'fitness_level': 'intermediate',
      'workout_days_per_week': 5,
      'workout_duration_minutes': 45,
      'available_equipment': <String>[],
      'disliked_exercises': <String>[],
      'injury_limitations': <String>[],
      'dietary_restrictions': <String>[],
      'food_allergies': <String>[],
      'cuisine_preference': 'pakistani',
      'meals_per_day': 4,
      'disliked_foods': <String>[],
      'goal': 'fitness',
      'age': 25,
      'height_cm': 170.0,
      'weight_kg': 70.0,
      'gender': 'male',
      'health_conditions': <String>[],
    };
  }
}
