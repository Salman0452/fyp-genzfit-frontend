import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/plan_models.dart';
import '../../utils/constants.dart';

class AdminPlanSettingsScreen extends StatefulWidget {
  const AdminPlanSettingsScreen({super.key});

  @override
  State<AdminPlanSettingsScreen> createState() =>
      _AdminPlanSettingsScreenState();
}

class _AdminPlanSettingsScreenState extends State<AdminPlanSettingsScreen> {
  final _plansRef = FirebaseFirestore.instance.collection('plans');
  bool _saving = false;

  Color _accentColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;
  }

  Color _backgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF1A1A1A) : AppColors.background;
  }

  Color _cardColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF262626) : AppColors.surface;
  }

  InputDecoration _fieldDecoration(BuildContext context, String label,
      {String? hint}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: isDark ? const Color(0xFF1F1F1F) : AppColors.surfaceVariant,
      labelStyle: TextStyle(
        color: isDark ? AppColors.textOnBrand : AppColors.textTertiary,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: isDark ? AppColors.textSecondary : AppColors.textSecondary,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _accentColor(context), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _addOrUpdatePlan(PlanModel? plan) async {
    final nameController = TextEditingController(text: plan?.name ?? '');
    final descController = TextEditingController(text: plan?.description ?? '');
    final priceController =
        TextEditingController(text: plan?.price.toString() ?? '');
    final durationController =
        TextEditingController(text: plan?.duration ?? '');
    final dailyLimitController =
        TextEditingController(text: plan?.dailyMessageLimit.toString() ?? '');
    final sortOrderController =
        TextEditingController(text: plan?.sortOrder.toString() ?? '');
    await showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: _cardColor(context),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _accentColor(context).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  plan == null ? Icons.add_circle_outline : Icons.edit,
                  color: _accentColor(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  plan == null ? 'Add pricing plan' : 'Edit pricing plan',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: _fieldDecoration(context, 'Plan name',
                      hint: 'Free, Monthly, Yearly'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: _fieldDecoration(context, 'Description',
                      hint: 'Short benefit-focused description'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: _fieldDecoration(context, 'Price (PKR)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: dailyLimitController,
                        keyboardType: TextInputType.number,
                        decoration: _fieldDecoration(context, 'Daily AI limit'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: durationController,
                        decoration: _fieldDecoration(context, 'Duration',
                            hint: 'free / monthly / yearly'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: sortOrderController,
                        keyboardType: TextInputType.number,
                        decoration: _fieldDecoration(context, 'Sort order',
                            hint: 'Lower number shows first'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _accentColor(context).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _accentColor(context).withOpacity(0.18),
                    ),
                  ),
                  child: Text(
                    'This plan is used by the client pricing screen and AI message limits.',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textOnBrand
                          : AppColors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color:
                      isDark ? AppColors.textSecondary : AppColors.textTertiary,
                ),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor(context),
                foregroundColor: AppColors.textOnBrand,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _saving
                  ? null
                  : () async {
                      final data = {
                        'name': nameController.text.trim(),
                        'description': descController.text.trim(),
                        'price': int.tryParse(priceController.text.trim()) ?? 0,
                        'duration': durationController.text.trim(),
                        'dailyMessageLimit':
                            int.tryParse(dailyLimitController.text.trim()) ?? 0,
                        'sortOrder':
                            int.tryParse(sortOrderController.text.trim()) ?? 0,
                      };
                      setState(() => _saving = true);
                      try {
                        if (plan == null) {
                          await _plansRef.add(data);
                        } else {
                          await _plansRef.doc(plan.id).update(data);
                        }
                        if (mounted) Navigator.pop(context);
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save plan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: _backgroundColor(context),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF262626) : AppColors.surface,
        elevation: 0,
        title: Text(
          'Plan & Pricing',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: _accentColor(context),
                foregroundColor: AppColors.textOnBrand,
              ),
              icon: const Icon(Icons.add),
              onPressed: () => _addOrUpdatePlan(null),
              tooltip: 'Add plan',
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _plansRef.orderBy('sortOrder').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load pricing plans.',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            );
          }

          final plans = snapshot.data?.docs
                  .map((doc) => PlanModel.fromFirestore(doc))
                  .toList() ??
              [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _accentColor(context).withOpacity(0.95),
                      AppColors.brandBlue.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.18 : 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.price_change_outlined,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plan & Pricing',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Create subscription plans that control AI usage, price, and visibility in the client app.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.92),
                              height: 1.35,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cardColor(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF333333)
                        : const Color(0xFFE6E6E6),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage pricing plans',
                            style: TextStyle(
                              color:
                                  isDark ? Colors.white : AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add, edit, and reorder plans from one place.',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.textTertiary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor(context),
                        foregroundColor: AppColors.textOnBrand,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => _addOrUpdatePlan(null),
                      icon: const Icon(Icons.add),
                      label: const Text('Add plan'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (plans.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _cardColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF333333)
                          : const Color(0xFFE6E6E6),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 44, color: _accentColor(context)),
                      const SizedBox(height: 10),
                      Text(
                        'No pricing plans yet',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap the + button to create your first plan.',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...plans.map((plan) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _cardColor(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF333333)
                            : const Color(0xFFE6E6E6),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 6,
                            decoration: BoxDecoration(
                              color: _accentColor(context),
                              borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(20)),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          plan.name,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          plan.description,
                                          style: TextStyle(
                                            color: isDark
                                                ? AppColors.textSecondary
                                                : AppColors.textTertiary,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _addOrUpdatePlan(plan),
                                    icon: const Icon(Icons.edit_outlined),
                                    color: _accentColor(context),
                                    tooltip: 'Edit plan',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _InfoChip(
                                    icon: Icons.payments_outlined,
                                    label: 'PKR ${plan.price}',
                                    accent: _accentColor(context),
                                    dark: isDark,
                                  ),
                                  _InfoChip(
                                    icon: Icons.schedule_outlined,
                                    label: plan.duration,
                                    accent: AppColors.brandBlue,
                                    dark: isDark,
                                  ),
                                  _InfoChip(
                                    icon: Icons.smart_toy_outlined,
                                    label:
                                        '${plan.dailyMessageLimit} AI msgs/day',
                                    accent: AppColors.brandBlueDark,
                                    dark: isDark,
                                  ),
                                  _InfoChip(
                                    icon: Icons.sort,
                                    label: 'Order ${plan.sortOrder}',
                                    accent: isDark
                                        ? AppColors.brandGreen
                                        : AppColors.brandGreenDeep,
                                    dark: isDark,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool dark;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withOpacity(dark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: dark ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
