import 'package:cloud_firestore/cloud_firestore.dart';

class Meal {
  final String id;
  final String userId;
  final String name;
  final String mealType; // breakfast, lunch, dinner, snack
  final double calories;
  final double protein; // in grams
  final double carbs; // in grams
  final double fats; // in grams
  final DateTime timestamp;
  final String? notes;
  final String? imageUrl;

  Meal({
    required this.id,
    required this.userId,
    required this.name,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.timestamp,
    this.notes,
    this.imageUrl,
  });

  // Convert Meal to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'mealType': mealType,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'timestamp': Timestamp.fromDate(timestamp),
      'notes': notes,
      'imageUrl': imageUrl,
    };
  }

  // Create Meal from Firestore document
  factory Meal.fromMap(String id, Map<String, dynamic> map) {
    return Meal(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      mealType: map['mealType'] ?? '',
      calories: (map['calories'] ?? 0).toDouble(),
      protein: (map['protein'] ?? 0).toDouble(),
      carbs: (map['carbs'] ?? 0).toDouble(),
      fats: (map['fats'] ?? 0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      notes: map['notes'],
      imageUrl: map['imageUrl'],
    );
  }

  // Copy with method for easy updates
  Meal copyWith({
    String? id,
    String? userId,
    String? name,
    String? mealType,
    double? calories,
    double? protein,
    double? carbs,
    double? fats,
    DateTime? timestamp,
    String? notes,
    String? imageUrl,
  }) {
    return Meal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      mealType: mealType ?? this.mealType,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      timestamp: timestamp ?? this.timestamp,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

// Daily nutrition summary
class DailyNutrition {
  final DateTime date;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFats;
  final int mealCount;

  DailyNutrition({
    required this.date,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFats,
    required this.mealCount,
  });

  // Calculate total macros in calories
  double get proteinCalories => totalProtein * 4; // 4 cal per gram
  double get carbsCalories => totalCarbs * 4; // 4 cal per gram
  double get fatsCalories => totalFats * 9; // 9 cal per gram

  // Calculate macro percentages
  double get proteinPercentage => totalCalories > 0 ? (proteinCalories / totalCalories) * 100 : 0;
  double get carbsPercentage => totalCalories > 0 ? (carbsCalories / totalCalories) * 100 : 0;
  double get fatsPercentage => totalCalories > 0 ? (fatsCalories / totalCalories) * 100 : 0;
}
