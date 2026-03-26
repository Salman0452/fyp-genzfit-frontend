import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/transaction_model.dart';
import '../models/bank_details_model.dart';
import '../models/payout_model.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const double platformCommissionRate = 0.10; // 10% platform fee
  static const String transactionsCollection = 'transactions';
  static const String bankDetailsCollection = 'bank_details';
  static const String payoutsCollection = 'payouts';

  /// Initiate a payment for trainer hiring
  /// Returns transaction ID
  Future<String> initiatePayment({
    required String clientId,
    required String trainerId,
    required String sessionId,
    required double sessionAmount,
  }) async {
    try {
      // Get commission rate from Firestore
      double commissionRate = platformCommissionRate; // Default 10%
      try {
        final settingsDoc = await _firestore
            .collection('platform_settings')
            .doc('commission')
            .get();
        if (settingsDoc.exists) {
          final rate = settingsDoc.data()?['rate'] as num?;
          if (rate != null) {
            commissionRate = rate.toDouble();
          }
        }
      } catch (e) {
        print('Error loading commission rate, using default: $e');
      }

      final platformFee = sessionAmount * commissionRate;
      final trainerAmount = sessionAmount - platformFee;

      final transaction = TransactionModel(
        id: '', // Will be set by Firestore
        clientId: clientId,
        trainerId: trainerId,
        sessionId: sessionId,
        amount: sessionAmount,
        platformFee: platformFee,
        trainerAmount: trainerAmount,
        paymentMethod: PaymentMethod.jazzCash,
        status: TransactionStatus.pendingVerification,
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection(transactionsCollection)
          .add(transaction.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to initiate payment: $e');
    }
  }

  /// Record payment proof (receipt image) and update transaction status
  Future<void> recordPaymentProof({
    required String transactionId,
    required File proofImage,
    required PaymentMethod paymentMethod,
  }) async {
    try {
      // Upload receipt image to Firebase Storage
      final fileName =
          'transaction_proofs/$transactionId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child(fileName);
      await ref.putFile(proofImage);
      final downloadUrl = await ref.getDownloadURL();

      // Update transaction with proof URL and payment method
      await _firestore
          .collection(transactionsCollection)
          .doc(transactionId)
          .update({
        'clientPaymentProofUrl': downloadUrl,
        'paymentMethod': paymentMethod.value,
      });
    } catch (e) {
      throw Exception('Failed to record payment proof: $e');
    }
  }

  /// Verify payment by admin (approve or reject)
  Future<void> verifyPayment({
    required String transactionId,
    required bool approved,
    required String adminId,
    String? rejectionReason,
  }) async {
    try {
      final updateData = {
        'status': approved
            ? TransactionStatus.verified.value
            : TransactionStatus.failed.value,
        'verifiedAt': Timestamp.now(),
        'verifiedByAdminId': adminId,
        if (!approved) 'rejectionReason': rejectionReason,
      };

      await _firestore
          .collection(transactionsCollection)
          .doc(transactionId)
          .update(updateData);

      if (approved) {
        // Update session status to active
        final transaction = await getTransaction(transactionId);
        await _firestore
            .collection('sessions')
            .doc(transaction!.sessionId)
            .update({
          'paymentStatus': 'paid',
          'paymentVerifiedAt': Timestamp.now(),
          'status': 'active',
        });
      }
    } catch (e) {
      throw Exception('Failed to verify payment: $e');
    }
  }

  /// Get transaction details
  Future<TransactionModel?> getTransaction(String transactionId) async {
    try {
      final doc = await _firestore
          .collection(transactionsCollection)
          .doc(transactionId)
          .get();
      if (!doc.exists) return null;
      return TransactionModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get transaction: $e');
    }
  }

  /// Get all transactions for a client
  Future<List<TransactionModel>> getClientTransactions(String clientId) async {
    try {
      final snapshot = await _firestore
          .collection(transactionsCollection)
          .where('clientId', isEqualTo: clientId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get client transactions: $e');
    }
  }

  /// Get all transactions for a trainer
  Future<List<TransactionModel>> getTrainerTransactions(
      String trainerId) async {
    try {
      final snapshot = await _firestore
          .collection(transactionsCollection)
          .where('trainerId', isEqualTo: trainerId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get trainer transactions: $e');
    }
  }

  /// Get pending verification transactions (admin view)
  Future<List<TransactionModel>> getPendingVerificationTransactions() async {
    try {
      final snapshot = await _firestore
          .collection(transactionsCollection)
          .where('status',
              isEqualTo: TransactionStatus.pendingVerification.value)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get pending transactions: $e');
    }
  }

  /// Save trainer's bank details
  Future<String> saveBankDetails({
    required String trainerId,
    required String accountHolderName,
    required String bankName,
    required String accountNumber,
    String? iban,
    String? phoneNumber,
    required String transferMethod,
    bool isDefault = true,
  }) async {
    try {
      // If this is default, unset other default bank details
      if (isDefault) {
        await _firestore
            .collection('trainers')
            .doc(trainerId)
            .collection(bankDetailsCollection)
            .where('isDefault', isEqualTo: true)
            .get()
            .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.update({'isDefault': false});
          }
        });
      }

      final bankDetails = BankDetailsModel(
        id: '', // Will be set by Firestore
        trainerId: trainerId,
        accountHolderName: accountHolderName,
        bankName: bankName,
        accountNumber: accountNumber,
        iban: iban,
        phoneNumber: phoneNumber,
        transferMethod: transferMethod,
        verificationStatus: BankVerificationStatus.pending,
        createdAt: DateTime.now(),
        isDefault: isDefault,
        updatedAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('trainers')
          .doc(trainerId)
          .collection(bankDetailsCollection)
          .add(bankDetails.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to save bank details: $e');
    }
  }

  /// Get trainer's bank details
  Future<List<BankDetailsModel>> getTrainerBankDetails(String trainerId) async {
    try {
      final snapshot = await _firestore
          .collection('trainers')
          .doc(trainerId)
          .collection(bankDetailsCollection)
          .orderBy('isDefault', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => BankDetailsModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get bank details: $e');
    }
  }

  /// Get trainer's default bank details (for payment checkout)
  Future<BankDetailsModel?> getTrainerDefaultBankDetails(
      String trainerId) async {
    try {
      final snapshot = await _firestore
          .collection('trainers')
          .doc(trainerId)
          .collection(bankDetailsCollection)
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return BankDetailsModel.fromFirestore(snapshot.docs.first);
      }

      // If no default, return the first verified one
      final allSnapshot = await _firestore
          .collection('trainers')
          .doc(trainerId)
          .collection(bankDetailsCollection)
          .where('verificationStatus', isEqualTo: 'verified')
          .limit(1)
          .get();

      if (allSnapshot.docs.isNotEmpty) {
        return BankDetailsModel.fromFirestore(allSnapshot.docs.first);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to get default bank details: $e');
    }
  }

  /// Verify bank details by admin
  Future<void> verifyBankDetails({
    required String trainerId,
    required String bankDetailsId,
    required bool approved,
    required String adminId,
    String? rejectionReason,
  }) async {
    try {
      final updateData = {
        'verificationStatus': approved
            ? BankVerificationStatus.verified.value
            : BankVerificationStatus.rejected.value,
        'verifiedAt': Timestamp.now(),
        'verifiedByAdminId': adminId,
        if (!approved) 'rejectionReason': rejectionReason,
        'updatedAt': Timestamp.now(),
      };

      await _firestore
          .collection('trainers')
          .doc(trainerId)
          .collection(bankDetailsCollection)
          .doc(bankDetailsId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to verify bank details: $e');
    }
  }

  /// Request payout by trainer
  Future<String> requestPayout({
    required String trainerId,
    required String bankDetailsId,
    required double amount,
  }) async {
    try {
      final payout = PayoutModel(
        id: '', // Will be set by Firestore
        trainerId: trainerId,
        bankDetailsId: bankDetailsId,
        amount: amount,
        status: PayoutStatus.pending,
        createdAt: DateTime.now(),
        transactionCount: 0,
        transactionIds: [],
      );

      final docRef = await _firestore
          .collection(payoutsCollection)
          .add(payout.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to request payout: $e');
    }
  }

  /// Get trainer's payouts
  Future<List<PayoutModel>> getTrainerPayouts(String trainerId) async {
    try {
      final snapshot = await _firestore
          .collection(payoutsCollection)
          .where('trainerId', isEqualTo: trainerId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => PayoutModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get trainer payouts: $e');
    }
  }

  /// Get pending payout requests (admin view)
  Future<List<PayoutModel>> getPendingPayouts() async {
    try {
      final snapshot = await _firestore
          .collection(payoutsCollection)
          .where('status', isEqualTo: PayoutStatus.pending.value)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => PayoutModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get pending payouts: $e');
    }
  }

  /// Approve payout by admin
  Future<void> approvePayout({
    required String payoutId,
    required String adminId,
  }) async {
    try {
      await _firestore.collection(payoutsCollection).doc(payoutId).update({
        'status': PayoutStatus.approved.value,
        'approvedAt': Timestamp.now(),
        'approvedByAdminId': adminId,
      });
    } catch (e) {
      throw Exception('Failed to approve payout: $e');
    }
  }

  /// Process payout (mark as processing / completed with bank reference)
  Future<void> processPayout({
    required String payoutId,
    required String bankTransferReference,
    required String adminId,
  }) async {
    try {
      await _firestore.collection(payoutsCollection).doc(payoutId).update({
        'status': PayoutStatus.completed.value,
        'processedAt': Timestamp.now(),
        'completedAt': Timestamp.now(),
        'bankTransferReference': bankTransferReference,
      });

      // Mark all transactions in this payout as completed
      final payout =
          await _firestore.collection(payoutsCollection).doc(payoutId).get();
      final transactionIds =
          List<String>.from(payout['transactionIds'] as List<dynamic>? ?? []);

      for (var transactionId in transactionIds) {
        await _firestore
            .collection(transactionsCollection)
            .doc(transactionId)
            .update({
          'status': TransactionStatus.completed.value,
          'completedAt': Timestamp.now(),
          'bankTransferReference': bankTransferReference,
        });
      }
    } catch (e) {
      throw Exception('Failed to process payout: $e');
    }
  }

  /// Fail payout with reason
  Future<void> failPayout({
    required String payoutId,
    required String failureReason,
  }) async {
    try {
      await _firestore.collection(payoutsCollection).doc(payoutId).update({
        'status': PayoutStatus.failed.value,
        'failureReason': failureReason,
      });
    } catch (e) {
      throw Exception('Failed to mark payout as failed: $e');
    }
  }

  /// Get trainer earnings summary
  Future<TrainerEarnings> getTrainerEarnings(String trainerId) async {
    try {
      // Get all transactions for trainer
      final allTransactions = await getTrainerTransactions(trainerId);

      double totalEarnings = 0;
      double pendingEarnings = 0;
      double completedPayouts = 0;
      int unverifiedCount = 0;
      DateTime lastPayoutDate = DateTime(2020);

      for (var transaction in allTransactions) {
        // Only count verified and completed transactions
        if (transaction.status == TransactionStatus.verified ||
            transaction.status == TransactionStatus.completed) {
          totalEarnings += transaction.trainerAmount;

          if (transaction.status == TransactionStatus.verified) {
            pendingEarnings += transaction.trainerAmount;
          } else if (transaction.status == TransactionStatus.completed) {
            completedPayouts += transaction.trainerAmount;
            if (transaction.completedAt!.isAfter(lastPayoutDate)) {
              lastPayoutDate = transaction.completedAt!;
            }
          }
        } else if (transaction.status ==
            TransactionStatus.pendingVerification) {
          unverifiedCount++;
        }
      }

      // Get recent payouts
      final payouts = await getTrainerPayouts(trainerId);
      final recentPayouts = payouts
          .where((p) => p.status == PayoutStatus.completed)
          .take(10)
          .toList();

      return TrainerEarnings(
        totalEarnings: totalEarnings,
        pendingEarnings: pendingEarnings,
        completedPayouts: completedPayouts,
        totalSessions: allTransactions
            .where((t) =>
                t.status == TransactionStatus.verified ||
                t.status == TransactionStatus.completed)
            .length,
        unverifiedTransactions: unverifiedCount,
        lastPayoutDate: lastPayoutDate,
        recentPayouts: recentPayouts,
      );
    } catch (e) {
      throw Exception('Failed to get trainer earnings: $e');
    }
  }
}
