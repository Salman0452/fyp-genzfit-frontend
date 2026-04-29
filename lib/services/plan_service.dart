import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/plan_models.dart';

class PlanService {
  final _plansRef = FirebaseFirestore.instance.collection('plans');
  final _subscriptionsRef =
      FirebaseFirestore.instance.collection('user_subscriptions');
  final _usageRef = FirebaseFirestore.instance.collection('chatbot_usage');

  Future<List<PlanModel>> fetchPlans() async {
    final snapshot = await _plansRef.orderBy('sortOrder').get();
    return snapshot.docs.map((doc) => PlanModel.fromFirestore(doc)).toList();
  }

  Future<UserSubscriptionModel?> getActiveSubscription(String userId) async {
    final snapshot = await _subscriptionsRef
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .orderBy('startDate', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return UserSubscriptionModel.fromFirestore(snapshot.docs.first);
  }

  Future<void> createSubscriptionRequest({
    required String userId,
    required String planId,
    required String paymentReceiptUrl,
  }) async {
    await _subscriptionsRef.add({
      'userId': userId,
      'planId': planId,
      'startDate': Timestamp.now(),
      'status': 'pending',
      'paymentReceiptUrl': paymentReceiptUrl,
    });
  }

  Future<ChatbotUsageModel?> getTodayUsage(String userId) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    final snapshot = await _usageRef
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return ChatbotUsageModel.fromFirestore(snapshot.docs.first);
  }

  Future<void> incrementUsage(String userId) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final usageQuery = await _usageRef
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .limit(1)
        .get();
    if (usageQuery.docs.isEmpty) {
      await _usageRef.add({
        'userId': userId,
        'date': Timestamp.fromDate(start),
        'messageCount': 1,
      });
    } else {
      final doc = usageQuery.docs.first;
      await doc.reference.update({
        'messageCount': FieldValue.increment(1),
      });
    }
  }
}
