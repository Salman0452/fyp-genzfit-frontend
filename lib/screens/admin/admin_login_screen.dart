import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genzfit/models/user_model.dart';
import 'package:genzfit/screens/admin/admin_dashboard_screen.dart';
import 'package:genzfit/screens/admin/quick_admin_setup_screen.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  // Temporary migration helper: delete this entry point after admin bootstrap.
  static const bool _enableQuickAdminSetup = true;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Sign in with Firebase Auth
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Check if user has admin role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User not found in database');
      }

      final userData = userDoc.data()!;
      final role = userData['role'] as String?;
      const allowedAdminRoles = {
        'admin',
        'super_admin',
        'finance_admin',
        'moderator',
        'support',
      };

      if (role == null || !allowedAdminRoles.contains(role)) {
        await FirebaseAuth.instance.signOut();
        throw Exception('Access denied: Admin privileges required');
      }

      // Navigate to admin dashboard
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => AdminDashboardScreen(
              admin: UserModel.fromFirestore(userDoc),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.red.shade700
                : Colors.red.shade900,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              color: cardBackground,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo/Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: brandGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.admin_panel_settings,
                          size: 64,
                          color: brandGreen,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'GenZFit Admin',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Management Portal',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: primaryText),
                        decoration: InputDecoration(
                          labelText: 'Admin Email',
                          labelStyle: TextStyle(color: secondaryText),
                          prefixIcon: Icon(Icons.email, color: brandGreen),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: brandGreen),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: primaryText),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: secondaryText),
                          prefixIcon: Icon(Icons.lock, color: brandGreen),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: secondaryText,
                            ),
                            onPressed: () {
                              setState(
                                  () => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: brandGreen),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandGreen,
                            foregroundColor: isDark
                                ? AppColors.textPrimary
                                : const Color(0xFFFFFFFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark
                                        ? AppColors.textPrimary
                                        : const Color(0xFFFFFFFF),
                                  ),
                                )
                              : Text(
                                  'Sign In',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      if (_enableQuickAdminSetup) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const QuickAdminSetupScreen(),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.build_circle_outlined),
                          label: Text(
                            'Quick Admin Setup (Temporary)',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: brandGreen,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Warning Text
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? Colors.orange.shade700
                                  : Colors.orange.shade200)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (isDark
                                    ? Colors.orange.shade700
                                    : Colors.orange.shade600)
                                .withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: isDark
                                  ? Colors.orange.shade300
                                  : Colors.orange.shade800,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This portal is restricted to authorized administrators only',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.orange.shade300
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
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
}
