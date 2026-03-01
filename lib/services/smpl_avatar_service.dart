import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/measurement_model.dart';

// ---------------------------------------------------------------------------
// SmplAvatarService
// ---------------------------------------------------------------------------
// Calls the FastAPI SMPL-X backend (/generate-avatar), downloads the
// returned binary .glb file, caches it locally, and persists snapshot
// metadata to Firestore.
//
// The backend POST /generate-avatar accepts JSON and returns a binary .glb
// (Content-Type: model/gltf-binary). No base64 wrapping – raw bytes.
// ---------------------------------------------------------------------------
class SmplAvatarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Backend base URL. Override in .env via SMPL_BACKEND_URL.
  /// Default: Android emulator host loopback (10.0.2.2 = your machine).
  String get _baseUrl =>
      dotenv.env['SMPL_BACKEND_URL'] ?? 'http://10.0.2.2:8000';

  // ── Public API ─────────────────────────────────────────────────────────

  /// Generate a SMPL-X avatar from [measurement].
  ///
  /// Calls POST /generate-avatar on the backend. The backend generates the
  /// SMPL-X mesh, applies UV skin texture, and returns binary .glb bytes.
  ///
  /// The .glb is saved locally under avatars/{userId}/{date}.glb.
  /// Snapshot metadata is persisted to Firestore (avatar_snapshots).
  ///
  /// Returns the absolute local file path of the saved .glb.
  Future<String> generateAvatar({
    required String userId,
    required MeasurementModel measurement,
  }) async {
    // Build JSON request body for the backend
    final payload = <String, dynamic>{
      'gender': measurement.gender ?? 'neutral',
      'height': measurement.height,
      'weight': measurement.weight,
    };

    // Include body measurements if available (chest, waist, hips, etc.)
    if (measurement.estimatedMeasurements.isNotEmpty) {
      payload['body_measurements'] = measurement.estimatedMeasurements;
    }

    final uri = Uri.parse('$_baseUrl/generate-avatar');

    late http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 120));
    } on SocketException catch (e) {
      throw SmplBackendException(
        'Cannot reach SMPL-X backend at $_baseUrl.\n'
        'Start the server: uvicorn main:app --reload --host 0.0.0.0 --port 8000\n'
        'Error: $e',
      );
    }

    if (response.statusCode != 200) {
      throw SmplBackendException(
          'Backend returned ${response.statusCode}: ${response.body}');
    }

    // Backend returns raw .glb bytes (Content-Type: model/gltf-binary)
    final glbBytes = response.bodyBytes;
    if (glbBytes.isEmpty) {
      throw const SmplBackendException('Backend returned an empty .glb.');
    }

    // Save .glb to local storage
    final dateKey = _dateKey(measurement.date);
    final localPath = await _saveGlb(userId, dateKey, glbBytes);

    // Persist snapshot metadata to Firestore
    await _persistSnapshot(
      userId: userId,
      dateKey: dateKey,
      measurements: {
        'height': measurement.height,
        'weight': measurement.weight,
        ...measurement.estimatedMeasurements,
      },
      localGlbPath: localPath,
    );

    return localPath;
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

  /// Load a specific snapshot's .glb path.
  ///
  /// Returns the cached local file path if it exists.
  /// If cache is missing, throws [SmplBackendException]
  /// (re-generation requires calling [generateAvatar] directly).
  Future<String> getGlbPath({
    required String userId,
    required String snapDate,
  }) async {
    final localPath = await _localGlbPath(userId, snapDate);
    if (await File(localPath).exists()) return localPath;
    throw SmplBackendException('Local .glb cache missing for $snapDate. '
        'Call generateAvatar() to re-generate.');
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

  // ── Private helpers ─────────────────────────────────────────────────────────

  Future<String> _saveGlb(
    String userId,
    String dateKey,
    Uint8List bytes,
  ) async {
    final path = await _localGlbPath(userId, dateKey);
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

  Future<void> _persistSnapshot({
    required String userId,
    required String dateKey,
    required Map<String, dynamic> measurements,
    required String localGlbPath,
  }) async {
    // Check for an existing Firestore document on the same date
    final existing = await _firestore
        .collection('avatar_snapshots')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: dateKey)
        .limit(1)
        .get();

    final data = <String, dynamic>{
      'userId': userId,
      'date': dateKey,
      'measurements': measurements,
      'localGlbPath': localGlbPath,
      'updatedAt': Timestamp.now(),
    };

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update(data);
    } else {
      data['createdAt'] = Timestamp.now();
      await _firestore.collection('avatar_snapshots').add(data);
    }
  }
}

// ---------------------------------------------------------------------------
// AvatarSnapshot — lightweight Firestore-backed avatar record
// ---------------------------------------------------------------------------

class AvatarSnapshot {
  final String id;
  final String userId;
  final String date; // "YYYY-MM-DD"
  final Map<String, dynamic> measurements;
  final String? localGlbPath; // absolute path; null if cache cleared

  const AvatarSnapshot({
    required this.id,
    required this.userId,
    required this.date,
    required this.measurements,
    this.localGlbPath,
  });

  factory AvatarSnapshot.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AvatarSnapshot(
      id: doc.id,
      userId: d['userId'] as String,
      date: d['date'] as String,
      measurements: Map<String, dynamic>.from(d['measurements'] as Map? ?? {}),
      localGlbPath: d['localGlbPath'] as String?,
    );
  }

  double? get weight => (measurements['weight'] as num?)?.toDouble();
  double? get height => (measurements['height'] as num?)?.toDouble();
  double? get waist => (measurements['waist'] as num?)?.toDouble();
  double? get chest => (measurements['chest'] as num?)?.toDouble();
  double? get hips => (measurements['hips'] as num?)?.toDouble();
}

// ─── Error ────────────────────────────────────────────────────────────────────

class SmplBackendException implements Exception {
  final String message;
  const SmplBackendException(this.message);

  @override
  String toString() => 'SmplBackendException: $message';
}
