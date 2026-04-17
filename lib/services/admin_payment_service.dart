// ADMIN PAYMENT VERIFICATION IMPLEMENTATION GUIDE
//
// This document outlines the architecture for:
// 1. Admin viewing pending payments
// 2. Verifying/rejecting payments
// 3. Creating active sessions
// 4. Tracking earnings
// 5. Sending notifications to trainer and client

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genzfit/services/payment_service.dart';

class AdminPaymentVerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PaymentService _paymentService = PaymentService();

  /// Get all pending payment verifications
  Stream<List<PendingPaymentModel>> getPendingPayments() {
    return _firestore
        .collection('transactions')
        .where('status', isEqualTo: 'pending_verification')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PendingPaymentModel.fromFirestore(doc))
            .toList());
  }

  /// Get verified sessions for admin tracking
  Stream<List<VerifiedSessionModel>> getVerifiedSessions({
    String? trainerId,
    String? clientId,
  }) {
    Query query =
        _firestore.collection('sessions').where('status', isEqualTo: 'active');

    if (trainerId != null) {
      query = query.where('trainerId', isEqualTo: trainerId);
    }

    if (clientId != null) {
      query = query.where('clientId', isEqualTo: clientId);
    }

    return query.orderBy('startDate', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => VerifiedSessionModel.fromFirestore(doc))
            .toList());
  }

  /// Get earnings ledger for a trainer
  Stream<List<EarningsLedgerModel>> getTrainerEarningsLedger(
    String trainerId,
  ) {
    return _firestore
        .collection('earnings_ledger')
        .where('trainerId', isEqualTo: trainerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EarningsLedgerModel.fromFirestore(doc))
            .toList());
  }

  /// Get all earnings ledger entries (for admin dashboard)
  Stream<List<EarningsLedgerModel>> getAllEarningsLedger() {
    return _firestore
        .collection('earnings_ledger')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EarningsLedgerModel.fromFirestore(doc))
            .toList());
  }

  /// Approve payment and create session
  /// This sends notifications to both trainer and client
  Future<void> approvePayment({
    required String transactionId,
    required String adminId,
  }) async {
    try {
      await _paymentService.verifyPayment(
        transactionId: transactionId,
        approved: true,
        adminId: adminId,
      );
    } catch (e) {
      throw Exception('Failed to approve payment: $e');
    }
  }

  /// Reject payment
  /// This sends a notification to the client
  Future<void> rejectPayment({
    required String transactionId,
    required String adminId,
    required String rejectionReason,
  }) async {
    try {
      await _paymentService.verifyPayment(
        transactionId: transactionId,
        approved: false,
        adminId: adminId,
        rejectionReason: rejectionReason,
      );
    } catch (e) {
      throw Exception('Failed to reject payment: $e');
    }
  }

  /// Get total platform revenue
  Future<double> getTotalPlatformRevenue() async {
    try {
      final snapshot = await _firestore.collection('earnings_ledger').get();
      double total = 0.0;

      for (var doc in snapshot.docs) {
        final platformFee =
            (doc.data()['platformFee'] as num?)?.toDouble() ?? 0.0;
        total += platformFee;
      }

      return total;
    } catch (e) {
      throw Exception('Failed to get platform revenue: $e');
    }
  }

  /// Get total trainer earnings
  Future<double> getTrainerTotalEarnings(String trainerId) async {
    try {
      final snapshot = await _firestore
          .collection('earnings_ledger')
          .where('trainerId', isEqualTo: trainerId)
          .get();

      double total = 0.0;

      for (var doc in snapshot.docs) {
        final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
        total += amount;
      }

      return total;
    } catch (e) {
      throw Exception('Failed to get trainer earnings: $e');
    }
  }
}

// Models for admin panel
class PendingPaymentModel {
  final String transactionId;
  final String clientId;
  final String trainerId;
  final String sessionId;
  final double amount;
  final double platformFee;
  final double trainerAmount;
  final String clientName;
  final String trainerName;
  final String clientProofUrl;
  final DateTime createdAt;

  PendingPaymentModel({
    required this.transactionId,
    required this.clientId,
    required this.trainerId,
    required this.sessionId,
    required this.amount,
    required this.platformFee,
    required this.trainerAmount,
    required this.clientName,
    required this.trainerName,
    required this.clientProofUrl,
    required this.createdAt,
  });

  factory PendingPaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PendingPaymentModel(
      transactionId: doc.id,
      clientId: data['clientId'] ?? '',
      trainerId: data['trainerId'] ?? '',
      sessionId: data['sessionId'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      platformFee: (data['platformFee'] as num?)?.toDouble() ?? 0.0,
      trainerAmount: (data['trainerAmount'] as num?)?.toDouble() ?? 0.0,
      clientName: data['clientName'] ?? 'Unknown',
      trainerName: data['trainerName'] ?? 'Unknown',
      clientProofUrl: data['clientPaymentProofUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class VerifiedSessionModel {
  final String sessionId;
  final String clientId;
  final String trainerId;
  final String clientName;
  final String trainerName;
  final double amount;
  final DateTime startDate;
  final DateTime endDate;
  final String status;

  VerifiedSessionModel({
    required this.sessionId,
    required this.clientId,
    required this.trainerId,
    required this.clientName,
    required this.trainerName,
    required this.amount,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  factory VerifiedSessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VerifiedSessionModel(
      sessionId: doc.id,
      clientId: data['clientId'] ?? '',
      trainerId: data['trainerId'] ?? '',
      clientName: data['clientName'] ?? 'Unknown',
      trainerName: data['trainerName'] ?? 'Unknown',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 30)),
      status: data['status'] ?? 'active',
    );
  }
}

class EarningsLedgerModel {
  final String id;
  final String trainerId;
  final String clientId;
  final String sessionId;
  final String transactionId;
  final double trainerAmount;
  final double platformFee;
  final double totalAmount;
  final DateTime createdAt;
  final String status;
  final String type;

  EarningsLedgerModel({
    required this.id,
    required this.trainerId,
    required this.clientId,
    required this.sessionId,
    required this.transactionId,
    required this.trainerAmount,
    required this.platformFee,
    required this.totalAmount,
    required this.createdAt,
    required this.status,
    required this.type,
  });

  factory EarningsLedgerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EarningsLedgerModel(
      id: doc.id,
      trainerId: data['trainerId'] ?? '',
      clientId: data['clientId'] ?? '',
      sessionId: data['sessionId'] ?? '',
      transactionId: data['transactionId'] ?? '',
      trainerAmount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      platformFee: (data['platformFee'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'active',
      type: data['type'] ?? 'session_payment',
    );
  }
}
