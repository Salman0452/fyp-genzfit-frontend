import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:genzfit/models/withdrawal_request_model.dart';
import 'package:genzfit/services/withdrawal_service.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/utils/download_helper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class FinancialManagementScreen extends StatefulWidget {
  const FinancialManagementScreen({super.key});

  @override
  State<FinancialManagementScreen> createState() =>
      _FinancialManagementScreenState();
}

class _FinancialManagementScreenState extends State<FinancialManagementScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WithdrawalService _withdrawalService = WithdrawalService();
  late TabController _tabController;
  bool _isAccessLoading = true;
  bool _canManageFinance = false;

  double _totalRevenue = 0.0;
  double _platformRevenue = 0.0;
  double _pendingPayouts = 0.0;
  double _commissionRate = 0.20; // 20% default
  String _payoutStatusFilter = 'all';
  int _payoutLimit = 100;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFinancialSummary();
    _loadCommissionRate();
    _loadRoleAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCommissionRate() async {
    try {
      final settingsDoc = await _firestore
          .collection('platform_settings')
          .doc('commission')
          .get();
      if (settingsDoc.exists) {
        final rate = settingsDoc.data()?['rate'] as num?;
        if (rate != null) {
          setState(() => _commissionRate = rate.toDouble());
        }
      }
    } catch (e) {
      print('Error loading commission rate: $e');
    }
  }

  Future<void> _loadRoleAccess() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _isAccessLoading = false;
          _canManageFinance = false;
        });
        return;
      }

      final userDoc = await _firestore.collection('users').doc(uid).get();
      final role = userDoc.data()?['role'] as String? ?? '';

      setState(() {
        _isAccessLoading = false;
        _canManageFinance = role == 'admin' || role == 'finance_admin';
      });
    } catch (_) {
      setState(() {
        _isAccessLoading = false;
        _canManageFinance = false;
      });
    }
  }

  Future<void> _loadFinancialSummary() async {
    try {
      final ledgerSnapshot = await _firestore
          .collection('earnings_ledger')
          .where('type', isEqualTo: 'session_payment')
          .get();

      final pendingWithdrawalsSnapshot = await _firestore
          .collection('withdrawal_requests')
          .where('status', whereIn: ['requested', 'approved', 'processing'])
          .get();

      double totalRev = 0.0;
      double platformRev = 0.0;
      double pending = 0.0;

      for (var doc in ledgerSnapshot.docs) {
        final data = doc.data();
        final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final platformFee = (data['platformFee'] as num?)?.toDouble() ?? 0.0;

        totalRev += totalAmount;
        platformRev += platformFee;
      }

      for (var doc in pendingWithdrawalsSnapshot.docs) {
        final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
        pending += amount;
      }

      setState(() {
        _totalRevenue = totalRev;
        _platformRevenue = platformRev;
        _pendingPayouts = pending;
      });
    } catch (e) {
      print('Error loading financial summary: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAccessLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_canManageFinance) {
      return Scaffold(
        appBar: AppBar(title: const Text('Financial Management')),
        body: const Center(
          child: Text('You do not have permission to manage finances.'),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Financial Management',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: brandGreen,
          labelColor: brandGreen,
          unselectedLabelColor:
              isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary,
          labelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Payouts'),
            Tab(text: 'Refunds'),
            Tab(text: 'Revenue'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Export Payouts CSV',
            onPressed: _exportPayoutsCsv,
            icon: const Icon(Icons.download),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFinancialSummary(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPayoutsTab(),
                _buildRefundsTab(),
                _buildRevenueBreakdownTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;
    final greenColor =
        isDark ? const Color(0xFF7FFA88) : const Color(0xFF66BB6A);
    final orangeColor =
        isDark ? Colors.orange.shade400 : Colors.orange.shade700;

    return Container(
      padding: const EdgeInsets.all(16),
      color: cardBackground,
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Revenue',
              '\$${_totalRevenue.toStringAsFixed(2)}',
              Icons.attach_money,
              greenColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Platform Share',
              '\$${_platformRevenue.toStringAsFixed(2)}',
              Icons.account_balance,
              brandGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Pending Payouts',
              '\$${_pendingPayouts.toStringAsFixed(2)}',
              Icons.pending_actions,
              orangeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardInnerBackground =
        isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardInnerBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutsTab() {
    Query<Map<String, dynamic>> query = _firestore
        .collection('withdrawal_requests')
        .orderBy('createdAt', descending: true);

    if (_payoutStatusFilter != 'all') {
      query = query.where('status', isEqualTo: _payoutStatusFilter);
    }

    query = query.limit(_payoutLimit);

    return Column(
      children: [
        _buildPayoutStatusFilters(),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: GoogleFonts.inter(color: Colors.red),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF83BCB5)),
                );
              }

              final requests = snapshot.data?.docs ?? [];

              if (requests.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No withdrawal requests',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request =
                            WithdrawalRequestModel.fromFirestore(requests[index]);
                        return _buildPayoutCard(request);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _payoutLimit += 100;
                          });
                        },
                        icon: const Icon(Icons.expand_more),
                        label: Text('Load More (${requests.length})'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPayoutStatusFilters() {
    final statuses = [
      'all',
      'requested',
      'approved',
      'processing',
      'completed',
      'rejected',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: statuses.map((status) {
            final selected = _payoutStatusFilter == status;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(status[0].toUpperCase() + status.substring(1)),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _payoutStatusFilter = status;
                    _payoutLimit = 100;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPayoutCard(WithdrawalRequestModel request) {
    final amount = request.amount;
    final trainerId = request.trainerId;
    final createdAt = request.createdAt;
    final status = request.status;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF171917),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _withdrawalStatusColor(status).withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _withdrawalStatusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.payments,
                    color: _withdrawalStatusColor(status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Withdrawal #${request.id.substring(0, 8)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Requested ${DateFormat('MMM dd, yyyy • HH:mm').format(createdAt)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rs. ${amount.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF7FFA88),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _withdrawalStatusColor(status).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _withdrawalStatusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _firestore.collection('users').doc(trainerId).get(),
              builder: (context, snapshot) {
                final trainerName = snapshot.data?.data()?['name'] as String?;
                return Text(
                  'Trainer: ${trainerName ?? trainerId}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            _buildPayoutActions(request),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutActions(WithdrawalRequestModel request) {
    final adminId = FirebaseAuth.instance.currentUser?.uid;

    if (request.status == WithdrawalStatus.requested) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showWithdrawalRejectDialog(request, adminId),
              icon: const Icon(Icons.close),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                await _withdrawalService.approveWithdrawal(
                  withdrawalId: request.id,
                  trainerId: request.trainerId,
                  adminId: adminId,
                );
              },
              icon: const Icon(Icons.check),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    if (request.status == WithdrawalStatus.approved) {
      return ElevatedButton.icon(
        onPressed: () async {
          await _withdrawalService.markWithdrawalProcessing(
            withdrawalId: request.id,
            trainerId: request.trainerId,
            adminId: adminId,
          );
        },
        icon: const Icon(Icons.sync),
        label: const Text('Mark Processing'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 44),
        ),
      );
    }

    if (request.status == WithdrawalStatus.processing ||
        request.status == WithdrawalStatus.approved) {
      return ElevatedButton.icon(
        onPressed: () => _showCompleteWithdrawalDialog(request, adminId),
        icon: const Icon(Icons.done_all),
        label: const Text('Complete Payout'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7FFA88),
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 44),
        ),
      );
    }

    if (request.status == WithdrawalStatus.completed) {
      return Text(
        'Bank Ref: ${request.transactionId ?? 'N/A'}',
        style: GoogleFonts.inter(
          color: Colors.white70,
          fontSize: 12,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _showWithdrawalRejectDialog(
    WithdrawalRequestModel request,
    String? adminId,
  ) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Withdrawal'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await _withdrawalService.rejectWithdrawal(
                withdrawalId: request.id,
                trainerId: request.trainerId,
                rejectionReason: controller.text.trim(),
                adminId: adminId,
              );
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCompleteWithdrawalDialog(
    WithdrawalRequestModel request,
    String? adminId,
  ) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Payout'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Bank Transaction ID',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await _withdrawalService.completeWithdrawal(
                withdrawalId: request.id,
                transactionId: controller.text.trim(),
                trainerId: request.trainerId,
                adminId: adminId,
              );
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7FFA88),
              foregroundColor: Colors.black,
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPayoutsCsv() async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('withdrawal_requests')
          .orderBy('createdAt', descending: true);

      if (_payoutStatusFilter != 'all') {
        query = query.where('status', isEqualTo: _payoutStatusFilter);
      }

      query = query.limit(_payoutLimit);
      final snapshot = await query.get();

      final rows = <String>[
        'withdrawalId,trainerId,trainerName,amount,status,createdAt,processedAt,completedAt,transactionId,rejectionReason'
      ];

      for (final doc in snapshot.docs) {
        final request = WithdrawalRequestModel.fromFirestore(doc);
        final trainerDoc =
            await _firestore.collection('users').doc(request.trainerId).get();
        final trainerName = trainerDoc.data()?['name'] as String? ?? '';

        rows.add(
          [
            request.id,
            request.trainerId,
            trainerName,
            request.amount.toStringAsFixed(2),
            request.status.name,
            request.createdAt.toIso8601String(),
            request.processedAt?.toIso8601String() ?? '',
            request.completedAt?.toIso8601String() ?? '',
            request.transactionId ?? '',
            request.rejectionReason ?? '',
          ].map(_csvCell).join(','),
        );
      }

      final content = rows.join('\n');
      if (kIsWeb) {
        downloadCsvFile(
          content,
          'payouts_${_payoutStatusFilter}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? 'Payout queue exported'
                  : 'CSV export is only supported on web',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export CSV: $e')),
      );
    }
  }

  String _csvCell(Object? value) {
    final text = (value ?? '').toString().replaceAll('"', '""');
    return '"$text"';
  }

  Color _withdrawalStatusColor(WithdrawalStatus status) {
    switch (status) {
      case WithdrawalStatus.requested:
        return Colors.orange;
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

  Widget _buildRefundsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('refund_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF83BCB5)),
          );
        }

        final refunds = snapshot.data?.docs ?? [];

        if (refunds.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                Text(
                  'No pending refunds',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _createTestRefund(),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Test Refund'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF83BCB5)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: refunds.length,
          itemBuilder: (context, index) {
            final refund = refunds[index].data() as Map<String, dynamic>;
            final refundId = refunds[index].id;
            return _buildRefundCard(refund, refundId);
          },
        );
      },
    );
  }

  Widget _buildRefundCard(Map<String, dynamic> refund, String refundId) {
    final amount = (refund['amount'] as num?)?.toDouble() ?? 0.0;
    final reason = refund['reason'] as String? ?? 'No reason provided';
    final userId = refund['userId'] as String? ?? '';
    final createdAt = (refund['createdAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF171917),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.money_off, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refund Request',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          DateFormat('MMM dd, yyyy • hh:mm a')
                              .format(createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white38,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Reason',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white38,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reason,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(userId).get(),
              builder: (context, snapshot) {
                final userName = snapshot.data?.data() != null
                    ? (snapshot.data!.data() as Map<String, dynamic>)['name']
                            as String? ??
                        'Unknown'
                    : 'Loading...';
                return Text(
                  'User: $userName',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _processRefund(refundId, userId, amount),
                    icon: const Icon(Icons.check),
                    label: Text(
                      'Approve Refund',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7FFA88),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectRefund(refundId),
                    icon: const Icon(Icons.close),
                    label: Text(
                      'Reject',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueBreakdownTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('sessions')
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF83BCB5)),
          );
        }

        final sessions = snapshot.data?.docs ?? [];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index].data() as Map<String, dynamic>;
            final sessionId = sessions[index].id;
            return _buildRevenueCard(session, sessionId);
          },
        );
      },
    );
  }

  Widget _buildRevenueCard(Map<String, dynamic> session, String sessionId) {
    final amount = (session['amount'] as num?)?.toDouble() ?? 0.0;
    final platformAmount = amount * _commissionRate;
    final isPaid = session['trainerPaid'] as bool? ?? false;
    final completedAt = (session['completedAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF171917),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7FFA88).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.attach_money,
                  color: Color(0xFF7FFA88), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session #${sessionId.substring(0, 8)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (completedAt != null)
                    Text(
                      DateFormat('MMM dd, yyyy').format(completedAt),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${platformAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF83BCB5),
                  ),
                ),
                Text(
                  isPaid ? 'Paid' : 'Pending',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isPaid ? const Color(0xFF7FFA88) : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processRefund(
      String refundId, String userId, double amount) async {
    try {
      await _firestore.collection('refund_requests').doc(refundId).update({
        'status': 'approved',
        'processedAt': FieldValue.serverTimestamp(),
      });

      // TODO: Integrate with payment gateway to process actual refund

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refund processed successfully'),
            backgroundColor: Color(0xFF7FFA88),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectRefund(String refundId) async {
    try {
      await _firestore.collection('refund_requests').doc(refundId).update({
        'status': 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refund rejected'),
            backgroundColor: Color(0xFF7FFA88),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createTestRefund() async {
    try {
      await _firestore.collection('refund_requests').add({
        'userId': 'test_user_id',
        'sessionId': 'test_session_id',
        'amount': 50.0,
        'reason': 'Test refund request - Session cancelled by trainer',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test refund created'),
            backgroundColor: Color(0xFF7FFA88),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
