// routes.dart
import 'package:flutter/material.dart';
import 'package:genzfit/features/splash/splash_screen.dart';
import 'package:genzfit/features/onboarding/onboarding_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const SplashScreen(),
  '/onboarding': (context) => const OnboardingScreen(),
};
