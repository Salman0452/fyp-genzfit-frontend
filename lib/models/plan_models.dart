import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a subscription plan (free, monthly, yearly)
class PlanModel {
  final String id;
  final String name; // e.g., Free, Monthly, Yearly
  final int dailyMessageLimit;
  final int price; // in PKR
  final String duration; // 'free', 'monthly', 'yearly'
  final String description;
  final int sortOrder;

  PlanModel({
    required this.id,
    required this.name,
    required this.dailyMessageLimit,
    required this.price,
    required this.duration,
    required this.description,
    required this.sortOrder,
  });

  factory PlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlanModel(
      id: doc.id,
      name: data['name'] ?? '',
      dailyMessageLimit: data['dailyMessageLimit'] ?? 0,
      price: data['price'] ?? 0,
      duration: data['duration'] ?? 'free',
      description: data['description'] ?? '',
      sortOrder: data['sortOrder'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'dailyMessageLimit': dailyMessageLimit,
      'price': price,
      'duration': duration,
      'description': description,
      'sortOrder': sortOrder,
    };
  }
}

/// Represents a user's subscription to a plan
class UserSubscriptionModel {
  final String id;
  final String userId;
  final String planId;
  final DateTime startDate;
  final DateTime? endDate;
  final String status; // 'pending', 'active', 'expired', 'cancelled'
  final String? paymentReceiptUrl;
  final String? adminNote;

  UserSubscriptionModel({
    required this.id,
    required this.userId,
    required this.planId,
    required this.startDate,
    this.endDate,
    required this.status,
    this.paymentReceiptUrl,
    this.adminNote,
  });

  factory UserSubscriptionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserSubscriptionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      planId: data['planId'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      status: data['status'] ?? 'pending',
      paymentReceiptUrl: data['paymentReceiptUrl'],
      adminNote: data['adminNote'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'planId': planId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'status': status,
      'paymentReceiptUrl': paymentReceiptUrl,
      'adminNote': adminNote,
    };
  }
}

/// Tracks daily AI chatbot message usage for a user
class ChatbotUsageModel {
  final String id;
  final String userId;
  final DateTime date;
  final int messageCount;

  ChatbotUsageModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.messageCount,
  });

  factory ChatbotUsageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatbotUsageModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      messageCount: data['messageCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'messageCount': messageCount,
    };
  }
}
