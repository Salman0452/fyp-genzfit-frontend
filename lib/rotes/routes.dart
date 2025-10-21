// routes.dart
import 'package:flutter/material.dart';
import 'package:genzfit/features/splash/splash_screen.dart';
import 'package:genzfit/features/onboarding/onboarding_screen.dart';
import 'package:genzfit/features/onboarding/role_selection_screen.dart';
import 'package:genzfit/features/auth/presentation/trainer-login.dart';
import 'package:genzfit/features/auth/presentation/trainer-signup.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const SplashScreen(),
  '/onboarding': (context) => const OnboardingScreen(),
  '/role-selection': (context) => const RoleSelectionScreen(),
  '/trainerLogin': (context) => const TrainerLoginScreen(),
  '/trainerSignup': (context) => const TrainerSignupScreen(),
};
