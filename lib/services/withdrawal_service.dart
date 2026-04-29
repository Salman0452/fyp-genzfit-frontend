import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genzfit/models/withdrawal_request_model.dart';
import 'package:genzfit/models/bank_details_model.dart';
import 'package:genzfit/services/admin_audit_service.dart';

class WithdrawalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<String>> _resolveTrainerIds(String trainerId) async {
    final ids = <String>{trainerId};

    try {
      final trainerDoc =
          await _firestore.collection('trainers').doc(trainerId).get();
      final userId = trainerDoc.data()?['userId'] as String?;
      if (userId != null && userId.isNotEmpty) {
        ids.add(userId);
      }
    } catch (_) {}

    try {
      final trainerDocs = await _firestore
          .collection('trainers')
          .where('userId', isEqualTo: trainerId)
          .limit(5)
          .get();
      for (final doc in trainerDocs.docs) {
        ids.add(doc.id);
      }
    } catch (_) {}

    return ids.toList();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchByTrainerIds({
    required String collection,
    required List<String> trainerIds,
    String? status,
    List<String>? statusIn,
    String? type,
  }) async {
    final dedupedIds = trainerIds.toSet().toList();
    final all = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final id in dedupedIds) {
      Query<Map<String, dynamic>> query =
          _firestore.collection(collection).where('trainerId', isEqualTo: id);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }
      if (statusIn != null && statusIn.isNotEmpty) {
        query = query.where('status', whereIn: statusIn);
      }
      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }

      final snapshot = await query.get();
      all.addAll(snapshot.docs);
    }

    return all;
  }

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

      final withdrawalDoc = await _firestore
          .collection('withdrawal_requests')
          .doc(withdrawalId)
          .get();
      if (!withdrawalDoc.exists) {
        throw Exception('Withdrawal request not found');
      }

      final withdrawal = WithdrawalRequestModel.fromFirestore(withdrawalDoc);

      final batch = _firestore.batch();

      batch.update(
          _firestore.collection('withdrawal_requests').doc(withdrawalId), {
        'status': 'completed',
        'transactionId': transactionId,
        'completedAt': Timestamp.fromDate(now),
      });

      final paymentLedgerRef = _firestore.collection('payment_ledger').doc();
      batch.set(paymentLedgerRef, {
        'trainerId': trainerId,
        'type': 'withdrawal_completed',
        'amount': 0,
        'description': 'Withdrawal completed - Transaction ID: $transactionId',
        'referenceId': withdrawalId,
        'createdAt': Timestamp.fromDate(now),
      });

      final earningsLedgerRef = _firestore.collection('earnings_ledger').doc();
      batch.set(earningsLedgerRef, {
        'trainerId': trainerId,
        'clientId': null,
        'sessionId': null,
        'transactionId': transactionId,
        'amount': -withdrawal.amount,
        'platformFee': 0,
        'totalAmount': 0,
        'createdAt': Timestamp.fromDate(now),
        'status': 'active',
        'type': 'withdrawal_payout',
        'referenceId': withdrawalId,
        'withdrawalId': withdrawalId,
        'description': 'Payout completed for withdrawal $withdrawalId',
      });

      await batch.commit();

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
    return Stream.fromFuture(_resolveTrainerIds(trainerId)).asyncExpand((ids) {
      Query<Map<String, dynamic>> query =
          _firestore.collection('payment_ledger');

      if (ids.length == 1) {
        query = query.where('trainerId', isEqualTo: ids.first);
      } else {
        query = query.where('trainerId', whereIn: ids.take(10).toList());
      }

      return query.snapshots().asyncMap((snapshot) async {
        final items =
            snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();

        final withdrawalReferenceIds = items
            .where((item) {
              final type = item['type'] as String? ?? '';
              return type.startsWith('withdrawal_') &&
                  type != 'withdrawal_requested';
            })
            .map((item) => (item['referenceId'] as String?) ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

        final withdrawalDocs = await Future.wait(
          withdrawalReferenceIds.map(
            (refId) =>
                _firestore.collection('withdrawal_requests').doc(refId).get(),
          ),
        );

        final withdrawalAmountById = <String, double>{};
        for (final doc in withdrawalDocs) {
          if (!doc.exists) continue;
          final data = doc.data() ?? <String, dynamic>{};
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          withdrawalAmountById[doc.id] = amount;
        }

        for (final item in items) {
          final type = item['type'] as String? ?? '';
          if (!type.startsWith('withdrawal_') ||
              type == 'withdrawal_requested') {
            continue;
          }

          final refId = item['referenceId'] as String?;
          final originalAmount =
              refId != null ? withdrawalAmountById[refId] : null;
          item['sourceAmount'] = originalAmount ?? 0.0;
          item['displayAmount'] = originalAmount ?? 0.0;
          item['signedAmount'] = -(originalAmount ?? 0.0);
        }

        items.sort((a, b) {
          final ta = (a['createdAt'] as Timestamp?)?.toDate();
          final tb = (b['createdAt'] as Timestamp?)?.toDate();
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });
        return items;
      });
    });
  }

  /// Get trainer's available balance
  Future<double> getAvailableBalance(String trainerId) async {
    try {
      print('DEBUG getAvailableBalance: trainerId=$trainerId');
      final trainerIds = await _resolveTrainerIds(trainerId);

      final earningsDocs = await _fetchByTrainerIds(
        collection: 'earnings_ledger',
        trainerIds: trainerIds,
        status: 'active',
      );

      print(
          'DEBUG earningsSnapshot.size=${earningsDocs.length} for trainerIds=$trainerIds');

      double totalEarnings = 0.0;
      for (var doc in earningsDocs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        print('DEBUG earnings doc=${doc.id} amount=$amount data=$data');
        totalEarnings += amount;
      }

      // Subtract pending/approved/processing requests from available balance.
      final pendingWithdrawalDocs = await _fetchByTrainerIds(
        collection: 'withdrawal_requests',
        trainerIds: trainerIds,
        statusIn: ['requested', 'approved', 'processing'],
      );

      print(
          'DEBUG pendingWithdrawalSnapshot.size=${pendingWithdrawalDocs.length}');
      double pendingWithdrawals = 0.0;
      for (var doc in pendingWithdrawalDocs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        print('DEBUG withdrawal doc=${doc.id} amount=$amount data=$data');
        pendingWithdrawals += amount;
      }

      // Legacy safety: if completed withdrawals exist but payout entries were
      // never written to earnings_ledger, subtract them here to avoid stale
      // balance after admin completion.
      final completedWithdrawalDocs = await _fetchByTrainerIds(
        collection: 'withdrawal_requests',
        trainerIds: trainerIds,
        status: 'completed',
      );

      final payoutDocs = await _fetchByTrainerIds(
        collection: 'earnings_ledger',
        trainerIds: trainerIds,
        type: 'withdrawal_payout',
      );

      final payoutReferenceIds = <String>{};
      bool hasMappedPayoutRefs = false;
      for (final doc in payoutDocs) {
        final data = doc.data();
        final refId = (data['withdrawalId'] ?? data['referenceId']) as String?;
        if (refId != null && refId.isNotEmpty) {
          payoutReferenceIds.add(refId);
          hasMappedPayoutRefs = true;
        }
      }

      double legacyCompletedAdjust = 0.0;
      if (payoutDocs.isEmpty) {
        for (final doc in completedWithdrawalDocs) {
          final data = doc.data();
          legacyCompletedAdjust += (data['amount'] as num?)?.toDouble() ?? 0.0;
        }
      } else if (hasMappedPayoutRefs) {
        for (final doc in completedWithdrawalDocs) {
          if (!payoutReferenceIds.contains(doc.id)) {
            final data = doc.data();
            legacyCompletedAdjust +=
                (data['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }

      print(
          'DEBUG totals: totalEarnings=$totalEarnings pendingWithdrawals=$pendingWithdrawals legacyCompletedAdjust=$legacyCompletedAdjust');

      return totalEarnings - pendingWithdrawals - legacyCompletedAdjust;
    } catch (e) {
      print('Error getting available balance: $e');
      return 0;
    }
  }

  /// Diagnostic version: returns detailed debug info about earnings and withdrawals
  /// Useful to display in UI when diagnosing balance issues.
  Future<Map<String, dynamic>> getAvailableBalanceDebug(
      String trainerId) async {
    try {
      final trainerIds = await _resolveTrainerIds(trainerId);

      final earningsDocsRaw = await _fetchByTrainerIds(
        collection: 'earnings_ledger',
        trainerIds: trainerIds,
        status: 'active',
      );

      double totalEarnings = 0.0;
      final List<Map<String, dynamic>> earningsDocs = [];
      for (var doc in earningsDocsRaw) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        earningsDocs.add({'id': doc.id, 'amount': amount, 'data': data});
        totalEarnings += amount;
      }

      final withdrawalDocsRaw = await _fetchByTrainerIds(
        collection: 'withdrawal_requests',
        trainerIds: trainerIds,
        statusIn: ['requested', 'approved', 'processing'],
      );

      double pendingWithdrawals = 0.0;
      final List<Map<String, dynamic>> withdrawalDocs = [];
      for (var doc in withdrawalDocsRaw) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        withdrawalDocs.add({'id': doc.id, 'amount': amount, 'data': data});
        pendingWithdrawals += amount;
      }

      final completedWithdrawalDocsRaw = await _fetchByTrainerIds(
        collection: 'withdrawal_requests',
        trainerIds: trainerIds,
        status: 'completed',
      );

      final payoutDocsRaw = await _fetchByTrainerIds(
        collection: 'earnings_ledger',
        trainerIds: trainerIds,
        type: 'withdrawal_payout',
      );

      final payoutReferenceIds = <String>{};
      bool hasMappedPayoutRefs = false;
      for (final doc in payoutDocsRaw) {
        final data = doc.data();
        final refId = (data['withdrawalId'] ?? data['referenceId']) as String?;
        if (refId != null && refId.isNotEmpty) {
          payoutReferenceIds.add(refId);
          hasMappedPayoutRefs = true;
        }
      }

      double legacyCompletedAdjust = 0.0;
      if (payoutDocsRaw.isEmpty) {
        for (final doc in completedWithdrawalDocsRaw) {
          final data = doc.data();
          legacyCompletedAdjust += (data['amount'] as num?)?.toDouble() ?? 0.0;
        }
      } else if (hasMappedPayoutRefs) {
        for (final doc in completedWithdrawalDocsRaw) {
          if (!payoutReferenceIds.contains(doc.id)) {
            final data = doc.data();
            legacyCompletedAdjust +=
                (data['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }

      final finalBalance =
          totalEarnings - pendingWithdrawals - legacyCompletedAdjust;

      return {
        'usedTrainerId': trainerIds.join(', '),
        'trainerIds': trainerIds,
        'ledgerCount': earningsDocsRaw.length,
        'earningsDocs': earningsDocs,
        'totalEarnings': totalEarnings,
        'withdrawalCount': withdrawalDocsRaw.length,
        'withdrawalDocs': withdrawalDocs,
        'pendingWithdrawals': pendingWithdrawals,
        'completedWithdrawalCount': completedWithdrawalDocsRaw.length,
        'payoutLedgerCount': payoutDocsRaw.length,
        'legacyCompletedAdjust': legacyCompletedAdjust,
        'finalBalance': finalBalance,
      };
    } catch (e) {
      print('Error in getAvailableBalanceDebug: $e');
      return {
        'usedTrainerId': trainerId,
        'ledgerCount': 0,
        'earningsDocs': [],
        'totalEarnings': 0.0,
        'withdrawalCount': 0,
        'withdrawalDocs': [],
        'pendingWithdrawals': 0.0,
        'finalBalance': 0.0,
        'error': e.toString(),
      };
    }
  }
}
