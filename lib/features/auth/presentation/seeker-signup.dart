import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../services/auth_service.dart';

class SeekerSignupScreen extends StatefulWidget {
  const SeekerSignupScreen({super.key});

  @override
  State<SeekerSignupScreen> createState() => _SeekerSignupScreenState();
}

class _SeekerSignupScreenState extends State<SeekerSignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final ageController = TextEditingController();
  final weightController = TextEditingController();
  final heightController = TextEditingController();
  
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

  bool _isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    ageController.dispose();
    weightController.dispose();
    heightController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {String type = 'error'}) {
    Color bgColor;

    switch (type) {
      case 'success':
        bgColor = Colors.greenAccent.shade700;
        break;
      default:
        bgColor = Colors.redAccent.shade700;
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

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  Future<void> _signup() async {
    FocusScope.of(context).unfocus(); // close keyboard

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;
    final age = ageController.text.trim();
    final weight = weightController.text.trim();
    final height = heightController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty ||
        age.isEmpty || weight.isEmpty || height.isEmpty) {
      _showSnackBar("All fields are required.");
      return;
    }

    if (!_isValidEmail(email)) {
      _showSnackBar("Please enter a valid email address.");
      return;
    }

    if (password.length < 6) {
      _showSnackBar("Password must be at least 6 characters.");
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar("Passwords do not match.");
      return;
    }

    // Validate numeric fields
    final ageNum = int.tryParse(age);
    final weightNum = double.tryParse(weight);
    final heightNum = double.tryParse(height);

    if (ageNum == null || ageNum < 13 || ageNum > 120) {
      _showSnackBar("Please enter a valid age (13-120).");
      return;
    }

    if (weightNum == null || weightNum < 30 || weightNum > 300) {
      _showSnackBar("Please enter a valid weight (30-300 kg).");
      return;
    }

    if (heightNum == null || heightNum < 100 || heightNum > 250) {
      _showSnackBar("Please enter a valid height (100-250 cm).");
      return;
    }

    setState(() => _isLoading = true);

    // Call AuthService to signup seeker
    final authService = AuthService();
    final error = await authService.signUpSeeker(
      name: name,
      email: email,
      password: password,
      age: ageNum,
      weight: weightNum,
      height: heightNum,
      gender: selectedGender,
      fitnessGoal: selectedGoal,
    );

    setState(() => _isLoading = false);

    if (error != null) {
      _showSnackBar(error);
    } else {
      _showSnackBar("Signup Successful! Please login.", type: 'success');

      // After success, navigate to login
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("Create Your Profile",
                    style: AppTextStyles.heading.copyWith(color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  "Let's get to know you better",
                  style: AppTextStyles.body.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 32),
                
                // Basic Info
                _buildTextField(nameController, "Full Name", Icons.person),
                const SizedBox(height: 16),
                _buildTextField(emailController, "Email", Icons.email),
                const SizedBox(height: 16),
                _buildTextField(passwordController, "Password", Icons.lock,
                    isPassword: true),
                const SizedBox(height: 16),
                _buildTextField(confirmPasswordController, "Confirm Password",
                    Icons.lock_outline, isPassword: true),
                
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Physical Details",
                    style: AppTextStyles.subheading.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Physical details in a row
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        ageController, "Age", Icons.cake,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        weightController, "Weight (kg)", Icons.monitor_weight,
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
                        heightController, "Height (cm)", Icons.height,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        "Gender",
                        selectedGender,
                        genderOptions,
                        Icons.person_outline,
                        (value) => setState(() => selectedGender = value!),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Fitness Goal",
                    style: AppTextStyles.subheading.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                _buildDropdown(
                  "Select Your Goal",
                  selectedGoal,
                  goalOptions,
                  Icons.flag,
                  (value) => setState(() => selectedGoal = value!),
                ),
                
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cta,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _signup,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Create Account",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Already have an account? Login",
                      style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String hint,
    String value,
    List<String> items,
    IconData icon,
    void Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          dropdownColor: AppColors.cardBackground,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Icon(icon, color: Colors.white70, size: 20),
                  const SizedBox(width: 12),
                  Text(item),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
