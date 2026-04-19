import 'package:flutter/material.dart';
import 'package:genzfit/services/withdrawal_service.dart';
import 'package:genzfit/models/withdrawal_request_model.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminWithdrawalManagementScreen extends StatefulWidget {
  const AdminWithdrawalManagementScreen({super.key});

  @override
  State<AdminWithdrawalManagementScreen> createState() =>
      _AdminWithdrawalManagementScreenState();
}

class _AdminWithdrawalManagementScreenState
    extends State<AdminWithdrawalManagementScreen> {
  final WithdrawalService _withdrawalService = WithdrawalService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Withdrawal Requests'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: StreamBuilder<List<WithdrawalRequestModel>>(
        stream: _withdrawalService.getPendingWithdrawals(),
        builder: (context, snapshot) {
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
                    'No pending withdrawal requests',
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
              return _buildWithdrawalRequestCard(context, request);
            },
          );
        },
      ),
    );
  }

  Widget _buildWithdrawalRequestCard(
    BuildContext context,
    WithdrawalRequestModel request,
  ) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(request.trainerId)
          .get(),
      builder: (context, userSnapshot) {
        final trainerName = userSnapshot.data?.get('name') ?? 'Unknown Trainer';
        final trainerEmail = userSnapshot.data?.get('email') ?? '';

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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trainerName,
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
                        trainerEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(request.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      request.status.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(request.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Withdrawal amount
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
                    Text(
                      'Withdrawal Amount',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey
                            : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Rs. ${request.amount.toStringAsFixed(2)}',
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

              // Bank details
              FutureBuilder<DocumentSnapshot?>(
                future:
                    _getBankDetails(request.trainerId, request.bankDetailsId),
                builder: (context, bankSnapshot) {
                  if (bankSnapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }

                  if (!bankSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final bankData =
                      bankSnapshot.data?.data() as Map<String, dynamic>?;
                  if (bankData == null) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bank Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bank: ${bankData['bankName'] ?? ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Account: ${(bankData['accountNumber'] as String?)?.replaceRange(0, (bankData['accountNumber'] as String).length - 4, '*' * ((bankData['accountNumber'] as String).length - 4)) ?? ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Holder: ${bankData['accountName'] ?? ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),

              // Request date
              Text(
                'Requested: ${DateFormat('MMM dd, yyyy HH:mm').format(request.createdAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons
              if (request.status == WithdrawalStatus.requested)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showRejectDialog(context, request);
                        },
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _approveWithdrawal(context, request);
                        },
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                )
              else if (request.status == WithdrawalStatus.approved)
                ElevatedButton.icon(
                  onPressed: () {
                    _showCompleteDialog(context, request);
                  },
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('Mark as Completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<DocumentSnapshot?> _getBankDetails(
      String trainerId, String? bankDetailsId) async {
    if (bankDetailsId == null) return null;
    try {
      return await FirebaseFirestore.instance
          .collection('trainers')
          .doc(trainerId)
          .collection('bank_details')
          .doc(bankDetailsId)
          .get();
    } catch (e) {
      return null;
    }
  }

  Color _getStatusColor(WithdrawalStatus status) {
    switch (status) {
      case WithdrawalStatus.requested:
        return AppColors.warning;
      case WithdrawalStatus.approved:
        return Colors.blue;
      case WithdrawalStatus.processing:
        return Colors.cyan;
      case WithdrawalStatus.completed:
        return AppColors.success;
      case WithdrawalStatus.rejected:
      case WithdrawalStatus.failed:
        return AppColors.error;
    }
  }

  void _approveWithdrawal(
    BuildContext context,
    WithdrawalRequestModel request,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Withdrawal'),
        content: Text(
          'Are you sure you want to approve this withdrawal request for Rs. ${request.amount.toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _withdrawalService.approveWithdrawal(
                  withdrawalId: request.id,
                  trainerId: request.trainerId,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Withdrawal approved'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(
    BuildContext context,
    WithdrawalRequestModel request,
  ) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Withdrawal'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason',
            hintText: 'Enter reason for rejection',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a rejection reason'),
                  ),
                );
                return;
              }

              try {
                await _withdrawalService.rejectWithdrawal(
                  withdrawalId: request.id,
                  trainerId: request.trainerId,
                  rejectionReason: reasonController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Withdrawal rejected'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showCompleteDialog(
    BuildContext context,
    WithdrawalRequestModel request,
  ) {
    final transactionIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mark this withdrawal as completed and provide the transaction ID.',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: transactionIdController,
              decoration: const InputDecoration(
                labelText: 'Transaction ID',
                hintText: 'Enter bank transaction ID',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (transactionIdController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a transaction ID'),
                  ),
                );
                return;
              }

              try {
                await _withdrawalService.completeWithdrawal(
                  withdrawalId: request.id,
                  transactionId: transactionIdController.text,
                  trainerId: request.trainerId,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Withdrawal marked as completed'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }
}
