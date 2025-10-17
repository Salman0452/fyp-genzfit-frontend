import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      fontFamily: 'Poppins',
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        background: AppColors.background,
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          color: AppColors.text,
          fontFamily: 'Inter'
        ),
        bodyMedium: TextStyle(
          color: AppColors.text,
          fontFamily: 'Inter'
        ),
        titleLarge: TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins'
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cta,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}