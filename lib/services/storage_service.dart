import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
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
