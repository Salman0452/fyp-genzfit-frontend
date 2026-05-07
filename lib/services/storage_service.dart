import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class StorageService {
  static const String _cloudName = 'dvpdkmpp8';
  static const String _uploadPreset = 'genzfit_preset';

  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    _cloudName,
    _uploadPreset,
    cache: false,
  );
  final Uuid _uuid = const Uuid();

  // Upload image
  Future<String> uploadImage(File file, String folder) async {
    try {
      final fileName = '${_uuid.v4()}.jpg';

      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image,
          folder: folder,
          publicId: fileName,
        ),
      );

      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }

  // Upload image bytes (web-safe / file-picker friendly)
  Future<String> uploadImageBytes(
    Uint8List bytes,
    String folder,
    String publicId, {
    String fileName = 'receipt.jpg',
  }) async {
    try {
      print('[CloudinaryUpload] Starting upload...');
      print('[CloudinaryUpload] Bytes length: ${bytes.length}');
      print('[CloudinaryUpload] Folder: $folder');
      print('[CloudinaryUpload] Public ID: $publicId');
      print('[CloudinaryUpload] File name: $fileName');

      if (bytes.isEmpty) {
        throw Exception('Image bytes are empty');
      }

      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      print('[CloudinaryUpload] Upload URI: $uri');
      print('[CloudinaryUpload] Upload preset: $_uploadPreset');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = folder
        ..fields['public_id'] = publicId
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ));

      print('[CloudinaryUpload] Request created, sending...');

      final streamed =
          await request.send().timeout(const Duration(seconds: 120));
      print('[CloudinaryUpload] Response status code: ${streamed.statusCode}');

      final body = await http.Response.fromStream(streamed);
      print('[CloudinaryUpload] Response body length: ${body.body.length}');
      print(
          '[CloudinaryUpload] Response body (first 500 chars): ${body.body.substring(0, body.body.length > 500 ? 500 : body.body.length)}');

      if (streamed.statusCode == 200) {
        print('[CloudinaryUpload] Status 200, parsing response...');
        final responseData = jsonDecode(body.body);
        print('[CloudinaryUpload] Parsed response: $responseData');

        if (responseData is Map<String, dynamic>) {
          final url = responseData['secure_url'];
          print('[CloudinaryUpload] Extracted URL: $url');

          if (url != null && url is String && url.isNotEmpty) {
            print('[CloudinaryUpload] Upload successful! URL: $url');
            return url;
          }
          throw Exception('No secure_url in response: $responseData');
        }
        throw Exception('Invalid response format: ${body.body}');
      }

      print(
          '[CloudinaryUpload] Status code ${streamed.statusCode}, error response: ${body.body}');
      throw Exception(
          'Cloudinary image upload failed (${streamed.statusCode}): ${body.body}');
    } catch (e, stackTrace) {
      print('[CloudinaryUpload] Exception caught: $e');
      print('[CloudinaryUpload] Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Upload video
  Future<String> uploadVideo(File file, String folder) async {
    try {
      final fileName = '${_uuid.v4()}.mp4';

      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Video,
          folder: folder,
          publicId: fileName,
        ),
      );

      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload video: ${e.toString()}');
    }
  }

  // Upload profile picture
  Future<String> uploadProfilePicture(File file, String userId) async {
    return await uploadImage(file, 'profile_pictures/$userId');
  }

  // Upload body scan photo
  Future<String> uploadBodyScanPhoto(File file, String userId) async {
    return await uploadImage(file, 'body_scans/$userId');
  }

  // Upload certificate
  Future<String> uploadCertificate(File file, String trainerId) async {
    return await uploadImage(file, 'certificates/$trainerId');
  }

  // Upload trainer video
  Future<String> uploadTrainerVideo(File file, String trainerId) async {
    return await uploadVideo(file, 'trainer_videos/$trainerId');
  }

  // Upload chat image
  Future<String> uploadChatImage(File file, String chatId) async {
    return await uploadImage(file, 'chat_images/$chatId');
  }

  // Upload chat video
  Future<String> uploadChatVideo(File file, String chatId) async {
    return await uploadVideo(file, 'chat_videos/$chatId');
  }

  /// Upload raw GLB bytes directly to Cloudinary (resource_type=raw).
  /// [folder] e.g. 'avatars/uid123', [publicId] e.g. '2026-03-01'
  Future<String> uploadGlbBytes(
    Uint8List bytes,
    String folder,
    String publicId,
  ) async {
    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/raw/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = folder
      ..fields['public_id'] = publicId
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: '$publicId.glb',
      ));
    final streamed = await request.send().timeout(const Duration(seconds: 120));
    final body = await http.Response.fromStream(streamed);
    if (streamed.statusCode == 200) {
      final data = jsonDecode(body.body) as Map<String, dynamic>;
      return data['secure_url'] as String;
    }
    throw Exception(
        'Cloudinary GLB upload failed (${streamed.statusCode}): ${body.body}');
  }

  // Delete file by URL (Cloudinary requires API key/secret for deletion)
  // For now, we'll just skip deletion as it requires admin API
  Future<void> deleteFile(String downloadUrl) async {
    try {
      // Note: Cloudinary deletion requires API key and secret
      // This would need to be done from backend for security
      // For now, we'll just return success
      return;
    } catch (e) {
      throw Exception('Failed to delete file: ${e.toString()}');
    }
  }

  // Get download URL (already have it from upload)
  Future<String> getDownloadUrl(String path) async {
    return path; // Cloudinary returns direct URL
  }
}
