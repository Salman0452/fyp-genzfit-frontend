import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genzfit/models/withdrawal_request_model.dart';
import 'package:genzfit/models/bank_details_model.dart';
import 'package:genzfit/services/admin_audit_service.dart';

class WithdrawalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Request a withdrawal
  Future<String> requestWithdrawal({
    required String trainerId,
    required double amount,
    required String bankDetailsId,
  }) async {
    try {
      // Validate amount
      if (amount <= 0) {
        throw Exception('Withdrawal amount must be greater than 0');
      }

      // Check if bank details exist and are verified
      final bankDetailsDoc = await _firestore
          .collection('trainers')
          .doc(trainerId)
          .collection('bank_details')
          .doc(bankDetailsId)
          .get();

      if (!bankDetailsDoc.exists) {
        throw Exception('Bank details not found');
      }

      final bankDetails = BankDetailsModel.fromFirestore(bankDetailsDoc);
      if (bankDetails.verificationStatus != BankVerificationStatus.verified) {
        throw Exception('Bank details must be verified before withdrawal');
      }

      // Create withdrawal request
      final withdrawalData = {
        'trainerId': trainerId,
        'amount': amount,
        'status': 'requested',
        'bankDetailsId': bankDetailsId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection('withdrawal_requests')
          .add(withdrawalData);

      // Create ledger entry
      await _createLedgerEntry(
        trainerId: trainerId,
        type: 'withdrawal_requested',
        amount: -amount,
        description: 'Withdrawal request for Rs. ${amount.toStringAsFixed(2)}',
        referenceId: docRef.id,
      );

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to request withdrawal: $e');
    }
  }

  /// Get withdrawal history for trainer
  Stream<List<WithdrawalRequestModel>> getWithdrawalHistory(String trainerId) {
    return _firestore
        .collection('withdrawal_requests')
        .where('trainerId', isEqualTo: trainerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WithdrawalRequestModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get pending withdrawal requests (admin view)
  Stream<List<WithdrawalRequestModel>> getPendingWithdrawals() {
    return _firestore
        .collection('withdrawal_requests')
        .where('status', isEqualTo: 'requested')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WithdrawalRequestModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Approve withdrawal request (admin action)
  Future<void> approveWithdrawal({
    required String withdrawalId,
    required String trainerId,
    String? adminId,
  }) async {
    try {
      final now = DateTime.now();

      await _firestore
          .collection('withdrawal_requests')
          .doc(withdrawalId)
          .update({
        'status': 'approved',
        'processedAt': Timestamp.fromDate(now),
      });

      // Create ledger entry
      final withdrawal = await getWithdrawalRequest(withdrawalId);
      if (withdrawal != null) {
        await _createLedgerEntry(
          trainerId: trainerId,
          type: 'withdrawal_approved',
          amount: 0,
          description:
              'Withdrawal request approved - Rs. ${withdrawal.amount.toStringAsFixed(2)}',
          referenceId: withdrawalId,
        );
      }

      if (adminId != null) {
        await AdminAuditService.logAction(
          adminId: adminId,
          actionType: 'withdrawal_approved',
          entityType: 'withdrawal_request',
          entityId: withdrawalId,
          metadata: {'trainerId': trainerId},
        );
      }
    } catch (e) {
      throw Exception('Failed to approve withdrawal: $e');
    }
  }

  /// Reject withdrawal request (admin action)
  Future<void> rejectWithdrawal({
    required String withdrawalId,
    required String trainerId,
    required String rejectionReason,
    String? adminId,
  }) async {
    try {
      final now = DateTime.now();

      await _firestore
          .collection('withdrawal_requests')
          .doc(withdrawalId)
          .update({
        'status': 'rejected',
        'rejectionReason': rejectionReason,
        'processedAt': Timestamp.fromDate(now),
      });

      // Create ledger entry
      final withdrawal = await getWithdrawalRequest(withdrawalId);
      if (withdrawal != null) {
        await _createLedgerEntry(
          trainerId: trainerId,
          type: 'withdrawal_rejected',
          amount: withdrawal.amount,
          description: 'Withdrawal request rejected - $rejectionReason',
          referenceId: withdrawalId,
        );
      }

      if (adminId != null) {
        await AdminAuditService.logAction(
          adminId: adminId,
          actionType: 'withdrawal_rejected',
          entityType: 'withdrawal_request',
          entityId: withdrawalId,
          metadata: {
            'trainerId': trainerId,
            'rejectionReason': rejectionReason,
          },
        );
      }
    } catch (e) {
      throw Exception('Failed to reject withdrawal: $e');
    }
  }

  Future<void> markWithdrawalProcessing({
    required String withdrawalId,
    required String trainerId,
    String? adminId,
  }) async {
    try {
      await _firestore
          .collection('withdrawal_requests')
          .doc(withdrawalId)
          .update({
        'status': 'processing',
        'processedAt': FieldValue.serverTimestamp(),
      });

      if (adminId != null) {
        await AdminAuditService.logAction(
          adminId: adminId,
          actionType: 'withdrawal_processing',
          entityType: 'withdrawal_request',
          entityId: withdrawalId,
          metadata: {'trainerId': trainerId},
        );
      }
    } catch (e) {
      throw Exception('Failed to mark withdrawal as processing: $e');
    }
  }

  /// Mark withdrawal as completed
  Future<void> completeWithdrawal({
    required String withdrawalId,
    required String transactionId,
    required String trainerId,
    String? adminId,
  }) async {
    try {
      final now = DateTime.now();

      await _firestore
          .collection('withdrawal_requests')
          .doc(withdrawalId)
          .update({
        'status': 'completed',
        'transactionId': transactionId,
        'completedAt': Timestamp.fromDate(now),
      });

      // Create ledger entry
      final withdrawal = await getWithdrawalRequest(withdrawalId);
      if (withdrawal != null) {
        await _createLedgerEntry(
          trainerId: trainerId,
          type: 'withdrawal_completed',
          amount: 0,
          description: 'Withdrawal completed - Transaction ID: $transactionId',
          referenceId: withdrawalId,
        );
      }

      if (adminId != null) {
        await AdminAuditService.logAction(
          adminId: adminId,
          actionType: 'withdrawal_completed',
          entityType: 'withdrawal_request',
          entityId: withdrawalId,
          metadata: {
            'trainerId': trainerId,
            'transactionId': transactionId,
          },
        );
      }
    } catch (e) {
      throw Exception('Failed to complete withdrawal: $e');
    }
  }

  /// Get a specific withdrawal request
  Future<WithdrawalRequestModel?> getWithdrawalRequest(
      String withdrawalId) async {
    try {
      final doc = await _firestore
          .collection('withdrawal_requests')
          .doc(withdrawalId)
          .get();

      if (!doc.exists) return null;
      return WithdrawalRequestModel.fromFirestore(doc);
    } catch (e) {
      print('Error getting withdrawal request: $e');
      return null;
    }
  }

  /// Get trainer's bank details
  Future<BankDetailsModel?> getBankDetails(
      String trainerId, String bankDetailsId) async {
    try {
      final doc = await _firestore
          .collection('trainers')
          .doc(trainerId)
          .collection('bank_details')
          .doc(bankDetailsId)
          .get();

      if (!doc.exists) return null;
      return BankDetailsModel.fromFirestore(doc);
    } catch (e) {
      print('Error getting bank details: $e');
      return null;
    }
  }

  /// Get all bank details for trainer
  Stream<List<BankDetailsModel>> getTrainerBankDetails(String trainerId) {
    return _firestore
        .collection('trainers')
        .doc(trainerId)
        .collection('bank_details')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BankDetailsModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Update bank details
  Future<void> updateBankDetails({
    required String trainerId,
    required String bankDetailsId,
    required String accountName,
    required String accountNumber,
    required String bankName,
    String? bankCode,
  }) async {
    try {
      await _firestore
          .collection('trainers')
          .doc(trainerId)
          .collection('bank_details')
          .doc(bankDetailsId)
          .update({
        'accountHolderName': accountName,
        'accountNumber': accountNumber,
        'bankName': bankName,
        'bankCode': bankCode,
        'verificationStatus':
            'pending', // Reset verification status when updated
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update bank details: $e');
    }
  }

  /// Add new bank details
  Future<String> addBankDetails({
    required String trainerId,
    required String accountName,
    required String accountNumber,
    required String bankName,
    String? bankCode,
  }) async {
    try {
      final bankDetailsData = {
        'trainerId': trainerId,
        'accountHolderName': accountName,
        'accountNumber': accountNumber,
        'bankName': bankName,
        'bankCode': bankCode,
        'transferMethod': 'bank_transfer',
        'verificationStatus': 'pending',
        'isDefault': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection('trainers')
          .doc(trainerId)
          .collection('bank_details')
          .add(bankDetailsData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add bank details: $e');
    }
  }

  /// Create payment ledger entry
  Future<void> _createLedgerEntry({
    required String trainerId,
    required String type,
    required double amount,
    required String description,
    required String referenceId,
  }) async {
    try {
      await _firestore.collection('payment_ledger').add({
        'trainerId': trainerId,
        'type': type,
        'amount': amount,
        'description': description,
        'referenceId': referenceId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating ledger entry: $e');
    }
  }

  /// Get payment history for trainer
  Stream<List<Map<String, dynamic>>> getPaymentHistory(String trainerId) {
    return _firestore
        .collection('payment_ledger')
        .where('trainerId', isEqualTo: trainerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    });
  }

  /// Get trainer's available balance
  Future<double> getAvailableBalance(String trainerId) async {
    try {
      final sessionsSnapshot = await _firestore
          .collection('sessions')
          .where('trainerId', isEqualTo: trainerId)
          .where('status', isEqualTo: 'completed')
          .get();

      double totalEarnings = 0;
      for (var doc in sessionsSnapshot.docs) {
        final amount = doc.get('amount') as double?;
        if (amount != null) {
          totalEarnings += amount;
        }
      }

      // Subtract pending and approved withdrawals
      final withdrawalSnapshot = await _firestore
          .collection('withdrawal_requests')
          .where('trainerId', isEqualTo: trainerId)
          .where('status',
              whereIn: ['requested', 'approved', 'processing']).get();

      double pendingWithdrawals = 0;
      for (var doc in withdrawalSnapshot.docs) {
        final amount = doc.get('amount') as double?;
        if (amount != null) {
          pendingWithdrawals += amount;
        }
      }

      return totalEarnings - pendingWithdrawals;
    } catch (e) {
      print('Error getting available balance: $e');
      return 0;
    }
  }
}
