import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const GenZFitApp());
}

class GenZFitApp extends StatelessWidget {
  const GenZFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenZFit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
     // home: const SplashScreen,
    );
  }
}