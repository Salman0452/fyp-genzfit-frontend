import 'package:flutter/material.dart';

class AppColors {
  // Black shades - strong and bold
  static const Color primary = Color(0xFF0A0A0A); // Deep Black
  static const Color secondary = Color(0xFF1A1A1A); // Charcoal Black
  static const Color darkGray = Color(0xFF2D2D2D); // Dark Gray
  static const Color mediumGray = Color(0xFF404040); // Medium Gray
  
  // Accent colors - energetic and motivating (Cyan + Orange combo)
  static const Color accent = Color(0xFF00D9FF); // Electric Cyan - main brand color
  static const Color accentOrange = Color(0xFFFF6B35); // Vibrant Orange - secondary
  static const Color accentPurple = Color(0xFF9D4EDD); // Purple for premium features
  
  // UI colors
  static const Color background = Color(0xFF0F0F0F); // Almost Black background
  static const Color cardBackground = Color(0xFF1C1C1C); // Card background
  static const Color text = Color(0xFFFFFFFF); // Pure White text
  static const Color textSecondary = Color(0xFFB0B0B0); // Light Gray text
  static const Color textMuted = Color(0xFF707070); // Muted Gray
  
  // CTA and highlights
  static const Color cta = Color(0xFF00D9FF); // Electric Cyan for CTAs
  static const Color ctaSecondary = Color(0xFFFF6B35); // Orange for secondary CTAs
  static const Color success = Color(0xFF00C896); // Emerald Green
  static const Color warning = Color(0xFFFFA726); // Amber Orange
  static const Color error = Color(0xFFFF3366); // Hot Pink/Red

  // Gradients - powerful and motivating
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00D9FF), Color(0xFFFF6B35)], // Cyan to Orange
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF00D9FF), Color(0xFF0099CC)], // Light to dark cyan
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleOrangeGradient = LinearGradient(
    colors: [Color(0xFF9D4EDD), Color(0xFFFF6B35)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0A0A0A), Color(0xFF2D2D2D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}