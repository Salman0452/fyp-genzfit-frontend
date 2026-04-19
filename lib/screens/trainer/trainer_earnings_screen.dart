import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:genzfit/providers/auth_provider.dart';
import 'package:genzfit/services/withdrawal_service.dart';
import 'package:genzfit/models/bank_details_model.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/widgets/custom_button.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrainerEarningsScreen extends StatefulWidget {
  const TrainerEarningsScreen({super.key});

  @override
  State<TrainerEarningsScreen> createState() => _TrainerEarningsScreenState();
}

class _TrainerEarningsScreenState extends State<TrainerEarningsScreen> {
  final WithdrawalService _withdrawalService = WithdrawalService();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final trainerId = authProvider.user?.uid ?? '';

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Earnings & Withdrawals'),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          bottom: TabBar(
            labelColor: AppColors.brandGreen,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Bank Details'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(trainerId),
            _buildBankDetailsTab(trainerId),
            _buildHistoryTab(trainerId),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(String trainerId) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance card
          FutureBuilder<double>(
            future: _withdrawalService.getAvailableBalance(trainerId),
            builder: (context, snapshot) {
              final balance = snapshot.data ?? 0.0;
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.brandGreen,
                      AppColors.brandGreenDeep,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Balance',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Rs. ${balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Quick actions
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: 'Request Withdrawal',
              onPressed: () {
                _showWithdrawalDialog(context, trainerId);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetailsTab(String trainerId) {
    return StreamBuilder<List<BankDetailsModel>>(
      stream: _withdrawalService.getTrainerBankDetails(trainerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final bankDetails = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bank Accounts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (bankDetails.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No bank accounts added',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey
                                    : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bankDetails.length,
                  itemBuilder: (context, index) {
                    final bank = bankDetails[index];
                    return _buildBankDetailsCard(context, bank, trainerId);
                  },
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Add Bank Account',
                  onPressed: () {
                    _showAddBankDetailsDialog(context, trainerId);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBankDetailsCard(
      BuildContext context, BankDetailsModel bank, String trainerId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: bank.verificationStatus == BankVerificationStatus.verified
              ? AppColors.success
              : AppColors.warning,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bank.bankName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      bank.verificationStatus == BankVerificationStatus.verified
                          ? AppColors.success.withOpacity(0.2)
                          : AppColors.warning.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  bank.verificationStatus == BankVerificationStatus.verified
                      ? 'Verified'
                      : 'Pending',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: bank.verificationStatus ==
                            BankVerificationStatus.verified
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Account Holder: ${bank.accountHolderName}',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Account Number: ${bank.maskedAccountNumber}',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showEditBankDetailsDialog(context, bank, trainerId);
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Delete bank details
                  },
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(String trainerId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _withdrawalService.getPaymentHistory(trainerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final history = snapshot.data ?? [];

        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                Text(
                  'No transaction history',
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
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            return _buildHistoryItem(context, item);
          },
        );
      },
    );
  }

  Widget _buildHistoryItem(BuildContext context, Map<String, dynamic> item) {
    final type = item['type'] as String;
    final amount = item['amount'] as double;
    final description = item['description'] as String;
    final createdAt = (item['createdAt'] as Timestamp).toDate();

    IconData icon;
    Color color;

    switch (type) {
      case 'session_completed':
        icon = Icons.add_circle;
        color = AppColors.success;
        break;
      case 'withdrawal_requested':
        icon = Icons.remove_circle;
        color = AppColors.warning;
        break;
      case 'withdrawal_completed':
        icon = Icons.check_circle;
        color = AppColors.success;
        break;
      case 'withdrawal_rejected':
        icon = Icons.cancel;
        color = AppColors.error;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy HH:mm').format(createdAt),
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
          Text(
            '${amount > 0 ? '+' : '-'}Rs. ${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: amount > 0 ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  void _showWithdrawalDialog(BuildContext context, String trainerId) {
    final amountController = TextEditingController();
    String? selectedBankId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Withdrawal'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return StreamBuilder<List<BankDetailsModel>>(
              stream: _withdrawalService.getTrainerBankDetails(trainerId),
              builder: (context, snapshot) {
                final bankDetails = snapshot.data ?? [];
                final verifiedBanks = bankDetails
                    .where((b) =>
                        b.verificationStatus == BankVerificationStatus.verified)
                    .toList();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Withdrawal Amount (Rs.)',
                        hintText: 'Enter amount',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (verifiedBanks.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Please add and verify a bank account first',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      DropdownButton<String>(
                        value: selectedBankId,
                        hint: const Text('Select Bank Account'),
                        isExpanded: true,
                        items: verifiedBanks.map((bank) {
                          return DropdownMenuItem(
                            value: bank.id,
                            child: Text(
                                '${bank.bankName} - ${bank.accountNumber.substring(bank.accountNumber.length - 4)}'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => selectedBankId = value);
                        },
                      ),
                  ],
                );
              },
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }
              if (selectedBankId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a bank account')),
                );
                return;
              }

              try {
                await _withdrawalService.requestWithdrawal(
                  trainerId: trainerId,
                  amount: amount,
                  bankDetailsId: selectedBankId!,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Withdrawal request submitted successfully'),
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
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  void _showAddBankDetailsDialog(BuildContext context, String trainerId) {
    final nameController = TextEditingController();
    final accountController = TextEditingController();
    final bankController = TextEditingController();
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bank Account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: 'Account Holder Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountController,
                decoration: const InputDecoration(labelText: 'Account Number'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bankController,
                decoration: const InputDecoration(labelText: 'Bank Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration:
                    const InputDecoration(labelText: 'Bank Code (Optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  accountController.text.isEmpty ||
                  bankController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please fill all required fields')),
                );
                return;
              }

              try {
                await _withdrawalService.addBankDetails(
                  trainerId: trainerId,
                  accountName: nameController.text,
                  accountNumber: accountController.text,
                  bankName: bankController.text,
                  bankCode:
                      codeController.text.isEmpty ? null : codeController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Bank account added. Awaiting admin verification.'),
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
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditBankDetailsDialog(
      BuildContext context, BankDetailsModel bank, String trainerId) {
    final nameController = TextEditingController(text: bank.accountHolderName);
    final accountController = TextEditingController(text: bank.accountNumber);
    final bankController = TextEditingController(text: bank.bankName);
    final codeController = TextEditingController(text: bank.iban ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bank Account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: 'Account Holder Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountController,
                decoration: const InputDecoration(labelText: 'Account Number'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bankController,
                decoration: const InputDecoration(labelText: 'Bank Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration:
                    const InputDecoration(labelText: 'Bank Code (Optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  accountController.text.isEmpty ||
                  bankController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please fill all required fields')),
                );
                return;
              }

              try {
                await _withdrawalService.updateBankDetails(
                  trainerId: trainerId,
                  bankDetailsId: bank.id,
                  accountName: nameController.text,
                  accountNumber: accountController.text,
                  bankName: bankController.text,
                  bankCode:
                      codeController.text.isEmpty ? null : codeController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Bank account updated. Awaiting re-verification.'),
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
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
