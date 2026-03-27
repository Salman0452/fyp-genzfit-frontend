import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:genzfit/providers/auth_provider.dart';
import 'package:genzfit/providers/language_provider.dart';
import 'package:genzfit/providers/theme_provider.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/screens/client/edit_profile_screen.dart';
import 'package:genzfit/screens/auth/forgot_password_screen.dart';
import 'package:genzfit/screens/common/privacy_policy_screen.dart';
import 'package:genzfit/screens/common/terms_of_service_screen.dart';
import 'package:genzfit/screens/common/help_support_screen.dart';
import 'package:genzfit/screens/common/language_selection_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showLogoutDialog(BuildContext context) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode
                  ? AppColors.error.withOpacity(0.3)
                  : AppColors.error.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon badge
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.logout,
                      color: AppColors.error,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDarkMode
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Message
              Text(
                'Are you sure you want to logout from your account?',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: isDarkMode
                              ? const Color(0xFF404040)
                              : const Color(0xFFE8E8E8),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.borderRadius),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? const Color(0xFFFFFFFF)
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: const Color(0xFFFFFFFF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.borderRadius),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
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

    if (confirmed == true && context.mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/role-selection');
      }
    }
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode
                  ? (isDarkMode
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep)
                      .withOpacity(0.3)
                  : AppColors.brandGreenDeep.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon badge
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (isDarkMode
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isDarkMode
                                ? AppColors.brandGreen
                                : AppColors.brandGreenDeep)
                            .withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.fitness_center,
                      color: isDarkMode
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GenZFit',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDarkMode
                                ? const Color(0xFFFFFFFF)
                                : AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'v1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? const Color(0xFF808080)
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Description
              Text(
                'GenZFit is your AI-powered fitness companion. Track your progress, get personalized recommendations, and achieve your fitness goals with expert guidance.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.borderRadius),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            isDarkMode ? const Color(0xFF0A0A0A) : AppColors.surface,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your preferences',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFF808080)
                    : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Consumer2<LanguageProvider, ThemeProvider>(
        builder: (context, languageProvider, themeProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Account Section
              Text(
                'Account',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                context,
                icon: Icons.person,
                title: 'Edit Profile',
                subtitle: 'Update your personal information',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfileScreen(),
                    ),
                  );
                },
              ),
              _buildSettingItem(
                context,
                icon: Icons.lock,
                title: 'Change Password',
                subtitle: 'Update your password',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Preferences Section
              Text(
                'Preferences',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                context,
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'Manage notification preferences',
                onTap: () {
                  // TODO: Navigate to notifications settings
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Coming soon!'),
                      backgroundColor: AppColors.accent,
                    ),
                  );
                },
              ),
              _buildSettingItem(
                context,
                icon: Icons.language,
                title: 'Language',
                subtitle: languageProvider.currentLanguageName,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LanguageSelectionScreen(),
                    ),
                  );
                },
              ),
              _buildThemeSettingsCard(context, themeProvider),

              const SizedBox(height: 32),

              // Privacy Section
              Text(
                'Privacy & Security',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                context,
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                subtitle: 'View our privacy policy',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyScreen(),
                    ),
                  );
                },
              ),
              _buildSettingItem(
                context,
                icon: Icons.description,
                title: 'Terms of Service',
                subtitle: 'View terms and conditions',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TermsOfServiceScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // About Section
              Text(
                'About',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                context,
                icon: Icons.info,
                title: 'About GenZFit',
                subtitle: 'Version 1.0.0',
                onTap: () {
                  _showAboutDialog(context);
                },
              ),
              _buildSettingItem(
                context,
                icon: Icons.help,
                title: 'Help & Support',
                subtitle: 'Get help with the app',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HelpSupportScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Logout Button
              Container(
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  border: Border.all(
                    color: AppColors.error.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.logout,
                    color: AppColors.error,
                    size: 22,
                  ),
                  title: Text(
                    'Logout',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                  ),
                  subtitle: Text(
                    'Sign out of your account',
                    style: TextStyle(
                      color: AppColors.error.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.error.withOpacity(0.6),
                    size: 16,
                  ),
                  onTap: () => _showLogoutDialog(context),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThemeSettingsCard(
    BuildContext context,
    ThemeProvider themeProvider,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final modeLabel = switch (themeProvider.themeMode) {
      ThemeMode.system => 'System (Auto)',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF404040) : const Color(0xFFE8E8E8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.palette,
              color:
                  isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep,
              size: 22,
            ),
            title: Text(
              'Theme',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
            subtitle: Text(
              modeLabel,
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFB0B0B0)
                    : AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Divider(
            height: 1,
            color:
                isDarkMode ? const Color(0xFF404040) : const Color(0xFFE8E8E8),
          ),
          SwitchListTile.adaptive(
            title: Text(
              'Use system theme',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Automatically match your phone theme',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFB0B0B0)
                    : AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            value: themeProvider.useSystemTheme,
            activeColor:
                isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep,
            onChanged: (value) => themeProvider.setUseSystemTheme(value),
          ),
          SwitchListTile.adaptive(
            title: Text(
              'Dark mode',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              themeProvider.useSystemTheme
                  ? 'Disabled while system theme is enabled'
                  : 'Turn off for light mode',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFB0B0B0)
                    : AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            value: themeProvider.isDarkMode,
            activeColor:
                isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep,
            onChanged: themeProvider.useSystemTheme
                ? null
                : (value) => themeProvider.setDarkModeEnabled(value),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF404040) : const Color(0xFFE8E8E8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDarkMode ? const Color(0xFFFFFFFF) : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: -0.3,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color:
                isDarkMode ? const Color(0xFFB0B0B0) : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isDarkMode ? const Color(0xFF808080) : AppColors.textSecondary,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
}
