import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thin service that talks to the GenzFit backend (RPM edition).
/// The backend no longer generates GLBs — it just stores & returns RPM URLs.
class AvatarGenerationService {
  static const String _baseUrl = String.fromEnvironment(
    'AVATAR_API_URL',
    defaultValue: 'http://192.168.10.11:8000',
  );

  // ── Save an RPM avatar URL to the backend ──────────────────────────────
  Future<Map<String, dynamic>> saveRpmAvatar({
    required String userId,
    required String rpmModelUrl,
    String rpmThumbnailUrl = '',
    double? height,
    double? weight,
    String gender = 'male',
    Map<String, dynamic> measurements = const {},
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/v1/avatar/save');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id':           userId,
              'rpm_model_url':     rpmModelUrl,
              'rpm_thumbnail_url': rpmThumbnailUrl,
              'height':            height,
              'weight':            weight,
              'gender':            gender,
              'measurements':      measurements,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success':      true,
          'modelUrl':     data['model_url'] ?? rpmModelUrl,
          'thumbnailUrl': data['thumbnail_url'] ?? rpmThumbnailUrl,
        };
      }
      throw Exception('Save failed: ${response.statusCode}');
    } catch (e) {
      // Even if the backend is down, we still have the URL — return it.
      return {
        'success':      true,
        'modelUrl':     rpmModelUrl,
        'thumbnailUrl': rpmThumbnailUrl,
      };
    }
  }

  // ── Get the latest saved avatar URL ───────────────────────────────────
  Future<Map<String, dynamic>> getLatestAvatar(String userId) async {
    try {
      final url = Uri.parse('$_baseUrl/api/v1/avatar/latest/$userId');
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success':      data['success'] ?? false,
          'modelUrl':     data['model_url'] ?? '',
          'thumbnailUrl': data['thumbnail_url'] ?? '',
        };
      }
      return {'success': false, 'modelUrl': '', 'thumbnailUrl': ''};
    } catch (_) {
      return {'success': false, 'modelUrl': '', 'thumbnailUrl': ''};
    }
  }

  // ── Health check ───────────────────────────────────────────────────────
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
