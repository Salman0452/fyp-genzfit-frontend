import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/measurement_model.dart';
import 'smpl_avatar_service.dart';
import 'storage_service.dart';

/// Service that manages Ready Player Me avatars.
///
/// Flow:
///   1.  User creates a fullbody avatar in [AvatarCreatorScreen] (WebView iframe).
///   2.  The iframe posts the avatar URL back (e.g. https://models.readyplayer.me/abc123.glb).
///   3.  We save the avatarId to Firestore under the user's profile.
///   4.  On each body-scan measurement we call [generateSnapshot]:
///         • POST the base GLB + measurements to the Python backend.
///         • Backend applies body-shape morph weights (Overweight/Thin/Muscular).
///         • We cache the returned GLB locally under {date}.glb.
///   5.  AvatarViewerScreen loads per-date GLBs in the timeline.
class ReadyPlayerMeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Config
  // ---------------------------------------------------------------------------

  /// Your RPM partner subdomain – set RPM_SUBDOMAIN in .env.
  /// Register free at https://readyplayer.me/developers
  String get _subdomain =>
      dotenv.env['RPM_SUBDOMAIN'] ?? 'demo'; // 'demo' works for testing

  /// Python SMPL backend base URL (reused for body-morph endpoint).
  String get _backendUrl =>
      dotenv.env['SMPL_BACKEND_URL'] ?? 'http://10.0.2.2:8000';

  // ---------------------------------------------------------------------------
  // Avatar creator URL
  // ---------------------------------------------------------------------------

  /// Full-screen WebView URL for the RPM iframe creator.
  /// Opens the RPM avatar builder pre-configured for fullbody avatars.
  String get creatorIframeUrl => 'https://$_subdomain.readyplayer.me/avatar'
      '?frameApi'
      '&bodyType=fullbody'
      '&clearCache'
      '&quickStart=false';

  // ---------------------------------------------------------------------------
  // Firestore – base avatar URL
  // ---------------------------------------------------------------------------

  /// Persist the RPM avatar URL for a user (called once after creation).
  Future<void> saveBaseAvatarUrl(String userId, String avatarUrl) async {
    await _firestore.collection('users').doc(userId).set(
      {
        'rpmAvatarUrl': avatarUrl,
        'rpmAvatarUpdatedAt': Timestamp.now(),
      },
      SetOptions(merge: true),
    );
  }

  /// Retrieve the saved RPM avatar URL (null if user hasn't created one yet).
  Future<String?> getBaseAvatarUrl(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data()?['rpmAvatarUrl'] as String?;
  }

  // ---------------------------------------------------------------------------
  // Per-snapshot GLB generation
  // ---------------------------------------------------------------------------

  /// Generate (or return cached) a body-morphed GLB for [measurement].
  ///
  /// Steps:
  ///   1. Look for a cached local GLB for this date → return early if found.
  ///   2. Download the base RPM .glb bytes.
  ///   3. POST base GLB + measurements to Python backend /morph-avatar endpoint.
  ///   4. Cache returned GLB and persist snapshot metadata to Firestore.
  Future<String> generateSnapshot({
    required String userId,
    required String baseAvatarUrl,
    required MeasurementModel measurement,
  }) async {
    final dateKey = _dateKey(measurement.date);

    // Return cached Cloudinary URL if this date's snapshot already exists.
    final existing = await _firestore
        .collection('avatar_snapshots')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: dateKey)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      final url = existing.docs.first.data()['cloudinaryGlbUrl'] as String?;
      if (url != null && url.isNotEmpty) return url;
    }

    // 1. Download base RPM GLB.
    final glbUrl = _ensureGlbSuffix(baseAvatarUrl);
    final baseBytes = await _downloadBytes(glbUrl);

    // 2. Send to Python backend for body-shape morphing.
    final morphedBytes = await _morphGlb(
      baseGlbBytes: baseBytes,
      measurement: measurement,
    );

    // 3. Upload morphed GLB to Cloudinary.
    final cloudinaryUrl = await StorageService()
        .uploadGlbBytes(morphedBytes, 'avatars/$userId', dateKey);

    // 4. Persist metadata snapshot with Cloudinary URL.
    await _persistSnapshot(
      userId: userId,
      date: dateKey,
      avatarUrl: baseAvatarUrl,
      cloudinaryGlbUrl: cloudinaryUrl,
      measurement: measurement,
    );

    return cloudinaryUrl;
  }

  /// Build a quality-param GLB URL for direct use in model_viewer_plus
  /// (fallback when no morphed GLB exists yet — shows base avatar immediately).
  String buildDirectGlbUrl(String baseAvatarUrl, {String quality = 'medium'}) {
    final base = _ensureGlbSuffix(baseAvatarUrl);
    final lod = quality == 'high' ? '0' : '1';
    final uri = Uri.parse(base);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'morphTargets': 'ARKit,Oculus Visemes',
      'lod': lod,
      'useHands': 'false',
      'textureAtlas': '1024',
    }).toString();
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  Future<List<AvatarSnapshot>> getAvatarHistory(String userId) async {
    final snap = await _firestore
        .collection('avatar_snapshots')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: false)
        .get();
    return snap.docs.map(AvatarSnapshot.fromFirestore).toList();
  }

  /// Returns the Cloudinary URL for a snapshot, or the base RPM URL as fallback.
  Future<String> getGlbUrl({
    required String userId,
    required String snapDate,
    required String baseAvatarUrl,
  }) async {
    final snap = await _firestore
        .collection('avatar_snapshots')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: snapDate)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final url = snap.docs.first.data()['cloudinaryGlbUrl'] as String?;
      if (url != null && url.isNotEmpty) return url;
    }
    // Fallback: serve base RPM avatar directly.
    return buildDirectGlbUrl(baseAvatarUrl);
  }

  // ---------------------------------------------------------------------------
  // Backend morph call
  // ---------------------------------------------------------------------------

  Future<Uint8List> _morphGlb({
    required Uint8List baseGlbBytes,
    required MeasurementModel measurement,
  }) async {
    final uri = Uri.parse('$_backendUrl/morph-avatar');
    try {
      final request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes(
          'glb',
          baseGlbBytes,
          filename: 'avatar.glb',
        ))
        ..fields['height'] = (measurement.height ?? 170).toString()
        ..fields['weight'] = (measurement.weight ?? 70).toString()
        ..fields['age'] = (measurement.age ?? 25).toString()
        ..fields['gender'] = measurement.gender ?? 'male';

      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      if (streamed.statusCode == 200) {
        return Uint8List.fromList(await streamed.stream.toBytes());
      }
    } catch (_) {
      // Backend not available — return base GLB unchanged.
    }
    return baseGlbBytes;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<Uint8List> _downloadBytes(String url) async {
    final resp =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception('Failed to download GLB from $url (${resp.statusCode})');
    }
    return resp.bodyBytes;
  }

  Future<void> _persistSnapshot({
    required String userId,
    required String date,
    required String avatarUrl,
    required String cloudinaryGlbUrl,
    required MeasurementModel measurement,
  }) async {
    final existing = await _firestore
        .collection('avatar_snapshots')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: date)
        .limit(1)
        .get();

    final data = <String, dynamic>{
      'userId': userId,
      'date': date,
      'betas': <double>[],
      'measurements': {
        'height': measurement.height,
        'weight': measurement.weight,
        'chest': measurement.estimatedMeasurements['chest'],
        'waist': measurement.estimatedMeasurements['waist'],
        'hips': measurement.estimatedMeasurements['hips'],
        'shoulderWidth': measurement.estimatedMeasurements['shoulderWidth'],
      },
      'cloudinaryGlbUrl': cloudinaryGlbUrl,
      'rpmAvatarUrl': avatarUrl,
      'updatedAt': Timestamp.now(),
    };

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update(data);
    } else {
      data['createdAt'] = Timestamp.now();
      await _firestore.collection('avatar_snapshots').add(data);
    }
  }

  String _ensureGlbSuffix(String url) {
    final stripped = url.split('?').first;
    return stripped.endsWith('.glb') ? stripped : '$stripped.glb';
  }

  String _dateKey(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
