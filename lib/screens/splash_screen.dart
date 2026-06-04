import 'package:flutter/material.dart';
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
          if (!_isModelActive(refreshedModel)) {
            await authProvider.signOut();
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/role-selection');
            }
            return;
          }
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
      if (!_isModelActive(userModel)) {
        await authProvider.signOut();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/role-selection');
        }
        return;
      }
      _navigateToHome(userModel.role);
    }
  }

  bool _isModelActive(UserModel model) {
    final status = model.status.toLowerCase();
    return status != 'suspended' &&
        status != 'inactive' &&
        status != 'disabled';
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final logoAsset = isDarkMode
        ? 'assets/images/splash_screen_dark.png'
        : 'assets/images/splash_screen_light.png';
    final splashBackgroundColor =
        isDarkMode ? AppColors.charcoal : AppColors.brandGreenDeep;
    final splashTextColor =
        isDarkMode ? AppColors.textOnBrand : AppColors.textOnBrand;

    return Scaffold(
      backgroundColor: splashBackgroundColor,
      body: Container(
        color: splashBackgroundColor,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: Image.asset(
                    logoAsset,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 48),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    splashTextColor,
                  ),
                  strokeWidth: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
