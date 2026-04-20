import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:genzfit/models/bank_details_model.dart';
import 'package:genzfit/services/payment_service.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminBankVerificationScreen extends StatefulWidget {
  const AdminBankVerificationScreen({super.key});

  @override
  State<AdminBankVerificationScreen> createState() =>
      _AdminBankVerificationScreenState();
}

class _AdminBankVerificationScreenState extends State<AdminBankVerificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PaymentService _paymentService = PaymentService();

  String _statusFilter = 'pending';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Trainer Bank Verification',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildStatusFilters(),
          Expanded(child: _buildBankDetailsList()),
        ],
      ),
    );
  }

  Widget _buildStatusFilters() {
    final statuses = ['pending', 'verified', 'rejected', 'all'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: statuses.map((status) {
            final selected = _statusFilter == status;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(status[0].toUpperCase() + status.substring(1)),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _statusFilter = status;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBankDetailsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collectionGroup('bank_details').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        final filtered = docs.where((doc) {
          final status = (doc.data()['verificationStatus'] as String? ?? '').toLowerCase();
          if (_statusFilter == 'all') return true;
          return status == _statusFilter;
        }).toList()
          ..sort((a, b) {
            final aTs = a.data()['createdAt'] as Timestamp?;
            final bTs = b.data()['createdAt'] as Timestamp?;
            final aMs = aTs?.millisecondsSinceEpoch ?? 0;
            final bMs = bTs?.millisecondsSinceEpoch ?? 0;
            return bMs.compareTo(aMs);
          });

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'No $_statusFilter bank details found',
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final data = doc.data();

            final trainerDoc = doc.reference.parent.parent;
            if (trainerDoc == null) {
              return const SizedBox.shrink();
            }

            final trainerId = trainerDoc.id;
            final verificationStatus = (data['verificationStatus'] as String? ?? '').toLowerCase();

            return _buildBankCard(
              bankDetailsId: doc.id,
              trainerId: trainerId,
              accountHolderName: data['accountHolderName'] as String? ?? '-',
              bankName: data['bankName'] as String? ?? '-',
              accountNumber: data['accountNumber'] as String? ?? '-',
              iban: data['iban'] as String?,
              transferMethod: data['transferMethod'] as String? ?? '-',
              verificationStatus: verificationStatus,
              rejectionReason: data['rejectionReason'] as String?,
            );
          },
        );
      },
    );
  }

  Widget _buildBankCard({
    required String bankDetailsId,
    required String trainerId,
    required String accountHolderName,
    required String bankName,
    required String accountNumber,
    required String transferMethod,
    required String verificationStatus,
    String? iban,
    String? rejectionReason,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = isDark ? const Color(0xFF171917) : AppColors.surface;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _firestore.collection('users').doc(trainerId).get(),
      builder: (context, userSnapshot) {
        final trainerName = userSnapshot.data?.data()?['name'] as String? ?? trainerId;
        final trainerEmail = userSnapshot.data?.data()?['email'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _statusColor(verificationStatus).withOpacity(0.28)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trainerName,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary,
                            ),
                          ),
                          if (trainerEmail.isNotEmpty)
                            Text(
                              trainerEmail,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: (isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary)
                                    .withOpacity(0.62),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor(verificationStatus).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        verificationStatus.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(verificationStatus),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _row('Account Holder', accountHolderName),
                _row('Bank', bankName),
                _row('Account', _maskAccount(accountNumber)),
                if (iban != null && iban.isNotEmpty) _row('IBAN', iban),
                _row('Transfer Method', transferMethod),
                if (verificationStatus == 'rejected' && (rejectionReason ?? '').isNotEmpty)
                  _row('Reason', rejectionReason!),
                const SizedBox(height: 12),
                if (verificationStatus == 'pending' || verificationStatus == 'unverified')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRejectDialog(trainerId, bankDetailsId),
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
                          onPressed: () => _verifyBankDetails(
                            trainerId: trainerId,
                            bankDetailsId: bankDetailsId,
                            approved: true,
                          ),
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: (isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary)
                    .withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'verified':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'pending':
      case 'unverified':
        return AppColors.warning;
      default:
        return Colors.grey;
    }
  }

  String _maskAccount(String accountNumber) {
    if (accountNumber.length <= 4) return accountNumber;
    final hidden = '*' * (accountNumber.length - 4);
    return '$hidden${accountNumber.substring(accountNumber.length - 4)}';
  }

  Future<void> _verifyBankDetails({
    required String trainerId,
    required String bankDetailsId,
    required bool approved,
    String? rejectionReason,
  }) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin authentication required')),
      );
      return;
    }

    try {
      await _paymentService.verifyBankDetails(
        trainerId: trainerId,
        bankDetailsId: bankDetailsId,
        approved: approved,
        adminId: adminId,
        rejectionReason: rejectionReason,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? 'Bank details approved' : 'Bank details rejected'),
          backgroundColor: approved ? AppColors.success : AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showRejectDialog(String trainerId, String bankDetailsId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Bank Details'),
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
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;

              Navigator.pop(context);
              await _verifyBankDetails(
                trainerId: trainerId,
                bankDetailsId: bankDetailsId,
                approved: false,
                rejectionReason: reason,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
