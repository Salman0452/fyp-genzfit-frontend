import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:genzfit/providers/plan_provider.dart';
import 'package:genzfit/utils/constants.dart';

class AdminSubscriptionRequestsScreen extends StatefulWidget {
  const AdminSubscriptionRequestsScreen({super.key});

  @override
  State<AdminSubscriptionRequestsScreen> createState() =>
      _AdminSubscriptionRequestsScreenState();
}

class _AdminSubscriptionRequestsScreenState
    extends State<AdminSubscriptionRequestsScreen> {
  String? _extractFirestoreIndexUrl(Object? error) {
    final errorText = error?.toString() ?? '';
    final match = RegExp(r'https://console\.firebase\.google\.com/[^\s)\]]+')
        .firstMatch(errorText);
    return match?.group(0);
  }

  Widget _buildQueryError(BuildContext context, Object? error) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorText = error?.toString() ?? 'Unknown error';
    final indexUrl = _extractFirestoreIndexUrl(error);

    debugPrint('Subscription requests Firestore error: $errorText');
    if (indexUrl != null) debugPrint('Firestore index URL: $indexUrl');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? Colors.red.shade300 : Colors.red.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              'Firestore Error',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              errorText,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? const Color(0xFFFFB4B4) : Colors.red.shade700,
              ),
            ),
            if (indexUrl != null) ...[
              const SizedBox(height: 16),
              SelectableText(
                indexUrl,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                  color: AppColors.brandGreenDeep,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: indexUrl));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Index link copied to clipboard')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy index link'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Subscription Requests'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: context.read<PlanProvider>().getPendingSubscriptionsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildQueryError(context, snapshot.error);
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 64,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No pending subscription requests',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _buildSubscriptionRequestCard(
                  context, request, context.read<PlanProvider>());
            },
          );
        },
      ),
    );
  }

  Widget _buildSubscriptionRequestCard(
    BuildContext context,
    Map<String, dynamic> request,
    PlanProvider planProvider,
  ) {
    final timestamp = request['timestamp'] as dynamic;
    final requestDate = timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(
            (timestamp.seconds ?? 0) * 1000,
          )
        : DateTime.now();

    final planDuration = _parseDuration(request['planDuration'] as String?);
    final billingCycle =
        (request['billingCycle'] as String? ?? '').trim().toLowerCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: AppColors.brandGreen.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with user info
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandGreen.withOpacity(0.2),
                ),
                child: (request['userAvatar'] as String?)?.isNotEmpty ?? false
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: request['userAvatar'] as String,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              Icon(Icons.person, color: AppColors.brandGreen),
                        ),
                      )
                    : Icon(Icons.person, color: AppColors.brandGreen),
              ),
              const SizedBox(width: 12),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['userName'] as String? ?? 'Unknown User',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request['userEmail'] as String? ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Timestamp
              Text(
                DateFormat('dd MMM, hh:mm a').format(requestDate),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Plan details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.brandGreen.withOpacity(0.1)
                  : AppColors.brandGreenDeep.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['planName'] as String? ?? 'Unknown Plan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${planDuration} days',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (billingCycle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Billing: ${billingCycle[0].toUpperCase()}${billingCycle.substring(1)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Rs. ${(request['planPrice'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Receipt image
          if ((request['receiptUrl'] as String?)?.isNotEmpty ?? false)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Receipt',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey
                            : AppColors.textSecondary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        _showReceiptViewer(
                          context,
                          request['receiptUrl'] as String,
                        );
                      },
                      icon: const Icon(Icons.open_in_full, size: 16),
                      label: const Text('View image'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black
                        : const Color(0xFFF4F4F4),
                    child: CachedNetworkImage(
                      imageUrl: request['receiptUrl'] as String,
                      fit: BoxFit.contain,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showApproveDialog(
                      context,
                      request,
                      planProvider,
                      planDuration,
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showRejectDialog(context, request, planProvider);
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(
    BuildContext context,
    Map<String, dynamic> request,
    PlanProvider planProvider,
    int planDuration,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final endDate = DateTime.now().add(Duration(days: planDuration));

        return AlertDialog(
          title: const Text('Approve Subscription Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Approving for: ${request['userName']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Plan: ${request['planName']}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Duration: $planDuration days',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'End Date: ${DateFormat('dd MMM yyyy').format(endDate)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8BDD3C),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _approveSubscription(
                  context,
                  dialogContext,
                  request,
                  planProvider,
                  planDuration,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );
  }

  void _showRejectDialog(
    BuildContext context,
    Map<String, dynamic> request,
    PlanProvider planProvider,
  ) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Subscription Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rejecting for: ${request['userName']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Rejection reason (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Enter reason for rejection...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _rejectSubscription(
                  context,
                  dialogContext,
                  request,
                  planProvider,
                  noteController.text,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _approveSubscription(
    BuildContext context,
    BuildContext dialogContext,
    Map<String, dynamic> request,
    PlanProvider planProvider,
    int planDuration,
  ) async {
    try {
      Navigator.pop(dialogContext); // Close dialog

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processing approval...'),
          duration: Duration(seconds: 2),
        ),
      );

      await planProvider.approveSubscription(
        docId: request['docId'] as String,
        durationDays: planDuration,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Subscription approved for ${request['userName']}',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectSubscription(
    BuildContext context,
    BuildContext dialogContext,
    Map<String, dynamic> request,
    PlanProvider planProvider,
    String adminNote,
  ) async {
    try {
      Navigator.pop(dialogContext); // Close dialog

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processing rejection...'),
          duration: Duration(seconds: 2),
        ),
      );

      await planProvider.rejectSubscription(
        docId: request['docId'] as String,
        adminNote: adminNote.isEmpty ? 'No reason provided' : adminNote,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Subscription rejected for ${request['userName']}',
            ),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showReceiptViewer(BuildContext context, String receiptUrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: isDark ? const Color(0xFF151515) : AppColors.surface,
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.of(dialogContext).size.height * 0.8,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Receipt Viewer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.black,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: CachedNetworkImage(
                          imageUrl: receiptUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.white70,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close and continue'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _parseDuration(String? durationStr) {
    if (durationStr == null || durationStr.isEmpty) return 30;

    final normalized = durationStr.toLowerCase().trim();
    if (normalized == 'free') return 0;
    if (normalized == 'monthly' || normalized == 'month') return 30;
    if (normalized == 'yearly' || normalized == 'year') return 365;

    // Parse "30 days", "1 month", "1 year" format
    final parts = durationStr.split(' ');
    if (parts.length >= 2) {
      final number = int.tryParse(parts[0]) ?? 1;
      final unit = parts[1].toLowerCase();

      if (unit.contains('year')) {
        return number * 365;
      } else if (unit.contains('month')) {
        return number * 30;
      } else if (unit.contains('day')) {
        return number;
      }
    }

    return 30; // Default 30 days
  }
}
