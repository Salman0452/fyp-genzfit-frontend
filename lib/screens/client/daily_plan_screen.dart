import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/progress_tracking_model.dart';
import '../../services/recommendation_service.dart';
import '../../services/weekly_plan_service.dart';
import '../../services/body_analysis_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

class DailyPlanScreen extends StatefulWidget {
  const DailyPlanScreen({Key? key}) : super(key: key);

  @override
  State<DailyPlanScreen> createState() => _DailyPlanScreenState();
}

class _DailyPlanScreenState extends State<DailyPlanScreen>
    with SingleTickerProviderStateMixin {
  final WeeklyPlanService _weeklyPlanService = WeeklyPlanService();
  final RecommendationService _recommendationService = RecommendationService();
  final BodyAnalysisService _bodyAnalysisService = BodyAnalysisService();

  late TabController _tabController;
  bool _isLoading = false;
  String _loadingStatus = 'Loading your plan…';

  List<MealCompletion> _todayMeals = [];
  List<ExerciseCompletion> _todayExercises = [];
  bool _isRestDay = false;
  String _dayName = '';
  List<String> _weeklyRestDays = [];

  int _completedMeals = 0;
  int _completedExercises = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTodayPlan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTodayPlan() async {
    setState(() {
      _isLoading = true;
      _loadingStatus = 'Loading your plan…';
    });

    try {
      final user =
          Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user == null) return;

      final measurements =
          await _bodyAnalysisService.getUserMeasurements(user.id);
      final latestMeasurement =
          measurements.isNotEmpty ? measurements.first : null;

      final plan = await _weeklyPlanService.loadTodayPlan(
        user: user,
        measurement: latestMeasurement,
        onProgress: (status) => setState(() => _loadingStatus = status),
      );

      setState(() {
        _todayMeals = plan.meals;
        _todayExercises = plan.exercises;
        _isRestDay = plan.isRestDay;
        _dayName = plan.dayName;
        _weeklyRestDays = plan.weeklyRestDays;
        _updateCompletionCounts();
      });
    } catch (e) {
      print('Error loading plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading plan: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _regenerateToday() async {
    setState(() {
      _isLoading = true;
      _loadingStatus = 'Regenerating today\'s plan…';
    });
    try {
      final user =
          Provider.of<AuthProvider>(context, listen: false).currentUser!;
      final measurements =
          await _bodyAnalysisService.getUserMeasurements(user.id);
      final latestMeasurement =
          measurements.isNotEmpty ? measurements.first : null;

      final plan = await _weeklyPlanService.regenerateToday(
        user: user,
        measurement: latestMeasurement,
      );

      setState(() {
        _todayMeals = plan.meals;
        _todayExercises = plan.exercises;
        _isRestDay = plan.isRestDay;
        _dayName = plan.dayName;
        _weeklyRestDays = plan.weeklyRestDays;
        _updateCompletionCounts();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Today\'s plan refreshed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error regenerating today: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _regenerateWeek() async {
    setState(() {
      _isLoading = true;
      _loadingStatus = 'Generating new weekly plan…';
    });
    try {
      final user =
          Provider.of<AuthProvider>(context, listen: false).currentUser!;
      final measurements =
          await _bodyAnalysisService.getUserMeasurements(user.id);
      final latestMeasurement =
          measurements.isNotEmpty ? measurements.first : null;

      await _weeklyPlanService.regenerateWeek(
        user: user,
        measurement: latestMeasurement,
        onProgress: (status) => setState(() => _loadingStatus = status),
      );

      await _loadTodayPlan();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗓️ New weekly plan generated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error regenerating week: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateCompletionCounts() {
    _completedMeals =
        _todayMeals.where((m) => m.status == CompletionStatus.completed).length;
    _completedExercises = _todayExercises
        .where((e) => e.status == CompletionStatus.completed)
        .length;
  }

  Future<void> _completeMeal(MealCompletion meal) async {
    try {
      await _recommendationService.completeMeal(meal.id);
      await _loadTodayPlan();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Completed: ${meal.mealName}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error completing meal: $e');
    }
  }

  Future<void> _completeExercise(ExerciseCompletion exercise) async {
    try {
      await _recommendationService.completeExercise(exercise.id);
      await _loadTodayPlan();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Completed: ${exercise.exerciseName}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error completing exercise: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const dayNames = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    final displayDay =
        _dayName.isNotEmpty ? _dayName : dayNames[DateTime.now().weekday - 1];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Plan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                Text(
                  displayDay,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted),
                ),
                if (_isRestDay) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.accentTeal.withOpacity(0.5)),
                    ),
                    child: const Text(
                      'Rest Day',
                      style: TextStyle(
                          color: AppColors.accentTeal, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            color: AppColors.charcoal,
            onSelected: (val) {
              if (val == 'today') _regenerateToday();
              if (val == 'week') _regenerateWeek();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'today',
                child: Row(children: [
                  const Icon(Icons.refresh,
                      size: 18, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Text('Refresh Today',
                      style: const TextStyle(color: AppColors.textPrimary)),
                ]),
              ),
              PopupMenuItem(
                value: 'week',
                child: Row(children: [
                  const Icon(Icons.calendar_month,
                      size: 18, color: AppColors.accentTeal),
                  const SizedBox(width: 10),
                  const Text('New Week Plan',
                      style: TextStyle(color: AppColors.textPrimary)),
                ]),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          indicatorWeight: 2,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.muted,
          tabs: const [
            Tab(text: 'Meals'),
            Tab(text: 'Workouts'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.accent),
                  const SizedBox(height: 16),
                  Text(
                    _loadingStatus,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 14),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _buildStatsCard(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMealsList(),
                      _buildExercisesList(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsCard() {
    final totalTasks = _todayMeals.length + _todayExercises.length;
    final completedTasks = _completedMeals + _completedExercises;
    final completionPercent =
        totalTasks > 0 ? (completedTasks / totalTasks * 100).toInt() : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppColors.accent.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Completion',
            '$completionPercent%',
            Icons.timeline,
            AppColors.accent,
          ),
          Container(width: 1, height: 40, color: AppColors.charcoal),
          _buildStatItem(
            'Meals',
            '$_completedMeals/${_todayMeals.length}',
            Icons.restaurant,
            AppColors.warning,
          ),
          Container(width: 1, height: 40, color: AppColors.charcoal),
          _buildStatItem(
            'Workouts',
            '$_completedExercises/${_isRestDay ? '–' : _todayExercises.length}',
            Icons.fitness_center,
            AppColors.accentTeal,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildMealsList() {
    if (_todayMeals.isEmpty) {
      return _buildEmptyState(
        icon: Icons.restaurant_menu,
        message: 'No meals planned for today',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _todayMeals.length,
      itemBuilder: (context, index) {
        final meal = _todayMeals[index];
        final isCompleted = meal.status == CompletionStatus.completed;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: isCompleted
                  ? AppColors.accent.withOpacity(0.4)
                  : AppColors.charcoal,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.warning.withOpacity(0.4)),
                      ),
                      child: Text(
                        meal.mealType.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isCompleted)
                      const Icon(Icons.check_circle,
                          color: AppColors.accent, size: 22),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  meal.mealName,
                  style: TextStyle(
                    color: isCompleted
                        ? AppColors.muted
                        : AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildMacroChip(
                        '${meal.calories} kcal',
                        Icons.local_fire_department,
                        AppColors.error),
                    const SizedBox(width: 8),
                    _buildMacroChip(
                        'P ${meal.macros['protein']}g',
                        Icons.egg_outlined,
                        AppColors.accentTeal),
                    const SizedBox(width: 8),
                    _buildMacroChip(
                        'C ${meal.macros['carbs']}g',
                        Icons.grain,
                        AppColors.warning),
                  ],
                ),
                if (!isCompleted) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _completeMeal(meal),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.background,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppConstants.radiusSmall),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Mark as Done',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _getNextWorkoutDay() {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    final todayIdx = DateTime.now().weekday - 1;
    for (int i = 1; i <= 7; i++) {
      final next = days[(todayIdx + i) % 7];
      if (!_weeklyRestDays.contains(next)) return next;
    }
    return 'soon';
  }

  Widget _buildExercisesList() {
    if (_isRestDay) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.accentTeal.withOpacity(0.25),
                      width: 1.5),
                ),
                child: const Icon(Icons.self_improvement,
                    size: 60, color: AppColors.accentTeal),
              ),
              const SizedBox(height: 24),
              const Text(
                'Rest Day 🧘',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Recovery is part of training.\nYour muscles grow during rest.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.muted, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 8),
              Text(
                'Next workout: ${_getNextWorkoutDay()}',
                style: const TextStyle(
                    color: AppColors.accentTeal,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: _regenerateToday,
                icon: const Icon(Icons.refresh,
                    color: AppColors.accentTeal, size: 18),
                label: const Text(
                  'Override – Add Light Workout',
                  style: TextStyle(
                      color: AppColors.accentTeal, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: AppColors.accentTeal.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusSmall),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_todayExercises.isEmpty) {
      return _buildEmptyState(
        icon: Icons.fitness_center,
        message: 'No workouts planned for today',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _todayExercises.length,
      itemBuilder: (context, index) {
        final exercise = _todayExercises[index];
        final isCompleted = exercise.status == CompletionStatus.completed;

        final difficultyColor = exercise.difficulty == 'beginner'
            ? AppColors.accent
            : exercise.difficulty == 'intermediate'
                ? AppColors.warning
                : AppColors.error;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: isCompleted
                  ? AppColors.accent.withOpacity(0.4)
                  : AppColors.charcoal,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: difficultyColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: difficultyColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        exercise.difficulty.toUpperCase(),
                        style: TextStyle(
                          color: difficultyColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isCompleted)
                      const Icon(Icons.check_circle,
                          color: AppColors.accent, size: 22),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  exercise.exerciseName,
                  style: TextStyle(
                    color: isCompleted
                        ? AppColors.muted
                        : AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildExerciseInfo(
                        '${exercise.sets} sets',
                        Icons.repeat,
                        AppColors.accent),
                    const SizedBox(width: 16),
                    _buildExerciseInfo(
                        '${exercise.reps} reps',
                        Icons.fitness_center,
                        AppColors.accentTeal),
                    const SizedBox(width: 16),
                    _buildExerciseInfo(
                        '${exercise.durationMinutes} min',
                        Icons.timer_outlined,
                        AppColors.warning),
                  ],
                ),
                if (exercise.targetMuscles.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: exercise.targetMuscles
                        .map((muscle) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.charcoal,
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: Text(
                                muscle,
                                style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11),
                              ),
                            ))
                        .toList(),
                  ),
                ],
                if (!isCompleted) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _completeExercise(exercise),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.background,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppConstants.radiusSmall),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Mark as Done',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
      {required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.charcoal,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: AppColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _regenerateToday,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Generate AI Plan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusSmall),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseInfo(String text, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
