import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';
import 'package:genzfit/features/splash/splash_screen.dart';

void main() {
  runApp(const GenZFitApp());
}

class GenZFitApp extends StatelessWidget {
  const GenZFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenZFit',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
