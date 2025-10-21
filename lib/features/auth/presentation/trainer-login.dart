import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class TrainerLoginScreen extends StatefulWidget {
  const TrainerLoginScreen({super.key});

  @override
  State<TrainerLoginScreen> createState() => _TrainerLoginScreenState();
}

class _TrainerLoginScreenState extends State<TrainerLoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {String type = 'error'}) {
    Color bgColor;

    switch (type) {
      case 'success':
        bgColor = Colors.greenAccent.shade700;
        break;
      case 'warning':
        bgColor = Colors.orangeAccent.shade700;
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

  void _login() {
    if (_formKey.currentState!.validate()) {
      // Proceed with login logic
      _showSnackBar("Login Successful (placeholder)", type: 'success');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "Trainer Login",
                        style: AppTextStyles.heading.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 40),
                      _buildTextField(
                        controller: emailController,
                        hint: "Enter your email",
                        icon: Icons.email_outlined,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Email is required";
                          } else if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$')
                              .hasMatch(value)) {
                            return "Enter a valid email";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: passwordController,
                        hint: "Enter your password",
                        icon: Icons.lock_outline,
                        isPassword: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Password is required";
                          } else if (value.length < 6) {
                            return "Password must be at least 6 characters";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cta,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                          shadowColor: Colors.black26,
                        ),
                        onPressed: _login,
                        child: const Text(
                          "Login",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/trainerSignup');
                        },
                        child: const Text(
                          "Don’t have an account? Sign up",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    bool isPassword = false,
  }) {
    return Focus(
      onFocusChange: (_) => setState(() {}),
      child: Builder(builder: (context) {
        final isFocused = Focus.of(context).hasFocus;
        return TextFormField(
          controller: controller,
          obscureText: isPassword && !_isPasswordVisible,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54),
            prefixIcon: Icon(
              icon,
              color: isFocused ? Colors.white : Colors.white70,
            ),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.white70,
              ),
              onPressed: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
            )
                : null,
            filled: true,
            fillColor: Colors.white.withOpacity(isFocused ? 0.18 : 0.1),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white, width: 1.5),
            ),
          ),
        );
      }),
    );
  }
}
