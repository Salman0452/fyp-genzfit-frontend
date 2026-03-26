import 'package:cloud_firestore/cloud_firestore.dart';

/// Bank verification status
enum BankVerificationStatus {
  unverified, // Not yet verified by admin
  verified, // Verified and approved
  rejected, // Rejected - needs resubmission
  pending, // Verification in progress
}

extension BankVerificationStatusString on BankVerificationStatus {
  String get value {
    return toString().split('.').last;
  }

  String get displayName {
    switch (this) {
      case BankVerificationStatus.unverified:
        return 'Unverified';
      case BankVerificationStatus.verified:
        return 'Verified';
      case BankVerificationStatus.rejected:
        return 'Rejected';
      case BankVerificationStatus.pending:
        return 'Pending';
    }
  }
}

extension BankVerificationStatusFromString on String {
  BankVerificationStatus toBankVerificationStatus() {
    switch (this) {
      case 'unverified':
        return BankVerificationStatus.unverified;
      case 'verified':
        return BankVerificationStatus.verified;
      case 'rejected':
        return BankVerificationStatus.rejected;
      case 'pending':
        return BankVerificationStatus.pending;
      default:
        return BankVerificationStatus.unverified;
    }
  }
}

/// Represents trainer's bank details for receiving payouts
class BankDetailsModel {
  final String id;
  final String trainerId;
  final String accountHolderName;
  final String bankName;
  final String accountNumber; // Or IBAN for international
  final String? iban;
  final String? phoneNumber; // For Jazz Cash / EasyPaisa
  final String transferMethod; // 'bank_transfer', 'jazz_cash', 'easypaisa'
  final BankVerificationStatus verificationStatus;
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final String? verifiedByAdminId;
  final String? rejectionReason;
  final bool isDefault; // Primary payout method
  final DateTime updatedAt;

  BankDetailsModel({
    required this.id,
    required this.trainerId,
    required this.accountHolderName,
    required this.bankName,
    required this.accountNumber,
    this.iban,
    this.phoneNumber,
    required this.transferMethod,
    required this.verificationStatus,
    required this.createdAt,
    this.verifiedAt,
    this.verifiedByAdminId,
    this.rejectionReason,
    required this.isDefault,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory BankDetailsModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return BankDetailsModel(
      id: doc.id,
      trainerId: data['trainerId'] as String,
      accountHolderName: data['accountHolderName'] as String,
      bankName: data['bankName'] as String,
      accountNumber: data['accountNumber'] as String,
      iban: data['iban'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      transferMethod: data['transferMethod'] as String,
      verificationStatus:
          (data['verificationStatus'] as String).toBankVerificationStatus(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      verifiedAt: data['verifiedAt'] != null
          ? (data['verifiedAt'] as Timestamp).toDate()
          : null,
      verifiedByAdminId: data['verifiedByAdminId'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      isDefault: data['isDefault'] as bool? ?? false,
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'trainerId': trainerId,
      'accountHolderName': accountHolderName,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'iban': iban,
      'phoneNumber': phoneNumber,
      'transferMethod': transferMethod,
      'verificationStatus': verificationStatus.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'verifiedByAdminId': verifiedByAdminId,
      'rejectionReason': rejectionReason,
      'isDefault': isDefault,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with modifications
  BankDetailsModel copyWith({
    String? id,
    String? trainerId,
    String? accountHolderName,
    String? bankName,
    String? accountNumber,
    String? iban,
    String? phoneNumber,
    String? transferMethod,
    BankVerificationStatus? verificationStatus,
    DateTime? createdAt,
    DateTime? verifiedAt,
    String? verifiedByAdminId,
    String? rejectionReason,
    bool? isDefault,
    DateTime? updatedAt,
  }) {
    return BankDetailsModel(
      id: id ?? this.id,
      trainerId: trainerId ?? this.trainerId,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      iban: iban ?? this.iban,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      transferMethod: transferMethod ?? this.transferMethod,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      createdAt: createdAt ?? this.createdAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedByAdminId: verifiedByAdminId ?? this.verifiedByAdminId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      isDefault: isDefault ?? this.isDefault,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Mask account number for display (show last 4 digits)
  String get maskedAccountNumber {
    if (accountNumber.length <= 4) return '****';
    return '****${accountNumber.substring(accountNumber.length - 4)}';
  }

  @override
  String toString() =>
      'BankDetailsModel(id: $id, trainerId: $trainerId, bankName: $bankName, verificationStatus: $verificationStatus)';
}
