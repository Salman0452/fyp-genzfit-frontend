// routes.dart
import 'package:flutter/material.dart';
import 'package:genzfit/features/splash/splash_screen.dart';
import 'package:genzfit/features/onboarding/onboarding_screen.dart';
import 'package:genzfit/features/onboarding/role_selection_screen.dart';
import 'package:genzfit/features/auth/presentation/trainer-login.dart';
import 'package:genzfit/features/auth/presentation/trainer-signup.dart';
import 'package:genzfit/features/auth/presentation/seeker-login.dart';
import 'package:genzfit/features/auth/presentation/seeker-signup.dart';
import 'package:genzfit/features/trainer/presentation/trainer_dashboard.dart';
import 'package:genzfit/features/seeker/presentation/seeker_dashboard.dart';
import 'package:genzfit/features/trainer/presentation/settings_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const SplashScreen(),
  '/onboarding': (context) => const OnboardingScreen(),
  '/role-selection': (context) => const RoleSelectionScreen(),
  '/trainerLogin': (context) => const TrainerLoginScreen(),
  '/trainerSignup': (context) => const TrainerSignupScreen(),
  '/seekerLogin': (context) => const SeekerLoginScreen(),
  '/seekerSignup': (context) => const SeekerSignupScreen(),
  '/trainerDashboard': (context) => const TrainerDashboardScreen(),
  '/seekerDashboard': (context) => const SeekerDashboardScreen(),
  '/settings': (context) => const SettingsScreen(),
};
