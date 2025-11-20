import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/recommendation_model.dart';
import '../../models/measurement_model.dart';
import '../../services/recommendation_service.dart';
import '../../providers/auth_provider.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RecommendationService _recommendationService = RecommendationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<MealRecommendation> _mealRecommendations = [];
  List<ExerciseRecommendation> _exerciseRecommendations = [];
  bool _isLoadingMeals = false;
  bool _isLoadingExercises = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecommendations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) return;

    // Load latest measurement
    final measurementSnapshot = await _firestore
        .collection('measurements')
        .where('userId', isEqualTo: user.id)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    final measurement = measurementSnapshot.docs.isNotEmpty
        ? MeasurementModel.fromFirestore(measurementSnapshot.docs.first)
        : null;

    await Future.wait([
      _generateMealRecommendations(user, measurement),
      _generateExerciseRecommendations(user, measurement),
    ]);
  }

  Future<void> _generateMealRecommendations(user, MeasurementModel? measurement) async {
    setState(() => _isLoadingMeals = true);
    try {
      final meals = await _recommendationService.generateMealRecommendations(
        user: user,
        latestMeasurement: measurement,
        count: 5,
      );
      setState(() {
        _mealRecommendations = meals;
        _isLoadingMeals = false;
      });
    } catch (e) {
      print('Error loading meal recommendations: $e');
      setState(() => _isLoadingMeals = false);
    }
  }

  Future<void> _generateExerciseRecommendations(user, MeasurementModel? measurement) async {
    setState(() => _isLoadingExercises = true);
    try {
      final exercises = await _recommendationService.generateExerciseRecommendations(
        user: user,
        latestMeasurement: measurement,
        count: 5,
      );
      setState(() {
        _exerciseRecommendations = exercises;
        _isLoadingExercises = false;
      });
    } catch (e) {
      print('Error loading exercise recommendations: $e');
      setState(() => _isLoadingExercises = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'AI Recommendations',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRecommendations,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.5),
          tabs: const [
            Tab(text: 'Meals'),
            Tab(text: 'Exercises'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMealsTab(),
          _buildExercisesTab(),
        ],
      ),
    );
  }

  Widget _buildMealsTab() {
    if (_isLoadingMeals) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_mealRecommendations.isEmpty) {
      return _buildEmptyState('No meal recommendations yet');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _mealRecommendations.length,
      itemBuilder: (context, index) {
        return _buildMealCard(_mealRecommendations[index]);
      },
    );
  }

  Widget _buildExercisesTab() {
    if (_isLoadingExercises) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_exerciseRecommendations.isEmpty) {
      return _buildEmptyState('No exercise recommendations yet');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _exerciseRecommendations.length,
      itemBuilder: (context, index) {
        return _buildExerciseCard(_exerciseRecommendations[index]);
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(MealRecommendation meal) {
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
        gradient: LinearGradient(
          colors: [
            Colors.grey[900]!,
            Colors.grey[850]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: mealTypeColor.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                        meal.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        meal.mealType.toUpperCase(),
                        style: TextStyle(
                          color: mealTypeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${meal.calories} cal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Macros
                Row(
                  children: [
                    _buildMacroChip('Protein', '${meal.macros['protein']}g', Colors.red),
                    const SizedBox(width: 8),
                    _buildMacroChip('Carbs', '${meal.macros['carbs']}g', Colors.blue),
                    const SizedBox(width: 8),
                    _buildMacroChip('Fats', '${meal.macros['fats']}g', Colors.orange),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Ingredients
                Text(
                  'Ingredients:',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: meal.ingredients.map((ingredient) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ingredient,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(ExerciseRecommendation exercise) {
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
        gradient: LinearGradient(
          colors: [
            Colors.grey[900]!,
            Colors.grey[850]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: difficultyColor.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                        exercise.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        exercise.difficulty.toUpperCase(),
                        style: TextStyle(
                          color: difficultyColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${exercise.durationMinutes} min',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Sets and Reps
                Row(
                  children: [
                    _buildInfoBox('Sets', exercise.sets.toString(), Icons.repeat),
                    const SizedBox(width: 12),
                    _buildInfoBox('Reps', exercise.reps.toString(), Icons.numbers),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Target Muscles
                Text(
                  'Target Muscles:',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: exercise.targetMuscles.map((muscle) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        muscle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.7), size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
