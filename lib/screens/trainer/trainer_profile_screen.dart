import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:genzfit/providers/auth_provider.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/widgets/custom_button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:genzfit/services/storage_service.dart';
import 'package:genzfit/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TrainerProfileScreen extends StatefulWidget {
  const TrainerProfileScreen({super.key});

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;
  bool _isUploadingVideo = false;

  Future<void> _uploadProfilePicture() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Upload to Firebase Storage
      final imageUrl = await _storageService.uploadImage(
        File(image.path),
        'profile_pictures/$userId.jpg',
      );

      // Update user profile
      await _firestoreService.updateUser(userId, {'avatarUrl': imageUrl});

      // Update local state
      await authProvider.refreshUser();

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _uploadCertificate() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Upload to Firebase Storage
      final certificateUrl = await _storageService.uploadImage(
        File(image.path),
        'certificates/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Get trainer document
      final trainerSnapshot = await FirebaseFirestore.instance
          .collection('trainers')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (trainerSnapshot.docs.isNotEmpty) {
        final trainerId = trainerSnapshot.docs.first.id;
        final currentData = trainerSnapshot.docs.first.data();
        final certifications = List<String>.from(
          currentData['certifications'] ?? [],
        );
        certifications.add(certificateUrl);

        // Update trainer profile
        await FirebaseFirestore.instance
            .collection('trainers')
            .doc(trainerId)
            .update({
          'certifications': certifications,
        });
      }

      // Update local state
      await authProvider.refreshUser();

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificate uploaded! Pending admin verification.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload certificate: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _uploadVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video == null) return;

      setState(() => _isUploadingVideo = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Upload to Cloudinary
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
      final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];

      if (cloudName == null || uploadPreset == null) {
        throw Exception('Cloudinary configuration missing');
      }

      final cloudinary = CloudinaryPublic(cloudName, uploadPreset, cache: false);

      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          video.path,
          resourceType: CloudinaryResourceType.Video,
          folder: 'trainer_videos/$userId',
        ),
      );

      final videoUrl = response.secureUrl;

      // Get trainer document
      final trainerSnapshot = await FirebaseFirestore.instance
          .collection('trainers')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (trainerSnapshot.docs.isNotEmpty) {
        final trainerId = trainerSnapshot.docs.first.id;
        final currentData = trainerSnapshot.docs.first.data();
        final videoUrls = List<String>.from(
          currentData['videoUrls'] ?? [],
        );
        videoUrls.add(videoUrl);

        // Update trainer profile
        await FirebaseFirestore.instance
            .collection('trainers')
            .doc(trainerId)
            .update({
          'videoUrls': videoUrls,
        });
      }

      // Update local state
      await authProvider.refreshUser();

      if (mounted) {
        setState(() => _isUploadingVideo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video uploaded successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingVideo = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload video: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<DocumentSnapshot?> _getTrainerData(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('trainers')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;
    final userId = authProvider.user?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot?>(
        future: _getTrainerData(userId),
        builder: (context, trainerSnapshot) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile header
                _buildProfileHeader(user),
                const SizedBox(height: 24),

                // Verification status
                _buildVerificationStatus(user, trainerSnapshot.data),
                const SizedBox(height: 24),

                // Stats
                _buildStatsCard(user, trainerSnapshot.data),
                const SizedBox(height: 24),

                // Expertise
                _buildExpertiseSection(user, trainerSnapshot.data),
                const SizedBox(height: 24),

                // Certifications
                _buildCertificationsSection(user, trainerSnapshot.data),
                const SizedBox(height: 24),

                // Videos section
                _buildVideosSection(user, trainerSnapshot.data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Avatar with edit button
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.accent,
                backgroundImage: user?.avatarUrl != null
                    ? CachedNetworkImageProvider(user!.avatarUrl!)
                    : null,
                child: user?.avatarUrl == null
                    ? Text(
                        user?.name?.substring(0, 1).toUpperCase() ?? 'T',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.background,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isLoading ? null : _uploadProfilePicture,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surface,
                        width: 2,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.background,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: AppColors.background,
                            size: 16,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            user?.name ?? 'Trainer',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Email
          Text(
            user?.email ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Hourly rate
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.attach_money,
                  color: AppColors.accent,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${user?.hourlyRate ?? 0}/hour',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Edit profile button
          CustomButton(
            text: 'Edit Profile',
            onPressed: () {
              // TODO: Navigate to edit profile
            },
            isOutlined: true,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStatus(user, DocumentSnapshot? trainerDoc) {
    final trainerData = trainerDoc?.data() as Map<String, dynamic>?;
    final isVerified = trainerData?['verified'] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isVerified
            ? AppColors.success.withOpacity(0.1)
            : AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: isVerified
              ? AppColors.success.withOpacity(0.3)
              : AppColors.warning.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.pending,
            color: isVerified ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVerified ? 'Verified Trainer' : 'Verification Pending',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isVerified ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isVerified
                      ? 'Your profile has been verified by admin'
                      : 'Upload certificates to get verified',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(user, DocumentSnapshot? trainerDoc) {
    final trainerData = trainerDoc?.data() as Map<String, dynamic>?;
    final rating = (trainerData?['rating'] ?? 0.0).toDouble();
    final clients = trainerData?['clients'] ?? 0;
    final totalEarnings = (trainerData?['totalEarnings'] ?? 0.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Rating',
              rating.toStringAsFixed(1),
              Icons.star,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.charcoal,
          ),
          Expanded(
            child: _buildStatItem(
              'Clients',
              '$clients',
              Icons.people,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.charcoal,
          ),
          Expanded(
            child: _buildStatItem(
              'Earnings',
              '\$${totalEarnings.toStringAsFixed(0)}',
              Icons.monetization_on,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accent, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildExpertiseSection(user, DocumentSnapshot? trainerDoc) {
    final trainerData = trainerDoc?.data() as Map<String, dynamic>?;
    final expertise = List<String>.from(trainerData?['expertise'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Expertise',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        expertise.isEmpty
            ? const Text(
                'No expertise added',
                style: TextStyle(color: AppColors.textSecondary),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: expertise.map((exp) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.accent.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      exp,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildCertificationsSection(user, DocumentSnapshot? trainerDoc) {
    final trainerData = trainerDoc?.data() as Map<String, dynamic>?;
    final certifications = List<String>.from(trainerData?['certifications'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Certifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: _isLoading ? null : _uploadCertificate,
              icon: const Icon(Icons.add, color: AppColors.accent),
              label: const Text(
                'Add',
                style: TextStyle(color: AppColors.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        certifications.isEmpty
            ? Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No certifications yet',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: certifications.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    child: CachedNetworkImage(
                      imageUrl: certifications[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.charcoal,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.charcoal,
                        child: const Icon(
                          Icons.error,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildVideosSection(user, DocumentSnapshot? trainerDoc) {
    final trainerData = trainerDoc?.data() as Map<String, dynamic>?;
    final videoUrls = List<String>.from(trainerData?['videoUrls'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Training Videos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: _isUploadingVideo ? null : _uploadVideo,
              icon: _isUploadingVideo
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : const Icon(Icons.add, color: AppColors.accent),
              label: Text(
                _isUploadingVideo ? 'Uploading...' : 'Add',
                style: const TextStyle(color: AppColors.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        videoUrls.isEmpty
            ? Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.video_library,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No videos yet',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Upload training videos to showcase your expertise',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 16 / 9,
                ),
                itemCount: videoUrls.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          color: AppColors.charcoal,
                          child: CachedNetworkImage(
                            imageUrl: videoUrls[index],
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => const Icon(
                              Icons.video_library,
                              color: AppColors.textSecondary,
                              size: 40,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.5),
                              ],
                            ),
                          ),
                        ),
                        const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }
}
