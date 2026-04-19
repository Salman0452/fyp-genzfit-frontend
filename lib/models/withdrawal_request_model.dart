import 'package:cloud_firestore/cloud_firestore.dart';

enum WithdrawalStatus {
  requested,
  approved,
  rejected,
  processing,
  completed,
  failed,
}

extension WithdrawalStatusString on WithdrawalStatus {
  String get value {
    return toString().split('.').last;
  }

  String get displayName {
    switch (this) {
      case WithdrawalStatus.requested:
        return 'Requested';
      case WithdrawalStatus.approved:
        return 'Approved';
      case WithdrawalStatus.rejected:
        return 'Rejected';
      case WithdrawalStatus.processing:
        return 'Processing';
      case WithdrawalStatus.completed:
        return 'Completed';
      case WithdrawalStatus.failed:
        return 'Failed';
    }
  }
}

extension WithdrawalStatusFromString on String {
  WithdrawalStatus toWithdrawalStatus() {
    switch (this) {
      case 'requested':
        return WithdrawalStatus.requested;
      case 'approved':
        return WithdrawalStatus.approved;
      case 'rejected':
        return WithdrawalStatus.rejected;
      case 'processing':
        return WithdrawalStatus.processing;
      case 'completed':
        return WithdrawalStatus.completed;
      case 'failed':
        return WithdrawalStatus.failed;
      default:
        return WithdrawalStatus.requested;
    }
  }
}

/// Represents a withdrawal request from trainer
class WithdrawalRequestModel {
  final String id;
  final String trainerId;
  final double amount;
  final WithdrawalStatus status;
  final String? bankDetailsId;
  final String? rejectionReason;
  final String? transactionId;
  final DateTime createdAt;
  final DateTime? processedAt;
  final DateTime? completedAt;

  WithdrawalRequestModel({
    required this.id,
    required this.trainerId,
    required this.amount,
    required this.status,
    this.bankDetailsId,
    this.rejectionReason,
    this.transactionId,
    required this.createdAt,
    this.processedAt,
    this.completedAt,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'trainerId': trainerId,
      'amount': amount,
      'status': status.value,
      'bankDetailsId': bankDetailsId,
      'rejectionReason': rejectionReason,
      'transactionId': transactionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedAt':
          processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  // Create from Firestore document
  factory WithdrawalRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WithdrawalRequestModel(
      id: doc.id,
      trainerId: data['trainerId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      status: (data['status'] as String? ?? 'requested').toWithdrawalStatus(),
      bankDetailsId: data['bankDetailsId'],
      rejectionReason: data['rejectionReason'],
      transactionId: data['transactionId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      processedAt: data['processedAt'] != null
          ? (data['processedAt'] as Timestamp).toDate()
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Create a copy with modifications
  WithdrawalRequestModel copyWith({
    String? id,
    String? trainerId,
    double? amount,
    WithdrawalStatus? status,
    String? bankDetailsId,
    String? rejectionReason,
    String? transactionId,
    DateTime? createdAt,
    DateTime? processedAt,
    DateTime? completedAt,
  }) {
    return WithdrawalRequestModel(
      id: id ?? this.id,
      trainerId: trainerId ?? this.trainerId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      bankDetailsId: bankDetailsId ?? this.bankDetailsId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
