import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'GenZFit';
  static const String appVersion = '1.0.0';

  // Primary Colors - Fitstreak Design Palette
  static const Color primaryLight = Color(0xFFD6DFE2); // Light gray (primary)
  static const Color primaryDark = Color(0xFF010101); // Almost black (primary)
  static const Color primaryBrand = Color(0xFFD5FF5F); // Lime green (primary)
  static const Color primaryWhite = Color(0xFFFFFFFF); // White (primary)

  // Secondary Colors - Fitstreak Design Palette
  static const Color secondaryGray = Color(0xFF9F9F9F); // Gray (secondary)
  static const Color secondaryBlue = Color(
    0xFF9AC0D6,
  ); // Light blue (secondary)
  static const Color secondaryDarkGray = Color(
    0xFF595959,
  ); // Dark gray (secondary)
  static const Color secondaryBlueGray = Color(
    0xFF4E6075,
  ); // Blue-gray (secondary)

  // Backward Compatibility Aliases (use AppColors instead for new code)
  static const Color primaryGold = Color(0xFFD5FF5F); // Alias for primaryBrand
  static const Color accentGold = Color(0xFF9AC0D6); // Alias for secondaryBlue
  static const Color charcoalGray = Color(0xFF010101); // Alias for primaryDark
  static const Color primaryBlack = Color(0xFF010101); // Alias for primaryDark
  static const Color textWhite = Color(0xFFFFFFFF); // Alias for primaryWhite
  static const Color textGray = Color(0xFF9F9F9F); // Alias for secondaryGray
  static const Color textDarkGray = Color(0xFF010101); // Alias for primaryDark

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String measurementsCollection = 'measurements';
  static const String avatarsCollection = 'avatars';
  static const String trainersCollection = 'trainers';
  static const String chatsCollection = 'chats';
  static const String sessionsCollection = 'sessions';
  static const String recommendationsCollection = 'recommendations';
  static const String chatbotHistoryCollection = 'chatbot_history';
  static const String platformAnalyticsCollection = 'platform_analytics';
  static const String verificationRequestsCollection = 'verification_requests';
  static const String reportsCollection = 'reports';

  // User Roles
  static const String roleClient = 'client';
  static const String roleTrainer = 'trainer';
  static const String roleAdmin = 'admin';

  // User Goals
  static const String goalFitness = 'fitness';
  static const String goalWeightGain = 'weightGain';
  static const String goalWeightLoss = 'weightLoss';

  // Session Status
  static const String sessionRequested = 'requested';
  static const String sessionActive = 'active';
  static const String sessionCompleted = 'completed';

  // User Status
  static const String statusActive = 'active';
  static const String statusSuspended = 'suspended';

  // Verification Status
  static const String verificationPending = 'pending';
  static const String verificationApproved = 'approved';
  static const String verificationRejected = 'rejected';

  // Padding & Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  // Font Sizes
  static const double fontSmall = 12.0;
  static const double fontMedium = 14.0;
  static const double fontLarge = 16.0;
  static const double fontXLarge = 20.0;
  static const double fontXXLarge = 24.0;
  static const double fontTitle = 32.0;

  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Shared Preferences Keys
  static const String keyUserId = 'userId';
  static const String keyUserRole = 'userRole';
  static const String keyIsLoggedIn = 'isLoggedIn';
  static const String keyOnboardingComplete = 'onboardingComplete';
}

// Simplified color constants for new screens - Fitstreak Design
class AppColors {
  // Background and Surface
  static const Color background = Color(
    0xFFF5F5F5,
  ); // Soft light gray background
  static const Color surface = Color(0xFFFAFAFA); // Off-white surface
  static const Color surfaceVariant = Color(0xFFEEEEEE); // Light gray surface

  // Brand Colors
  static const Color brandGreen = Color(
    0xFFD5FF5F,
  ); // Lime green (primary brand - for dark backgrounds)
  static const Color brandGreenDeep = Color(
    0xFF8BDD3C,
  ); // Deeper green (for white backgrounds - less exhausting)
  static const Color brandBlue = Color(0xFF9AC0D6); // Light blue (secondary)

  // Text Colors
  static const Color textPrimary = Color(0xFF010101); // Almost black
  static const Color textSecondary = Color(0xFF9F9F9F); // Gray
  static const Color textTertiary = Color(0xFF595959); // Dark gray
  static const Color textOnBrand = Color(0xFFFFFFFF); // White on brand colors

  // Status Colors (mapped to palette where possible)
  static const Color error = Color(
    0xFF595959,
  ); // Dark gray for errors (from palette)
  static const Color success = Color(0xFFD5FF5F); // Green (from palette)
  static const Color warning = Color(
    0xFF595959,
  ); // Dark gray for warnings (from palette)
  static const Color info = Color(0xFF9AC0D6); // Light blue (from palette)

  // Secondary Accent Colors (from PRIMARY & SECONDARY palette only)
  static const Color accent = Color(0xFFD5FF5F); // Green (primary)
  static const Color accentTeal = Color(0xFF9AC0D6); // Light blue (secondary)
  static const Color accentCyan = Color(0xFF9AC0D6); // Light blue (secondary)
  static const Color accentViolet = Color(0xFF4E6075); // Blue-gray (secondary)
  static const Color accentGray = Color(0xFF9F9F9F); // Gray (secondary)
  static const Color accentDarkGray = Color(
    0xFF595959,
  ); // Dark gray (secondary)
  static const Color muted = Color(0xFF9F9F9F);
  static const Color charcoal = Color(0xFF010101);
}

class AppSizes {
  static const double borderRadius = 12.0;
}
