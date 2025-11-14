import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/services/auth_service.dart';

class SeekerSettingsScreen extends StatefulWidget {
  const SeekerSettingsScreen({super.key});

  @override
  State<SeekerSettingsScreen> createState() => _SeekerSettingsScreenState();
}

class _SeekerSettingsScreenState extends State<SeekerSettingsScreen> {
  final AuthService _authService = AuthService();
  
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final ageController = TextEditingController();
  final weightController = TextEditingController();
  final heightController = TextEditingController();
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  
  String selectedGender = 'Male';
  String selectedGoal = 'Weight Loss';
  
  final List<String> genderOptions = ['Male', 'Female', 'Other'];
  final List<String> goalOptions = [
    'Weight Loss',
    'Muscle Gain',
    'Get Fit',
    'Endurance',
    'Flexibility',
  ];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    ageController.dispose();
    weightController.dispose();
    heightController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    
    final data = await _authService.getSeekerData();
    
    if (data != null) {
      setState(() {
        nameController.text = data['name'] ?? '';
        emailController.text = data['email'] ?? '';
        ageController.text = (data['age'] ?? '').toString();
        weightController.text = (data['weight'] ?? '').toString();
        heightController.text = (data['height'] ?? '').toString();
        selectedGender = data['gender'] ?? 'Male';
        selectedGoal = data['fitnessGoal'] ?? 'Weight Loss';
      });
    }
    
    setState(() => _isLoading = false);
  }

  void _showSnackBar(String message, {String type = 'error'}) {
    Color bgColor;
    switch (type) {
      case 'success':
        bgColor = AppColors.success;
        break;
      default:
        bgColor = AppColors.error;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();

    final name = nameController.text.trim();
    final age = int.tryParse(ageController.text.trim());
    final weight = double.tryParse(weightController.text.trim());
    final height = double.tryParse(heightController.text.trim());

    if (name.isEmpty || age == null || weight == null || height == null) {
      _showSnackBar("Please fill all fields correctly.");
      return;
    }

    if (age < 13 || age > 120) {
      _showSnackBar("Please enter a valid age (13-120).");
      return;
    }

    if (weight < 30 || weight > 300) {
      _showSnackBar("Please enter a valid weight (30-300 kg).");
      return;
    }

    if (height < 100 || height > 250) {
      _showSnackBar("Please enter a valid height (100-250 cm).");
      return;
    }

    setState(() => _isSaving = true);

    final error = await _authService.updateSeekerProfile(
      name: name,
      age: age,
      weight: weight,
      height: height,
      gender: selectedGender,
      fitnessGoal: selectedGoal,
    );

    setState(() => _isSaving = false);

    if (error != null) {
      _showSnackBar(error);
    } else {
      _showSnackBar("Profile updated successfully!", type: 'success');
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = currentPasswordController.text;
    final newPassword = newPasswordController.text;

    if (currentPassword.isEmpty || newPassword.isEmpty) {
      _showSnackBar("Please enter both passwords.");
      return;
    }

    if (newPassword.length < 6) {
      _showSnackBar("New password must be at least 6 characters.");
      return;
    }

    final error = await _authService.updatePassword(newPassword);

    if (error != null) {
      _showSnackBar(error);
    } else {
      _showSnackBar("Password updated successfully!", type: 'success');
      currentPasswordController.clear();
      newPasswordController.clear();
      Navigator.pop(context);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    Navigator.pushNamedAndRemoveUntil(context, '/role-selection', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        backgroundColor: AppColors.primary,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile header
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.accent,
                          child: Text(
                            nameController.text.isNotEmpty
                                ? nameController.text[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          nameController.text,
                          style: AppTextStyles.heading.copyWith(fontSize: 22),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          emailController.text,
                          style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Personal Information
                  _buildSectionTitle('Personal Information'),
                  const SizedBox(height: 16),
                  _buildTextField(nameController, "Full Name", Icons.person),
                  const SizedBox(height: 16),
                  _buildTextField(emailController, "Email", Icons.email, enabled: false),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle('Physical Details'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          ageController,
                          "Age",
                          Icons.cake,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          weightController,
                          "Weight (kg)",
                          Icons.monitor_weight,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          heightController,
                          "Height (cm)",
                          Icons.height,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          "Gender",
                          selectedGender,
                          genderOptions,
                          (value) => setState(() => selectedGender = value!),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle('Fitness Goal'),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    "Your Goal",
                    selectedGoal,
                    goalOptions,
                    (value) => setState(() => selectedGoal = value!),
                  ),

                  const SizedBox(height: 32),
                  _buildSectionTitle('Security'),
                  const SizedBox(height: 16),
                  ListTile(
                    tileColor: AppColors.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(Icons.lock, color: AppColors.accent),
                    title: const Text('Change Password', style: TextStyle(color: AppColors.text)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: _showChangePasswordDialog,
                  ),

                  const SizedBox(height: 32),
                  _buildSectionTitle('Actions'),
                  const SizedBox(height: 16),
                  ListTile(
                    tileColor: AppColors.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(Icons.logout, color: AppColors.error),
                    title: const Text('Logout', style: TextStyle(color: AppColors.error)),
                    onTap: _logout,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.subheading.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      style: TextStyle(
        color: enabled ? AppColors.text : AppColors.textMuted,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        labelText: hint,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.cardBackground,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.mediumGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.darkGray),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String hint,
    String value,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mediumGray),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          dropdownColor: AppColors.cardBackground,
          style: const TextStyle(color: AppColors.text, fontSize: 16),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Password', style: TextStyle(color: AppColors.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                labelText: 'Current Password',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _changePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cta,
            ),
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
