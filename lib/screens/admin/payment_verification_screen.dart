import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:genzfit/models/transaction_model.dart';
import 'package:genzfit/services/payment_service.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/utils/download_helper.dart';
import 'package:intl/intl.dart';

class PaymentVerificationScreen extends StatefulWidget {
  const PaymentVerificationScreen({super.key});

  @override
  State<PaymentVerificationScreen> createState() =>
      _PaymentVerificationScreenState();
}

class _PaymentVerificationScreenState extends State<PaymentVerificationScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PaymentService _paymentService = PaymentService();
  final ScrollController _pendingTableHorizontalScrollController =
      ScrollController();
  late TabController _tabController;
  bool _isAccessLoading = true;
  bool _canManagePayments = false;
  int _pendingLimit = 100;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRoleAccess();
  }

  @override
  void dispose() {
    _pendingTableHorizontalScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRoleAccess() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _isAccessLoading = false;
          _canManagePayments = false;
        });
        return;
      }

      final userDoc = await _firestore.collection('users').doc(uid).get();
      final role = userDoc.data()?['role'] as String? ?? '';

      setState(() {
        _isAccessLoading = false;
        _canManagePayments =
            role == 'admin' ||
            role == 'super_admin' ||
            role == 'finance_admin' ||
            role == 'financeAdmin';
      });
    } catch (_) {
      setState(() {
        _isAccessLoading = false;
        _canManagePayments = false;
      });
    }
  }

  Future<void> _verifyPayment(
    String transactionId,
    String _,
  ) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin authentication required'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      await _paymentService.verifyPayment(
        transactionId: transactionId,
        approved: true,
        adminId: adminId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment verified successfully'),
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
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectPayment(
    String transactionId,
    String _,
    String reason,
  ) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin authentication required'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      await _paymentService.verifyPayment(
        transactionId: transactionId,
        approved: false,
        adminId: adminId,
        rejectionReason: reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment rejected'),
            backgroundColor: AppColors.error,
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

  @override
  Widget build(BuildContext context) {
    if (_isAccessLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_canManagePayments) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment Verification')),
        body: const Center(
          child: Text('You do not have permission to manage payments.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        elevation: 0,
        title: const Text(
          'Payment Verification',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.brandGreen
              : AppColors.brandGreenDeep,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.brandGreen
              : AppColors.brandGreenDeep,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Verified'),
            Tab(text: 'Rejected'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Export Pending CSV',
            onPressed: _exportPendingPaymentsCsv,
            icon: const Icon(Icons.download),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingPaymentsTab(),
          _buildVerifiedPaymentsTab(),
          _buildRejectedPaymentsTab(),
        ],
      ),
    );
  }

  Widget _buildPendingPaymentsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('transactions')
          .where('status', isEqualTo: 'pendingVerification')
          .orderBy('createdAt', descending: true)
          .limit(_pendingLimit)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No pending payments',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: RawScrollbar(
                  controller: _pendingTableHorizontalScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  thickness: 10,
                  radius: const Radius.circular(10),
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  child: SingleChildScrollView(
                    controller: _pendingTableHorizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.resolveWith(
                        (states) => Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF3F3F3),
                      ),
                      columns: const [
                        DataColumn(label: Text('Transaction')),
                        DataColumn(label: Text('Client')),
                        DataColumn(label: Text('Trainer')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('Submitted')),
                        DataColumn(label: Text('Aging')),
                        DataColumn(label: Text('Receipt')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: docs.map((doc) {
                        final transaction = TransactionModel.fromFirestore(doc);
                        final hasReceipt =
                            (transaction.clientPaymentProofUrl ?? '').trim().isNotEmpty;
                        final aging = DateTime.now().difference(transaction.createdAt);
                        final agingLabel =
                            '${aging.inDays}d ${aging.inHours.remainder(24)}h';

                        return DataRow(
                          cells: [
                            DataCell(Text(transaction.id.substring(0, 8).toUpperCase())),
                            DataCell(_buildUserNameCell(transaction.clientId)),
                            DataCell(_buildUserNameCell(transaction.trainerId)),
                            DataCell(
                              Text('PKR ${transaction.amount.toStringAsFixed(0)}'),
                            ),
                            DataCell(
                              Text(DateFormat('MMM dd • HH:mm').format(transaction.createdAt)),
                            ),
                            DataCell(
                              Text(
                                agingLabel,
                                style: TextStyle(
                                  color: aging.inDays >= 2
                                      ? AppColors.error
                                      : AppColors.warning,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataCell(
                              TextButton(
                                onPressed: !hasReceipt
                                    ? null
                                    : () => _openReceiptPreview(
                                          transaction.clientPaymentProofUrl!,
                                        ),
                                child: const Text('View'),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: hasReceipt
                                        ? 'Approve'
                                        : 'Receipt required before approval',
                                    onPressed: hasReceipt
                                        ? () => _verifyPayment(doc.id, '')
                                        : null,
                                    icon: Icon(
                                      Icons.check_circle,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.brandGreen
                                          : AppColors.brandGreenDeep,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Reject',
                                    onPressed: () => _showQuickRejectDialog(doc.id),
                                    icon:
                                        const Icon(Icons.cancel, color: AppColors.error),
                                  ),
                                  IconButton(
                                    tooltip: 'Details',
                                    onPressed: () => _showPaymentDetails(
                                      transaction: transaction,
                                      docId: doc.id,
                                      isPending: true,
                                    ),
                                    icon: const Icon(Icons.open_in_new),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _pendingLimit += 100;
                    });
                  },
                  icon: const Icon(Icons.expand_more),
                  label: Text('Load More (${docs.length})'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserNameCell(String userId) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _firestore.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final name = snapshot.data?.data()?['name'] as String?;
        return Text(name ?? userId.substring(0, 6));
      },
    );
  }

  void _openReceiptPreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }

  void _showQuickRejectDialog(String transactionId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payment'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter rejection reason',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              await _rejectPayment(transactionId, '', reasonController.text.trim());
              if (context.mounted) {
                Navigator.pop(context);
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

  Future<void> _exportPendingPaymentsCsv() async {
    try {
      final snapshot = await _firestore
          .collection('transactions')
          .where('status', isEqualTo: 'pendingVerification')
          .orderBy('createdAt', descending: true)
          .limit(_pendingLimit)
          .get();

      final rows = <String>[
        'transactionId,clientId,clientName,trainerId,trainerName,amount,paymentMethod,createdAt,status'
      ];

      for (final doc in snapshot.docs) {
        final tx = TransactionModel.fromFirestore(doc);

        final clientDoc = await _firestore.collection('users').doc(tx.clientId).get();
        final trainerDoc =
            await _firestore.collection('users').doc(tx.trainerId).get();

        final clientName = clientDoc.data()?['name'] as String? ?? '';
        final trainerName = trainerDoc.data()?['name'] as String? ?? '';

        rows.add(
          [
            tx.id,
            tx.clientId,
            clientName,
            tx.trainerId,
            trainerName,
            tx.amount.toStringAsFixed(2),
            tx.paymentMethod.value,
            tx.createdAt.toIso8601String(),
            tx.status.value,
          ].map(_csvCell).join(','),
        );
      }

      final content = rows.join('\n');

      if (kIsWeb) {
        downloadCsvFile(
          content,
          'pending_payments_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? 'Pending payments exported'
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

  Widget _buildVerifiedPaymentsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('transactions')
          .where('status', isEqualTo: 'verified')
          .orderBy('verifiedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No verified payments',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final transaction = TransactionModel.fromFirestore(docs[index]);

            return _buildPaymentCard(
              transaction: transaction,
              docId: docs[index].id,
              isPending: false,
            );
          },
        );
      },
    );
  }

  Widget _buildRejectedPaymentsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('transactions')
          .where('status', isEqualTo: 'failed')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No rejected payments',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final transaction = TransactionModel.fromFirestore(docs[index]);

            return _buildPaymentCard(
              transaction: transaction,
              docId: docs[index].id,
              isPending: false,
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentCard({
    required TransactionModel transaction,
    required String docId,
    required bool isPending,
  }) {
    return GestureDetector(
      onTap: () => _showPaymentDetails(
        transaction: transaction,
        docId: docId,
        isPending: isPending,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A2A2A)
              : AppColors.surface,
          border: Border.all(
            color: _getStatusBorderColor(transaction.status.displayName),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaction ID',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transaction.id.substring(0, 8).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(transaction.status.displayName)
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    transaction.status.displayName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(transaction.status.displayName),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: AppColors.charcoal, height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PKR ${transaction.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd, yyyy').format(transaction.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDetails({
    required TransactionModel transaction,
    required String docId,
    required bool isPending,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentDetailsSheet(
        transaction: transaction,
        docId: docId,
        isPending: isPending,
        onVerify: (transactionId, trainerId) =>
            _verifyPayment(transactionId, trainerId),
        onReject: (transactionId, trainerId, reason) =>
            _rejectPayment(transactionId, trainerId, reason),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending verification':
        return AppColors.warning;
      case 'verified':
        return Theme.of(context).brightness == Brightness.dark
            ? AppColors.brandGreen
            : AppColors.brandGreenDeep;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.muted;
    }
  }

  Color _getStatusBorderColor(String status) {
    return _getStatusColor(status).withOpacity(0.5);
  }
}

class PaymentDetailsSheet extends StatefulWidget {
  final TransactionModel transaction;
  final String docId;
  final bool isPending;
  final Future<void> Function(String, String) onVerify;
  final Future<void> Function(String, String, String) onReject;

  const PaymentDetailsSheet({
    Key? key,
    required this.transaction,
    required this.docId,
    required this.isPending,
    required this.onVerify,
    required this.onReject,
  }) : super(key: key);

  @override
  State<PaymentDetailsSheet> createState() => _PaymentDetailsSheetState();
}

class _PaymentDetailsSheetState extends State<PaymentDetailsSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _rejectionReasonController =
      TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _showProofImage() async {
    if (widget.transaction.clientPaymentProofUrl != null) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              widget.transaction.clientPaymentProofUrl!,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Payment Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Transaction Info
              _buildDetailSection(
                'Transaction Information',
                [
                  ('Transaction ID', widget.transaction.id),
                  ('Status', widget.transaction.status.displayName),
                  (
                    'Amount',
                    'PKR ${widget.transaction.amount.toStringAsFixed(0)}'
                  ),
                  (
                    'Platform Fee',
                    'PKR ${widget.transaction.platformFee.toStringAsFixed(0)}'
                  ),
                  (
                    'Trainer Receives',
                    'PKR ${widget.transaction.trainerAmount.toStringAsFixed(0)}'
                  ),
                  (
                    'Payment Method',
                    widget.transaction.paymentMethod.displayName
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Client & Trainer Info
              FutureBuilder<DocumentSnapshot>(
                future: _firestore
                    .collection('users')
                    .doc(widget.transaction.clientId)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final clientData = snapshot.data?.data() as Map?;
                    return _buildDetailSection(
                      'Client Information',
                      [
                        ('Name', clientData?['name'] ?? 'N/A'),
                        ('Email', clientData?['email'] ?? 'N/A'),
                        ('Phone', clientData?['phone'] ?? 'N/A'),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 20),

              // Receipt Image
              if (widget.transaction.clientPaymentProofUrl != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Receipt',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _showProofImage,
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.charcoal),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.transaction.clientPaymentProofUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

              // Action Buttons
              if (widget.isPending) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            setState(() => _isLoading = true);
                            await widget.onVerify(
                              widget.docId,
                              widget.transaction.trainerId,
                            );
                            if (mounted) {
                              setState(() => _isLoading = false);
                              Navigator.pop(context);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Verify Payment',
                      style: TextStyle(
                        color: AppColors.background,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _showRejectDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Reject Payment',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<(String, String)> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.charcoal),
          ),
          child: Column(
            children: details
                .asMap()
                .entries
                .map(
                  (entry) => Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.value.$1,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            entry.value.$2,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (entry.key < details.length - 1)
                        Divider(
                          color: AppColors.charcoal,
                          height: 12,
                        ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : AppColors.surface,
        title: const Text(
          'Reject Payment',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: _rejectionReasonController,
          decoration: InputDecoration(
            hintText: 'Enter rejection reason',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandGreen
                    : AppColors.brandGreenDeep,
                width: 2,
              ),
            ),
          ),
          style: const TextStyle(color: AppColors.textPrimary),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_rejectionReasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a reason'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              setState(() => _isLoading = true);
              await widget.onReject(
                widget.docId,
                widget.transaction.trainerId,
                _rejectionReasonController.text,
              );
              if (!mounted) return;
              setState(() => _isLoading = false);
              Navigator.pop(context);
              Navigator.pop(context);
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
}
