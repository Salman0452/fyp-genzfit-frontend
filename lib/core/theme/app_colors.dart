import 'package:flutter/material.dart';

/// App-wide color palette
class AppColors {
  // Primary gradient colors - Exact colors from mockup (Light Mode)
  static const Color gradientStart = Color(0xFF37CDFA); // #37cdfa - bright cyan
  static const Color gradientEnd = Color(0xFF87EFCE); // #87efce - mint/teal
  
  // Dark Mode gradient colors
  static const Color darkGradientStart = Color(0xFF1A5F7A); // Dark cyan
  static const Color darkGradientEnd = Color(0xFF2D7B6C); // Dark teal
  
  // Primary colors
  static const Color primaryBlue = Color(0xFF37CDFA); // Bright cyan
  static const Color primaryCyan = Color(0xFF43DBE6); // Card gradient cyan
  
  // Dark mode primary colors
  static const Color darkPrimaryBlue = Color(0xFF2A9FD6); // Muted cyan for dark mode
  static const Color darkPrimaryCyan = Color(0xFF3ABBC8); // Muted cyan for dark mode
  
  // Text colors - Light Mode
  static const Color textDark = Color(0xFF1E293B); // Dark blue-gray for headings
  static const Color textMedium = Color(0xFF475569); // Medium gray for body text
  static const Color textLight = Color(0xFF94A3B8); // Light gray for hints
  static const Color textWhite = Color(0xFFFFFFFF);
  
  // Text colors - Dark Mode
  static const Color darkTextPrimary = Color(0xFFE2E8F0); // Light gray for primary text
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Medium gray for secondary text
  static const Color darkTextTertiary = Color(0xFF64748B); // Darker gray for tertiary text
  
  // Background colors - Light Mode
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  
  // Background colors - Dark Mode
  static const Color darkBackground = Color(0xFF0F172A); // Very dark blue-gray
  static const Color darkBackgroundSecondary = Color(0xFF1E293B); // Dark blue-gray
  static const Color darkSurface = Color(0xFF334155); // Medium dark gray
  
  // Button colors
  static const Color buttonPrimary = Color(0xFF43DBE6); // Card gradient cyan
  static const Color buttonSecondary = Color(0xFF37CDFA); // Bright cyan
  
  // Dark mode button colors
  static const Color darkButtonPrimary = Color(0xFF3ABBC8);
  static const Color darkButtonSecondary = Color(0xFF2A9FD6);
  
  // Accent colors
  static const Color accentBlue = Color(0xFF37CDFA); // Bright cyan
  static const Color accentTeal = Color(0xFF58E2D8); // Card gradient teal
  
  // Role card gradient (for trainer/client cards)
  static const Color cardGradientLeft = Color(0xFF43DBE6); // #43dbe6
  static const Color cardGradientRight = Color(0xFF58E2D8); // #58e2d8
  
  // Dark mode card gradient
  static const Color darkCardGradientLeft = Color(0xFF2A7F8A); // Darker cyan
  static const Color darkCardGradientRight = Color(0xFF3D9A8F); // Darker teal
  
  // Utility colors (same for both modes)
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  
  // Shadow colors
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowMedium = Color(0x33000000);
  static const Color darkShadow = Color(0x40000000); // Stronger shadow for dark mode
  
  // Input field colors - Dark Mode
  static const Color darkInputFill = Color(0xFF334155); // Dark surface for inputs
  static const Color darkInputBorder = Color(0xFF475569); // Border color
}
