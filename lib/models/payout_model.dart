import 'package:cloud_firestore/cloud_firestore.dart';

/// Payout request status
enum PayoutStatus {
  pending, // Trainer requested payout
  approved, // Admin approved
  processing, // Bank transfer initiated
  completed, // Payment sent to trainer
  failed, // Transfer failed
  cancelled, // Request cancelled
}

extension PayoutStatusString on PayoutStatus {
  String get value {
    return toString().split('.').last;
  }

  String get displayName {
    switch (this) {
      case PayoutStatus.pending:
        return 'Pending';
      case PayoutStatus.approved:
        return 'Approved';
      case PayoutStatus.processing:
        return 'Processing';
      case PayoutStatus.completed:
        return 'Completed';
      case PayoutStatus.failed:
        return 'Failed';
      case PayoutStatus.cancelled:
        return 'Cancelled';
    }
  }
}

extension PayoutStatusFromString on String {
  PayoutStatus toPayoutStatus() {
    switch (this) {
      case 'pending':
        return PayoutStatus.pending;
      case 'approved':
        return PayoutStatus.approved;
      case 'processing':
        return PayoutStatus.processing;
      case 'completed':
        return PayoutStatus.completed;
      case 'failed':
        return PayoutStatus.failed;
      case 'cancelled':
        return PayoutStatus.cancelled;
      default:
        return PayoutStatus.pending;
    }
  }
}

/// Represents a payout request from trainer
class PayoutModel {
  final String id;
  final String trainerId;
  final String bankDetailsId; // Reference to BankDetailsModel
  final double amount;
  final PayoutStatus status;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedByAdminId;
  final DateTime? processedAt;
  final String? bankTransferReference; // Bank transaction ID/reference number
  final DateTime? completedAt;
  final String? failureReason;
  final int transactionCount; // Number of sessions paid out in this payout
  final List<String> transactionIds; // List of transaction IDs included
  final Map<String, dynamic>? metadata;

  PayoutModel({
    required this.id,
    required this.trainerId,
    required this.bankDetailsId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    this.approvedByAdminId,
    this.processedAt,
    this.bankTransferReference,
    this.completedAt,
    this.failureReason,
    required this.transactionCount,
    required this.transactionIds,
    this.metadata,
  });

  /// Create from Firestore document
  factory PayoutModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return PayoutModel(
      id: doc.id,
      trainerId: data['trainerId'] as String,
      bankDetailsId: data['bankDetailsId'] as String,
      amount: (data['amount'] as num).toDouble(),
      status: (data['status'] as String).toPayoutStatus(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      approvedByAdminId: data['approvedByAdminId'] as String?,
      processedAt: data['processedAt'] != null
          ? (data['processedAt'] as Timestamp).toDate()
          : null,
      bankTransferReference: data['bankTransferReference'] as String?,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      failureReason: data['failureReason'] as String?,
      transactionCount: data['transactionCount'] as int? ?? 0,
      transactionIds:
          List<String>.from(data['transactionIds'] as List<dynamic>? ?? []),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'trainerId': trainerId,
      'bankDetailsId': bankDetailsId,
      'amount': amount,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedByAdminId': approvedByAdminId,
      'processedAt':
          processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'bankTransferReference': bankTransferReference,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'failureReason': failureReason,
      'transactionCount': transactionCount,
      'transactionIds': transactionIds,
      'metadata': metadata,
    };
  }

  /// Create a copy with modifications
  PayoutModel copyWith({
    String? id,
    String? trainerId,
    String? bankDetailsId,
    double? amount,
    PayoutStatus? status,
    DateTime? createdAt,
    DateTime? approvedAt,
    String? approvedByAdminId,
    DateTime? processedAt,
    String? bankTransferReference,
    DateTime? completedAt,
    String? failureReason,
    int? transactionCount,
    List<String>? transactionIds,
    Map<String, dynamic>? metadata,
  }) {
    return PayoutModel(
      id: id ?? this.id,
      trainerId: trainerId ?? this.trainerId,
      bankDetailsId: bankDetailsId ?? this.bankDetailsId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedByAdminId: approvedByAdminId ?? this.approvedByAdminId,
      processedAt: processedAt ?? this.processedAt,
      bankTransferReference:
          bankTransferReference ?? this.bankTransferReference,
      completedAt: completedAt ?? this.completedAt,
      failureReason: failureReason ?? this.failureReason,
      transactionCount: transactionCount ?? this.transactionCount,
      transactionIds: transactionIds ?? this.transactionIds,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() =>
      'PayoutModel(id: $id, trainerId: $trainerId, amount: $amount, status: $status)';
}

/// Trainer earnings summary for dashboard
class TrainerEarnings {
  final double totalEarnings; // Lifetime earnings
  final double pendingEarnings; // Available for payout (verified transactions)
  final double completedPayouts; // Already paid out
  final int totalSessions; // Total completed sessions
  final int unverifiedTransactions; // Awaiting admin verification
  final DateTime lastPayoutDate;
  final List<PayoutModel> recentPayouts; // Last 10 payouts

  TrainerEarnings({
    required this.totalEarnings,
    required this.pendingEarnings,
    required this.completedPayouts,
    required this.totalSessions,
    required this.unverifiedTransactions,
    required this.lastPayoutDate,
    required this.recentPayouts,
  });

  /// Calculate available balance (verified transactions not yet paid out)
  double get availableBalance => pendingEarnings;
}
