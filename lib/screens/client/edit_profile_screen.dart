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
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
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
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
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
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.accent
                              : AppColors.brandGreenDeep,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 2,
                          ),
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
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB0B0B0)
                        : AppColors.textSecondary,
                  ),
                  prefixIcon: Icon(
                    Icons.person,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.accent
                        : AppColors.brandGreenDeep,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.accent
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
                ),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF808080)
                        : AppColors.textSecondary,
                  ),
                  prefixIcon: Icon(
                    Icons.email,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF808080)
                        : AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFF0F0F0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  helperText: 'Email cannot be changed',
                  helperStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF808080)
                        : AppColors.textSecondary,
                    fontSize: 12,
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
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFF5F5F5),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Fitness Goal',
                  labelStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB0B0B0)
                        : AppColors.textSecondary,
                  ),
                  prefixIcon: Icon(
                    Icons.flag,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.accent
                        : AppColors.brandGreenDeep,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF404040)
                          : const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.accent
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
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      'Avatar Skin Tone',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFB0B0B0)
                            : AppColors.textSecondary,
                        fontSize: 13,
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
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.white : color.withOpacity(0.3),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(selected ? 0.6 : 0.2),
                blurRadius: selected ? 12 : 4,
                spreadRadius: selected ? 1 : 0,
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
                  fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                  shadows: const [Shadow(color: Colors.black38, blurRadius: 3)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
