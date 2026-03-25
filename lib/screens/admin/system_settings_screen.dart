import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:genzfit/utils/constants.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Commission Settings
  double _commissionRate = 0.20; // 20% default
  final TextEditingController _commissionController = TextEditingController();

  // Feature Toggles
  bool _aiCoachEnabled = true;
  bool _chatEnabled = true;
  bool _videoCallsEnabled = true;
  bool _trainerVerificationRequired = true;
  bool _autoApprovalEnabled = false;
  bool _maintenanceMode = false;

  // Payment Settings
  String _paymentGateway = 'stripe';
  bool _refundsEnabled = true;
  int _refundWindowDays = 7;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _commissionController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      // Load commission settings
      final commissionDoc = await _firestore
          .collection('platform_settings')
          .doc('commission')
          .get();
      if (commissionDoc.exists) {
        final rate = commissionDoc.data()?['rate'] as num?;
        if (rate != null) {
          setState(() {
            _commissionRate = rate.toDouble();
            _commissionController.text =
                (_commissionRate * 100).toStringAsFixed(0);
          });
        }
      }

      // Load feature toggles
      final featuresDoc = await _firestore
          .collection('platform_settings')
          .doc('features')
          .get();
      if (featuresDoc.exists) {
        final data = featuresDoc.data()!;
        setState(() {
          _aiCoachEnabled = data['aiCoachEnabled'] as bool? ?? true;
          _chatEnabled = data['chatEnabled'] as bool? ?? true;
          _videoCallsEnabled = data['videoCallsEnabled'] as bool? ?? true;
          _trainerVerificationRequired =
              data['trainerVerificationRequired'] as bool? ?? true;
          _autoApprovalEnabled = data['autoApprovalEnabled'] as bool? ?? false;
          _maintenanceMode = data['maintenanceMode'] as bool? ?? false;
        });
      }

      // Load payment settings
      final paymentDoc =
          await _firestore.collection('platform_settings').doc('payment').get();
      if (paymentDoc.exists) {
        final data = paymentDoc.data()!;
        setState(() {
          _paymentGateway = data['gateway'] as String? ?? 'stripe';
          _refundsEnabled = data['refundsEnabled'] as bool? ?? true;
          _refundWindowDays = data['refundWindowDays'] as int? ?? 7;
        });
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      // Save commission settings
      await _firestore.collection('platform_settings').doc('commission').set({
        'rate': _commissionRate,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Save feature toggles
      await _firestore.collection('platform_settings').doc('features').set({
        'aiCoachEnabled': _aiCoachEnabled,
        'chatEnabled': _chatEnabled,
        'videoCallsEnabled': _videoCallsEnabled,
        'trainerVerificationRequired': _trainerVerificationRequired,
        'autoApprovalEnabled': _autoApprovalEnabled,
        'maintenanceMode': _maintenanceMode,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Save payment settings
      await _firestore.collection('platform_settings').doc('payment').set({
        'gateway': _paymentGateway,
        'refundsEnabled': _refundsEnabled,
        'refundWindowDays': _refundWindowDays,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved successfully'),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.brandGreen
                : AppColors.brandGreenDeep,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF171917)
            : AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'System Settings',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : AppColors.textPrimary,
          ),
        ),
        actions: [
          if (_isSaving)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _saveSettings,
              icon: Icon(Icons.save,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.brandGreen
                      : AppColors.brandGreenDeep),
              tooltip: 'Save Settings',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.brandGreen
                      : AppColors.brandGreenDeep),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCommissionSection(),
                  const SizedBox(height: 32),
                  _buildFeatureTogglesSection(),
                  const SizedBox(height: 32),
                  _buildPaymentSettingsSection(),
                  const SizedBox(height: 32),
                  _buildDangerZoneSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildCommissionSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF171917)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.brandGreen
                      : AppColors.brandGreenDeep,
                  size: 24),
              const SizedBox(width: 12),
              Text(
                'Commission Settings',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Platform Commission Rate',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary)
                  .withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _commissionController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary),
                  decoration: InputDecoration(
                    suffixText: '%',
                    suffixStyle: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color:
                              (Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFFFFFFFF)
                                      : AppColors.textPrimary)
                                  .withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep),
                    ),
                  ),
                  onChanged: (value) {
                    final percentage = double.tryParse(value);
                    if (percentage != null &&
                        percentage >= 0 &&
                        percentage <= 100) {
                      setState(() => _commissionRate = percentage / 100);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trainer receives: ${((1 - _commissionRate) * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Platform takes: ${(_commissionRate * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.brandGreen
                      : AppColors.brandGreenDeep)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep)
                      .withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep,
                    size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Changes will apply to all new sessions. Existing sessions will use their original rate.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFFFFFFF)
                              : AppColors.textPrimary)
                          .withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTogglesSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF171917)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.toggle_on,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.brandGreen
                      : AppColors.brandGreenDeep,
                  size: 24),
              const SizedBox(width: 12),
              Text(
                'Feature Toggles',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildToggleItem(
            'AI Coach',
            'Enable AI-powered fitness coaching',
            _aiCoachEnabled,
            (value) => setState(() => _aiCoachEnabled = value),
            Icons.psychology,
          ),
          const Divider(color: Colors.white12, height: 32),
          _buildToggleItem(
            'Chat System',
            'Enable messaging between users and trainers',
            _chatEnabled,
            (value) => setState(() => _chatEnabled = value),
            Icons.chat,
          ),
          const Divider(color: Colors.white12, height: 32),
          _buildToggleItem(
            'Video Calls',
            'Enable video calling features',
            _videoCallsEnabled,
            (value) => setState(() => _videoCallsEnabled = value),
            Icons.video_call,
          ),
          Divider(
              color: (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary)
                  .withOpacity(0.12),
              height: 32),
          _buildToggleItem(
            'Trainer Verification',
            'Require trainers to be verified before accepting clients',
            _trainerVerificationRequired,
            (value) => setState(() => _trainerVerificationRequired = value),
            Icons.verified_user,
          ),
          const Divider(color: Colors.white12, height: 32),
          _buildToggleItem(
            'Auto-Approval',
            'Automatically approve trainer applications (not recommended)',
            _autoApprovalEnabled,
            (value) => setState(() => _autoApprovalEnabled = value),
            Icons.auto_awesome,
            isWarning: true,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(
    String title,
    String description,
    bool value,
    ValueChanged<bool> onChanged,
    IconData icon, {
    bool isWarning = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isWarning
                    ? Colors.orange
                    : (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep))
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isWarning
                ? Colors.orange
                : (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandGreen
                    : AppColors.brandGreenDeep),
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary)
                      .withOpacity(0.38),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: isWarning
              ? Colors.orange
              : (Theme.of(context).brightness == Brightness.dark
                  ? AppColors.brandGreen
                  : AppColors.brandGreenDeep),
        ),
      ],
    );
  }

  Widget _buildPaymentSettingsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF171917)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.brandGreen
                      : AppColors.brandGreenDeep,
                  size: 24),
              const SizedBox(width: 12),
              Text(
                'Payment Settings',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Payment Gateway',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary)
                  .withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _paymentGateway,
            dropdownColor: Theme.of(context).scaffoldBackgroundColor,
            style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary)
                        .withOpacity(0.2)),
              ),
            ),
            items: [
              DropdownMenuItem(
                value: 'stripe',
                child: Text('Stripe', style: GoogleFonts.inter()),
              ),
              DropdownMenuItem(
                value: 'paypal',
                child: Text('PayPal', style: GoogleFonts.inter()),
              ),
              DropdownMenuItem(
                value: 'razorpay',
                child: Text('Razorpay', style: GoogleFonts.inter()),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _paymentGateway = value);
              }
            },
          ),
          const SizedBox(height: 24),
          _buildToggleItem(
            'Refunds Enabled',
            'Allow users to request refunds',
            _refundsEnabled,
            (value) => setState(() => _refundsEnabled = value),
            Icons.money_off,
          ),
          if (_refundsEnabled) ...[
            const SizedBox(height: 24),
            Text(
              'Refund Window (Days)',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary)
                    .withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              keyboardType: TextInputType.number,
              style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary),
              controller:
                  TextEditingController(text: _refundWindowDays.toString()),
              decoration: InputDecoration(
                suffixText: 'days',
                suffixStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFFFFFFF)
                              : AppColors.textPrimary)
                          .withOpacity(0.2)),
                ),
              ),
              onChanged: (value) {
                final days = int.tryParse(value);
                if (days != null && days > 0) {
                  setState(() => _refundWindowDays = days);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDangerZoneSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF171917)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.red, size: 24),
              const SizedBox(width: 12),
              Text(
                'Danger Zone',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildToggleItem(
            'Maintenance Mode',
            'Prevent all users from accessing the platform',
            _maintenanceMode,
            (value) => setState(() => _maintenanceMode = value),
            Icons.construction,
            isWarning: true,
          ),
          if (_maintenanceMode) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Platform is currently in maintenance mode. Users will not be able to access any features.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
