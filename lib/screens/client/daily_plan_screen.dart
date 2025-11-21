import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/measurement_model.dart';
import '../../models/recommendation_model.dart';
import '../../models/progress_tracking_model.dart';
import '../../services/recommendation_service.dart';
import '../../services/body_analysis_service.dart';
import '../../providers/auth_provider.dart';

class DailyPlanScreen extends StatefulWidget {
  const DailyPlanScreen({Key? key}) : super(key: key);

  @override
  State<DailyPlanScreen> createState() => _DailyPlanScreenState();
}

class _DailyPlanScreenState extends State<DailyPlanScreen> with SingleTickerProviderStateMixin {
  final RecommendationService _recommendationService = RecommendationService();
  final BodyAnalysisService _bodyAnalysisService = BodyAnalysisService();
  
  late TabController _tabController;
  bool _isLoading = false;
  
  List<MealCompletion> _todayMeals = [];
  List<ExerciseCompletion> _todayExercises = [];
  
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
    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user == null) return;

      // Check if we already have today's plan
      final existingMeals = await _recommendationService.getTodayMeals(user.id);
      final existingExercises = await _recommendationService.getTodayExercises(user.id);

      if (existingMeals.isEmpty || existingExercises.isEmpty) {
        // Generate new daily plan with AI
        await _generateNewDailyPlan(user);
      } else {
        // Load existing plan
        setState(() {
          _todayMeals = existingMeals;
          _todayExercises = existingExercises;
          _updateCompletionCounts();
        });
      }
    } catch (e) {
      print('Error loading today\'s plan: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading plan: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateNewDailyPlan(UserModel user) async {
    try {
      // Get latest measurements
      final measurements = await _bodyAnalysisService.getUserMeasurements(user.id);
      final latestMeasurement = measurements.isNotEmpty ? measurements.first : null;

      // Generate today's meals and exercises with AI
      final meals = await _recommendationService.generateDailyMeals(
        user: user,
        latestMeasurement: latestMeasurement,
      );

      final exercises = await _recommendationService.generateDailyExercises(
        user: user,
        latestMeasurement: latestMeasurement,
      );

      // Reload from Firestore to get completion objects
      final todayMeals = await _recommendationService.getTodayMeals(user.id);
      final todayExercises = await _recommendationService.getTodayExercises(user.id);

      setState(() {
        _todayMeals = todayMeals;
        _todayExercises = todayExercises;
        _updateCompletionCounts();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ New AI-powered plan generated for today!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error generating daily plan: $e');
      rethrow;
    }
  }

  void _updateCompletionCounts() {
    _completedMeals = _todayMeals.where((m) => m.status == CompletionStatus.completed).length;
    _completedExercises = _todayExercises.where((e) => e.status == CompletionStatus.completed).length;
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
    final today = DateTime.now();
    final dayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][today.weekday - 1];
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Today\'s Plan', style: TextStyle(fontSize: 20)),
            Text(
              dayName,
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _generateNewDailyPlan(
              Provider.of<AuthProvider>(context, listen: false).currentUser!,
            ),
            tooltip: 'Regenerate Plan',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Meals'),
            Tab(text: 'Workouts'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
    final completionPercent = totalTasks > 0 ? (completedTasks / totalTasks * 100).toInt() : 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[900]!, Colors.grey[850]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Completion', '$completionPercent%', Icons.timeline),
          _buildStatItem('Meals', '$_completedMeals/${_todayMeals.length}', Icons.restaurant),
          _buildStatItem('Workouts', '$_completedExercises/${_todayExercises.length}', Icons.fitness_center),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildMealsList() {
    if (_todayMeals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No meals planned for today',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _generateNewDailyPlan(
                Provider.of<AuthProvider>(context, listen: false).currentUser!,
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate AI Plan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _todayMeals.length,
      itemBuilder: (context, index) {
        final meal = _todayMeals[index];
        final isCompleted = meal.status == CompletionStatus.completed;

        return Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        meal.mealType.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isCompleted)
                      const Icon(Icons.check_circle, color: Colors.green, size: 24),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  meal.mealName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMacroChip('${meal.calories} cal', Icons.local_fire_department),
                    const SizedBox(width: 8),
                    _buildMacroChip('P: ${meal.macros['protein']}g', Icons.egg),
                    const SizedBox(width: 8),
                    _buildMacroChip('C: ${meal.macros['carbs']}g', Icons.grain),
                  ],
                ),
                if (!isCompleted) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _completeMeal(meal),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Mark as Completed'),
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

  Widget _buildExercisesList() {
    if (_todayExercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No workouts planned for today',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _generateNewDailyPlan(
                Provider.of<AuthProvider>(context, listen: false).currentUser!,
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate AI Plan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _todayExercises.length,
      itemBuilder: (context, index) {
        final exercise = _todayExercises[index];
        final isCompleted = exercise.status == CompletionStatus.completed;

        return Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: exercise.difficulty == 'beginner'
                            ? Colors.green
                            : exercise.difficulty == 'intermediate'
                                ? Colors.orange
                                : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        exercise.difficulty.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isCompleted)
                      const Icon(Icons.check_circle, color: Colors.green, size: 24),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  exercise.exerciseName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildExerciseInfo('${exercise.sets} sets', Icons.repeat),
                    const SizedBox(width: 12),
                    _buildExerciseInfo('${exercise.reps} reps', Icons.fitness_center),
                    const SizedBox(width: 12),
                    _buildExerciseInfo('${exercise.durationMinutes} min', Icons.timer),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: exercise.targetMuscles
                      .map((muscle) => Chip(
                            label: Text(muscle),
                            backgroundColor: Colors.grey[800],
                            labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
                            padding: EdgeInsets.zero,
                          ))
                      .toList(),
                ),
                if (!isCompleted) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _completeExercise(exercise),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Mark as Completed'),
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

  Widget _buildMacroChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: Colors.grey[300], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseInfo(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: Colors.grey[300], fontSize: 13),
        ),
      ],
    );
  }
}
