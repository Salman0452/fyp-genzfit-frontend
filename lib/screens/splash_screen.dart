import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../models/user_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();

    // Wait for Firebase Auth to restore session (max 3 seconds)
    int attempts = 0;
    while (attempts < 30) {
      if (authProvider.user != null && authProvider.userModel != null) {
        // User is fully loaded
        break;
      }
      if (authProvider.user == null && attempts > 10) {
        // No user after 1 second, likely not logged in
        break;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (!mounted) return;

    final user = authProvider.user;
    final userModel = authProvider.userModel;

    if (user == null) {
      // No Firebase Auth user, go to role selection
      Navigator.pushReplacementNamed(context, '/role-selection');
    } else if (userModel == null) {
      // Firebase user exists but Firestore data failed to load
      // Try to fetch user data one more time
      try {
        await authProvider.refreshUserData();
        if (!mounted) return;

        final refreshedModel = authProvider.userModel;
        if (refreshedModel != null) {
          _navigateToHome(refreshedModel.role);
        } else {
          // Still null, sign out and restart
          await authProvider.signOut();
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/role-selection');
          }
        }
      } catch (e) {
        // Failed to fetch user data, sign out
        await authProvider.signOut();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/role-selection');
        }
      }
    } else {
      // User is fully loaded, navigate to home
      _navigateToHome(userModel.role);
    }
  }

  void _navigateToHome(UserRole role) {
    if (!mounted) return;

    if (role == UserRole.client) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/client-home',
        (route) => false,
      );
    } else if (role == UserRole.trainer) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/trainer-home',
        (route) => false,
      );
    } else if (role == UserRole.admin) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/admin-dashboard',
        (route) => false,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/role-selection');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo/Icon with Modern Design
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep,
                      (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep)
                          .withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep)
                          .withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.fitness_center,
                  size: 60,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF010101)
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),
              // App Title
              Text(
                'GenZFit',
                style: GoogleFonts.plusJakartaSans(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              // Sub Title
              Text(
                'Transform Your Body, Elevate Your Life',
                style: GoogleFonts.plusJakartaSans(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 64),
              // Loading Indicator
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).brightness == Brightness.dark
                      ? AppColors.brandGreen
                      : AppColors.brandGreenDeep,
                ),
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
