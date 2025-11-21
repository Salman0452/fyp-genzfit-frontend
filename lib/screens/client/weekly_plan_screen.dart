import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/progress_tracking_model.dart';
import '../../models/recommendation_model.dart';
import '../../services/recommendation_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

class WeeklyPlanScreen extends StatefulWidget {
  const WeeklyPlanScreen({super.key});

  @override
  State<WeeklyPlanScreen> createState() => _WeeklyPlanScreenState();
}

class _WeeklyPlanScreenState extends State<WeeklyPlanScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RecommendationService _recommendationService = RecommendationService();
  
  List<MealCompletion> _todayMeals = [];
  List<ExerciseCompletion> _todayExercises = [];
  bool _isLoading = true;
  Map<String, dynamic>? _completionStats;

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
    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user == null) return;

      // Check if weekly schedule exists
      final weeklySchedule = await _recommendationService.getCurrentWeekSchedule(user.id);
      
      if (weeklySchedule == null) {
        // Generate new weekly schedule
        await _generateWeeklyPlan();
      }

      // Load today's tasks
      final meals = await _recommendationService.getTodayMeals(user.id);
      final exercises = await _recommendationService.getTodayExercises(user.id);
      final stats = await _recommendationService.getUserCompletionHistory(user.id);

      setState(() {
        _todayMeals = meals;
        _todayExercises = exercises;
        _completionStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading today plan: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateWeeklyPlan() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    
    if (user == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      // Generate weekly plans
      final mealPlan = await _recommendationService.generateWeeklyMealPlan(
        user: user,
        latestMeasurement: null, // Add measurement loading if needed
      );
      
      final exercisePlan = await _recommendationService.generateWeeklyExercisePlan(
        user: user,
        latestMeasurement: null,
      );

      // Save to Firestore
      await _recommendationService.saveWeeklySchedule(
        userId: user.id,
        mealPlan: mealPlan,
        exercisePlan: exercisePlan,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        await _loadTodayPlan(); // Reload
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating plan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Weekly Plan',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _generateWeeklyPlan,
            tooltip: 'Generate New Plan',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Today\'s Meals'),
            Tab(text: 'Today\'s Workouts'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : Column(
              children: [
                _buildStatsCard(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMealsTab(),
                      _buildExercisesTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsCard() {
    if (_completionStats == null) return const SizedBox.shrink();

    final completionRate = _completionStats!['completionRate'] as double;
    final totalCompleted = _completionStats!['totalMealsCompleted'] as int;
        _completionStats!['totalExercisesCompleted'] as int;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withOpacity(0.2),
            AppColors.accent.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Completion',
                '${completionRate.toStringAsFixed(0)}%',
                Icons.check_circle,
              ),
              _buildStatItem(
                'Tasks Done',
                '$totalCompleted',
                Icons.task_alt,
              ),
              _buildStatItem(
                'This Week',
                '${_todayMeals.length + _todayExercises.length}',
                Icons.calendar_today,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accent, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMealsTab() {
    if (_todayMeals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, size: 80, color: AppColors.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text(
              'No meals scheduled for today',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _generateWeeklyPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
              ),
              child: const Text('Generate Weekly Plan'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _todayMeals.length,
      itemBuilder: (context, index) {
        return _buildMealCompletionCard(_todayMeals[index]);
      },
    );
  }

  Widget _buildExercisesTab() {
    if (_todayExercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 80, color: AppColors.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text(
              'No exercises scheduled for today',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _generateWeeklyPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
              ),
              child: const Text('Generate Weekly Plan'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _todayExercises.length,
      itemBuilder: (context, index) {
        return _buildExerciseCompletionCard(_todayExercises[index]);
      },
    );
  }

  Widget _buildMealCompletionCard(MealCompletion meal) {
    final isCompleted = meal.status == CompletionStatus.completed;
    
    Color mealTypeColor;
    IconData mealTypeIcon;

    switch (meal.mealType.toLowerCase()) {
      case 'breakfast':
        mealTypeColor = Colors.orange;
        mealTypeIcon = Icons.wb_sunny;
        break;
      case 'lunch':
        mealTypeColor = Colors.blue;
        mealTypeIcon = Icons.lunch_dining;
        break;
      case 'dinner':
        mealTypeColor = Colors.purple;
        mealTypeIcon = Icons.dinner_dining;
        break;
      default:
        mealTypeColor = Colors.green;
        mealTypeIcon = Icons.fastfood;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: isCompleted ? AppColors.success : AppColors.charcoal,
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: mealTypeColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mealTypeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(mealTypeIcon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.mealName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        meal.mealType.toUpperCase(),
                        style: TextStyle(
                          color: mealTypeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${meal.calories} cal',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isCompleted ? null : () => _completeMeal(meal.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCompleted ? AppColors.success : AppColors.accent,
                      foregroundColor: AppColors.background,
                      disabledBackgroundColor: AppColors.success.withOpacity(0.5),
                    ),
                    icon: Icon(
                      isCompleted ? Icons.check_circle : Icons.check,
                      size: 20,
                    ),
                    label: Text(
                      isCompleted ? 'Completed' : 'Mark as Done',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCompletionCard(ExerciseCompletion exercise) {
    final isCompleted = exercise.status == CompletionStatus.completed;
    
    Color difficultyColor;
    switch (exercise.difficulty.toLowerCase()) {
      case 'beginner':
        difficultyColor = Colors.green;
        break;
      case 'intermediate':
        difficultyColor = Colors.orange;
        break;
      case 'advanced':
        difficultyColor = Colors.red;
        break;
      default:
        difficultyColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: isCompleted ? AppColors.success : AppColors.charcoal,
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: difficultyColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: difficultyColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.fitness_center, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.exerciseName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${exercise.sets} sets × ${exercise.reps} reps • ${exercise.durationMinutes} min',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isCompleted ? null : () => _completeExercise(exercise.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCompleted ? AppColors.success : AppColors.accent,
                      foregroundColor: AppColors.background,
                      disabledBackgroundColor: AppColors.success.withOpacity(0.5),
                    ),
                    icon: Icon(
                      isCompleted ? Icons.check_circle : Icons.check,
                      size: 20,
                    ),
                    label: Text(
                      isCompleted ? 'Completed' : 'Mark as Done',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeMeal(String mealId) async {
    try {
      await _recommendationService.completeMeal(mealId);
      await _loadTodayPlan();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal marked as completed! 🎉'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _completeExercise(String exerciseId) async {
    try {
      await _recommendationService.completeExercise(exerciseId);
      await _loadTodayPlan();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exercise completed! Great job! 💪'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
