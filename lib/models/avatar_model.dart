import 'package:cloud_firestore/cloud_firestore.dart';

class Avatar3D {
  final String id;
  final String userId;
  final String? modelUrl;
  final Map<String, dynamic> measurements;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Avatar3D({
    required this.id,
    required this.userId,
    this.modelUrl,
    required this.measurements,
    required this.createdAt,
    this.updatedAt,
  });

  factory Avatar3D.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Avatar3D(
      id: doc.id,
      userId: data['userId'] ?? '',
      modelUrl: data['modelUrl'],
      measurements: data['measurements'] ?? {},
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt:
          data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'modelUrl': modelUrl,
      'measurements': measurements,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  Avatar3D copyWith({
    String? id,
    String? userId,
    String? modelUrl,
    Map<String, dynamic>? measurements,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Avatar3D(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      modelUrl: modelUrl ?? this.modelUrl,
      measurements: measurements ?? this.measurements,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper method to get specific measurements
  double? getMeasurement(String key) {
    final value = measurements[key];
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  // Common measurement getters
  double? get height => getMeasurement('height');
  double? get weight => getMeasurement('weight');
  double? get chest => getMeasurement('chest');
  double? get waist => getMeasurement('waist');
  double? get hips => getMeasurement('hips');
  double? get shoulderWidth => getMeasurement('shoulderWidth');
  double? get armLength => getMeasurement('armLength');
  double? get legLength => getMeasurement('legLength');

  // Calculate BMI
  double? get bmi {
    if (height != null && weight != null && height! > 0) {
      final heightInMeters = height! / 100;
      return weight! / (heightInMeters * heightInMeters);
    }
    return null;
  }

  // Get body type based on measurements
  String get bodyType {
    if (measurements.isEmpty) return 'Unknown';
    
    final bmiValue = bmi;
    if (bmiValue == null) return 'Unknown';

    if (bmiValue < 18.5) return 'Underweight';
    if (bmiValue < 25) return 'Normal';
    if (bmiValue < 30) return 'Overweight';
    return 'Obese';
  }
}
