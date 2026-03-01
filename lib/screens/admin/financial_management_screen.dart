import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class FinancialManagementScreen extends StatefulWidget {
  const FinancialManagementScreen({super.key});

  @override
  State<FinancialManagementScreen> createState() => _FinancialManagementScreenState();
}

class _FinancialManagementScreenState extends State<FinancialManagementScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  double _totalRevenue = 0.0;
  double _platformRevenue = 0.0;
  double _trainerRevenue = 0.0;
  double _pendingPayouts = 0.0;
  double _commissionRate = 0.20; // 20% default

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFinancialSummary();
    _loadCommissionRate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCommissionRate() async {
    try {
      final settingsDoc = await _firestore.collection('platform_settings').doc('commission').get();
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

  Future<void> _loadFinancialSummary() async {
    try {
      final sessionsSnapshot = await _firestore
          .collection('sessions')
          .where('status', isEqualTo: 'completed')
          .get();

      double totalRev = 0.0;
      double pending = 0.0;

      for (var doc in sessionsSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final isPaid = data['trainerPaid'] as bool? ?? false;

        totalRev += amount;
        if (!isPaid) {
          pending += amount * (1 - _commissionRate);
        }
      }

      setState(() {
        _totalRevenue = totalRev;
        _platformRevenue = totalRev * _commissionRate;
        _trainerRevenue = totalRev * (1 - _commissionRate);
        _pendingPayouts = pending;
      });
    } catch (e) {
      print('Error loading financial summary: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF171917),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Financial Management',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF83BCB5),
          labelColor: const Color(0xFF83BCB5),
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Payouts'),
            Tab(text: 'Refunds'),
            Tab(text: 'Revenue'),
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF171917),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Revenue',
              '\$${_totalRevenue.toStringAsFixed(2)}',
              Icons.attach_money,
              const Color(0xFF7FFA88),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Platform Share',
              '\$${_platformRevenue.toStringAsFixed(2)}',
              Icons.account_balance,
              const Color(0xFF83BCB5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Pending Payouts',
              '\$${_pendingPayouts.toStringAsFixed(2)}',
              Icons.pending_actions,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
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
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('sessions')
          .where('status', isEqualTo: 'completed')
          .where('trainerPaid', isEqualTo: false)
          .orderBy('completedAt', descending: true)
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

        if (sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                Text(
                  'No pending payouts',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index].data() as Map<String, dynamic>;
            final sessionId = sessions[index].id;
            return _buildPayoutCard(session, sessionId);
          },
        );
      },
    );
  }

  Widget _buildPayoutCard(Map<String, dynamic> session, String sessionId) {
    final amount = (session['amount'] as num?)?.toDouble() ?? 0.0;
    final trainerAmount = amount * (1 - _commissionRate);
    final platformAmount = amount * _commissionRate;
    final trainerId = session['trainerId'] as String? ?? '';
    final clientId = session['clientId'] as String? ?? '';
    final completedAt = (session['completedAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF171917),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.pending_actions, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session #${sessionId.substring(0, 8)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (completedAt != null)
                        Text(
                          'Completed ${DateFormat('MMM dd, yyyy').format(completedAt)}',
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
                      '\$${trainerAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF7FFA88),
                      ),
                    ),
                    Text(
                      'to trainer',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount Details',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total: \$${amount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        'Platform (${(_commissionRate * 100).toInt()}%): \$${platformAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF83BCB5),
                        ),
                      ),
                      Text(
                        'Trainer (${((1 - _commissionRate) * 100).toInt()}%): \$${trainerAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF7FFA88),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('users').doc(trainerId).get(),
                    builder: (context, snapshot) {
                      final trainerName = snapshot.data?.data() != null
                          ? (snapshot.data!.data() as Map<String, dynamic>)['name'] as String? ?? 'Unknown'
                          : 'Loading...';
                      return Text(
                        'Trainer: $trainerName',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _processPayou(sessionId, trainerId, trainerAmount),
              icon: const Icon(Icons.payment),
              label: Text(
                'Process Payout',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7FFA88),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                Icon(Icons.check_circle_outline, size: 64, color: Colors.white24),
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
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF83BCB5)),
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
    final sessionId = refund['sessionId'] as String? ?? '';
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
                  child: const Icon(Icons.money_off, color: Colors.red, size: 20),
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
                          DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt),
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
                    ? (snapshot.data!.data() as Map<String, dynamic>)['name'] as String? ?? 'Unknown'
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
    final trainerAmount = amount * (1 - _commissionRate);
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
              child: const Icon(Icons.attach_money, color: Color(0xFF7FFA88), size: 20),
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

  Future<void> _processPayou(String sessionId, String trainerId, double amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF171917),
        title: Text(
          'Process Payout',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        content: Text(
          'Confirm payout of \$${amount.toStringAsFixed(2)} to trainer?',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7FFA88)),
            child: Text('Confirm', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Mark session as paid
        await _firestore.collection('sessions').doc(sessionId).update({
          'trainerPaid': true,
          'paidAt': FieldValue.serverTimestamp(),
        });

        // TODO: Integrate with payment gateway to actually send money

        await _loadFinancialSummary();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payout processed successfully'),
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

  Future<void> _processRefund(String refundId, String userId, double amount) async {
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
