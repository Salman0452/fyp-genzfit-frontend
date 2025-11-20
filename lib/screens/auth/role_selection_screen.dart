import 'package:flutter/material.dart';
import 'package:genzfit/screens/auth/signup_screen.dart';
import '../../utils/constants.dart';
import '../../models/user_model.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.primaryBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppConstants.paddingXLarge),
              const Text(
                'GenZFit',
                style: TextStyle(
                  color: AppConstants.primaryGold,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              const Text(
                'Choose Your Path',
                style: TextStyle(
                  color: AppConstants.textWhite,
                  fontSize: AppConstants.fontTitle,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              const Text(
                'Select your role to get started',
                style: TextStyle(
                  color: AppConstants.textGray,
                  fontSize: AppConstants.fontLarge,
                ),
              ),
              const SizedBox(height: AppConstants.paddingXLarge * 2),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoleCard(
                      role: UserRole.client,
                      title: 'Client',
                      description:
                          'Transform your fitness journey with AI-powered insights and expert trainers',
                      icon: Icons.fitness_center,
                      onTap: () => _navigateToSignup(context, UserRole.client),
                    ),
                    const SizedBox(height: AppConstants.paddingLarge),
                    _RoleCard(
                      role: UserRole.trainer,
                      title: 'Trainer',
                      description:
                          'Share your expertise and build your fitness coaching business',
                      icon: Icons.sports_martial_arts,
                      onTap: () => _navigateToSignup(context, UserRole.trainer),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.paddingLarge),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(
                      color: AppConstants.textGray,
                      fontSize: AppConstants.fontMedium,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/login'),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: AppConstants.primaryGold,
                        fontSize: AppConstants.fontMedium,
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
    );
  }

  void _navigateToSignup(BuildContext context, UserRole role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignupScreen(role: role),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppConstants.charcoalGray,
              AppConstants.slateGray,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(
            color: AppConstants.accentGray,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppConstants.primaryGold.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: AppConstants.primaryGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              child: Icon(
                icon,
                size: 40,
                color: AppConstants.primaryGold,
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppConstants.textWhite,
                      fontSize: AppConstants.fontXLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppConstants.textGray,
                      fontSize: AppConstants.fontMedium,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppConstants.primaryGold,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
