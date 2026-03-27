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
        avatarUrl = await _storageService.uploadProfilePicture(
          _selectedImage!,
          userId,
        );
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Profile',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Update your personal information',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFF9F9F9F)
                    : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.brandGreen
                                : AppColors.brandGreenDeep)
                            .withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withOpacity(0.2)
                              : Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 64,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFF5F5F5),
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
                                color: AppColors.accent,
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (_isUploadingImage)
                    Positioned.fill(
                      child: CircleAvatar(
                        radius: 64,
                        backgroundColor: Colors.black.withOpacity(0.3),
                        child: const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.accent),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploadingImage ? null : _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
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
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB0B0B0)
                        : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.person,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF262626)
                      : const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : const Color(0xFFE8E8E8),
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : const Color(0xFFE8E8E8),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep,
                      width: 2,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF808080)
                      : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF808080)
                        : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.email,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF808080)
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFF0F0F0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : const Color(0xFFE8E8E8),
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : const Color(0xFFE8E8E8),
                      width: 1.5,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : const Color(0xFFE8E8E8),
                      width: 1.5,
                    ),
                  ),
                  helperText: 'Email cannot be changed',
                  helperStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF808080)
                        : AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),

              // Goal dropdown
              DropdownButtonFormField<String>(
                value: _selectedGoal,
                dropdownColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF262626)
                    : const Color(0xFFF8F8F8),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: 'Fitness Goal',
                  labelStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB0B0B0)
                        : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.flag,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF262626)
                      : const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : const Color(0xFFE8E8E8),
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : const Color(0xFFE8E8E8),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep,
                      width: 2,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'Avatar Skin Tone',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFB0B0B0)
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
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
              const SizedBox(height: 40),

              // Update button
              CustomButton(
                text: 'Update Profile',
                onPressed: _updateProfile,
                isLoading: _isLoading,
                icon: Icons.check,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandGreen
                    : AppColors.brandGreenDeep,
              ),
              const SizedBox(height: 12),

              // Cancel button
              CustomButton(
                text: 'Cancel',
                onPressed: () => Navigator.pop(context),
                isOutlined: true,
                textColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandGreen
                    : AppColors.brandGreenDeep,
              ),
              const SizedBox(height: 20),
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
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            border: Border.all(
              color: selected
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFFFFFFFF))
                  : color.withOpacity(0.2),
              width: selected ? 2.5 : 1.5,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            children: [
              if (selected)
                const Icon(Icons.check, color: Colors.white, size: 18),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
