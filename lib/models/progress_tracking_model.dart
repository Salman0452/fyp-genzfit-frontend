import 'package:cloud_firestore/cloud_firestore.dart';

enum CompletionStatus {
  pending,
  completed,
  skipped,
}

class MealCompletion {
  final String id;
  final String userId;
  final String mealName;
  final String mealType;
  final DateTime scheduledDate;
  final CompletionStatus status;
  final DateTime? completedAt;
  final int calories;
  final Map<String, dynamic> macros;

  MealCompletion({
    required this.id,
    required this.userId,
    required this.mealName,
    required this.mealType,
    required this.scheduledDate,
    required this.status,
    this.completedAt,
    required this.calories,
    required this.macros,
  });

  factory MealCompletion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealCompletion(
      id: doc.id,
      userId: data['userId'] ?? '',
      mealName: data['mealName'] ?? '',
      mealType: data['mealType'] ?? '',
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      status: CompletionStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CompletionStatus.pending,
      ),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      calories: data['calories'] ?? 0,
      macros: data['macros'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'mealName': mealName,
      'mealType': mealType,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'status': status.name,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'calories': calories,
      'macros': macros,
    };
  }
}

class ExerciseCompletion {
  final String id;
  final String userId;
  final String exerciseName;
  final DateTime scheduledDate;
  final CompletionStatus status;
  final DateTime? completedAt;
  final int sets;
  final int reps;
  final int durationMinutes;
  final String difficulty;
  final List<String> targetMuscles;

  ExerciseCompletion({
    required this.id,
    required this.userId,
    required this.exerciseName,
    required this.scheduledDate,
    required this.status,
    this.completedAt,
    required this.sets,
    required this.reps,
    required this.durationMinutes,
    required this.difficulty,
    required this.targetMuscles,
  });

  factory ExerciseCompletion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExerciseCompletion(
      id: doc.id,
      userId: data['userId'] ?? '',
      exerciseName: data['exerciseName'] ?? '',
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      status: CompletionStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CompletionStatus.pending,
      ),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      sets: data['sets'] ?? 0,
      reps: data['reps'] ?? 0,
      durationMinutes: data['durationMinutes'] ?? 0,
      difficulty: data['difficulty'] ?? '',
      targetMuscles: List<String>.from(data['targetMuscles'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'exerciseName': exerciseName,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'status': status.name,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'sets': sets,
      'reps': reps,
      'durationMinutes': durationMinutes,
      'difficulty': difficulty,
      'targetMuscles': targetMuscles,
    };
  }
}

class WeeklySchedule {
  final String id;
  final String userId;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final Map<String, List<String>> mealSchedule; // day -> meal IDs
  final Map<String, List<String>> exerciseSchedule; // day -> exercise IDs
  final DateTime createdAt;

  WeeklySchedule({
    required this.id,
    required this.userId,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.mealSchedule,
    required this.exerciseSchedule,
    required this.createdAt,
  });

  factory WeeklySchedule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WeeklySchedule(
      id: doc.id,
      userId: data['userId'] ?? '',
      weekStartDate: (data['weekStartDate'] as Timestamp).toDate(),
      weekEndDate: (data['weekEndDate'] as Timestamp).toDate(),
      mealSchedule: Map<String, List<String>>.from(
        (data['mealSchedule'] ?? {}).map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ),
      ),
      exerciseSchedule: Map<String, List<String>>.from(
        (data['exerciseSchedule'] ?? {}).map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ),
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'weekStartDate': Timestamp.fromDate(weekStartDate),
      'weekEndDate': Timestamp.fromDate(weekEndDate),
      'mealSchedule': mealSchedule,
      'exerciseSchedule': exerciseSchedule,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
