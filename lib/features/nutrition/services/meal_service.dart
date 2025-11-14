import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal.dart';

class MealService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  // Add a new meal
  Future<String?> addMeal(Meal meal) async {
    try {
      if (_userId == null) return null;

      final docRef = await _firestore
          .collection('seekers')
          .doc(_userId)
          .collection('meals')
          .add(meal.toMap());

      return docRef.id;
    } catch (e) {
      print('Error adding meal: $e');
      return null;
    }
  }

  // Update an existing meal
  Future<bool> updateMeal(Meal meal) async {
    try {
      if (_userId == null) return false;

      await _firestore
          .collection('seekers')
          .doc(_userId)
          .collection('meals')
          .doc(meal.id)
          .update(meal.toMap());

      return true;
    } catch (e) {
      print('Error updating meal: $e');
      return false;
    }
  }

  // Delete a meal
  Future<bool> deleteMeal(String mealId) async {
    try {
      if (_userId == null) return false;

      await _firestore
          .collection('seekers')
          .doc(_userId)
          .collection('meals')
          .doc(mealId)
          .delete();

      return true;
    } catch (e) {
      print('Error deleting meal: $e');
      return false;
    }
  }

  // Get meals for a specific date
  Stream<List<Meal>> getMealsForDate(DateTime date) {
    if (_userId == null) return Stream.value([]);

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
        .collection('seekers')
        .doc(_userId)
        .collection('meals')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Meal.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Get meals for a date range
  Stream<List<Meal>> getMealsForDateRange(DateTime startDate, DateTime endDate) {
    if (_userId == null) return Stream.value([]);

    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    return _firestore
        .collection('seekers')
        .doc(_userId)
        .collection('meals')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Meal.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Calculate daily nutrition for a specific date
  Future<DailyNutrition> getDailyNutrition(DateTime date) async {
    if (_userId == null) {
      return DailyNutrition(
        date: date,
        totalCalories: 0,
        totalProtein: 0,
        totalCarbs: 0,
        totalFats: 0,
        mealCount: 0,
      );
    }

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection('seekers')
        .doc(_userId)
        .collection('meals')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFats = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      totalCalories += (data['calories'] ?? 0).toDouble();
      totalProtein += (data['protein'] ?? 0).toDouble();
      totalCarbs += (data['carbs'] ?? 0).toDouble();
      totalFats += (data['fats'] ?? 0).toDouble();
    }

    return DailyNutrition(
      date: date,
      totalCalories: totalCalories,
      totalProtein: totalProtein,
      totalCarbs: totalCarbs,
      totalFats: totalFats,
      mealCount: snapshot.docs.length,
    );
  }

  // Get meals by type for a specific date
  Future<List<Meal>> getMealsByType(DateTime date, String mealType) async {
    if (_userId == null) return [];

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection('seekers')
        .doc(_userId)
        .collection('meals')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .where('mealType', isEqualTo: mealType)
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => Meal.fromMap(doc.id, doc.data()))
        .toList();
  }

  // Get weekly nutrition summary
  Future<Map<String, DailyNutrition>> getWeeklyNutrition(DateTime startDate) async {
    Map<String, DailyNutrition> weeklyData = {};
    
    for (int i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      final nutrition = await getDailyNutrition(date);
      weeklyData[date.toString().split(' ')[0]] = nutrition;
    }

    return weeklyData;
  }
}
