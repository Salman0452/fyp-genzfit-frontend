import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/avatar_model.dart';
import '../models/measurement_model.dart';

/// Talks to the Python FastAPI SMPL backend,
/// manages local GLB caching, and persists snapshots to Firestore.
class SmplAvatarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Default backend URL — override in .env as SMPL_BACKEND_URL
  String get _baseUrl =>
      dotenv.env['SMPL_BACKEND_URL'] ?? 'http://10.0.2.2:8000';

  // ------------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------------

  /// Generate a new 3D avatar for [userId] from a [MeasurementModel].
  ///
  /// Returns the updated [Avatar3D] with the local GLB path set.
  /// Persists snapshot metadata (betas + measurements) to Firestore.
  Future<Avatar3D> generateAvatar({
    required String userId,
    required MeasurementModel measurement,
    String skinTone = 'medium',
    bool showMuscles = true,
  }) async {
    final payload = _buildPayload(
      userId: userId,
      measurement: measurement,
      skinTone: skinTone,
      showMuscles: showMuscles,
    );

    final uri = Uri.parse('$_baseUrl/generate-avatar');

    late http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));
    } on SocketException catch (e) {
      throw SmplBackendException(
        'Cannot reach SMPL backend at $_baseUrl. '
        'Make sure the Python server is running.\n$e',
      );
    }

    if (response.statusCode != 200) {
      throw SmplBackendException(
        'Backend responded with ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // ── Decode & save GLB locally ────────────────────────────────────────
    final glbBytes = base64Decode(data['model_base64'] as String);
    final localGlbPath =
        await _saveGlbLocally(userId, measurement.date, glbBytes);

    // ── Build betas list ─────────────────────────────────────────────────
    final betas =
        (data['betas'] as List).map((e) => (e as num).toDouble()).toList();

    // ── Persist to Firestore ─────────────────────────────────────────────
    final docId = await _persistSnapshot(
      userId: userId,
      date: measurement.date,
      betas: betas,
      measurements: Map<String, dynamic>.from(data['body_measurements'] as Map),
      localGlbPath: localGlbPath,
    );

    return Avatar3D(
      id: docId,
      userId: userId,
      modelUrl: localGlbPath, // local file:// path for model_viewer_plus
      betaValues: betas,
      measurements: Map<String, dynamic>.from(data['body_measurements'] as Map),
      createdAt: measurement.date,
      generationMethod: data['message'] as String? ?? 'capsule-mesh',
    );
  }

  /// Load all avatar snapshots (metadata only) for [userId].
  Future<List<AvatarSnapshot>> getAvatarHistory(String userId) async {
    final snapshot = await _firestore
        .collection('avatar_snapshots')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: false)
        .get();

    return snapshot.docs.map(AvatarSnapshot.fromFirestore).toList();
  }

  /// Load a specific snapshot's GLB.
  ///
  /// If the GLB is already cached locally the local file is returned;
  /// otherwise it is re-downloaded from the backend.
  Future<String> getGlbPath({
    required String userId,
    required String snapDate,
    String fallbackSkinTone = 'medium',
  }) async {
    final localPath = await _localGlbPath(userId, snapDate);
    if (await File(localPath).exists()) return localPath;

    // Re-request from backend
    final uri = Uri.parse('$_baseUrl/avatar/$userId/$snapDate/glb');
    final response = await http.get(uri).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw SmplBackendException(
          'Failed to download GLB: ${response.statusCode}');
    }

    await File(localPath).writeAsBytes(response.bodyBytes);
    return localPath;
  }

  /// Check whether the backend is reachable.
  Future<bool> isBackendAvailable() async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------
  // Private helpers
  // ------------------------------------------------------------------

  Map<String, dynamic> _buildPayload({
    required String userId,
    required MeasurementModel measurement,
    String skinTone = 'medium',
    bool showMuscles = true,
  }) {
    final Map<String, dynamic> payload = {
      'user_id': userId,
      'date': measurement.date.toIso8601String().substring(0, 10),
      'height': measurement.height,
      'weight': measurement.weight,
      'age': measurement.age ?? 25,
      'gender': measurement.gender ?? 'male',
      'skin_tone': skinTone,
      'show_muscles': showMuscles,
    };

    // Attach ML Kit landmarks if available
    if (measurement.bodyLandmarks != null &&
        measurement.bodyLandmarks!.isNotEmpty) {
      payload['landmarks'] = measurement.bodyLandmarks;
    }

    // Attach anthropometric measurements if available
    if (measurement.estimatedMeasurements != null &&
        measurement.estimatedMeasurements!.isNotEmpty) {
      payload['measurements'] = measurement.estimatedMeasurements;
    }

    return payload;
  }

  Future<String> _saveGlbLocally(
    String userId,
    DateTime date,
    Uint8List bytes,
  ) async {
    final path = await _localGlbPath(userId, _dateKey(date));
    await File(path).writeAsBytes(bytes);
    return path;
  }

  Future<String> _localGlbPath(String userId, String dateKey) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/avatars/$userId');
    await folder.create(recursive: true);
    return '${folder.path}/$dateKey.glb';
  }

  String _dateKey(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  Future<String> _persistSnapshot({
    required String userId,
    required DateTime date,
    required List<double> betas,
    required Map<String, dynamic> measurements,
    required String localGlbPath,
  }) async {
    final dateKey = _dateKey(date);

    // Check for existing doc on same date
    final existing = await _firestore
        .collection('avatar_snapshots')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: dateKey)
        .limit(1)
        .get();

    final data = {
      'userId': userId,
      'date': dateKey,
      'betas': betas,
      'measurements': measurements,
      'localGlbPath': localGlbPath,
      'updatedAt': Timestamp.now(),
    };

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update(data);
      return existing.docs.first.id;
    } else {
      data['createdAt'] = Timestamp.now();
      final ref = await _firestore.collection('avatar_snapshots').add(data);
      return ref.id;
    }
  }
}

// ─── Lightweight snapshot model ───────────────────────────────────────────────

class AvatarSnapshot {
  final String id;
  final String userId;
  final String date; // "YYYY-MM-DD"
  final List<double> betas;
  final Map<String, dynamic> measurements;
  final String? localGlbPath;

  const AvatarSnapshot({
    required this.id,
    required this.userId,
    required this.date,
    required this.betas,
    required this.measurements,
    this.localGlbPath,
  });

  factory AvatarSnapshot.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AvatarSnapshot(
      id: doc.id,
      userId: d['userId'] as String,
      date: d['date'] as String,
      betas: (d['betas'] as List).map((e) => (e as num).toDouble()).toList(),
      measurements: Map<String, dynamic>.from(d['measurements'] as Map? ?? {}),
      localGlbPath: d['localGlbPath'] as String?,
    );
  }

  /// Key body stats for display in UI
  double? get weight => (measurements['weight'] as num?)?.toDouble();
  double? get waist => (measurements['waist'] as num?)?.toDouble();
  double? get chest => (measurements['chest'] as num?)?.toDouble();
}

// ─── Error ────────────────────────────────────────────────────────────────────

class SmplBackendException implements Exception {
  final String message;
  const SmplBackendException(this.message);

  @override
  String toString() => 'SmplBackendException: $message';
}
