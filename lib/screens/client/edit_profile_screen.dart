import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:genzfit/providers/auth_provider.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/widgets/custom_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:genzfit/services/storage_service.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final StorageService _storageService = StorageService();

  String? _selectedGoal;
  String _selectedSkinTone = 'medium';
  File? _selectedImage;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  final List<String> _goals = [
    'Lose Weight',
    'Build Muscle',
    'Get Fit',
    'Improve Health',
    'Increase Strength',
    'Improve Flexibility',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;

    _nameController.text = user?.name ?? '';
    _emailController.text = user?.email ?? '';

    // Set selected goal only if it exists in the list
    if (user?.goals != null && _goals.contains(user!.goals)) {
      _selectedGoal = user.goals;
    } else {
      _selectedGoal = _goals.first;
    }

    _selectedSkinTone = user?.skinTone ?? 'medium';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      String? avatarUrl;

      // Upload new avatar if selected
      if (_selectedImage != null) {
        setState(() => _isUploadingImage = true);
        avatarUrl =
            await _storageService.uploadProfilePicture(_selectedImage!, userId);
        setState(() => _isUploadingImage = false);
      }

      // Update Firestore
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'goals': _selectedGoal,
        'skinTone': _selectedSkinTone,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (avatarUrl != null) {
        updates['avatarUrl'] = avatarUrl;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(updates);

      // Refresh user data
      await authProvider.refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
        _isUploadingImage = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.accent,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : (user?.avatarUrl != null
                            ? NetworkImage(user!.avatarUrl!) as ImageProvider
                            : null),
                    child: _selectedImage == null && user?.avatarUrl == null
                        ? Text(
                            (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: AppColors.background,
                            ),
                          )
                        : null,
                  ),
                  if (_isUploadingImage)
                    const Positioned.fill(
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.black54,
                        child:
                            CircularProgressIndicator(color: AppColors.accent),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploadingImage ? null : _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.background, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: AppColors.background,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Name field
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.person, color: AppColors.accent),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email field (read-only)
              TextFormField(
                controller: _emailController,
                enabled: false,
                style: const TextStyle(color: AppColors.textSecondary),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon:
                      const Icon(Icons.email, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.charcoal,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: BorderSide.none,
                  ),
                  helperText: 'Email cannot be changed',
                  helperStyle: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Goal dropdown
              DropdownButtonFormField<String>(
                value: _selectedGoal,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Fitness Goal',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.flag, color: AppColors.accent),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _goals.map((goal) {
                  return DropdownMenuItem(
                    value: goal,
                    child: Text(goal),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedGoal = value);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a fitness goal';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Skin Tone selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      'Avatar Skin Tone',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  Row(
                    children: [
                      _SkinToneChip(
                        label: 'Light',
                        color: const Color(0xFFFFDCB9),
                        value: 'light',
                        selected: _selectedSkinTone == 'light',
                        onTap: () =>
                            setState(() => _selectedSkinTone = 'light'),
                      ),
                      const SizedBox(width: 10),
                      _SkinToneChip(
                        label: 'Medium',
                        color: const Color(0xFFD2A882),
                        value: 'medium',
                        selected: _selectedSkinTone == 'medium',
                        onTap: () =>
                            setState(() => _selectedSkinTone = 'medium'),
                      ),
                      const SizedBox(width: 10),
                      _SkinToneChip(
                        label: 'Brown',
                        color: const Color(0xFFB47850),
                        value: 'brown',
                        selected: _selectedSkinTone == 'brown',
                        onTap: () =>
                            setState(() => _selectedSkinTone = 'brown'),
                      ),
                      const SizedBox(width: 10),
                      _SkinToneChip(
                        label: 'Dark',
                        color: const Color(0xFF6E462D),
                        value: 'dark',
                        selected: _selectedSkinTone == 'dark',
                        onTap: () => setState(() => _selectedSkinTone = 'dark'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Update button
              CustomButton(
                text: 'Update Profile',
                onPressed: _updateProfile,
                isLoading: _isLoading,
                icon: Icons.check,
              ),
              const SizedBox(height: 16),

              // Cancel button
              CustomButton(
                text: 'Cancel',
                onPressed: () => Navigator.pop(context),
                isOutlined: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skin tone chip ────────────────────────────────────────────────────────────

class _SkinToneChip extends StatelessWidget {
  final String label;
  final Color color;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _SkinToneChip({
    required this.label,
    required this.color,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: selected
                ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                : [],
          ),
          child: Column(
            children: [
              if (selected)
                const Icon(Icons.check, color: Colors.white, size: 16),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
