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

  static int _asInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static List<String> _asStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final raw = value.toString();
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String _normalizeMealType(dynamic value) {
    final type = (value ?? '').toString().trim().toLowerCase();
    if (type.isEmpty) return 'meal';
    if (type == 'b') return 'breakfast';
    if (type == 'l') return 'lunch';
    if (type == 'd') return 'dinner';
    if (type == 's') return 'snack';
    return type;
  }

  factory MealRecommendation.fromMap(Map<String, dynamic> map) {
    final compactProtein = _asInt(map['p']);
    final compactCarbs = _asInt(map['ca']);
    final compactFats = _asInt(map['f']);
    final fullMacros = map['macros'] as Map<String, dynamic>?;

    return MealRecommendation(
      name: (map['name'] ?? map['n'] ?? '').toString(),
      description: (map['description'] ?? map['d'] ?? '').toString(),
      calories: _asInt(map['calories'] ?? map['c']),
      ingredients: _asStringList(map['ingredients'] ?? map['i']),
      mealType: _normalizeMealType(map['mealType'] ?? map['t']),
      macros: fullMacros != null
          ? {
              'protein': _asInt(fullMacros['protein']),
              'carbs': _asInt(fullMacros['carbs']),
              'fats': _asInt(fullMacros['fats']),
            }
          : {
              'protein': compactProtein,
              'carbs': compactCarbs,
              'fats': compactFats,
            },
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

  static int _asInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    final text = value.toString();
    final parsed = int.tryParse(text);
    if (parsed != null) return parsed;

    final first = RegExp(r'\d+').firstMatch(text)?.group(0);
    return int.tryParse(first ?? '') ?? fallback;
  }

  static List<String> _asStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final raw = value.toString();
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  factory ExerciseRecommendation.fromMap(Map<String, dynamic> map) {
    return ExerciseRecommendation(
      name: (map['name'] ?? map['n'] ?? '').toString(),
      description: (map['description'] ?? map['d'] ?? '').toString(),
      sets: _asInt(map['sets'] ?? map['s']),
      reps: _asInt(map['reps'] ?? map['r']),
      durationMinutes: _asInt(map['durationMinutes'] ?? map['du']),
      difficulty: (map['difficulty'] ?? map['di'] ?? '').toString(),
      targetMuscles: _asStringList(map['targetMuscles'] ?? map['m']),
      videoUrl: map['videoUrl'] ?? map['v'],
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
