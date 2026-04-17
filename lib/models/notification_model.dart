import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String type; // 'session_approved', 'payment_rejected', 'message', etc.
  final String title;
  final String message;
  final String? sessionId;
  final String? trainerId;
  final String? clientId;
  final DateTime createdAt;
  final bool read;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.sessionId,
    this.trainerId,
    this.clientId,
    required this.createdAt,
    required this.read,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      sessionId: data['sessionId'],
      trainerId: data['trainerId'],
      clientId: data['clientId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'sessionId': sessionId,
      'trainerId': trainerId,
      'clientId': clientId,
      'createdAt': Timestamp.fromDate(createdAt),
      'read': read,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? message,
    String? sessionId,
    String? trainerId,
    String? clientId,
    DateTime? createdAt,
    bool? read,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      sessionId: sessionId ?? this.sessionId,
      trainerId: trainerId ?? this.trainerId,
      clientId: clientId ?? this.clientId,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
    );
  }
}
