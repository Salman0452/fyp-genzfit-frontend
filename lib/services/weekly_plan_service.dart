import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/progress_tracking_model.dart';
import '../models/user_model.dart';
import '../models/measurement_model.dart';
import 'recommendation_service.dart';

/// Two-layer fitness planning model:
///
/// Layer 1 — Weekly Skeleton (generated once on Monday or first use of the week)
///   • Calls /generate-ai-plan with request_type=weekly_meals & weekly_exercises
///   • Saves all 7 days of meals + exercises to Firestore (meal_completions /
///     exercise_completions) with their correct scheduledDate per day
///   • Saves a `weekly_plans/{userId}_{weekStart}` document as the skeleton
///     record so we know the week has been planned
///
/// Layer 2 — Daily Adaptive Refresh (every morning)
///   • Reads today's items directly from meal_completions / exercise_completions
///   • If today is a rest day (empty exercises) → returns rest-day flag
///   • Meal data is always present (eat every day)
///
/// Firestore collections used:
///   meal_completions        — one doc per meal per day
///   exercise_completions    — one doc per exercise per day
///   weekly_plans            — one doc per user per week (skeleton metadata)
///   user_preferences        — preferences (existing)

class WeeklyPlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RecommendationService _recService = RecommendationService();

  static const List<String> _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  // ── Week helpers ──────────────────────────────────────────────────────────

  DateTime _weekStart(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
  }

  DateTime _dateForDay(DateTime weekStart, String dayName) {
    final idx = _dayNames.indexOf(dayName);
    return weekStart.add(Duration(days: idx));
  }

  String get _todayName => _dayNames[DateTime.now().weekday - 1];

  // ── Firestore weekly plan doc ─────────────────────────────────────────────

  String _planDocId(String userId, DateTime weekStart) =>
      '${userId}_${weekStart.toIso8601String().substring(0, 10)}';

  Future<bool> _hasWeeklyPlan(String userId) async {
    final weekStart = _weekStart(DateTime.now());
    final doc = await _firestore
        .collection('weekly_plans')
        .doc(_planDocId(userId, weekStart))
        .get();
    return doc.exists;
  }

  // ── Layer 1: Generate and save the full weekly skeleton ───────────────────

  Future<void> generateWeeklySkeleton({
    required UserModel user,
    required MeasurementModel? measurement,
    void Function(String status)? onProgress,
  }) async {
    final weekStart = _weekStart(DateTime.now());
    print(
        '📅 Generating weekly skeleton for week of ${weekStart.toIso8601String().substring(0, 10)}');

    onProgress?.call('Generating 7-day meal plan…');

    // ── Weekly meals ──────────────────────────────────────────────────────
    final mealPlan = await _recService.generateWeeklyMealPlan(
      user: user,
      latestMeasurement: measurement,
    );

    onProgress?.call('Generating workout schedule…');

    // ── Weekly exercises ──────────────────────────────────────────────────
    final exercisePlan = await _recService.generateWeeklyExercisePlan(
      user: user,
      latestMeasurement: measurement,
    );

    onProgress?.call('Saving to Firestore…');

    // ── Save to Firestore — delete old entries for this week first ─────────
    await _deleteWeekEntries(user.id, weekStart);

    // Save meals
    for (final entry in mealPlan.entries) {
      final dayDate = _dateForDay(weekStart, entry.key);
      for (final meal in entry.value) {
        await _firestore.collection('meal_completions').add(
              MealCompletion(
                id: '',
                userId: user.id,
                mealName: meal.name,
                mealType: meal.mealType,
                scheduledDate: dayDate,
                status: CompletionStatus.pending,
                calories: meal.calories,
                macros: meal.macros,
              ).toMap(),
            );
      }
    }

    // Save exercises (rest days will have empty list → nothing saved → isRestDay = true)
    for (final entry in exercisePlan.entries) {
      final dayDate = _dateForDay(weekStart, entry.key);
      for (final exercise in entry.value) {
        await _firestore.collection('exercise_completions').add(
              ExerciseCompletion(
                id: '',
                userId: user.id,
                exerciseName: exercise.name,
                scheduledDate: dayDate,
                status: CompletionStatus.pending,
                sets: exercise.sets,
                reps: exercise.reps,
                durationMinutes: exercise.durationMinutes,
                difficulty: exercise.difficulty,
                targetMuscles: exercise.targetMuscles,
              ).toMap(),
            );
      }
    }

    // ── Save skeleton metadata ─────────────────────────────────────────────
    // Compute which days are rest days (AI returned empty exercise list)
    final restDays = exercisePlan.entries
        .where((e) => e.value.isEmpty)
        .map((e) => e.key)
        .toList();

    await _firestore
        .collection('weekly_plans')
        .doc(_planDocId(user.id, weekStart))
        .set({
      'userId': user.id,
      'weekStart': Timestamp.fromDate(weekStart),
      'createdAt': Timestamp.now(),
      'workoutDaysPerWeek': 7 - restDays.length,
      'restDays': restDays,
      'totalMeals': mealPlan.values.fold(0, (s, l) => s + l.length),
      'totalExercises': exercisePlan.values.fold(0, (s, l) => s + l.length),
    });

    print('✅ Weekly skeleton saved — rest days: $restDays');
  }

  // ── Layer 2: Load today's plan ─────────────────────────────────────────────

  /// Returns the complete state for today.
  /// If no weekly plan exists yet (or it's Monday), generates the skeleton first.
  Future<TodayPlan> loadTodayPlan({
    required UserModel user,
    required MeasurementModel? measurement,
    void Function(String status)? onProgress,
  }) async {
    // Generate weekly skeleton if missing
    final hasWeekly = await _hasWeeklyPlan(user.id);
    if (!hasWeekly) {
      onProgress?.call('Preparing your weekly plan…');
      await generateWeeklySkeleton(
        user: user,
        measurement: measurement,
        onProgress: onProgress,
      );
    }

    // Load today's meals & exercises from Firestore
    final meals = await _recService.getTodayMeals(user.id);
    final exercises = await _recService.getTodayExercises(user.id);

    // Load rest-day metadata
    final weekStart = _weekStart(DateTime.now());
    final planDoc = await _firestore
        .collection('weekly_plans')
        .doc(_planDocId(user.id, weekStart))
        .get();

    final restDays = List<String>.from(planDoc.data()?['restDays'] ?? []);
    final isRestDay = restDays.contains(_todayName);

    return TodayPlan(
      meals: meals,
      exercises: exercises,
      isRestDay: isRestDay,
      dayName: _todayName,
      weeklyRestDays: restDays,
    );
  }

  // ── Regenerate only today (daily adaptive refresh) ─────────────────────────

  Future<TodayPlan> regenerateToday({
    required UserModel user,
    required MeasurementModel? measurement,
  }) async {
    // Regenerate meals for today only
    await _recService.generateDailyMeals(
      user: user,
      latestMeasurement: measurement,
    );

    // Only regenerate exercises if it's not a rest day
    final weekStart = _weekStart(DateTime.now());
    final planDoc = await _firestore
        .collection('weekly_plans')
        .doc(_planDocId(user.id, weekStart))
        .get();
    final restDays = List<String>.from(planDoc.data()?['restDays'] ?? []);
    final isRestDay = restDays.contains(_todayName);

    if (!isRestDay) {
      await _recService.generateDailyExercises(
        user: user,
        latestMeasurement: measurement,
      );
    }

    final meals = await _recService.getTodayMeals(user.id);
    final exercises = await _recService.getTodayExercises(user.id);

    return TodayPlan(
      meals: meals,
      exercises: exercises,
      isRestDay: isRestDay,
      dayName: _todayName,
      weeklyRestDays: restDays,
    );
  }

  // ── Regenerate the whole week (manual user action) ─────────────────────────

  Future<void> regenerateWeek({
    required UserModel user,
    required MeasurementModel? measurement,
    void Function(String status)? onProgress,
  }) async {
    final weekStart = _weekStart(DateTime.now());
    // Delete skeleton doc so loadTodayPlan triggers fresh generation
    await _firestore
        .collection('weekly_plans')
        .doc(_planDocId(user.id, weekStart))
        .delete();

    await generateWeeklySkeleton(
      user: user,
      measurement: measurement,
      onProgress: onProgress,
    );
  }

  // ── Get weekly overview for a week calendar widget ─────────────────────────

  Future<WeekOverview> getWeekOverview(String userId) async {
    final weekStart = _weekStart(DateTime.now());
    final weekEnd = weekStart.add(const Duration(days: 7));

    final mealsSnap = await _firestore
        .collection('meal_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(weekEnd))
        .get();

    final exercisesSnap = await _firestore
        .collection('exercise_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(weekEnd))
        .get();

    final planDoc = await _firestore
        .collection('weekly_plans')
        .doc(_planDocId(userId, weekStart))
        .get();

    final restDays = List<String>.from(planDoc.data()?['restDays'] ?? []);

    // Build per-day summary
    final Map<String, DaySummary> days = {};
    for (final dayName in _dayNames) {
      final dayDate = _dateForDay(weekStart, dayName);
      final dayStart = DateTime(dayDate.year, dayDate.month, dayDate.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final dayMeals =
          mealsSnap.docs.map((d) => MealCompletion.fromFirestore(d)).where((m) {
        final sd = m.scheduledDate;
        return !sd.isBefore(dayStart) && sd.isBefore(dayEnd);
      }).toList();

      final dayExercises = exercisesSnap.docs
          .map((d) => ExerciseCompletion.fromFirestore(d))
          .where((e) {
        final sd = e.scheduledDate;
        return !sd.isBefore(dayStart) && sd.isBefore(dayEnd);
      }).toList();

      days[dayName] = DaySummary(
        dayName: dayName,
        date: dayDate,
        meals: dayMeals,
        exercises: dayExercises,
        isRestDay: restDays.contains(dayName),
        isToday: dayName == _todayName,
      );
    }

    return WeekOverview(days: days, restDays: restDays);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _deleteWeekEntries(String userId, DateTime weekStart) async {
    final weekEnd = weekStart.add(const Duration(days: 7));

    final meals = await _firestore
        .collection('meal_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(weekEnd))
        .get();
    for (final doc in meals.docs) {
      await doc.reference.delete();
    }

    final exercises = await _firestore
        .collection('exercise_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(weekEnd))
        .get();
    for (final doc in exercises.docs) {
      await doc.reference.delete();
    }
  }
}

// ── Value objects ──────────────────────────────────────────────────────────────

class TodayPlan {
  final List<MealCompletion> meals;
  final List<ExerciseCompletion> exercises;
  final bool isRestDay;
  final String dayName;
  final List<String> weeklyRestDays;

  const TodayPlan({
    required this.meals,
    required this.exercises,
    required this.isRestDay,
    required this.dayName,
    required this.weeklyRestDays,
  });
}

class DaySummary {
  final String dayName;
  final DateTime date;
  final List<MealCompletion> meals;
  final List<ExerciseCompletion> exercises;
  final bool isRestDay;
  final bool isToday;

  int get completedMeals =>
      meals.where((m) => m.status == CompletionStatus.completed).length;
  int get completedExercises =>
      exercises.where((e) => e.status == CompletionStatus.completed).length;
  bool get allMealsDone => meals.isNotEmpty && completedMeals == meals.length;
  bool get allExercisesDone =>
      isRestDay ||
      (exercises.isNotEmpty && completedExercises == exercises.length);

  const DaySummary({
    required this.dayName,
    required this.date,
    required this.meals,
    required this.exercises,
    required this.isRestDay,
    required this.isToday,
  });
}

class WeekOverview {
  final Map<String, DaySummary> days;
  final List<String> restDays;

  int get totalWorkoutDays => 7 - restDays.length;
  int get completedWorkoutDays =>
      days.values.where((d) => !d.isRestDay && d.allExercisesDone).length;

  const WeekOverview({required this.days, required this.restDays});
}
