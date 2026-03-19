import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../utils/helpers.dart';
import '../../utils/design_utils.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      final user = authProvider.currentUser;
      if (user == null) return;

      // Navigate based on role - clear all previous routes
      if (user.role == UserRole.client) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/client-home',
          (route) => false,
        );
      } else if (user.role == UserRole.trainer) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/trainer-home',
          (route) => false,
        );
      } else if (user.role == UserRole.admin) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/admin-dashboard',
          (route) => false,
        );
      }
    } else {
      Helpers.showSnackBar(
        context,
        authProvider.error ?? 'Login failed',
        isError: true,
      );
    }
  }

  Future<void> _handleForgotPassword() async {
    Navigator.pushNamed(context, '/forgot-password');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                // App Branding
                Text(
                  'GenZFit',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.brandGreen,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 32),
                // Heading
                Text(
                  'Welcome Back',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                // Subheading
                Text(
                  'Sign in to continue your fitness journey',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 32),
                // Email Field
                CustomTextField(
                  label: 'Email',
                  hint: 'Enter your email',
                  controller: _emailController,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 16),
                // Password Field
                CustomTextField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _passwordController,
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  validator: Validators.validatePassword,
                ),
                const SizedBox(height: 12),
                // Forgot Password Link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _handleForgotPassword,
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.brandGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Sign In Button
                CustomButton(
                  text: 'Sign In',
                  onPressed: _handleLogin,
                  isLoading: authProvider.isLoading,
                ),
                const SizedBox(height: 32),
                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    GestureDetector(
                      onTap:
                          () => Navigator.pushReplacementNamed(
                            context,
                            '/role-selection',
                          ),
                      child: Text(
                        'Sign Up',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.brandGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
