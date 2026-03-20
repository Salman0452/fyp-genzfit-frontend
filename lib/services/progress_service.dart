import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/progress_tracking_model.dart';

class ProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://192.168.10.14:8000';

  // ── Get daily nutrition + exercise summary for last 7 days ─────────────────
  Future<List<Map<String, dynamic>>> getLast7DaysData(String userId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final rangeStart = todayStart.subtract(const Duration(days: 6));
    final rangeEnd = todayStart.add(const Duration(days: 1));

    final mealsFuture = _firestore
        .collection('meal_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(rangeEnd))
        .get();

    final exercisesFuture = _firestore
        .collection('exercise_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(rangeEnd))
        .get();

    final results = await Future.wait([mealsFuture, exercisesFuture]);
    final mealsSnap = results[0];
    final exercisesSnap = results[1];

    final Map<String, Map<String, dynamic>> byDay = {};
    for (int i = 6; i >= 0; i--) {
      final day = todayStart.subtract(Duration(days: i));
      final key = day.toIso8601String().split('T')[0];
      byDay[key] = {
        'date': key,
        'calories_consumed': 0,
        'protein': 0,
        'carbs': 0,
        'fats': 0,
        'calories_burned': 0,
        'meals_completed': 0,
        'meals_total': 0,
        'exercises_completed': 0,
        'exercises_total': 0,
      };
    }

    for (final doc in mealsSnap.docs) {
      final meal = MealCompletion.fromFirestore(doc);
      final key = meal.scheduledDate.toIso8601String().split('T')[0];
      final day = byDay[key];
      if (day == null) continue;

      day['meals_total'] = (day['meals_total'] as int) + 1;
      if (meal.status == CompletionStatus.completed) {
        day['meals_completed'] = (day['meals_completed'] as int) + 1;
        day['calories_consumed'] =
            (day['calories_consumed'] as int) + meal.calories;
        day['protein'] = (day['protein'] as int) +
            ((meal.macros['protein'] as num?)?.toInt() ?? 0);
        day['carbs'] = (day['carbs'] as int) +
            ((meal.macros['carbs'] as num?)?.toInt() ?? 0);
        day['fats'] = (day['fats'] as int) +
            ((meal.macros['fats'] as num?)?.toInt() ?? 0);
      }
    }

    for (final doc in exercisesSnap.docs) {
      final exercise = ExerciseCompletion.fromFirestore(doc);
      final key = exercise.scheduledDate.toIso8601String().split('T')[0];
      final day = byDay[key];
      if (day == null) continue;

      day['exercises_total'] = (day['exercises_total'] as int) + 1;
      if (exercise.status == CompletionStatus.completed) {
        day['exercises_completed'] = (day['exercises_completed'] as int) + 1;
        day['calories_burned'] = (day['calories_burned'] as int) +
            _estimateCaloriesBurned(
                exercise.durationMinutes, exercise.difficulty);
      }
    }

    return byDay.values.toList();
  }

  // ── Estimate calories burned based on duration and difficulty ──────────────
  int _estimateCaloriesBurned(int durationMinutes, String difficulty) {
    final met = switch (difficulty.toLowerCase()) {
      'beginner' => 4.0,
      'intermediate' => 6.0,
      'advanced' => 8.0,
      _ => 5.0,
    };
    // Assuming 70kg average weight: calories = MET * weight * hours
    return (met * 70 * (durationMinutes / 60)).toInt();
  }

  // ── Calculate current streak ────────────────────────────────────────────────
  Future<Map<String, int>> getStreakData(String userId) async {
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;
    bool currentStreakEnded = false;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final rangeStart = todayStart.subtract(const Duration(days: 59));
    final rangeEnd = todayStart.add(const Duration(days: 1));

    final snap = await _firestore
        .collection('exercise_completions')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'completed')
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(rangeEnd))
        .get();

    final completedDays = <String>{
      for (final doc in snap.docs)
        ((doc.data()['scheduledDate'] as Timestamp)
            .toDate()
            .toIso8601String()
            .split('T')[0]),
    };

    for (int i = 0; i < 60; i++) {
      final day = todayStart.subtract(Duration(days: i));
      final key = day.toIso8601String().split('T')[0];
      if (completedDays.contains(key)) {
        tempStreak++;
        if (!currentStreakEnded) {
          currentStreak = tempStreak;
        }
        longestStreak = max(longestStreak, tempStreak);
      } else {
        if (i > 0) {
          currentStreakEnded = true;
          tempStreak = 0;
        }
      }
    }

    return {
      'current': currentStreak,
      'longest': longestStreak,
    };
  }

  // ── Get today's exercises ───────────────────────────────────────────────────
  Future<List<ExerciseCompletion>> getTodayExercises(String userId) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    final snap = await _firestore
        .collection('exercise_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(end))
        .get();

    return snap.docs.map((d) => ExerciseCompletion.fromFirestore(d)).toList();
  }

  // ── Get today's nutrition totals ────────────────────────────────────────────
  Future<Map<String, int>> getTodayNutrition(String userId) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    final snap = await _firestore
        .collection('meal_completions')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'completed')
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(end))
        .get();

    int calories = 0, protein = 0, carbs = 0, fats = 0;
    for (final doc in snap.docs) {
      final meal = MealCompletion.fromFirestore(doc);
      calories += meal.calories;
      protein += (meal.macros['protein'] as num?)?.toInt() ?? 0;
      carbs += (meal.macros['carbs'] as num?)?.toInt() ?? 0;
      fats += (meal.macros['fats'] as num?)?.toInt() ?? 0;
    }

    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
    };
  }

  // ── Get today's completion counts ──────────────────────────────────────────
  Future<Map<String, int>> getTodayCompletionCounts(String userId) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    final mealsSnap = await _firestore
        .collection('meal_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(end))
        .get();

    final exercisesSnap = await _firestore
        .collection('exercise_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(end))
        .get();

    final completedMeals =
        mealsSnap.docs.where((d) => d.data()['status'] == 'completed').length;
    final completedExercises = exercisesSnap.docs
        .where((d) => d.data()['status'] == 'completed')
        .length;

    return {
      'meals_completed': completedMeals,
      'meals_total': mealsSnap.docs.length,
      'exercises_completed': completedExercises,
      'exercises_total': exercisesSnap.docs.length,
    };
  }

  // ── Get two most recent measurements ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getRecentMeasurements(
      String userId) async {
    final snap = await _firestore
        .collection('measurements')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .limit(2)
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      final meas = Map<String, dynamic>.from(
          data['estimatedMeasurements'] as Map? ?? {});
      return {
        'weight': (data['weight'] ?? 0).toDouble(),
        'chest': (meas['chest'] ?? 0).toDouble(),
        'waist': (meas['waist'] ?? 0).toDouble(),
        'hips': (meas['hips'] ?? 0).toDouble(),
        'shoulders': (meas['shoulders'] ?? 0).toDouble(),
        'thigh': (meas['thigh'] ?? 0).toDouble(),
        'date': data['date'] != null
            ? (data['date'] as Timestamp)
                .toDate()
                .toIso8601String()
                .split('T')[0]
            : '',
      };
    }).toList();
  }

  // ── Get AI progress analysis from backend ──────────────────────────────────
  Future<Map<String, dynamic>> getAIAnalysis({
    required String userId,
    required List<Map<String, dynamic>> weeklyData,
    required Map<String, dynamic> currentMeasurements,
    required Map<String, dynamic> previousMeasurements,
    required String goal,
    String fitnessLevel = 'intermediate',
  }) async {
    final response = await http.post(
      Uri.parse('$_backendUrl/analyze-progress'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'daily_nutrition': weeklyData,
        'current_measurements': currentMeasurements,
        'previous_measurements': previousMeasurements,
        'goal': goal,
        'fitness_level': fitnessLevel,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Analysis failed: ${response.statusCode}');
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  // ── Load user preferences from Firestore ──────────────────────────────────
  Future<Map<String, dynamic>?> loadUserPrefs(String userId) async {
    try {
      final doc =
          await _firestore.collection('user_preferences').doc(userId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  // ── Nutrition targets based on goal and weight ─────────────────────────────
  static Map<String, int> getNutritionTargets({
    required String goal,
    required double weightKg,
  }) {
    switch (goal) {
      case 'weight_loss':
      case 'weightLoss':
        return {
          'calories': 1600,
          'protein': (weightKg * 1.8).toInt(),
          'carbs': 180,
          'fats': 55,
        };
      case 'muscle_gain':
      case 'weightGain':
        return {
          'calories': 2500,
          'protein': (weightKg * 2.2).toInt(),
          'carbs': 300,
          'fats': 80,
        };
      default: // fitness
        return {
          'calories': 2000,
          'protein': (weightKg * 1.6).toInt(),
          'carbs': 250,
          'fats': 65,
        };
    }
  }
}
