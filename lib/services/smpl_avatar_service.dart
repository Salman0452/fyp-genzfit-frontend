import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/measurement_model.dart';

// ---------------------------------------------------------------------------
// SmplAvatarService
// ---------------------------------------------------------------------------
// Calls the FastAPI SMPL-X backend (/generate-avatar), which:
//   1. Generates the SMPL-X mesh
//   2. Uploads the .glb to Cloudinary
//   3. Returns a JSON response containing the Cloudinary URL (glb_url)
//
// The Cloudinary URL is persisted to Firestore (avatar_snapshots).
// No local file storage — the GLB lives permanently in Cloudinary.
// ---------------------------------------------------------------------------
class SmplAvatarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Backend base URL. Override in .env via SMPL_BACKEND_URL.
  String get _baseUrl =>
      dotenv.env['SMPL_BACKEND_URL'] ?? 'http://10.0.2.2:8000';

  // ── Public API ─────────────────────────────────────────────────────────

  /// Generate a SMPL-X avatar from [measurement].
  ///
  /// [skinTone] must be one of: light | medium | brown | dark.
  /// Defaults to "medium" if not provided.
  /// [poseStyle] selects a bodybuilding-style pose preset.
  Future<String?> generateAvatar({
    required String userId,
    required MeasurementModel measurement,
    String skinTone = 'medium',
    String poseStyle = 'classic_relaxed',
  }) async {
    final payload = <String, dynamic>{
      'user_id': userId,
      'gender': measurement.gender ?? 'neutral',
      'height': measurement.height,
      'weight': measurement.weight,
      'skin_tone': skinTone,
      'pose_style': poseStyle,
    };

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
          .timeout(const Duration(seconds: 180));
    } on SocketException catch (e) {
      throw SmplBackendException(
        'Cannot reach SMPL-X backend at $_baseUrl.\n'
        'Start the server: uvicorn main:app --reload --host 0.0.0.0 --port 8000\n'
        'Error: $e',
      );
    }

    if (response.statusCode != 200) {
      throw SmplBackendException(
          'Backend returned \${response.statusCode}: \${response.body}');
    }

    final Map<String, dynamic> jsonBody;
    try {
      jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw SmplBackendException('Backend returned invalid JSON: $e');
    }

    final glbUrl = jsonBody['glb_url'] as String?;

    // Persist snapshot metadata + Cloudinary URL to Firestore
    final dateKey = _dateKey(measurement.date);
    await _persistSnapshot(
      userId: userId,
      dateKey: dateKey,
      measurements: {
        'height': measurement.height,
        'weight': measurement.weight,
        ...measurement.estimatedMeasurements,
      },
      glbUrl: glbUrl,
      skinTone: skinTone,
      poseStyle: poseStyle,
    );

    return glbUrl;
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

  /// Returns the Cloudinary URL for the avatar snapshot on [snapDate].
  ///
  /// Reads from Firestore. Throws [SmplBackendException] if the snapshot
  /// does not exist or was saved without a Cloudinary URL.
  Future<String> getGlbUrl({
    required String userId,
    required String snapDate,
  }) async {
    final result = await _firestore
        .collection('avatar_snapshots')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: snapDate)
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      throw SmplBackendException('No snapshot found for $snapDate.');
    }

    final url = result.docs.first.data()['glbUrl'] as String?;
    if (url == null || url.isEmpty) {
      throw SmplBackendException(
          'No Cloudinary URL for $snapDate. Re-generate the avatar.');
    }
    return url;
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

  // ── Private helpers ──────────────────────────────────────────────────────

  String _dateKey(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  Future<void> _persistSnapshot({
    required String userId,
    required String dateKey,
    required Map<String, dynamic> measurements,
    String? glbUrl,
    String skinTone = 'medium',
    String poseStyle = 'classic_relaxed',
  }) async {
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
      'glbUrl': glbUrl, // Cloudinary public URL
      'skinTone': skinTone,
      'poseStyle': poseStyle,
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

  /// Cloudinary https:// URL for the .glb file. Null if upload failed.
  final String? glbUrl;

  /// Pose preset used when the avatar was generated.
  final String poseStyle;

  const AvatarSnapshot({
    required this.id,
    required this.userId,
    required this.date,
    required this.measurements,
    this.glbUrl,
    this.poseStyle = 'classic_relaxed',
  });

  factory AvatarSnapshot.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AvatarSnapshot(
      id: doc.id,
      userId: d['userId'] as String,
      date: d['date'] as String,
      measurements: Map<String, dynamic>.from(d['measurements'] as Map? ?? {}),
      glbUrl: d['glbUrl'] as String?,
      poseStyle: d['poseStyle'] as String? ?? 'classic_relaxed',
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
