import 'package:cloud_firestore/cloud_firestore.dart';

/// Payment method types available in Pakistan
enum PaymentMethod {
  jazzCash, // Jazz Cash (mobile wallet)
  easyPaisa, // EasyPaisa (mobile wallet)
  ubl, // UBL Bank
  abl, // ABL Bank
  meezanBank, // Meezan Bank
  hbl, // Habib Bank Limited
  other, // Other banks
}

extension PaymentMethodString on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.jazzCash:
        return 'Jazz Cash';
      case PaymentMethod.easyPaisa:
        return 'EasyPaisa';
      case PaymentMethod.ubl:
        return 'UBL Bank';
      case PaymentMethod.abl:
        return 'ABL Bank';
      case PaymentMethod.meezanBank:
        return 'Meezan Bank';
      case PaymentMethod.hbl:
        return 'HBL';
      case PaymentMethod.other:
        return 'Other Bank';
    }
  }

  String get value {
    return toString().split('.').last;
  }
}

extension PaymentMethodFromString on String {
  PaymentMethod toPaymentMethod() {
    switch (this) {
      case 'jazzCash':
        return PaymentMethod.jazzCash;
      case 'easyPaisa':
        return PaymentMethod.easyPaisa;
      case 'ubl':
        return PaymentMethod.ubl;
      case 'abl':
        return PaymentMethod.abl;
      case 'meezanBank':
        return PaymentMethod.meezanBank;
      case 'hbl':
        return PaymentMethod.hbl;
      default:
        return PaymentMethod.other;
    }
  }
}

/// Transaction payment status
enum TransactionStatus {
  pendingVerification, // Awaiting admin verification
  verified, // Payment verified by admin
  completed, // Session completed & trainer paid out
  failed, // Payment verification failed
  refunded, // Refund processed
  cancelled, // Transaction cancelled
}

extension TransactionStatusString on TransactionStatus {
  String get value {
    return toString().split('.').last;
  }

  String get displayName {
    switch (this) {
      case TransactionStatus.pendingVerification:
        return 'Pending Verification';
      case TransactionStatus.verified:
        return 'Verified';
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.refunded:
        return 'Refunded';
      case TransactionStatus.cancelled:
        return 'Cancelled';
    }
  }
}

extension TransactionStatusFromString on String {
  TransactionStatus toTransactionStatus() {
    switch (this) {
      case 'pendingVerification':
        return TransactionStatus.pendingVerification;
      case 'verified':
        return TransactionStatus.verified;
      case 'completed':
        return TransactionStatus.completed;
      case 'failed':
        return TransactionStatus.failed;
      case 'refunded':
        return TransactionStatus.refunded;
      case 'cancelled':
        return TransactionStatus.cancelled;
      default:
        return TransactionStatus.pendingVerification;
    }
  }
}

/// Represents a payment transaction for trainer hiring
class TransactionModel {
  final String id;
  final String clientId;
  final String trainerId;
  final String sessionId;
  final double amount;
  final double platformFee; // 10% commission
  final double trainerAmount; // amount - platformFee
  final PaymentMethod paymentMethod;
  final TransactionStatus status;
  final String?
      clientPaymentProofUrl; // Receipt image URL from Firebase Storage
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final String? verifiedByAdminId;
  final String? rejectionReason; // If status is 'failed'
  final String? bankTransferReference; // For trainer payout reference
  final DateTime? completedAt;
  final Map<String, dynamic>? metadata; // Additional data (notes, etc.)

  TransactionModel({
    required this.id,
    required this.clientId,
    required this.trainerId,
    required this.sessionId,
    required this.amount,
    required this.platformFee,
    required this.trainerAmount,
    required this.paymentMethod,
    required this.status,
    this.clientPaymentProofUrl,
    required this.createdAt,
    this.verifiedAt,
    this.verifiedByAdminId,
    this.rejectionReason,
    this.bankTransferReference,
    this.completedAt,
    this.metadata,
  });

  /// Create from Firestore document
  factory TransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return TransactionModel(
      id: doc.id,
      clientId: data['clientId'] as String,
      trainerId: data['trainerId'] as String,
      sessionId: data['sessionId'] as String,
      amount: (data['amount'] as num).toDouble(),
      platformFee: (data['platformFee'] as num).toDouble(),
      trainerAmount: (data['trainerAmount'] as num).toDouble(),
      paymentMethod: (data['paymentMethod'] as String).toPaymentMethod(),
      status: (data['status'] as String).toTransactionStatus(),
      clientPaymentProofUrl: data['clientPaymentProofUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      verifiedAt: data['verifiedAt'] != null
          ? (data['verifiedAt'] as Timestamp).toDate()
          : null,
      verifiedByAdminId: data['verifiedByAdminId'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      bankTransferReference: data['bankTransferReference'] as String?,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'trainerId': trainerId,
      'sessionId': sessionId,
      'amount': amount,
      'platformFee': platformFee,
      'trainerAmount': trainerAmount,
      'paymentMethod': paymentMethod.value,
      'status': status.value,
      'clientPaymentProofUrl': clientPaymentProofUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'verifiedByAdminId': verifiedByAdminId,
      'rejectionReason': rejectionReason,
      'bankTransferReference': bankTransferReference,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'metadata': metadata,
    };
  }

  /// Create a copy with modifications
  TransactionModel copyWith({
    String? id,
    String? clientId,
    String? trainerId,
    String? sessionId,
    double? amount,
    double? platformFee,
    double? trainerAmount,
    PaymentMethod? paymentMethod,
    TransactionStatus? status,
    String? clientPaymentProofUrl,
    DateTime? createdAt,
    DateTime? verifiedAt,
    String? verifiedByAdminId,
    String? rejectionReason,
    String? bankTransferReference,
    DateTime? completedAt,
    Map<String, dynamic>? metadata,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      trainerId: trainerId ?? this.trainerId,
      sessionId: sessionId ?? this.sessionId,
      amount: amount ?? this.amount,
      platformFee: platformFee ?? this.platformFee,
      trainerAmount: trainerAmount ?? this.trainerAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      clientPaymentProofUrl:
          clientPaymentProofUrl ?? this.clientPaymentProofUrl,
      createdAt: createdAt ?? this.createdAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedByAdminId: verifiedByAdminId ?? this.verifiedByAdminId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      bankTransferReference:
          bankTransferReference ?? this.bankTransferReference,
      completedAt: completedAt ?? this.completedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() =>
      'TransactionModel(id: $id, clientId: $clientId, trainerId: $trainerId, amount: $amount, status: $status)';
}
