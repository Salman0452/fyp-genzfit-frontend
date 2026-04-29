import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/plan_models.dart';
import '../services/plan_service.dart';

class ChatbotGuardService {
  final PlanService _planService = PlanService();

  /// Returns true if user can send a message, false if limit reached
  Future<bool> canSendMessage(String userId) async {
    final sub = await _planService.getActiveSubscription(userId);
    if (sub == null) return false;
    final planDoc = await FirebaseFirestore.instance
        .collection('plans')
        .doc(sub.planId)
        .get();
    if (!planDoc.exists) return false;
    final plan = PlanModel.fromFirestore(planDoc);
    final usage = await _planService.getTodayUsage(userId);
    final used = usage?.messageCount ?? 0;
    return used < plan.dailyMessageLimit;
  }

  /// Call this after sending a message
  Future<void> incrementUsage(String userId) async {
    await _planService.incrementUsage(userId);
  }
}
