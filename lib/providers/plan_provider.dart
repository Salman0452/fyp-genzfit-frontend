import 'package:flutter/material.dart';
import '../models/plan_models.dart';
import '../services/plan_service.dart';

class PlanProvider extends ChangeNotifier {
  final PlanService _planService = PlanService();

  List<PlanModel> _plans = [];
  UserSubscriptionModel? _activeSubscription;
  ChatbotUsageModel? _todayUsage;
  bool _loading = false;

  List<PlanModel> get plans => _plans;
  UserSubscriptionModel? get activeSubscription => _activeSubscription;
  ChatbotUsageModel? get todayUsage => _todayUsage;
  bool get loading => _loading;

  Future<void> loadPlans() async {
    _loading = true;
    notifyListeners();
    _plans = await _planService.fetchPlans();
    _loading = false;
    notifyListeners();
  }

  Future<void> loadActiveSubscription(String userId) async {
    _activeSubscription = await _planService.getActiveSubscription(userId);
    notifyListeners();
  }

  Future<void> loadTodayUsage(String userId) async {
    _todayUsage = await _planService.getTodayUsage(userId);
    notifyListeners();
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
    await _planService.createSubscriptionRequest(
      userId: userId,
      planId: planId,
      paymentReceiptUrl: paymentReceiptUrl,
      planName: planName,
      planDuration: planDuration,
      planPrice: planPrice,
      billingCycle: billingCycle,
    );
    await loadActiveSubscription(userId);
  }

  Future<void> incrementUsage(String userId) async {
    await _planService.incrementUsage(userId);
    await loadTodayUsage(userId);
  }

  Stream<List<Map<String, dynamic>>> getPendingSubscriptionsStream() {
    return _planService.getPendingSubscriptions();
  }

  Future<void> approveSubscription({
    required String docId,
    required int durationDays,
  }) async {
    await _planService.approveSubscription(
      docId: docId,
      durationDays: durationDays,
    );
  }

  Future<void> rejectSubscription({
    required String docId,
    required String adminNote,
  }) async {
    await _planService.rejectSubscription(
      docId: docId,
      adminNote: adminNote,
    );
  }
}
