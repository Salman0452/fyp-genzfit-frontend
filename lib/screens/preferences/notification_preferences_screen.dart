import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/user_preferences_service.dart';
import '../../utils/constants.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final UserPreferencesService _prefsService = UserPreferencesService();

  bool _isLoading = true;
  bool _isSaving = false;

  bool _notificationsEnabled = true;
  bool _sessionUpdates = true;
  bool _messageNotifications = true;
  bool _paymentNotifications = true;
  bool _reminderNotifications = true;
  bool _marketingNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    if (userId == null || userId.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    final prefs = await _prefsService.loadNotificationPreferences(userId);

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs['notifications_enabled'] ?? true;
      _sessionUpdates = prefs['session_updates'] ?? true;
      _messageNotifications = prefs['message_notifications'] ?? true;
      _paymentNotifications = prefs['payment_notifications'] ?? true;
      _reminderNotifications = prefs['reminder_notifications'] ?? true;
      _marketingNotifications = prefs['marketing_notifications'] ?? false;
      _isLoading = false;
    });
  }

  Future<void> _savePreferences() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;

    if (userId == null || userId.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _prefsService.saveNotificationPreferences(
        userId: userId,
        preferences: {
          'notifications_enabled': _notificationsEnabled,
          'session_updates': _sessionUpdates,
          'message_notifications': _messageNotifications,
          'payment_notifications': _paymentNotifications,
          'reminder_notifications': _reminderNotifications,
          'marketing_notifications': _marketingNotifications,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification preferences saved'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.brandGreen
              : AppColors.brandGreenDeep,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save preferences: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _resetToDefaults() async {
    setState(() {
      _notificationsEnabled = true;
      _sessionUpdates = true;
      _messageNotifications = true;
      _paymentNotifications = true;
      _reminderNotifications = true;
      _marketingNotifications = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        backgroundColor: surfaceColor,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _resetToDefaults,
            style: TextButton.styleFrom(
              foregroundColor:
                  isDark ? AppColors.brandGreen : AppColors.brandGreenDeep,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInfoCard(textPrimary, textSecondary),
                const SizedBox(height: 16),
                _buildSwitchCard(
                  title: 'Enable Notifications',
                  subtitle: 'Master switch for all app notifications',
                  value: _notificationsEnabled,
                  onChanged: (value) => setState(() {
                    _notificationsEnabled = value;
                    if (!value) {
                      _sessionUpdates = false;
                      _messageNotifications = false;
                      _paymentNotifications = false;
                      _reminderNotifications = false;
                      _marketingNotifications = false;
                    }
                  }),
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('What to notify me about'),
                const SizedBox(height: 12),
                _buildToggleItem(
                  title: 'Session updates',
                  subtitle: 'Approvals, cancellations, and schedule changes',
                  value: _sessionUpdates,
                  enabled: _notificationsEnabled,
                  onChanged: (value) => setState(() => _sessionUpdates = value),
                ),
                _buildToggleItem(
                  title: 'Messages',
                  subtitle: 'New chat messages and replies',
                  value: _messageNotifications,
                  enabled: _notificationsEnabled,
                  onChanged: (value) =>
                      setState(() => _messageNotifications = value),
                ),
                _buildToggleItem(
                  title: 'Payments & withdrawals',
                  subtitle:
                      'Payment confirmations and withdrawal status changes',
                  value: _paymentNotifications,
                  enabled: _notificationsEnabled,
                  onChanged: (value) =>
                      setState(() => _paymentNotifications = value),
                ),
                _buildToggleItem(
                  title: 'Reminders',
                  subtitle: 'Workout and appointment reminders',
                  value: _reminderNotifications,
                  enabled: _notificationsEnabled,
                  onChanged: (value) =>
                      setState(() => _reminderNotifications = value),
                ),
                _buildToggleItem(
                  title: 'Promotions & tips',
                  subtitle: 'News, offers, and product updates',
                  value: _marketingNotifications,
                  enabled: _notificationsEnabled,
                  onChanged: (value) =>
                      setState(() => _marketingNotifications = value),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _savePreferences,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Preferences'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoCard(Color textPrimary, Color textSecondary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withOpacity(isDark ? 0.4 : 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Control how the app notifies you',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These preferences are saved to your account and applied across the app.',
            style: TextStyle(color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor:
                isDark ? AppColors.brandGreen : AppColors.brandGreenDeep,
            activeTrackColor:
                (isDark ? AppColors.brandGreen : AppColors.brandGreenDeep)
                    .withOpacity(0.35),
            inactiveThumbColor: AppColors.textHint,
            inactiveTrackColor: AppColors.surfaceDim,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(subtitle),
        activeColor: isDark ? AppColors.brandGreen : AppColors.brandGreenDeep,
        activeTrackColor:
            (isDark ? AppColors.brandGreen : AppColors.brandGreenDeep)
                .withOpacity(0.35),
        inactiveThumbColor: AppColors.textHint,
        inactiveTrackColor: AppColors.surfaceDim,
        value: enabled ? value : false,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}
