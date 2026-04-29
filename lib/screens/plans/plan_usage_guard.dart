import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/plan_provider.dart';

/// Widget to wrap AI chatbot input and enforce message limits
class PlanUsageGuard extends StatelessWidget {
  final String userId;
  final Widget child;
  final int dailyLimit;

  const PlanUsageGuard(
      {super.key,
      required this.userId,
      required this.child,
      required this.dailyLimit});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlanProvider>(
      builder: (context, planProvider, _) {
        final usage = planProvider.todayUsage?.messageCount ?? 0;
        if (usage >= dailyLimit) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, color: Colors.red, size: 40),
                const SizedBox(height: 12),
                Text(
                    'You have reached your daily AI chatbot message limit. Upgrade your plan to continue.'),
              ],
            ),
          );
        }
        return child;
      },
    );
  }
}
