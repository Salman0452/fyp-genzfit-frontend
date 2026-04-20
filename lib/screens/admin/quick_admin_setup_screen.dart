import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:genzfit/models/user_model.dart';
import 'package:genzfit/screens/admin/admin_dashboard_screen.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';

class QuickAdminSetupScreen extends StatefulWidget {
  const QuickAdminSetupScreen({super.key});

  @override
  State<QuickAdminSetupScreen> createState() => _QuickAdminSetupScreenState();
}

class _QuickAdminSetupScreenState extends State<QuickAdminSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Super Admin');
  final _emailController = TextEditingController(text: 'admin@genzfit.com');
  final _passwordController = TextEditingController(text: 'admin123');
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = FirebaseAuth.instance;
      UserCredential credential;

      try {
        credential = await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') {
          rethrow;
        }

        credential = await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      final user = credential.user;
      if (user == null) {
        throw Exception('Failed to create admin user');
      }

      await user.updateDisplayName(_nameController.text.trim());

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'id': user.uid,
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'role': 'super_admin',
        'roleKey': 'super_admin',
        'status': 'active',
        'emailVerified': true,
        'createdAt': Timestamp.now(),
      }, SetOptions(merge: true));

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) =>
              AdminDashboardScreen(admin: UserModel.fromFirestore(userDoc)),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Auth error: ${e.code}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to setup admin: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Quick Admin Setup',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Temporary Internal Setup',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Creates or signs into the admin account and writes super_admin role in Firestore. Remove this screen after setup.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Role: super_admin',
                        style: GoogleFonts.inter(
                          color: secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _createAdmin,
                          icon: _isLoading
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.admin_panel_settings),
                          label: Text(
                            _isLoading ? 'Setting up...' : 'Create/Sign In Admin',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandGreen,
                          ),
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
