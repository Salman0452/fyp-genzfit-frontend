import 'package:cloud_firestore/cloud_firestore.dart';

class MeasurementModel {
  final String id;
  final String userId;
  final DateTime date;
  final double height; // in cm
  final double weight; // in kg
  final Map<String, dynamic> bodyLandmarks; // ML Kit pose landmarks
  final List<String> photoUrls;
  final Map<String, double> estimatedMeasurements; // chest, waist, hips, etc.
  final String? notes;

  MeasurementModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.height,
    required this.weight,
    required this.bodyLandmarks,
    required this.photoUrls,
    required this.estimatedMeasurements,
    this.notes,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'height': height,
      'weight': weight,
      'bodyLandmarks': bodyLandmarks,
      'photoUrls': photoUrls,
      'estimatedMeasurements': estimatedMeasurements,
      'notes': notes,
    };
  }

  // Create from Firestore document
  factory MeasurementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MeasurementModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      height: (data['height'] ?? 0).toDouble(),
      weight: (data['weight'] ?? 0).toDouble(),
      bodyLandmarks: Map<String, dynamic>.from(data['bodyLandmarks'] ?? {}),
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      estimatedMeasurements: Map<String, double>.from(
        (data['estimatedMeasurements'] ?? {}).map(
          (key, value) => MapEntry(key, (value ?? 0).toDouble()),
        ),
      ),
      notes: data['notes'],
    );
  }

  // Create from map
  factory MeasurementModel.fromMap(Map<String, dynamic> data, String id) {
    return MeasurementModel(
      id: id,
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      height: (data['height'] ?? 0).toDouble(),
      weight: (data['weight'] ?? 0).toDouble(),
      bodyLandmarks: Map<String, dynamic>.from(data['bodyLandmarks'] ?? {}),
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      estimatedMeasurements: Map<String, double>.from(
        (data['estimatedMeasurements'] ?? {}).map(
          (key, value) => MapEntry(key, (value ?? 0).toDouble()),
        ),
      ),
      notes: data['notes'],
    );
  }

  // Calculate BMI
  double get bmi => weight / ((height / 100) * (height / 100));

  // Get BMI category
  String get bmiCategory {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  // Copy with method
  MeasurementModel copyWith({
    String? id,
    String? userId,
    DateTime? date,
    double? height,
    double? weight,
    Map<String, dynamic>? bodyLandmarks,
    List<String>? photoUrls,
    Map<String, double>? estimatedMeasurements,
    String? notes,
  }) {
    return MeasurementModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      bodyLandmarks: bodyLandmarks ?? this.bodyLandmarks,
      photoUrls: photoUrls ?? this.photoUrls,
      estimatedMeasurements: estimatedMeasurements ?? this.estimatedMeasurements,
      notes: notes ?? this.notes,
    );
  }
}
