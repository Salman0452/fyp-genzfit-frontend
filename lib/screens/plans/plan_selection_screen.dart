import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'dart:typed_data';
import '../../providers/plan_provider.dart';
import '../../models/plan_models.dart';
import '../../services/payment_service.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';

class PlanSelectionScreen extends StatelessWidget {
  final String userId;
  final String? adminBankDetails; // Pass from settings or fetch in provider

  const PlanSelectionScreen(
      {super.key, required this.userId, this.adminBankDetails});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChangeNotifierProvider(
      create: (_) => PlanProvider()
        ..loadPlans()
        ..loadActiveSubscription(userId)
        ..loadTodayUsage(userId),
      child: Consumer<PlanProvider>(
        builder: (context, planProvider, _) {
          if (planProvider.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final activePlan = planProvider.activeSubscription;
          final plans = planProvider.plans;
          int dailyLimit = 3;
          if (activePlan != null) {
            final plan = plans.firstWhere(
              (p) => p.id == activePlan.planId,
              orElse: () => PlanModel(
                id: '',
                name: '',
                dailyMessageLimit: 3,
                price: 0,
                duration: '',
                description: '',
                sortOrder: 0,
              ),
            );
            dailyLimit = plan.dailyMessageLimit;
          }

          final used = planProvider.todayUsage?.messageCount ?? 0;
          final percent =
              dailyLimit > 0 ? (used / dailyLimit).clamp(0.0, 1.0) : 0.0;
          final activePlanName = planProvider.activeSubscription == null
              ? 'Free'
              : planProvider.plans
                  .where((p) => p.id == planProvider.activeSubscription!.planId)
                  .map((p) => p.name)
                  .cast<String?>()
                  .firstWhere((value) => value != null,
                      orElse: () => 'Unknown')!;

          return Scaffold(
            backgroundColor:
                isDark ? const Color(0xFF1A1A1A) : AppColors.background,
            appBar: AppBar(
              title: const Text('Choose Your Plan'),
              backgroundColor:
                  isDark ? const Color(0xFF262626) : AppColors.surface,
              elevation: 0,
              foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.brandBlue,
                        isDark
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.16 : 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.workspace_premium_outlined,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upgrade your AI access',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pick a plan that fits your coaching needs and message limits.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (planProvider.activeSubscription != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          isDark ? const Color(0xFF262626) : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF333333)
                            : const Color(0xFFE6E6E6),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.brandGreenDeep.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.verified,
                              color: AppColors.brandGreenDeep),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Plan: $activePlanName',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Status: ${planProvider.activeSubscription!.status}',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF262626) : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF333333)
                          : const Color(0xFFE6E6E6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Chatbot Usage',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$used used • ${(dailyLimit - used).clamp(0, dailyLimit)} left today',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearPercentIndicator(
                        lineHeight: 14.0,
                        percent: percent,
                        backgroundColor: isDark
                            ? const Color(0xFF3A3A3A)
                            : AppColors.surfaceVariant,
                        progressColor: percent < 1.0
                            ? AppColors.brandBlue
                            : Colors.redAccent,
                        barRadius: const Radius.circular(999),
                        padding: EdgeInsets.zero,
                        center: Text(
                          '${(percent * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...planProvider.plans.map((plan) {
                  final isFreePlan =
                      plan.duration.trim().toLowerCase() == 'free' ||
                          plan.price == 0;
                  final isCurrentActive =
                      planProvider.activeSubscription?.planId == plan.id &&
                          planProvider.activeSubscription?.status == 'active';
                  final isSelectedPlan = isCurrentActive || isFreePlan;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color:
                          isDark ? const Color(0xFF262626) : AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isCurrentActive
                            ? AppColors.brandGreenDeep.withOpacity(0.45)
                            : (isDark
                                ? const Color(0xFF333333)
                                : const Color(0xFFE6E6E6)),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.14 : 0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.brandBlue.withOpacity(0.12),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(24),
                                bottomLeft: Radius.circular(16),
                              ),
                            ),
                            child: Text(
                              plan.duration.toUpperCase(),
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.brandBlue,
                                          isDark
                                              ? AppColors.brandGreen
                                              : AppColors.brandGreenDeep,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(
                                      Icons.workspace_premium_outlined,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          plan.name,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.textPrimary,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          plan.description,
                                          style: TextStyle(
                                            color: isDark
                                                ? AppColors.textSecondary
                                                : AppColors.textTertiary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _PlanBadge(
                                    icon: Icons.payments_outlined,
                                    label: 'PKR ${plan.price}',
                                    isDark: isDark,
                                  ),
                                  _PlanBadge(
                                    icon: Icons.smart_toy_outlined,
                                    label: '${plan.dailyMessageLimit} msgs/day',
                                    isDark: isDark,
                                  ),
                                  if (isSelectedPlan)
                                    _PlanBadge(
                                      icon: Icons.check_circle_outline,
                                      label: isFreePlan && !isCurrentActive
                                          ? 'Default plan'
                                          : 'Current plan',
                                      isDark: isDark,
                                      highlight: true,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSelectedPlan
                                        ? AppColors.surfaceVariant
                                        : AppColors.brandBlue,
                                    foregroundColor: isSelectedPlan
                                        ? (isDark
                                            ? AppColors.textPrimary
                                            : AppColors.textPrimary)
                                        : Colors.white,
                                    disabledBackgroundColor:
                                        AppColors.surfaceVariant,
                                    disabledForegroundColor: isDark
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: isSelectedPlan
                                      ? null
                                      : () => _showPurchaseDialog(context, plan,
                                          adminBankDetails, userId),
                                  child: Text(
                                    isSelectedPlan
                                        ? (isFreePlan && !isCurrentActive
                                            ? 'Default plan'
                                            : 'Current plan')
                                        : 'Purchase plan',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isSelectedPlan
                                          ? (isDark
                                              ? AppColors.textPrimary
                                              : AppColors.textPrimary)
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
                if (planProvider.todayUsage != null)
                  Text(
                    'Today\'s AI Chatbot Usage: ${planProvider.todayUsage!.messageCount} / ${planProvider.plans.firstWhere((p) => p.id == planProvider.activeSubscription?.planId, orElse: () => PlanModel(id: '', name: '', dailyMessageLimit: 0, price: 0, duration: '', description: '', sortOrder: 0)).dailyMessageLimit}',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context, PlanModel plan,
      String? adminBankDetails, String userId) {
    final planProvider = Provider.of<PlanProvider>(context, listen: false);
    final paymentService = PaymentService();
    final storageService = StorageService();
    final days = _planValidityDays(plan.duration);
    final validUntil =
        days > 0 ? DateTime.now().add(Duration(days: days)) : DateTime.now();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final accent = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;
        final imagePicker = ImagePicker();
        final billingCycle = _deriveBillingCycle(plan.duration);

        XFile? selectedReceiptFile;
        bool isUploadingReceipt = false;
        bool isSubmitting = false;

        Future<void> pickReceiptFromGallery(StateSetter setDialogState) async {
          try {
            final picked = await imagePicker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 85,
              maxWidth: 1280,
              maxHeight: 1280,
            );
            if (picked == null) return;
            setDialogState(() {
              selectedReceiptFile = picked;
            });
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error picking receipt: $e')),
              );
            }
          }
        }

        Future<void> takeReceiptPhoto(StateSetter setDialogState) async {
          try {
            final picked = await imagePicker.pickImage(
              source: ImageSource.camera,
              imageQuality: 85,
              maxWidth: 1280,
              maxHeight: 1280,
            );
            if (picked == null) return;
            setDialogState(() {
              selectedReceiptFile = picked;
            });
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error taking receipt photo: $e')),
              );
            }
          }
        }

        Future<void> submitPurchase(StateSetter setDialogState) async {
          if (selectedReceiptFile == null) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Please upload a payment receipt')),
              );
            }
            return;
          }

          print('[SubmitPurchase] Receipt ready, setting uploading state...');
          setDialogState(() {
            isUploadingReceipt = true;
            isSubmitting = true;
          });

          try {
            String receiptUrl = '';
            final receiptBytes = await selectedReceiptFile!.readAsBytes();

            if (receiptBytes.isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Selected receipt is empty. Choose another image.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
              return;
            }

            if (receiptBytes.lengthInBytes > 8 * 1024 * 1024) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Receipt image is too large. Please select an image under 8MB.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
              return;
            }

            try {
              receiptUrl = await storageService.uploadImageBytes(
                receiptBytes,
                'plan_payment_receipts/$userId/${plan.id}',
                'receipt_${DateTime.now().millisecondsSinceEpoch}',
                fileName: selectedReceiptFile!.name,
              );
            } catch (uploadError) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Upload failed: ${uploadError.toString()}'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
              if (context.mounted) {
                setDialogState(() {
                  isUploadingReceipt = false;
                  isSubmitting = false;
                });
              }
              return;
            }

            if (receiptUrl.isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Upload failed: No URL returned'),
                    backgroundColor: AppColors.error,
                  ),
                );
                setDialogState(() {
                  isUploadingReceipt = false;
                  isSubmitting = false;
                });
              }
              return;
            }

            await planProvider.createSubscriptionRequest(
              userId: userId,
              planId: plan.id,
              paymentReceiptUrl: receiptUrl,
              planName: plan.name,
              planDuration: plan.duration,
              planPrice: plan.price.toDouble(),
              billingCycle: billingCycle,
            );

            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep,
                  content: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textPrimary
                            : AppColors.textOnBrand,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Purchase request submitted. Awaiting admin verification.',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.textPrimary
                                    : AppColors.textOnBrand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${e.toString()}'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          } finally {
            if (context.mounted) {
              setDialogState(() {
                isUploadingReceipt = false;
                isSubmitting = false;
              });
            }
          }
        }

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF262626) : AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          title: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.brandBlue, accent],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.workspace_premium_outlined,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Purchase ${plan.name}',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Follow the same checkout steps used for session payments',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textTertiary,
                        fontSize: 12.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: FutureBuilder<Map<String, dynamic>?>(
            future: paymentService.getPlatformBankDetails(),
            builder: (context, snapshot) {
              final bankDetails = snapshot.data;

              String detailValue(String key) =>
                  (bankDetails?[key] as String?) ?? '';

              final hasBankDetails = bankDetails != null &&
                  (detailValue('bankName').isNotEmpty ||
                      detailValue('accountHolder').isNotEmpty ||
                      detailValue('accountNumber').isNotEmpty ||
                      detailValue('iban').isNotEmpty);

              return StatefulBuilder(
                builder: (context, setDialogState) {
                  final stepBorderColor = accent.withOpacity(0.15);

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PurchaseStepCard(
                          stepNumber: 1,
                          title: 'Transfer details',
                          accent: accent,
                          isDark: isDark,
                          child: snapshot.connectionState ==
                                  ConnectionState.waiting
                              ? Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: accent,
                                    ),
                                  ),
                                )
                              : hasBankDetails
                                  ? Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1F1F1F)
                                            : AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: stepBorderColor,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          _BankDetailRow(
                                            label: 'Account Holder',
                                            value: detailValue('accountHolder'),
                                            icon: Icons.person_outline,
                                            accent: accent,
                                            isDark: isDark,
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            height: 1,
                                            color: isDark
                                                ? const Color(0xFF3A3A3A)
                                                : accent.withOpacity(0.10),
                                          ),
                                          const SizedBox(height: 12),
                                          _BankDetailRow(
                                            label: 'Bank Name',
                                            value: detailValue('bankName'),
                                            icon:
                                                Icons.account_balance_outlined,
                                            accent: accent,
                                            isDark: isDark,
                                          ),
                                          if (detailValue('iban')
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Container(
                                              height: 1,
                                              color: isDark
                                                  ? const Color(0xFF3A3A3A)
                                                  : accent.withOpacity(0.10),
                                            ),
                                            const SizedBox(height: 12),
                                            _BankDetailRow(
                                              label: 'IBAN',
                                              value: detailValue('iban'),
                                              icon: Icons.numbers_outlined,
                                              accent: accent,
                                              isDark: isDark,
                                            ),
                                          ],
                                          const SizedBox(height: 12),
                                          Container(
                                            height: 1,
                                            color: isDark
                                                ? const Color(0xFF3A3A3A)
                                                : accent.withOpacity(0.10),
                                          ),
                                          const SizedBox(height: 12),
                                          _BankDetailRow(
                                            label: 'Account Number',
                                            value: detailValue('accountNumber'),
                                            icon: Icons.credit_card_outlined,
                                            accent: accent,
                                            isDark: isDark,
                                          ),
                                        ],
                                      ),
                                    )
                                  : _DialogNotice(
                                      title: 'Bank details unavailable',
                                      message:
                                          'The admin has not configured bank details yet.',
                                      isDark: isDark,
                                      accent: accent,
                                    ),
                        ),
                        const SizedBox(height: 12),
                        _PurchaseStepCard(
                          stepNumber: 2,
                          title: 'Plan validity',
                          accent: AppColors.brandBlue,
                          isDark: isDark,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1F1F1F)
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.brandBlue.withOpacity(0.18),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Duration: ${plan.duration}',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  days > 0
                                      ? 'Estimated valid until ${DateFormat('dd MMM yyyy').format(validUntil)} after activation.'
                                      : 'This plan becomes active after admin verification.',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.textSecondary
                                        : AppColors.textTertiary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PurchaseStepCard(
                          stepNumber: 3,
                          title: 'Upload receipt',
                          accent: AppColors.brandBlue,
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 24, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1F1F1F)
                                      : AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        AppColors.brandBlue.withOpacity(0.18),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppColors.brandBlue
                                            .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.image_outlined,
                                        size: 28,
                                        color: AppColors.brandBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Upload Payment Receipt',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Pick a screenshot or photo of your payment confirmation',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? AppColors.textSecondary
                                            : AppColors.textTertiary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (selectedReceiptFile != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1F1F1F)
                                        : AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          AppColors.brandBlue.withOpacity(0.18),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: SizedBox(
                                          height: 180,
                                          width: double.infinity,
                                          child: FutureBuilder<Uint8List>(
                                            future: selectedReceiptFile!
                                                .readAsBytes(),
                                            builder:
                                                (context, previewSnapshot) {
                                              if (previewSnapshot
                                                      .connectionState ==
                                                  ConnectionState.waiting) {
                                                return Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: accent,
                                                  ),
                                                );
                                              }

                                              final previewBytes =
                                                  previewSnapshot.data;
                                              if (previewBytes == null ||
                                                  previewBytes.isEmpty) {
                                                return Container(
                                                  color: isDark
                                                      ? const Color(0xFF2A2A2A)
                                                      : const Color(0xFFF2F2F2),
                                                  alignment: Alignment.center,
                                                  child: Icon(
                                                    Icons.broken_image_outlined,
                                                    color: isDark
                                                        ? Colors.white54
                                                        : Colors.black45,
                                                  ),
                                                );
                                              }

                                              return Image.memory(
                                                previewBytes,
                                                fit: BoxFit.cover,
                                                cacheWidth: 720,
                                                filterQuality:
                                                    FilterQuality.low,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.receipt_long,
                                            color: AppColors.brandBlue,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              selectedReceiptFile!.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white
                                                    : AppColors.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Receipt selected successfully',
                                        style: TextStyle(
                                          color: isDark
                                              ? AppColors.textSecondary
                                              : AppColors.textTertiary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                _DialogNotice(
                                  title: 'No receipt selected',
                                  message:
                                      'Choose a receipt image from your device to continue.',
                                  isDark: isDark,
                                  accent: AppColors.brandBlue,
                                ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          isUploadingReceipt || isSubmitting
                                              ? null
                                              : () => pickReceiptFromGallery(
                                                  setDialogState),
                                      icon: const Icon(
                                          Icons.photo_library_outlined,
                                          size: 18),
                                      label: Text(
                                        selectedReceiptFile == null
                                            ? 'Choose Receipt'
                                            : 'Change Receipt',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.brandBlue
                                            .withOpacity(0.12),
                                        foregroundColor: AppColors.brandBlue,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 13,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: isUploadingReceipt ||
                                              isSubmitting
                                          ? null
                                          : () =>
                                              takeReceiptPhoto(setDialogState),
                                      icon: const Icon(
                                          Icons.camera_alt_outlined,
                                          size: 18),
                                      label: const Text(
                                        'Take Photo',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark
                                            ? const Color(0xFF343434)
                                            : AppColors.surface,
                                        foregroundColor: isDark
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 13,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          side: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF4A4A4A)
                                                : Colors.grey.withOpacity(0.25),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (isUploadingReceipt) ...[
                                const SizedBox(height: 12),
                                Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: AppColors.textOnBrand,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: isUploadingReceipt || isSubmitting
                                      ? null
                                      : () => submitPurchase(setDialogState),
                                  child: const Text(
                                    'Submit receipt',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed:
                  isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color:
                      isDark ? AppColors.textSecondary : AppColors.textTertiary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  int _planValidityDays(String duration) {
    switch (duration.trim().toLowerCase()) {
      case 'monthly':
        return 30;
      case 'yearly':
        return 365;
      case 'free':
        return 0;
      default:
        return 30;
    }
  }

  String _deriveBillingCycle(String duration) {
    final normalized = duration.trim().toLowerCase();
    if (normalized.contains('year')) return 'yearly';
    if (normalized.contains('month')) return 'monthly';
    if (normalized == 'free') return 'free';
    return 'custom';
  }
}

class _PlanBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final bool highlight;

  const _PlanBadge({
    required this.icon,
    required this.label,
    required this.isDark,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = highlight ? AppColors.brandGreenDeep : AppColors.brandBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withOpacity(isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseStepCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final Widget child;
  final Color accent;
  final bool isDark;

  const _PurchaseStepCard({
    required this.stepNumber,
    required this.title,
    required this.child,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B1B) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DialogNotice extends StatelessWidget {
  final String title;
  final String message;
  final bool isDark;
  final Color accent;

  const _DialogNotice({
    required this.title,
    required this.message,
    required this.isDark,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              color: isDark ? AppColors.textSecondary : AppColors.textTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BankDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool isDark;

  const _BankDetailRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
