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
  static const String _groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  late final String _apiKey;

  RecommendationService() {
    _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      throw Exception('GROQ_API_KEY not found in .env file');
    }
    print('✅ RecommendationService initialized with Groq API key (length: ${_apiKey.length})');
  }

  // Get yesterday's completion summary for adaptive AI
  Future<Map<String, dynamic>> getYesterdayCompletionSummary(String userId) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final startOfDay = DateTime(yesterday.year, yesterday.month, yesterday.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final mealsSnapshot = await _firestore
        .collection('meal_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final exercisesSnapshot = await _firestore
        .collection('exercise_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
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
      'completedExercises': completedExercises.map((e) => e.exerciseName).toList(),
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
      exerciseFreq[exercise.exerciseName] = (exerciseFreq[exercise.exerciseName] ?? 0) + 1;
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
      
      print('📊 Yesterday: ${yesterdaySummary['mealsCompleted']}/${yesterdaySummary['totalMealsScheduled']} meals completed');
      
      final prompt = _buildDailyMealPrompt(
        user, 
        latestMeasurement, 
        yesterdaySummary,
        preferences,
        history['allRecentMeals'] as List<String>, // Use ALL recent, not just completed
      );
      
      final response = await _callGroqAPI(prompt);
      
      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']') + 1;
      
      if (jsonStart == -1 || jsonEnd == 0) {
        print('❌ Invalid JSON response - no JSON array found');
        throw Exception('Invalid JSON response from AI');
      }
      
      final jsonText = response.substring(jsonStart, jsonEnd);
      print('🤖 AI Generated Today\'s Meals (length: ${jsonText.length} chars)');
      
      final List<dynamic> mealsJson = json.decode(jsonText);
      final meals = mealsJson
          .map((meal) => MealRecommendation.fromMap(meal as Map<String, dynamic>))
          .toList();
      
      print('✅ AI Generated ${meals.length} meals for today');
      
      // Save to Firestore with today's date
      await _saveDailyMeals(user.id, meals);
      
      return meals;
    } catch (e) {
      print('❌ AI Daily Meal Generation Failed: $e');
      print('⚠️ Using fallback default meals');
      return _getDefaultMealRecommendations(user.goals);
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
      
      print('📊 Yesterday: ${yesterdaySummary['exercisesCompleted']}/${yesterdaySummary['totalExercisesScheduled']} exercises completed');
      
      final prompt = _buildDailyExercisePrompt(
        user,
        latestMeasurement,
        yesterdaySummary,
        preferences,
        history['allRecentExercises'] as List<String>, // Use ALL recent, not just completed
      );
      
      final response = await _callGroqAPI(prompt);
      
      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']') + 1;
      
      if (jsonStart == -1 || jsonEnd == 0) {
        print('❌ Invalid JSON response - no JSON array found');
        throw Exception('Invalid JSON response from AI');
      }
      
      final jsonText = response.substring(jsonStart, jsonEnd);
      print('🤖 AI Generated Today\'s Exercises (length: ${jsonText.length} chars)');
      
      final List<dynamic> exercisesJson = json.decode(jsonText);
      final exercises = exercisesJson
          .map((ex) => ExerciseRecommendation.fromMap(ex as Map<String, dynamic>))
          .toList();
      
      print('✅ AI Generated ${exercises.length} exercises for today');
      
      // Save to Firestore with today's date
      await _saveDailyExercises(user.id, exercises);
      
      return exercises;
    } catch (e) {
      print('❌ AI Daily Exercise Generation Failed: $e');
      print('⚠️ Using fallback default exercises');
      return _getDefaultExerciseRecommendations(user.goals);
    }
  }

  // Save daily meals to Firestore
  Future<void> _saveDailyMeals(String userId, List<MealRecommendation> meals) async {
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
      
      await _firestore.collection('meal_completions').add(mealCompletion.toMap());
    }
    
    print('💾 Saved ${meals.length} new meals for today');
  }

  // Save daily exercises to Firestore
  Future<void> _saveDailyExercises(String userId, List<ExerciseRecommendation> exercises) async {
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
      
      await _firestore.collection('exercise_completions').add(exerciseCompletion.toMap());
    }
    
    print('💾 Saved ${exercises.length} new exercises for today');
  }

  // Build daily meal prompt with adaptive context
  String _buildDailyMealPrompt(
    UserModel user,
    MeasurementModel? measurement,
    Map<String, dynamic> yesterdaySummary,
    Map<String, List<String>> preferences,
    List<String> recentCompletedMeals,
  ) {
    final bmi = measurement?.bmi ?? 0;
    final goal = user.goals ?? 'fitness';
    final dayOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][DateTime.now().weekday - 1];
    
    final yesterdayCompleted = yesterdaySummary['mealsCompleted'] as int;
    final yesterdayTotal = yesterdaySummary['totalMealsScheduled'] as int;
    final skippedMeals = yesterdaySummary['skippedMeals'] as List<String>;
    final favoriteMeals = preferences['favoriteMeals'] as List<String>;
    
    String adaptiveContext = '';
    if (yesterdayTotal > 0) {
      final completionRate = (yesterdayCompleted / yesterdayTotal * 100).toInt();
      if (completionRate < 50) {
        adaptiveContext = 'User struggled yesterday ($completionRate% completion). Suggest easier, quick-prep meals.';
      } else if (completionRate >= 80) {
        adaptiveContext = 'User is motivated ($completionRate% completion)! Can suggest more complex recipes.';
      }
      
      if (skippedMeals.isNotEmpty) {
        adaptiveContext += ' Skipped: ${skippedMeals.join(', ')} - avoid similar types.';
      }
    }
    
    String preferenceHint = favoriteMeals.isNotEmpty 
        ? 'User enjoys: ${favoriteMeals.join(', ')} - use similar styles.'
        : '';
    
    return '''
Generate 3 personalized Pakistani/Asian meals for TODAY ($dayOfWeek).

User: $goal, ${measurement?.height ?? '?'}cm, ${measurement?.weight ?? '?'}kg, BMI: ${bmi.toStringAsFixed(1)}

ADAPTIVE CONTEXT:
$adaptiveContext
$preferenceHint
Recently recommended in last 30 days (MUST AVOID ALL): ${recentCompletedMeals.join(', ')}

CRITICAL: Generate 3 COMPLETELY NEW meals that user has NOT seen recently. Be creative with Pakistani cuisine variety!

PAKISTANI INGREDIENTS TO USE:
Proteins: Chicken, Beef, Mutton, Fish, Eggs, Daal (Chana, Moong, Masoor, Mash), Yogurt
Grains: Wheat (Dalia/Crushed wheat), Rice, Oats, Sabudana (Sago), Roti, Paratha
Vegetables: Palak (Spinach), Karela, Bhindi, Aloo, Gobi, Gajar, Shimla Mirch
Dairy: Milk, Lassi, Dahi, Paneer, Cheese
Healthy fats: Desi ghee (limited), Olive oil, Almonds, Walnuts

MEAL STRUCTURE:
Breakfast: Pakistani breakfast options
- Dalia (crushed wheat porridge) with milk and nuts
- Oats/Oatmeal with desi style (cinnamon, honey, dry fruits)
- Paratha with egg/omelette
- Halwa Puri (if muscle gain goal)
- Sabudana khichdi (light, digestible)
- Daal ka paratha with yogurt
- Fruit chaat with yogurt

Lunch: Traditional Pakistani meals
- Chicken Karahi with roti/rice
- Daal Chawal (any daal variety)
- Chicken Biryani (portion controlled)
- Aloo Palak with roti
- Chicken/Beef Qeema with vegetables
- Mix vegetable curry with chapati

Dinner: Lighter Pakistani options
- Grilled Chicken Tikka with salad
- Daal (moong/masoor) with 1-2 roti
- Khichdi (rice+daal) with raita
- Vegetable soup with chicken
- Bhindi/Karela sabzi with roti
- Fish curry (light gravy)

REQUIREMENTS:
- 1 Breakfast (350-450 cal, high protein, energizing)
- 1 Lunch (450-600 cal, balanced, satisfying)
- 1 Dinner (400-550 cal, lighter, easy to digest)
- Match $goal goal: ${goal == 'weight_loss' ? 'Lower calories, less oil, more vegetables and daal' : goal == 'muscle_gain' ? 'High protein (chicken, daal, eggs), moderate rice/roti' : 'Balanced traditional meals'}
- Use REAL Pakistani ingredients available in local markets
- Practical recipes Pakistani people actually eat
- Different from recent meals

JSON array:
[
  {"name": "Dalia with Milk & Almonds", "description": "Crushed wheat cooked with milk, honey and nuts", "calories": 380, "ingredients": ["Wheat dalia", "Milk", "Almonds", "Honey"], "mealType": "breakfast", "macros": {"protein": 15, "carbs": 55, "fats": 10}},
  {"name": "Chicken Karahi with Roti", "description": "Spicy tomato-based chicken curry with whole wheat roti", "calories": 520, "ingredients": ["Chicken", "Tomatoes", "Green chili", "Whole wheat roti"], "mealType": "lunch", "macros": {"protein": 40, "carbs": 45, "fats": 18}},
  {"name": "Moong Daal with Chapati", "description": "Light yellow lentils with 2 chapati and salad", "calories": 420, "ingredients": ["Moong daal", "Wheat chapati", "Cucumber", "Tomato"], "mealType": "dinner", "macros": {"protein": 20, "carbs": 60, "fats": 8}}
]
''';
  }

  // Build daily exercise prompt with adaptive context
  String _buildDailyExercisePrompt(
    UserModel user,
    MeasurementModel? measurement,
    Map<String, dynamic> yesterdaySummary,
    Map<String, List<String>> preferences,
    List<String> recentCompletedExercises,
  ) {
    final goal = user.goals ?? 'fitness';
    final bmi = measurement?.bmi ?? 0;
    final dayOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][DateTime.now().weekday - 1];
    final dayIndex = DateTime.now().weekday;
    
    final yesterdayCompleted = yesterdaySummary['exercisesCompleted'] as int;
    final yesterdayTotal = yesterdaySummary['totalExercisesScheduled'] as int;
    final favoriteExercises = preferences['favoriteExercises'] as List<String>;
    
    String adaptiveContext = '';
    if (yesterdayTotal > 0) {
      final completionRate = (yesterdayCompleted / yesterdayTotal * 100).toInt();
      if (completionRate < 50) {
        adaptiveContext = 'User struggled yesterday ($completionRate%). Keep it simple, beginner-friendly.';
      } else if (completionRate >= 80) {
        adaptiveContext = 'User crushed it yesterday ($completionRate%)! Can increase intensity.';
      }
    }
    
    String preferenceHint = favoriteExercises.isNotEmpty
        ? 'User likes: ${favoriteExercises.join(', ')} - similar style welcome.'
        : '';
    
    // Muscle group rotation by day
    String muscleGroupFocus = '';
    switch (dayIndex) {
      case 1: // Monday
        muscleGroupFocus = 'Chest + Triceps (Push)';
        break;
      case 2: // Tuesday
        muscleGroupFocus = 'Back + Biceps (Pull)';
        break;
      case 3: // Wednesday
        muscleGroupFocus = 'Legs + Core';
        break;
      case 4: // Thursday
        muscleGroupFocus = 'Shoulders + Abs';
        break;
      case 5: // Friday
        muscleGroupFocus = 'Full Body HIIT/Cardio';
        break;
      case 6: // Saturday
        muscleGroupFocus = 'Arms + Core (Light)';
        break;
      case 7: // Sunday
        muscleGroupFocus = 'Active Recovery (Yoga/Stretching)';
        break;
    }
    
    return '''
Generate 4 exercises for TODAY ($dayOfWeek).

User: $goal, ${measurement?.height ?? '?'}cm, ${measurement?.weight ?? '?'}kg, BMI: ${bmi.toStringAsFixed(1)}

ADAPTIVE CONTEXT:
$adaptiveContext
$preferenceHint
Recently done in last 30 days (MUST AVOID ALL): ${recentCompletedExercises.join(', ')}

CRITICAL: Generate 4 COMPLETELY NEW exercises that user has NOT done recently. Mix different movements and variations!

TODAY'S FOCUS: $muscleGroupFocus

REQUIREMENTS:
- 4 unique exercises targeting $muscleGroupFocus
- Match $goal goal (${goal == 'weight_loss' ? 'cardio focus' : goal == 'muscle_gain' ? 'strength focus' : 'balanced'})
- Progressive difficulty
- Home/gym friendly

JSON array:
[
  {"name": "...", "description": "...", "sets": 3, "reps": 12, "durationMinutes": 10, "difficulty": "intermediate", "targetMuscles": ["...", "..."]},
  {"name": "...", "description": "...", "sets": 3, "reps": 10, "durationMinutes": 12, "difficulty": "intermediate", "targetMuscles": ["..."]},
  {"name": "...", "description": "...", "sets": 3, "reps": 15, "durationMinutes": 8, "difficulty": "beginner", "targetMuscles": ["..."]},
  {"name": "...", "description": "...", "sets": 2, "reps": 12, "durationMinutes": 8, "difficulty": "beginner", "targetMuscles": ["..."]}
]
''';
  }

  // Get week start and end dates
  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: weekday - 1));
  }

  DateTime _getWeekEnd(DateTime date) {
    return _getWeekStart(date).add(const Duration(days: 6));
  }

  // Check if user has a schedule for current week
  Future<WeeklySchedule?> getCurrentWeekSchedule(String userId) async {
    final weekStart = _getWeekStart(DateTime.now());
    final weekEnd = _getWeekEnd(DateTime.now());

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
        .where('scheduledDate', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    final exercisesSnapshot = await _firestore
        .collection('exercise_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
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
    final completedMealNames = completedMeals.map((m) => m.mealName).toSet().toList();
    final completedExerciseNames = completedExercises.map((e) => e.exerciseName).toSet().toList();
    
    // All recent (for avoiding repetition)
    final allRecentMealNames = allRecentMeals.map((m) => m.mealName).toSet().toList();
    final allRecentExerciseNames = allRecentExercises.map((e) => e.exerciseName).toSet().toList();

    return {
      'completedMeals': completedMealNames,
      'completedExercises': completedExerciseNames,
      'allRecentMeals': allRecentMealNames,
      'allRecentExercises': allRecentExerciseNames,
      'totalMealsCompleted': completedMeals.length,
      'totalExercisesCompleted': completedExercises.length,
      'completionRate': _calculateCompletionRate(mealsSnapshot.docs.length + exercisesSnapshot.docs.length,
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
      
      final prompt = _buildWeeklyMealPrompt(user, latestMeasurement, completedMeals);
      final response = await _callGroqAPI(prompt);
      
      // Parse the JSON response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;
      
      if (jsonStart == -1 || jsonEnd == 0) {
        print('❌ Invalid JSON response - no JSON object found');
        throw Exception('Invalid JSON response from AI');
      }
      
      final jsonText = response.substring(jsonStart, jsonEnd);
      print('🤖 AI Generated Meal Plan Response (length: ${jsonText.length} chars)');
      
      final Map<String, dynamic> weekPlan = json.decode(jsonText);
      
      // Convert to map of day -> meal list
      final Map<String, List<MealRecommendation>> weeklyPlan = {};
      weekPlan.forEach((day, meals) {
        weeklyPlan[day] = (meals as List)
            .map((meal) => MealRecommendation.fromMap(meal as Map<String, dynamic>))
            .toList();
      });
      
      print('✅ AI Generated ${weeklyPlan.length} days with ${weeklyPlan.values.fold(0, (sum, meals) => sum + meals.length)} unique meals');
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
      print('📊 Found ${completedExercises.length} previously completed exercises');
      
      final prompt = _buildWeeklyExercisePrompt(user, latestMeasurement, completedExercises);
      final response = await _callGroqAPI(prompt);
      
      // Parse the JSON response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;
      
      if (jsonStart == -1 || jsonEnd == 0) {
        print('❌ Invalid JSON response - no JSON object found');
        throw Exception('Invalid JSON response from AI');
      }
      
      final jsonText = response.substring(jsonStart, jsonEnd);
      print('🤖 AI Generated Exercise Plan Response (length: ${jsonText.length} chars)');
      
      final Map<String, dynamic> weekPlan = json.decode(jsonText);
      
      // Convert to map of day -> exercise list
      final Map<String, List<ExerciseRecommendation>> weeklyPlan = {};
      weekPlan.forEach((day, exercises) {
        weeklyPlan[day] = (exercises as List)
            .map((exercise) => ExerciseRecommendation.fromMap(exercise as Map<String, dynamic>))
            .toList();
      });
      
      print('✅ AI Generated ${weeklyPlan.length} days with ${weeklyPlan.values.fold(0, (sum, exs) => sum + exs.length)} unique exercises');
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
        
        final doc = await _firestore.collection('meal_completions').add(mealCompletion.toMap());
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
        
        final doc = await _firestore.collection('exercise_completions').add(exerciseCompletion.toMap());
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
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
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
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    return snapshot.docs.map((doc) => MealCompletion.fromFirestore(doc)).toList();
  }

  // Get today's exercises
  Future<List<ExerciseCompletion>> getTodayExercises(String userId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('exercise_completions')
        .where('userId', isEqualTo: userId)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    return snapshot.docs.map((doc) => ExerciseCompletion.fromFirestore(doc)).toList();
  }
  Future<List<MealRecommendation>> generateMealRecommendations({
    required UserModel user,
    required MeasurementModel? latestMeasurement,
    int count = 5,
  }) async {
    try {
      final prompt = _buildMealPrompt(user, latestMeasurement, count);
      final response = await _callGroqAPI(prompt);
      
      // Parse the JSON response
      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']') + 1;
      
      if (jsonStart == -1 || jsonEnd == 0) {
        throw Exception('Invalid JSON response from AI');
      }
      
      final jsonText = response.substring(jsonStart, jsonEnd);
      final List<dynamic> mealsJson = json.decode(jsonText);
      
      return mealsJson
          .map((meal) => MealRecommendation.fromMap(meal as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error generating meal recommendations: $e');
      // Return default recommendations on error
      return _getDefaultMealRecommendations(user.goals);
    }
  }

  // Generate personalized exercise recommendations
  Future<List<ExerciseRecommendation>> generateExerciseRecommendations({
    required UserModel user,
    required MeasurementModel? latestMeasurement,
    int count = 5,
  }) async {
    try {
      final prompt = _buildExercisePrompt(user, latestMeasurement, count);
      final response = await _callGroqAPI(prompt);
      
      // Parse the JSON response
      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']') + 1;
      
      if (jsonStart == -1 || jsonEnd == 0) {
        throw Exception('Invalid JSON response from AI');
      }
      
      final jsonText = response.substring(jsonStart, jsonEnd);
      final List<dynamic> exercisesJson = json.decode(jsonText);
      
      return exercisesJson
          .map((exercise) => ExerciseRecommendation.fromMap(exercise as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error generating exercise recommendations: $e');
      // Return default recommendations on error
      return _getDefaultExerciseRecommendations(user.goals);
    }
  }

  // Call Groq API
  Future<String> _callGroqAPI(String prompt) async {
    try {
      print('📡 Calling Groq API with model: llama-3.1-8b-instant');
      print('📝 Prompt length: ${prompt.length} characters');
      
      final response = await http.post(
        Uri.parse(_groqApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a professional fitness and nutrition expert. Always respond with valid JSON only, no additional text.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 4000,
        }),
      );

      print('📥 Groq API Response Status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('❌ Groq API Error Response: ${response.body}');
        throw Exception('Groq API error: ${response.statusCode} - ${response.body}');
      }

      final data = json.decode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      print('✅ Groq API Success - Response length: ${content.length} characters');
      return content;
    } catch (e) {
      print('❌ Error calling Groq API: $e');
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

      await _firestore.collection('recommendations').add(recommendation.toMap());
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
      await _firestore.collection('recommendations').doc(recommendationId).delete();
    } catch (e) {
      print('Error deleting recommendation: $e');
      rethrow;
    }
  }

  // Build meal prompt (legacy - for single day)
  String _buildMealPrompt(UserModel user, MeasurementModel? measurement, int count) {
    final bmi = measurement?.bmi ?? 0;
    final goal = user.goals ?? 'fitness';
    
    return '''
You are a professional nutritionist. Generate $count personalized meal recommendations.

User Profile:
- Goal: $goal
- Height: ${measurement?.height ?? 'Unknown'} cm
- Weight: ${measurement?.weight ?? 'Unknown'} kg
- BMI: ${bmi.toStringAsFixed(1)}

Requirements:
1. Provide varied meals (breakfast, lunch, dinner options)
2. Match user's fitness goal
3. Include complete nutrition information
4. Use common, accessible ingredients

Return ONLY valid JSON array with this structure:
[
  {
    "name": "Meal name",
    "description": "Brief description",
    "calories": 450,
    "ingredients": ["ingredient1", "ingredient2"],
    "mealType": "breakfast/lunch/dinner",
    "macros": {"protein": 30, "carbs": 45, "fats": 15}
  }
]
''';
  }

  // Build exercise prompt (legacy - for single day)
  String _buildExercisePrompt(UserModel user, MeasurementModel? measurement, int count) {
    final bmi = measurement?.bmi ?? 0;
    final goal = user.goals ?? 'fitness';
    
    return '''
You are a professional fitness trainer. Generate $count personalized exercise recommendations.

User Profile:
- Goal: $goal
- Height: ${measurement?.height ?? 'Unknown'} cm
- Weight: ${measurement?.weight ?? 'Unknown'} kg
- BMI: ${bmi.toStringAsFixed(1)}

Requirements:
1. Mix cardio and strength training
2. Match user's fitness goal
3. Include beginner to intermediate difficulty
4. Provide clear instructions

Return ONLY valid JSON array with this structure:
[
  {
    "name": "Exercise name",
    "description": "How to perform",
    "sets": 3,
    "reps": 12,
    "durationMinutes": 15,
    "difficulty": "beginner/intermediate/advanced",
    "targetMuscles": ["muscle1", "muscle2"]
  }
]
''';
  }

  // Build weekly meal plan prompt
  String _buildWeeklyMealPrompt(UserModel user, MeasurementModel? measurement, List<String> completedMeals) {
    final bmi = measurement?.bmi ?? 0;
    final goal = user.goals ?? 'fitness';
    
    String avoidList = completedMeals.isEmpty ? 'None' : completedMeals.join(', ');
    String goalAdvice = goal == 'weight_loss' 
        ? 'Lower calories (1500-1800/day), high protein, low carbs' 
        : goal == 'muscle_gain' 
            ? 'High protein (2g/kg bodyweight), higher calories (2200-2800/day), complex carbs' 
            : 'Balanced nutrition (1800-2200/day)';
    
    return '''
You are a professional nutritionist. Create a personalized 7-day meal plan with MAXIMUM VARIETY.

User Profile:
- Fitness Goal: $goal
- Height: ${measurement?.height ?? 'Unknown'} cm
- Weight: ${measurement?.weight ?? 'Unknown'} kg
- BMI: ${bmi.toStringAsFixed(1)}

Previously Eaten (MUST AVOID): $avoidList

CRITICAL REQUIREMENTS:
1. Generate 21 UNIQUE meals (3 per day × 7 days)
2. Each meal MUST be completely different
3. Mix cuisines: Indian, Continental, Mediterranean, Asian, Mexican, Italian
4. Monday-Sunday: Each day should have a different theme
5. Goal-specific nutrition: $goalAdvice
6. Breakfast: High protein, energizing (350-450 calories)
7. Lunch: Balanced, satisfying (450-600 calories)
8. Dinner: Lighter, digestible (400-550 calories)
9. Real, cookable recipes with accessible ingredients
10. NO repetition within the week

Return ONLY valid JSON (no markdown, no extra text):
{
  "Monday": [
    {"name": "Greek Yogurt Parfait", "description": "Layered yogurt with berries and granola", "calories": 380, "ingredients": ["Greek yogurt", "Mixed berries", "Granola", "Honey"], "mealType": "breakfast", "macros": {"protein": 25, "carbs": 42, "fats": 12}},
    {"name": "Grilled Chicken Bowl", "description": "Quinoa bowl with grilled chicken", "calories": 520, "ingredients": ["Chicken breast", "Quinoa", "Broccoli"], "mealType": "lunch", "macros": {"protein": 38, "carbs": 48, "fats": 16}},
    {"name": "Baked Salmon", "description": "Herb salmon with asparagus", "calories": 450, "ingredients": ["Salmon", "Asparagus", "Lemon"], "mealType": "dinner", "macros": {"protein": 35, "carbs": 22, "fats": 24}}
  ],
  "Tuesday": [...completely different meals...],
  "Wednesday": [...],
  "Thursday": [...],
  "Friday": [...],
  "Saturday": [...],
  "Sunday": [...]
}
''';
  }

  // Build weekly exercise plan prompt
  String _buildWeeklyExercisePrompt(UserModel user, MeasurementModel? measurement, List<String> completedExercises) {
    final goal = user.goals ?? 'fitness';
    final bmi = measurement?.bmi ?? 0;
    
    String avoidList = completedExercises.isEmpty ? 'None' : completedExercises.join(', ');
    String goalFocus = goal == 'weight_loss' 
        ? 'More cardio, circuit training' 
        : goal == 'muscle_gain' 
            ? 'Heavy compound lifts, progressive overload' 
            : 'Balanced strength and cardio';
    
    return '''
Create a 7-day workout split with UNIQUE exercises each day.

User: $goal goal, ${measurement?.height ?? '?'} cm, ${measurement?.weight ?? '?'} kg, BMI: ${bmi.toStringAsFixed(1)}
Avoid: $avoidList

WEEKLY SPLIT:
Mon: Chest+Triceps (4 ex) | Tue: Back+Biceps (4 ex) | Wed: Legs+Core (4 ex)
Thu: Shoulders+Abs (4 ex) | Fri: HIIT/Cardio (4 ex) | Sat: Arms+Core (3 ex) | Sun: Recovery (2 ex)

Focus: $goalFocus
Each exercise: name, brief description, sets, reps, duration, difficulty, target muscles
NO repetition across week

JSON format:
{
  "Monday": [
    {"name": "Barbell Bench Press", "description": "Lower bar to chest, press up", "sets": 4, "reps": 10, "durationMinutes": 12, "difficulty": "intermediate", "targetMuscles": ["Chest", "Triceps"]},
    {"name": "Incline DB Press", "description": "45-degree press", "sets": 3, "reps": 12, "durationMinutes": 10, "difficulty": "intermediate", "targetMuscles": ["Upper Chest"]},
    {"name": "Cable Flyes", "description": "Cross cables, squeeze pecs", "sets": 3, "reps": 15, "durationMinutes": 8, "difficulty": "beginner", "targetMuscles": ["Chest"]},
    {"name": "Tricep Dips", "description": "Lower and push up", "sets": 3, "reps": 12, "durationMinutes": 8, "difficulty": "intermediate", "targetMuscles": ["Triceps"]}
  ],
  "Tuesday": [...4 different back/biceps exercises...],
  "Wednesday": [...4 different leg/core exercises...],
  "Thursday": [...4 different shoulder/abs exercises...],
  "Friday": [...4 different HIIT exercises...],
  "Saturday": [...3 different arm/core exercises...],
  "Sunday": [...2 recovery exercises...]
}
''';
  }

  // Default weekly meal plan (fallback)
  Map<String, List<MealRecommendation>> _getDefaultWeeklyMealPlan(String? goal) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final plan = <String, List<MealRecommendation>>{};
    
    for (var day in days) {
      plan[day] = [
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
          description: 'Fresh greens with grilled chicken and olive oil dressing',
          calories: 400,
          ingredients: ['Chicken breast', 'Mixed greens', 'Tomatoes', 'Cucumber'],
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
  Map<String, List<ExerciseRecommendation>> _getDefaultWeeklyExercisePlan(String? goal) {
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
        description: 'Fresh greens with grilled chicken, vegetables, and olive oil dressing',
        calories: 400,
        ingredients: ['Chicken breast', 'Mixed greens', 'Tomatoes', 'Cucumber', 'Olive oil'],
        mealType: 'lunch',
        macros: {'protein': 35, 'carbs': 20, 'fats': 18},
      ),
      MealRecommendation(
        name: 'Salmon with Sweet Potato',
        description: 'Baked salmon with roasted sweet potato and broccoli',
        calories: 500,
        ingredients: ['Salmon fillet', 'Sweet potato', 'Broccoli', 'Lemon', 'Herbs'],
        mealType: 'dinner',
        macros: {'protein': 40, 'carbs': 45, 'fats': 20},
      ),
    ];
  }

  // Default exercise recommendations (fallback)
  List<ExerciseRecommendation> _getDefaultExerciseRecommendations(String? goal) {
    return [
      ExerciseRecommendation(
        name: 'Push-ups',
        description: 'Classic bodyweight exercise for chest, shoulders, and triceps',
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
