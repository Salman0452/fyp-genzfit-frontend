import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/plan_models.dart';

class PlanService {
  final _plansRef = FirebaseFirestore.instance.collection('plans');
  final _subscriptionsRef =
      FirebaseFirestore.instance.collection('user_subscriptions');
  final _usageRef = FirebaseFirestore.instance.collection('chatbot_usage');

  String _inferBillingCycle(String duration) {
    final normalized = duration.trim().toLowerCase();
    if (normalized.contains('year')) return 'yearly';
    if (normalized.contains('month')) return 'monthly';
    if (normalized == 'free') return 'free';
    return 'custom';
  }

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
    required String planName,
    required String planDuration,
    required double planPrice,
    required String billingCycle,
  }) async {
    await _subscriptionsRef.add({
      'userId': userId,
      'planId': planId,
      'planName': planName,
      'planDuration': planDuration,
      'planPrice': planPrice,
      'billingCycle': billingCycle,
      'startDate': Timestamp.now(),
      'status': 'pending',
      'paymentReceiptUrl': paymentReceiptUrl,
      'requestType': 'subscription_purchase',
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

  Stream<List<Map<String, dynamic>>> getPendingSubscriptions() {
    return _subscriptionsRef
        .where('status', isEqualTo: 'pending')
        .orderBy('startDate', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> pendingList = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String;
        final planId = data['planId'] as String;

        // Fetch user info
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        final userData = userDoc.data() ?? {};

        // Fetch plan info
        final planDoc = await _plansRef.doc(planId).get();
        final planData = planDoc.data() ?? {};
        final rawDuration = (data['planDuration'] as String?) ??
            (planData['duration'] as String?) ??
            '';
        final billingCycle = (data['billingCycle'] as String?)
                    ?.trim()
                    .toLowerCase()
                    .isNotEmpty ==
                true
            ? (data['billingCycle'] as String).trim().toLowerCase()
            : _inferBillingCycle(rawDuration);

        pendingList.add({
          'docId': doc.id,
          'userId': userId,
          'userName': userData['name'] ?? 'Unknown User',
          'userEmail': userData['email'] ?? '',
          'userAvatar': userData['profilePhoto'] ?? '',
          'planId': planId,
          'planName': (data['planName'] as String?)?.isNotEmpty == true
              ? data['planName']
              : (planData['name'] ?? 'Unknown Plan'),
          'planPrice':
              (data['planPrice'] as num?) ?? (planData['price'] ?? 0.0),
          'planDuration': rawDuration,
          'billingCycle': billingCycle,
          'receiptUrl': data['paymentReceiptUrl'] ?? '',
          'timestamp': data['startDate'],
          'status': data['status'] ?? 'pending',
        });
      }

      return pendingList;
    });
  }

  Future<void> approveSubscription({
    required String docId,
    required int durationDays,
  }) async {
    final endDate = DateTime.now().add(Duration(days: durationDays));

    await _subscriptionsRef.doc(docId).update({
      'status': 'active',
      'endDate': Timestamp.fromDate(endDate),
      'approvedDate': Timestamp.now(),
    });
  }

  Future<void> rejectSubscription({
    required String docId,
    required String adminNote,
  }) async {
    await _subscriptionsRef.doc(docId).update({
      'status': 'rejected',
      'adminNote': adminNote,
      'rejectedDate': Timestamp.now(),
    });
  }
}
