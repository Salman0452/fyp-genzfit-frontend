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
import 'package:genzfit/screens/settings/edit_preferences_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        title: Text(
          'Logout',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFB0B0B0)
                : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: Consumer2<LanguageProvider, ThemeProvider>(
        builder: (context, languageProvider, themeProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Account Section
              const Text(
                'Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
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

              const SizedBox(height: 24),

              // Preferences Section
              const Text(
                'Preferences',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                context,
                icon: Icons.tune,
                title: 'Edit Preferences',
                subtitle: 'Update your goals, workout & diet settings',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditPreferencesScreen(),
                    ),
                  );
                },
              ),
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

              const SizedBox(height: 24),

              // Privacy Section
              const Text(
                'Privacy & Security',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
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

              const SizedBox(height: 24),

              // About Section
              const Text(
                'About',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                context,
                icon: Icons.info,
                title: 'About GenZFit',
                subtitle: 'Version 1.0.0',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'GenZFit',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(
                      Icons.fitness_center,
                      color: AppColors.accent,
                      size: 48,
                    ),
                    children: [
                      const Text(
                        'GenZFit is your AI-powered fitness companion. Track your progress, get personalized recommendations, and achieve your fitness goals.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  );
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

              const SizedBox(height: 32),

              // Logout Button
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 0),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Text(
                    'Sign out of your account',
                    style: TextStyle(color: AppColors.error),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.error,
                    size: 16,
                  ),
                  onTap: () => _showLogoutDialog(context),
                ),
              ),
              const SizedBox(height: 20),
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
    final modeLabel = switch (themeProvider.themeMode) {
      ThemeMode.system => 'System (Auto)',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.palette, color: AppColors.accent),
            title: Text(
              'Theme',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              modeLabel,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFB0B0B0)
                    : AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF404040)
                : AppColors.charcoal,
          ),
          SwitchListTile.adaptive(
            title: Text(
              'Use system theme',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Automatically match your phone theme',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFB0B0B0)
                    : AppColors.textSecondary,
              ),
            ),
            value: themeProvider.useSystemTheme,
            activeColor: AppColors.accent,
            onChanged: (value) => themeProvider.setUseSystemTheme(value),
          ),
          SwitchListTile.adaptive(
            title: Text(
              'Dark mode',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              themeProvider.useSystemTheme
                  ? 'Disabled while system theme is enabled'
                  : 'Turn off for light mode',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFB0B0B0)
                    : AppColors.textSecondary,
              ),
            ),
            value: themeProvider.isDarkMode,
            activeColor: AppColors.accent,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.accent),
        title: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFB0B0B0)
                : AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFB0B0B0)
              : AppColors.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }
}
