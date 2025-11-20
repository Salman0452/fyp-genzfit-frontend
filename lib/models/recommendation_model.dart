import 'package:cloud_firestore/cloud_firestore.dart';

enum RecommendationType {
  meal,
  exercise,
}

class Recommendation {
  final String id;
  final String userId;
  final RecommendationType type;
  final String title;
  final String description;
  final Map<String, dynamic> details;
  final DateTime generatedAt;
  final Map<String, dynamic>? basedOnMeasurements;

  Recommendation({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    required this.details,
    required this.generatedAt,
    this.basedOnMeasurements,
  });

  factory Recommendation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Recommendation(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] == 'meal'
          ? RecommendationType.meal
          : RecommendationType.exercise,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      details: data['details'] ?? {},
      generatedAt: (data['generatedAt'] as Timestamp).toDate(),
      basedOnMeasurements: data['basedOnMeasurements'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type == RecommendationType.meal ? 'meal' : 'exercise',
      'title': title,
      'description': description,
      'details': details,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'basedOnMeasurements': basedOnMeasurements,
    };
  }

  Recommendation copyWith({
    String? id,
    String? userId,
    RecommendationType? type,
    String? title,
    String? description,
    Map<String, dynamic>? details,
    DateTime? generatedAt,
    Map<String, dynamic>? basedOnMeasurements,
  }) {
    return Recommendation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      details: details ?? this.details,
      generatedAt: generatedAt ?? this.generatedAt,
      basedOnMeasurements: basedOnMeasurements ?? this.basedOnMeasurements,
    );
  }
}

class MealRecommendation {
  final String name;
  final String description;
  final int calories;
  final List<String> ingredients;
  final String mealType; // breakfast, lunch, dinner, snack
  final Map<String, dynamic> macros; // protein, carbs, fats

  MealRecommendation({
    required this.name,
    required this.description,
    required this.calories,
    required this.ingredients,
    required this.mealType,
    required this.macros,
  });

  factory MealRecommendation.fromMap(Map<String, dynamic> map) {
    return MealRecommendation(
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      calories: map['calories'] ?? 0,
      ingredients: List<String>.from(map['ingredients'] ?? []),
      mealType: map['mealType'] ?? '',
      macros: map['macros'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'calories': calories,
      'ingredients': ingredients,
      'mealType': mealType,
      'macros': macros,
    };
  }
}

class ExerciseRecommendation {
  final String name;
  final String description;
  final int sets;
  final int reps;
  final int durationMinutes;
  final String difficulty; // beginner, intermediate, advanced
  final List<String> targetMuscles;
  final String? videoUrl;

  ExerciseRecommendation({
    required this.name,
    required this.description,
    required this.sets,
    required this.reps,
    required this.durationMinutes,
    required this.difficulty,
    required this.targetMuscles,
    this.videoUrl,
  });

  factory ExerciseRecommendation.fromMap(Map<String, dynamic> map) {
    return ExerciseRecommendation(
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      sets: map['sets'] ?? 0,
      reps: map['reps'] ?? 0,
      durationMinutes: map['durationMinutes'] ?? 0,
      difficulty: map['difficulty'] ?? '',
      targetMuscles: List<String>.from(map['targetMuscles'] ?? []),
      videoUrl: map['videoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'sets': sets,
      'reps': reps,
      'durationMinutes': durationMinutes,
      'difficulty': difficulty,
      'targetMuscles': targetMuscles,
      'videoUrl': videoUrl,
    };
  }
}
