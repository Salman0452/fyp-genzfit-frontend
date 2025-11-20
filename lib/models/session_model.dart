import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionStatus {
  requested,
  active,
  completed,
  rejected,
  cancelled,
}

class SessionModel {
  final String id;
  final String clientId;
  final String trainerId;
  final SessionStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, dynamic>? plan;
  final String? notes;
  final double? amount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SessionModel({
    required this.id,
    required this.clientId,
    required this.trainerId,
    required this.status,
    this.startDate,
    this.endDate,
    this.plan,
    this.notes,
    this.amount,
    required this.createdAt,
    this.updatedAt,
  });

  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SessionModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      trainerId: data['trainerId'] ?? '',
      status: _getStatus(data['status']),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      plan: data['plan'] as Map<String, dynamic>?,
      notes: data['notes'],
      amount: data['amount']?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static SessionStatus _getStatus(String? status) {
    switch (status) {
      case 'requested':
        return SessionStatus.requested;
      case 'active':
        return SessionStatus.active;
      case 'completed':
        return SessionStatus.completed;
      case 'rejected':
        return SessionStatus.rejected;
      case 'cancelled':
        return SessionStatus.cancelled;
      default:
        return SessionStatus.requested;
    }
  }

  static String statusToString(SessionStatus status) {
    return status.toString().split('.').last;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'trainerId': trainerId,
      'status': statusToString(status),
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'plan': plan,
      'notes': notes,
      'amount': amount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  SessionModel copyWith({
    String? id,
    String? clientId,
    String? trainerId,
    SessionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? plan,
    String? notes,
    double? amount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SessionModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      trainerId: trainerId ?? this.trainerId,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      plan: plan ?? this.plan,
      notes: notes ?? this.notes,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
