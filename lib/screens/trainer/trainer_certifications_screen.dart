import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:genzfit/providers/auth_provider.dart';
import 'package:genzfit/services/storage_service.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/widgets/custom_button.dart';

class TrainerCertificationsScreen extends StatefulWidget {
  const TrainerCertificationsScreen({super.key});

  @override
  State<TrainerCertificationsScreen> createState() =>
      _TrainerCertificationsScreenState();
}

class _TrainerCertificationsScreenState
    extends State<TrainerCertificationsScreen> {
  late TextEditingController _certificationNameController;
  late TextEditingController _issuedByController;

  List<Map<String, dynamic>> _certifications = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _selectedImagePath;

  @override
  void initState() {
    super.initState();
    _certificationNameController = TextEditingController();
    _issuedByController = TextEditingController();
    _loadCertifications();
  }

  @override
  void dispose() {
    _certificationNameController.dispose();
    _issuedByController.dispose();
    super.dispose();
  }

  Future<void> _loadCertifications() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final List<Map<String, dynamic>> loadedCertifications = [];

      final trainerSnapshot = await FirebaseFirestore.instance
          .collection('trainers')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (trainerSnapshot.docs.isNotEmpty) {
        final trainerData = trainerSnapshot.docs.first.data();
        final certifications =
            trainerData['certifications'] as List<dynamic>? ?? [];
        for (final item in certifications) {
          if (item is Map) {
            loadedCertifications.add(Map<String, dynamic>.from(item));
          } else if (item is String && item.isNotEmpty) {
            loadedCertifications.add({
              'name': 'Certificate',
              'issuedBy': 'Uploaded certificate',
              'imageUrl': item,
              'dateAdded': '',
            });
          }
        }
      }

      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final userCertifications =
          (userSnapshot.data()?['certifications'] as List<dynamic>? ?? []);
      for (final item in userCertifications) {
        if (item is String && item.isNotEmpty) {
          final exists =
              loadedCertifications.any((cert) => cert['imageUrl'] == item);
          if (!exists) {
            loadedCertifications.add({
              'name': 'Certificate',
              'issuedBy': 'Uploaded certificate',
              'imageUrl': item,
              'dateAdded': '',
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _certifications = loadedCertifications;
        });
      }
    } catch (e) {
      print('Error loading certifications: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() => _selectedImagePath = image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _addCertification() async {
    if (_certificationNameController.text.isEmpty ||
        _issuedByController.text.isEmpty ||
        _selectedImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select an image'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) throw Exception('User not authenticated');

      // Upload image
      final storageService = StorageService();
      final imageUrl = await storageService.uploadCertificate(
        File(_selectedImagePath!),
        userId,
      );

      final newCertification = {
        'name': _certificationNameController.text,
        'issuedBy': _issuedByController.text,
        'imageUrl': imageUrl,
        'dateAdded': DateTime.now().toIso8601String(),
      };

      setState(() {
        _certifications.add(newCertification);
        _certificationNameController.clear();
        _issuedByController.clear();
        _selectedImagePath = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certification added successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add certification: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveCertifications() async {
    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) throw Exception('User not authenticated');

      // Get trainer and update
      final trainerSnapshot = await FirebaseFirestore.instance
          .collection('trainers')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (trainerSnapshot.docs.isNotEmpty) {
        final trainerId = trainerSnapshot.docs.first.id;
        await FirebaseFirestore.instance
            .collection('trainers')
            .doc(trainerId)
            .set({'certifications': _certifications}, SetOptions(merge: true));
      }

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'certifications': _certifications
            .map((cert) => cert['imageUrl'])
            .whereType<String>()
            .toList(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certifications updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save certifications: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _removeCertification(int index) {
    setState(() => _certifications.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Certifications'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Certifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Showcase your professional credentials',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0B0B0)
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Add Certification Form
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1A1A1A)
                          : AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppSizes.borderRadius),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF333333)
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add New Certification',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFFFFFFF)
                                    : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _certificationNameController,
                          decoration: InputDecoration(
                            hintText: 'Certification name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.brandGreen,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _issuedByController,
                          decoration: InputDecoration(
                            hintText: 'Issued by (organization/institution)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.brandGreen,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.brandGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.brandGreen.withOpacity(0.3),
                                strokeAlign: BorderSide.strokeAlignCenter,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  color: AppColors.brandGreen,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedImagePath == null
                                      ? 'Tap to upload certificate image'
                                      : 'Image selected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.brandGreen,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _addCertification,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandGreen,
                            ),
                            child: Text(
                              _isSaving ? 'Adding...' : 'Add Certification',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Certifications List
                  if (_certifications.isNotEmpty) ...[
                    Text(
                      'Added Certifications (${_certifications.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _certifications.length,
                      itemBuilder: (context, index) {
                        final cert = _certifications[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF1A1A1A)
                                    : AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(AppSizes.borderRadius),
                            border: Border.all(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF333333)
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (cert['imageUrl'] != null)
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft:
                                        Radius.circular(AppSizes.borderRadius),
                                    topRight:
                                        Radius.circular(AppSizes.borderRadius),
                                  ),
                                  child: Image.network(
                                    cert['imageUrl'],
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                cert['name'],
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context)
                                                              .brightness ==
                                                          Brightness.dark
                                                      ? const Color(0xFFFFFFFF)
                                                      : AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Issued by: ${cert['issuedBy']}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context)
                                                              .brightness ==
                                                          Brightness.dark
                                                      ? const Color(0xFFB0B0B0)
                                                      : AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _removeCertification(index),
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          color: AppColors.error,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ] else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No certifications added yet',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFB0B0B0)
                                    : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),

                  if (_certifications.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        text: _isSaving ? 'Saving...' : 'Save Certifications',
                        isLoading: _isSaving,
                        onPressed: _saveCertifications,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
