import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/recommendation_model.dart';
import '../models/user_model.dart';
import '../models/measurement_model.dart';
import '../models/progress_tracking_model.dart';

class RecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://192.168.10.15:8000';

  RecommendationService() {
    print(
        '✅ RecommendationService initialized (using backend AI at $_backendUrl)');
  }

  // Get yesterday's completion summary for adaptive AI
  Future<Map<String, dynamic>> getYesterdayCompletionSummary(
      String userId) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final startOfDay = DateTime(yesterday.year, yesterday.month, yesterday.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final mealsSnapshot = await _firestore
        .collection('meal_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final exercisesSnapshot = await _firestore
        .collection('exercise_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final completedMeals = mealsSnapshot.docs
        .map((doc) => MealCompletion.fromFirestore(doc))
        .where((m) => m.status == CompletionStatus.completed)
        .toList();

    final completedExercises = exercisesSnapshot.docs
        .map((doc) => ExerciseCompletion.fromFirestore(doc))
        .where((e) => e.status == CompletionStatus.completed)
        .toList();

    final skippedMeals = mealsSnapshot.docs
        .map((doc) => MealCompletion.fromFirestore(doc))
        .where((m) => m.status == CompletionStatus.skipped)
        .toList();

    return {
      'completedMeals': completedMeals.map((m) => m.mealName).toList(),
      'completedExercises':
          completedExercises.map((e) => e.exerciseName).toList(),
      'skippedMeals': skippedMeals.map((m) => m.mealName).toList(),
      'mealsCompleted': completedMeals.length,
      'exercisesCompleted': completedExercises.length,
      'totalMealsScheduled': mealsSnapshot.docs.length,
      'totalExercisesScheduled': exercisesSnapshot.docs.length,
    };
  }

  // Get last 7 days preferences (most completed meals/exercises)
  Future<Map<String, List<String>>> getUserPreferences(String userId) async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    final mealsSnapshot = await _firestore
        .collection('meal_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
        .where('status', isEqualTo: CompletionStatus.completed.name)
        .get();

    final exercisesSnapshot = await _firestore
        .collection('exercise_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
        .where('status', isEqualTo: CompletionStatus.completed.name)
        .get();

    // Count frequency
    final mealFreq = <String, int>{};
    final exerciseFreq = <String, int>{};

    for (var doc in mealsSnapshot.docs) {
      final meal = MealCompletion.fromFirestore(doc);
      mealFreq[meal.mealName] = (mealFreq[meal.mealName] ?? 0) + 1;
    }

    for (var doc in exercisesSnapshot.docs) {
      final exercise = ExerciseCompletion.fromFirestore(doc);
      exerciseFreq[exercise.exerciseName] =
          (exerciseFreq[exercise.exerciseName] ?? 0) + 1;
    }

    // Sort by frequency and get top preferences
    final topMeals = mealFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topExercises = exerciseFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'favoriteMeals': topMeals.take(5).map((e) => e.key).toList(),
      'favoriteExercises': topExercises.take(5).map((e) => e.key).toList(),
    };
  }

  // Generate today's meal recommendations with adaptive AI
  Future<List<MealRecommendation>> generateDailyMeals({
    required UserModel user,
    required MeasurementModel? latestMeasurement,
  }) async {
    print('🍽️ Generating TODAY\'S meals for user: ${user.id}');
    try {
      final yesterdaySummary = await getYesterdayCompletionSummary(user.id);
      final preferences = await getUserPreferences(user.id);
      final history = await getUserCompletionHistory(user.id);

      print(
          '📊 Yesterday: ${yesterdaySummary['mealsCompleted']}/${yesterdaySummary['totalMealsScheduled']} meals completed');

      final response = await _callBackendAI(
        'daily_meals',
        {
          'userId': user.id,
          'yesterdayMealsCompleted': yesterdaySummary['mealsCompleted'],
          'yesterdayMealsTotal': yesterdaySummary['totalMealsScheduled'],
          'skippedMeals': yesterdaySummary['skippedMeals'],
          'favoriteMeals': preferences['favoriteMeals'],
          'recentMeals': history['allRecentMeals'],
        },
      );

      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']') + 1;

      if (jsonStart == -1 || jsonEnd == 0) {
        print('❌ Invalid JSON response - no JSON array found');
        throw Exception('Invalid JSON response from AI');
      }

      final jsonText = response.substring(jsonStart, jsonEnd);
      print(
          '🤖 AI Generated Today\'s Meals (length: ${jsonText.length} chars)');

      final List<dynamic> mealsJson = json.decode(jsonText);
      final meals = mealsJson
          .map((meal) =>
              MealRecommendation.fromMap(meal as Map<String, dynamic>))
          .toList();

      print('✅ AI Generated ${meals.length} meals for today');

      // Save to Firestore with today's date
      await _saveDailyMeals(user.id, meals);

      return meals;
    } catch (e) {
      print('❌ AI Daily Meal Generation Failed: $e');
      print('⚠️ Using fallback default meals');
      final fallbackMeals = _getDefaultMealRecommendations(user.goals);
      await _saveDailyMeals(user.id, fallbackMeals);
      return fallbackMeals;
    }
  }

  // Generate today's exercise recommendations with adaptive AI
  Future<List<ExerciseRecommendation>> generateDailyExercises({
    required UserModel user,
    required MeasurementModel? latestMeasurement,
  }) async {
    print('💪 Generating TODAY\'S exercises for user: ${user.id}');
    try {
      final yesterdaySummary = await getYesterdayCompletionSummary(user.id);
      final preferences = await getUserPreferences(user.id);
      final history = await getUserCompletionHistory(user.id);

      print(
          '📊 Yesterday: ${yesterdaySummary['exercisesCompleted']}/${yesterdaySummary['totalExercisesScheduled']} exercises completed');

      final response = await _callBackendAI(
        'daily_exercises',
        {
          'userId': user.id,
          'yesterdayExercisesCompleted': yesterdaySummary['exercisesCompleted'],
          'yesterdayExercisesTotal':
              yesterdaySummary['totalExercisesScheduled'],
          'favoriteExercises': preferences['favoriteExercises'],
          'recentExercises': history['allRecentExercises'],
        },
      );

      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']') + 1;

      if (jsonStart == -1 || jsonEnd == 0) {
        print('❌ Invalid JSON response - no JSON array found');
        throw Exception('Invalid JSON response from AI');
      }

      final jsonText = response.substring(jsonStart, jsonEnd);
      print(
          '🤖 AI Generated Today\'s Exercises (length: ${jsonText.length} chars)');

      final List<dynamic> exercisesJson = json.decode(jsonText);
      final exercises = exercisesJson
          .map((ex) =>
              ExerciseRecommendation.fromMap(ex as Map<String, dynamic>))
          .toList();

      print('✅ AI Generated ${exercises.length} exercises for today');

      // Save to Firestore with today's date
      await _saveDailyExercises(user.id, exercises);

      return exercises;
    } catch (e) {
      print('❌ AI Daily Exercise Generation Failed: $e');
      print('⚠️ Using fallback default exercises');
      final fallbackExercises = _getDefaultExerciseRecommendations(user.goals);
      await _saveDailyExercises(user.id, fallbackExercises);
      return fallbackExercises;
    }
  }

  // Save daily meals to Firestore
  Future<void> _saveDailyMeals(
      String userId, List<MealRecommendation> meals) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    // First, delete any existing meals for today to avoid duplicates
    final existingMeals = await _firestore
        .collection('meal_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate', isEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    for (var doc in existingMeals.docs) {
      await doc.reference.delete();
    }

    // Now save new meals
    for (var meal in meals) {
      final mealCompletion = MealCompletion(
        id: '',
        userId: userId,
        mealName: meal.name,
        mealType: meal.mealType,
        scheduledDate: startOfDay,
        status: CompletionStatus.pending,
        calories: meal.calories,
        macros: meal.macros,
      );

      await _firestore
          .collection('meal_completions')
          .add(mealCompletion.toMap());
    }

    print('💾 Saved ${meals.length} new meals for today');
  }

  // Save daily exercises to Firestore
  Future<void> _saveDailyExercises(
      String userId, List<ExerciseRecommendation> exercises) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    // First, delete any existing exercises for today to avoid duplicates
    final existingExercises = await _firestore
        .collection('exercise_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate', isEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    for (var doc in existingExercises.docs) {
      await doc.reference.delete();
    }

    // Now save new exercises
    for (var exercise in exercises) {
      final exerciseCompletion = ExerciseCompletion(
        id: '',
        userId: userId,
        exerciseName: exercise.name,
        scheduledDate: startOfDay,
        status: CompletionStatus.pending,
        sets: exercise.sets,
        reps: exercise.reps,
        durationMinutes: exercise.durationMinutes,
        difficulty: exercise.difficulty,
        targetMuscles: exercise.targetMuscles,
      );

      await _firestore
          .collection('exercise_completions')
          .add(exerciseCompletion.toMap());
    }

    print('💾 Saved ${exercises.length} new exercises for today');
  }

  // Get week start and end dates
  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: weekday - 1));
  }

  DateTime _getWeekEnd(DateTime date) {
    return _getWeekStart(date).add(const Duration(days: 6));
  }

  // Check if user has a schedule for current week
  Future<WeeklySchedule?> getCurrentWeekSchedule(String userId) async {
    final weekStart = _getWeekStart(DateTime.now());

    final snapshot = await _firestore
        .collection('weekly_schedules')
        .where('userId', isEqualTo: userId)
        .where('weekStartDate', isEqualTo: Timestamp.fromDate(weekStart))
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return WeeklySchedule.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  // Get user's completion history
  Future<Map<String, dynamic>> getUserCompletionHistory(String userId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    final mealsSnapshot = await _firestore
        .collection('meal_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate',
            isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    final exercisesSnapshot = await _firestore
        .collection('exercise_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate',
            isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    final completedMeals = mealsSnapshot.docs
        .map((doc) => MealCompletion.fromFirestore(doc))
        .where((m) => m.status == CompletionStatus.completed)
        .toList();

    final completedExercises = exercisesSnapshot.docs
        .map((doc) => ExerciseCompletion.fromFirestore(doc))
        .where((e) => e.status == CompletionStatus.completed)
        .toList();

    // Also get ALL recent meals/exercises (including pending) for better variety
    final allRecentMeals = mealsSnapshot.docs
        .map((doc) => MealCompletion.fromFirestore(doc))
        .toList();

    final allRecentExercises = exercisesSnapshot.docs
        .map((doc) => ExerciseCompletion.fromFirestore(doc))
        .toList();

    // Extract unique meal and exercise names
    final completedMealNames =
        completedMeals.map((m) => m.mealName).toSet().toList();
    final completedExerciseNames =
        completedExercises.map((e) => e.exerciseName).toSet().toList();

    // All recent (for avoiding repetition)
    final allRecentMealNames =
        allRecentMeals.map((m) => m.mealName).toSet().toList();
    final allRecentExerciseNames =
        allRecentExercises.map((e) => e.exerciseName).toSet().toList();

    return {
      'completedMeals': completedMealNames,
      'completedExercises': completedExerciseNames,
      'allRecentMeals': allRecentMealNames,
      'allRecentExercises': allRecentExerciseNames,
      'totalMealsCompleted': completedMeals.length,
      'totalExercisesCompleted': completedExercises.length,
      'completionRate': _calculateCompletionRate(
          mealsSnapshot.docs.length + exercisesSnapshot.docs.length,
          completedMeals.length + completedExercises.length),
    };
  }

  double _calculateCompletionRate(int total, int completed) {
    if (total == 0) return 0.0;
    return (completed / total * 100);
  }

  // Generate weekly meal schedule with variety
  Future<Map<String, List<MealRecommendation>>> generateWeeklyMealPlan({
    required UserModel user,
    required MeasurementModel? latestMeasurement,
  }) async {
    print('🍽️ Starting weekly meal plan generation for user: ${user.id}');
    try {
      final history = await getUserCompletionHistory(user.id);
      final completedMeals = history['completedMeals'] as List<String>;
      print('📊 Found ${completedMeals.length} previously completed meals');

      final response = await _callBackendAI(
        'weekly_meals',
        {
          'userId': user.id,
          'recentMeals': completedMeals,
        },
      );

      // Parse the JSON response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;

      if (jsonStart == -1 || jsonEnd == 0) {
        print('❌ Invalid JSON response - no JSON object found');
        throw Exception('Invalid JSON response from AI');
      }

      final jsonText = response.substring(jsonStart, jsonEnd);
      print(
          '🤖 AI Generated Meal Plan Response (length: ${jsonText.length} chars)');

      final Map<String, dynamic> weekPlan = json.decode(jsonText);

      // Convert to map of day -> meal list
      final Map<String, List<MealRecommendation>> weeklyPlan = {};
      weekPlan.forEach((day, meals) {
        weeklyPlan[day] = (meals as List)
            .map((meal) =>
                MealRecommendation.fromMap(meal as Map<String, dynamic>))
            .toList();
      });

      print(
          '✅ AI Generated ${weeklyPlan.length} days with ${weeklyPlan.values.fold(0, (sum, meals) => sum + meals.length)} unique meals');
      return weeklyPlan;
    } catch (e) {
      print('❌ AI Meal Generation Failed: $e');
      print('⚠️ Using fallback default meal plan');
      return _getDefaultWeeklyMealPlan(user.goals);
    }
  }

  // Generate weekly exercise schedule
  Future<Map<String, List<ExerciseRecommendation>>> generateWeeklyExercisePlan({
    required UserModel user,
    required MeasurementModel? latestMeasurement,
  }) async {
    print('💪 Starting weekly exercise plan generation for user: ${user.id}');
    try {
      final history = await getUserCompletionHistory(user.id);
      final completedExercises = history['completedExercises'] as List<String>;
      print(
          '📊 Found ${completedExercises.length} previously completed exercises');

      final response = await _callBackendAI(
        'weekly_exercises',
        {
          'userId': user.id,
          'recentExercises': completedExercises,
        },
      );

      // Parse the JSON response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;

      if (jsonStart == -1 || jsonEnd == 0) {
        print('❌ Invalid JSON response - no JSON object found');
        throw Exception('Invalid JSON response from AI');
      }

      final jsonText = response.substring(jsonStart, jsonEnd);
      print(
          '🤖 AI Generated Exercise Plan Response (length: ${jsonText.length} chars)');

      final Map<String, dynamic> weekPlan = json.decode(jsonText);

      // Convert to map of day -> exercise list
      final Map<String, List<ExerciseRecommendation>> weeklyPlan = {};
      weekPlan.forEach((day, exercises) {
        weeklyPlan[day] = (exercises as List)
            .map((exercise) => ExerciseRecommendation.fromMap(
                exercise as Map<String, dynamic>))
            .toList();
      });

      print(
          '✅ AI Generated ${weeklyPlan.length} days with ${weeklyPlan.values.fold(0, (sum, exs) => sum + exs.length)} unique exercises');
      return weeklyPlan;
    } catch (e) {
      print('❌ AI Exercise Generation Failed: $e');
      print('⚠️ Using fallback default exercise plan');
      return _getDefaultWeeklyExercisePlan(user.goals);
    }
  }

  // Save weekly schedule to Firestore
  Future<void> saveWeeklySchedule({
    required String userId,
    required Map<String, List<MealRecommendation>> mealPlan,
    required Map<String, List<ExerciseRecommendation>> exercisePlan,
  }) async {
    final weekStart = _getWeekStart(DateTime.now());
    final weekEnd = _getWeekEnd(DateTime.now());

    // Save meal completions
    final Map<String, List<String>> mealScheduleIds = {};
    for (var entry in mealPlan.entries) {
      final day = entry.key;
      final meals = entry.value;
      final mealIds = <String>[];

      for (var i = 0; i < meals.length; i++) {
        final meal = meals[i];
        final scheduledDate = weekStart.add(Duration(days: _getDayIndex(day)));

        final mealCompletion = MealCompletion(
          id: '',
          userId: userId,
          mealName: meal.name,
          mealType: meal.mealType,
          scheduledDate: scheduledDate,
          status: CompletionStatus.pending,
          calories: meal.calories,
          macros: meal.macros,
        );

        final doc = await _firestore
            .collection('meal_completions')
            .add(mealCompletion.toMap());
        mealIds.add(doc.id);
      }
      mealScheduleIds[day] = mealIds;
    }

    // Save exercise completions
    final Map<String, List<String>> exerciseScheduleIds = {};
    for (var entry in exercisePlan.entries) {
      final day = entry.key;
      final exercises = entry.value;
      final exerciseIds = <String>[];

      for (var exercise in exercises) {
        final scheduledDate = weekStart.add(Duration(days: _getDayIndex(day)));

        final exerciseCompletion = ExerciseCompletion(
          id: '',
          userId: userId,
          exerciseName: exercise.name,
          scheduledDate: scheduledDate,
          status: CompletionStatus.pending,
          sets: exercise.sets,
          reps: exercise.reps,
          durationMinutes: exercise.durationMinutes,
          difficulty: exercise.difficulty,
          targetMuscles: exercise.targetMuscles,
        );

        final doc = await _firestore
            .collection('exercise_completions')
            .add(exerciseCompletion.toMap());
        exerciseIds.add(doc.id);
      }
      exerciseScheduleIds[day] = exerciseIds;
    }

    // Save weekly schedule
    final schedule = WeeklySchedule(
      id: '',
      userId: userId,
      weekStartDate: weekStart,
      weekEndDate: weekEnd,
      mealSchedule: mealScheduleIds,
      exerciseSchedule: exerciseScheduleIds,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('weekly_schedules').add(schedule.toMap());
  }

  int _getDayIndex(String day) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days.indexOf(day);
  }

  // Mark meal as completed
  Future<void> completeMeal(String mealId) async {
    await _firestore.collection('meal_completions').doc(mealId).update({
      'status': CompletionStatus.completed.name,
      'completedAt': Timestamp.now(),
    });
  }

  // Mark exercise as completed
  Future<void> completeExercise(String exerciseId) async {
    await _firestore.collection('exercise_completions').doc(exerciseId).update({
      'status': CompletionStatus.completed.name,
      'completedAt': Timestamp.now(),
    });
  }

  // Get today's meals
  Future<List<MealCompletion>> getTodayMeals(String userId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('meal_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    return snapshot.docs
        .map((doc) => MealCompletion.fromFirestore(doc))
        .toList();
  }

  // Get today's exercises
  Future<List<ExerciseCompletion>> getTodayExercises(String userId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('exercise_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    return snapshot.docs
        .map((doc) => ExerciseCompletion.fromFirestore(doc))
        .toList();
  }

  Future<List<MealRecommendation>> generateMealRecommendations({
    required UserModel user,
    required MeasurementModel? latestMeasurement,
    int count = 5,
  }) async {
    try {
      final response = await _callBackendAI(
        'daily_meals',
        {'userId': user.id},
      );
      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']') + 1;
      if (jsonStart == -1 || jsonEnd == 0)
        throw Exception('Invalid JSON response from AI');
      final List<dynamic> mealsJson =
          json.decode(response.substring(jsonStart, jsonEnd));
      return mealsJson
          .map((m) => MealRecommendation.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error generating meal recommendations: $e');
      return _getDefaultMealRecommendations(user.goals);
    }
  }

  Future<List<ExerciseRecommendation>> generateExerciseRecommendations({
    required UserModel user,
    required MeasurementModel? latestMeasurement,
    int count = 5,
  }) async {
    try {
      final response = await _callBackendAI(
        'daily_exercises',
        {'userId': user.id},
      );
      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']') + 1;
      if (jsonStart == -1 || jsonEnd == 0)
        throw Exception('Invalid JSON response from AI');
      final List<dynamic> exercisesJson =
          json.decode(response.substring(jsonStart, jsonEnd));
      return exercisesJson
          .map((e) => ExerciseRecommendation.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error generating exercise recommendations: $e');
      return _getDefaultExerciseRecommendations(user.goals);
    }
  }

  // ── Call backend AI endpoint (replaces direct Groq calls) ─────────────────
  Future<String> _callBackendAI(
    String requestType,
    Map<String, dynamic> contextData,
  ) async {
    print('📡 Calling backend AI: $requestType');
    try {
      // Load user preferences from Firestore and send inline so the backend
      // always has full personalization — no in-memory backend store needed.
      Map<String, dynamic>? userPrefs;
      final userId = contextData['userId'] as String?;
      if (userId != null) {
        try {
          final doc =
              await _firestore.collection('user_preferences').doc(userId).get();
          if (doc.exists && doc.data() != null) {
            userPrefs = doc.data()!;
            print('✅ Preferences loaded from Firestore for AI request');
          } else {
            print('⚠️ No preferences in Firestore — AI will use defaults');
          }
        } catch (e) {
          print('⚠️ Could not load preferences: $e');
        }
      }

      final response = await http
          .post(
            Uri.parse('$_backendUrl/generate-ai-plan'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'user_id': userId,
              'request_type': requestType,
              'yesterday_meals_completed':
                  contextData['yesterdayMealsCompleted'] ?? 0,
              'yesterday_meals_total': contextData['yesterdayMealsTotal'] ?? 0,
              'yesterday_exercises_completed':
                  contextData['yesterdayExercisesCompleted'] ?? 0,
              'yesterday_exercises_total':
                  contextData['yesterdayExercisesTotal'] ?? 0,
              'skipped_meals': contextData['skippedMeals'] ?? [],
              'favorite_meals': contextData['favoriteMeals'] ?? [],
              'favorite_exercises': contextData['favoriteExercises'] ?? [],
              'recent_meals': contextData['recentMeals'] ?? [],
              'recent_exercises': contextData['recentExercises'] ?? [],
              // Send preferences inline — backend uses this directly
              if (userPrefs != null) 'preferences': userPrefs,
            }),
          )
          .timeout(Duration(
              seconds: (requestType == 'weekly_meals' ||
                      requestType == 'weekly_exercises')
                  ? 120
                  : 60));

      if (response.statusCode != 200) {
        throw Exception(
            'Backend AI error ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body);
      final content = data['content'] as String;
      print('✅ Backend AI Success — ${content.length} chars');
      return content;
    } catch (e) {
      print('❌ Backend AI error: $e');
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

      await _firestore
          .collection('recommendations')
          .add(recommendation.toMap());
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
      await _firestore
          .collection('recommendations')
          .doc(recommendationId)
          .delete();
    } catch (e) {
      print('Error deleting recommendation: $e');
      rethrow;
    }
  }

  // Default weekly meal plan (fallback)
  Map<String, List<MealRecommendation>> _getDefaultWeeklyMealPlan(
      String? goal) {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final plan = <String, List<MealRecommendation>>{};

    for (var day in days) {
      plan[day] = [
        MealRecommendation(
          name: 'Protein Oatmeal Bowl',
          description: 'Hearty oatmeal with protein powder, berries, and nuts',
          calories: 350,
          ingredients: [
            'Oats',
            'Protein powder',
            'Berries',
            'Almonds',
            'Honey'
          ],
          mealType: 'breakfast',
          macros: {'protein': 25, 'carbs': 45, 'fats': 10},
        ),
        MealRecommendation(
          name: 'Grilled Chicken Salad',
          description:
              'Fresh greens with grilled chicken and olive oil dressing',
          calories: 400,
          ingredients: [
            'Chicken breast',
            'Mixed greens',
            'Tomatoes',
            'Cucumber'
          ],
          mealType: 'lunch',
          macros: {'protein': 35, 'carbs': 20, 'fats': 18},
        ),
        MealRecommendation(
          name: 'Salmon with Sweet Potato',
          description: 'Baked salmon with roasted sweet potato and broccoli',
          calories: 500,
          ingredients: ['Salmon fillet', 'Sweet potato', 'Broccoli'],
          mealType: 'dinner',
          macros: {'protein': 40, 'carbs': 45, 'fats': 20},
        ),
      ];
    }
    return plan;
  }

  // Default weekly exercise plan (fallback)
  Map<String, List<ExerciseRecommendation>> _getDefaultWeeklyExercisePlan(
      String? goal) {
    return {
      'Monday': [
        ExerciseRecommendation(
          name: 'Push-ups',
          description: 'Classic bodyweight exercise for chest',
          sets: 3,
          reps: 15,
          durationMinutes: 10,
          difficulty: 'beginner',
          targetMuscles: ['Chest', 'Triceps'],
        ),
      ],
      'Tuesday': [
        ExerciseRecommendation(
          name: 'Squats',
          description: 'Fundamental lower body exercise',
          sets: 3,
          reps: 12,
          durationMinutes: 10,
          difficulty: 'beginner',
          targetMuscles: ['Quadriceps', 'Glutes'],
        ),
      ],
      'Wednesday': [
        ExerciseRecommendation(
          name: 'Plank',
          description: 'Core strengthening exercise',
          sets: 3,
          reps: 1,
          durationMinutes: 5,
          difficulty: 'beginner',
          targetMuscles: ['Core', 'Abs'],
        ),
      ],
      'Thursday': [
        ExerciseRecommendation(
          name: 'Lunges',
          description: 'Single-leg strength exercise',
          sets: 3,
          reps: 12,
          durationMinutes: 10,
          difficulty: 'beginner',
          targetMuscles: ['Quadriceps', 'Glutes'],
        ),
      ],
      'Friday': [
        ExerciseRecommendation(
          name: 'Dumbbell Rows',
          description: 'Back strengthening exercise',
          sets: 3,
          reps: 12,
          durationMinutes: 10,
          difficulty: 'intermediate',
          targetMuscles: ['Back', 'Biceps'],
        ),
      ],
      'Saturday': [
        ExerciseRecommendation(
          name: 'Burpees',
          description: 'Full body cardio exercise',
          sets: 3,
          reps: 10,
          durationMinutes: 15,
          difficulty: 'intermediate',
          targetMuscles: ['Full body'],
        ),
      ],
      'Sunday': [
        ExerciseRecommendation(
          name: 'Active Recovery Walk',
          description: 'Light walking for recovery',
          sets: 1,
          reps: 1,
          durationMinutes: 30,
          difficulty: 'beginner',
          targetMuscles: ['Cardio'],
        ),
      ],
    };
  }

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
        description:
            'Fresh greens with grilled chicken, vegetables, and olive oil dressing',
        calories: 400,
        ingredients: [
          'Chicken breast',
          'Mixed greens',
          'Tomatoes',
          'Cucumber',
          'Olive oil'
        ],
        mealType: 'lunch',
        macros: {'protein': 35, 'carbs': 20, 'fats': 18},
      ),
      MealRecommendation(
        name: 'Salmon with Sweet Potato',
        description: 'Baked salmon with roasted sweet potato and broccoli',
        calories: 500,
        ingredients: [
          'Salmon fillet',
          'Sweet potato',
          'Broccoli',
          'Lemon',
          'Herbs'
        ],
        mealType: 'dinner',
        macros: {'protein': 40, 'carbs': 45, 'fats': 20},
      ),
    ];
  }

  // Default exercise recommendations (fallback)
  List<ExerciseRecommendation> _getDefaultExerciseRecommendations(
      String? goal) {
    return [
      ExerciseRecommendation(
        name: 'Push-ups',
        description:
            'Classic bodyweight exercise for chest, shoulders, and triceps',
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
