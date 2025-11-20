import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genzfit/models/measurement_model.dart';
import 'package:genzfit/services/storage_service.dart';
import 'package:uuid/uuid.dart';

class BodyAnalysisService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.accurate,
    ),
  );

  // Analyze pose from image and extract measurements
  Future<Map<String, dynamic>> analyzePose(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isEmpty) {
        throw Exception('No pose detected in the image. Please try again with better lighting and positioning.');
      }

      final pose = poses.first;
      final landmarks = pose.landmarks;

      // Extract landmarks as map
      final landmarksMap = <String, dynamic>{};
      for (var landmark in landmarks.entries) {
        landmarksMap[landmark.key.name] = {
          'x': landmark.value.x,
          'y': landmark.value.y,
          'z': landmark.value.z,
          'likelihood': landmark.value.likelihood,
        };
      }

      // Calculate measurements based on landmarks
      final measurements = _calculateMeasurements(landmarks);

      return {
        'landmarks': landmarksMap,
        'measurements': measurements,
        'confidence': _calculateOverallConfidence(landmarks),
      };
    } catch (e) {
      throw Exception('Failed to analyze pose: $e');
    }
  }

  // Calculate body measurements from landmarks
  Map<String, double> _calculateMeasurements(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final measurements = <String, double>{};

    try {
      // Shoulder width
      if (landmarks.containsKey(PoseLandmarkType.leftShoulder) &&
          landmarks.containsKey(PoseLandmarkType.rightShoulder)) {
        measurements['shoulderWidth'] = _calculateDistance(
          landmarks[PoseLandmarkType.leftShoulder]!,
          landmarks[PoseLandmarkType.rightShoulder]!,
        );
      }

      // Hip width
      if (landmarks.containsKey(PoseLandmarkType.leftHip) &&
          landmarks.containsKey(PoseLandmarkType.rightHip)) {
        measurements['hipWidth'] = _calculateDistance(
          landmarks[PoseLandmarkType.leftHip]!,
          landmarks[PoseLandmarkType.rightHip]!,
        );
      }

      // Arm length (left)
      if (landmarks.containsKey(PoseLandmarkType.leftShoulder) &&
          landmarks.containsKey(PoseLandmarkType.leftElbow) &&
          landmarks.containsKey(PoseLandmarkType.leftWrist)) {
        final upperArm = _calculateDistance(
          landmarks[PoseLandmarkType.leftShoulder]!,
          landmarks[PoseLandmarkType.leftElbow]!,
        );
        final forearm = _calculateDistance(
          landmarks[PoseLandmarkType.leftElbow]!,
          landmarks[PoseLandmarkType.leftWrist]!,
        );
        measurements['leftArmLength'] = upperArm + forearm;
      }

      // Leg length (left)
      if (landmarks.containsKey(PoseLandmarkType.leftHip) &&
          landmarks.containsKey(PoseLandmarkType.leftKnee) &&
          landmarks.containsKey(PoseLandmarkType.leftAnkle)) {
        final thigh = _calculateDistance(
          landmarks[PoseLandmarkType.leftHip]!,
          landmarks[PoseLandmarkType.leftKnee]!,
        );
        final shin = _calculateDistance(
          landmarks[PoseLandmarkType.leftKnee]!,
          landmarks[PoseLandmarkType.leftAnkle]!,
        );
        measurements['leftLegLength'] = thigh + shin;
      }

      // Torso length
      if (landmarks.containsKey(PoseLandmarkType.leftShoulder) &&
          landmarks.containsKey(PoseLandmarkType.leftHip)) {
        measurements['torsoLength'] = _calculateDistance(
          landmarks[PoseLandmarkType.leftShoulder]!,
          landmarks[PoseLandmarkType.leftHip]!,
        );
      }

      // Estimate chest (based on shoulder width with factor)
      if (measurements.containsKey('shoulderWidth')) {
        measurements['estimatedChest'] = measurements['shoulderWidth']! * 2.2;
      }

      // Estimate waist (based on hip width with factor)
      if (measurements.containsKey('hipWidth')) {
        measurements['estimatedWaist'] = measurements['hipWidth']! * 1.8;
        measurements['estimatedHips'] = measurements['hipWidth']! * 2.0;
      }
    } catch (e) {
      print('Error calculating measurements: $e');
    }

    return measurements;
  }

  // Calculate distance between two landmarks
  double _calculateDistance(PoseLandmark point1, PoseLandmark point2) {
    final dx = point1.x - point2.x;
    final dy = point1.y - point2.y;
    final dz = point1.z - point2.z;
    return sqrt(dx * dx + dy * dy + dz * dz);
  }

  // Calculate overall confidence score
  double _calculateOverallConfidence(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (landmarks.isEmpty) return 0.0;

    double totalConfidence = 0.0;
    int count = 0;

    for (var landmark in landmarks.values) {
      totalConfidence += landmark.likelihood;
      count++;
    }

    return count > 0 ? totalConfidence / count : 0.0;
  }

  // Save measurement to Firestore
  Future<String> saveMeasurement({
    required String userId,
    required double height,
    required double weight,
    required Map<String, dynamic> bodyLandmarks,
    required List<File> photos,
    required Map<String, double> estimatedMeasurements,
    String? notes,
  }) async {
    try {
      // Upload photos to Firebase Storage
      final photoUrls = <String>[];
      for (var i = 0; i < photos.length; i++) {
        final photoUrl = await _storageService.uploadImage(
          photos[i],
          'measurements/$userId/${const Uuid().v4()}_$i.jpg',
        );
        photoUrls.add(photoUrl);
      }

      // Create measurement document
      final measurement = MeasurementModel(
        id: const Uuid().v4(),
        userId: userId,
        date: DateTime.now(),
        height: height,
        weight: weight,
        bodyLandmarks: bodyLandmarks,
        photoUrls: photoUrls,
        estimatedMeasurements: estimatedMeasurements,
        notes: notes,
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection('measurements')
          .add(measurement.toMap());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to save measurement: $e');
    }
  }

  // Get user measurements
  Future<List<MeasurementModel>> getUserMeasurements(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('measurements')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MeasurementModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch measurements: $e');
    }
  }

  // Get latest measurement
  Future<MeasurementModel?> getLatestMeasurement(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('measurements')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return MeasurementModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      print('Failed to fetch latest measurement: $e');
      return null;
    }
  }

  // Delete measurement
  Future<void> deleteMeasurement(String measurementId, List<String> photoUrls) async {
    try {
      // Delete photos from storage
      for (var photoUrl in photoUrls) {
        await _storageService.deleteFile(photoUrl);
      }

      // Delete from Firestore
      await _firestore.collection('measurements').doc(measurementId).delete();
    } catch (e) {
      throw Exception('Failed to delete measurement: $e');
    }
  }

  // Estimate height from landmarks (in cm)
  double estimateHeight(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    try {
      // Calculate total body length from top of head to ankle
      double totalLength = 0.0;

      if (landmarks.containsKey(PoseLandmarkType.nose) &&
          landmarks.containsKey(PoseLandmarkType.leftAnkle)) {
        totalLength = _calculateDistance(
          landmarks[PoseLandmarkType.nose]!,
          landmarks[PoseLandmarkType.leftAnkle]!,
        );
      }

      // This is a pixel-based measurement, needs calibration
      // For now, we'll return a default value and require manual input
      return 170.0; // Default height in cm
    } catch (e) {
      return 170.0;
    }
  }

  // Dispose pose detector
  void dispose() {
    _poseDetector.close();
  }
}
