import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/plan_provider.dart';
import '../../models/plan_models.dart';

class PlanSelectionScreen extends StatelessWidget {
  final String userId;
  final String? adminBankDetails; // Pass from settings or fetch in provider

  const PlanSelectionScreen(
      {super.key, required this.userId, this.adminBankDetails});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PlanProvider()
        ..loadPlans()
        ..loadActiveSubscription(userId)
        ..loadTodayUsage(userId),
      child: Consumer<PlanProvider>(
        builder: (context, planProvider, _) {
          if (planProvider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Choose Your Plan')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (planProvider.activeSubscription != null)
                  Card(
                    color: Colors.green.shade50,
                    child: ListTile(
                      title: Text(
                          'Current Plan: ${planProvider.plans.firstWhere((p) => p.id == planProvider.activeSubscription!.planId, orElse: () => PlanModel(id: '', name: 'Unknown', dailyMessageLimit: 0, price: 0, duration: '', description: '', sortOrder: 0)).name}'),
                      subtitle: Text(
                          'Status: ${planProvider.activeSubscription!.status}'),
                    ),
                  ),
                ...planProvider.plans.map((plan) => Card(
                      child: ListTile(
                        title: Text(plan.name),
                        subtitle: Text(plan.description +
                            '\nDaily AI Chatbot Messages: ${plan.dailyMessageLimit}\nPrice: PKR ${plan.price} (${plan.duration})'),
                        trailing: ElevatedButton(
                          onPressed: planProvider.activeSubscription?.planId ==
                                      plan.id &&
                                  planProvider.activeSubscription?.status ==
                                      'active'
                              ? null
                              : () => _showPurchaseDialog(
                                  context, plan, adminBankDetails, userId),
                          child: const Text('Purchase'),
                        ),
                      ),
                    )),
                const SizedBox(height: 24),
                if (planProvider.todayUsage != null)
                  Text(
                      'Today\'s AI Chatbot Usage: ${planProvider.todayUsage!.messageCount} / ${planProvider.plans.firstWhere((p) => p.id == planProvider.activeSubscription?.planId, orElse: () => PlanModel(id: '', name: '', dailyMessageLimit: 0, price: 0, duration: '', description: '', sortOrder: 0)).dailyMessageLimit}'),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context, PlanModel plan,
      String? adminBankDetails, String userId) {
    final TextEditingController _receiptController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Purchase ${plan.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (adminBankDetails != null) ...[
              Text('Send payment to:'),
              SelectableText(adminBankDetails,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
            ],
            const Text('Upload payment receipt (URL):'),
            TextField(
              controller: _receiptController,
              decoration:
                  const InputDecoration(hintText: 'Paste receipt image URL'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_receiptController.text.isEmpty) return;
              await Provider.of<PlanProvider>(context, listen: false)
                  .createSubscriptionRequest(
                userId: userId,
                planId: plan.id,
                paymentReceiptUrl: _receiptController.text,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'Purchase request submitted. Awaiting admin verification.')));
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
