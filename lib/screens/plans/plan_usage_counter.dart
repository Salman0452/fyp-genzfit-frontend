import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/plan_provider.dart';

class PlanUsageCounter extends StatelessWidget {
  final int dailyLimit;
  const PlanUsageCounter({super.key, required this.dailyLimit});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlanProvider>(
      builder: (context, planProvider, _) {
        final used = planProvider.todayUsage?.messageCount ?? 0;
        return Text('AI Chatbot Usage: $used / $dailyLimit',
            style: const TextStyle(fontWeight: FontWeight.bold));
      },
    );
  }
}
