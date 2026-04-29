import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/plan_models.dart';

class AdminPlanSettingsScreen extends StatefulWidget {
  const AdminPlanSettingsScreen({super.key});

  @override
  State<AdminPlanSettingsScreen> createState() =>
      _AdminPlanSettingsScreenState();
}

class _AdminPlanSettingsScreenState extends State<AdminPlanSettingsScreen> {
  final _plansRef = FirebaseFirestore.instance.collection('plans');
  final _bankDetailsController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _bankDetailsController.dispose();
    super.dispose();
  }

  Future<void> _saveBankDetails() async {
    // Save to a settings collection or a dedicated doc
    await FirebaseFirestore.instance.collection('settings').doc('admin').set({
      'bankDetails': _bankDetailsController.text,
    }, SetOptions(merge: true));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Bank details updated.')));
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
      builder: (context) => AlertDialog(
        title: Text(plan == null ? 'Add Plan' : 'Edit Plan'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name')),
              TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description')),
              TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                      labelText: 'Duration (free/monthly/yearly)')),
              TextField(
                  controller: dailyLimitController,
                  decoration:
                      const InputDecoration(labelText: 'Daily Message Limit'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: sortOrderController,
                  decoration: const InputDecoration(labelText: 'Sort Order'),
                  keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'name': nameController.text,
                'description': descController.text,
                'price': int.tryParse(priceController.text) ?? 0,
                'duration': durationController.text,
                'dailyMessageLimit':
                    int.tryParse(dailyLimitController.text) ?? 0,
                'sortOrder': int.tryParse(sortOrderController.text) ?? 0,
              };
              if (plan == null) {
                await _plansRef.add(data);
              } else {
                await _plansRef.doc(plan.id).update(data);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Plan & Bank Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Bank Details (shown to clients for payment):'),
            TextField(
              controller: _bankDetailsController,
              maxLines: 2,
              decoration: const InputDecoration(
                  hintText: 'Bank details, account number, etc.'),
            ),
            ElevatedButton(
                onPressed: _saveBankDetails,
                child: const Text('Save Bank Details')),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Plans',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addOrUpdatePlan(null),
                ),
              ],
            ),
            StreamBuilder<QuerySnapshot>(
              stream: _plansRef.orderBy('sortOrder').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final plans = snapshot.data!.docs
                    .map((doc) => PlanModel.fromFirestore(doc))
                    .toList();
                return Column(
                  children: plans
                      .map((plan) => ListTile(
                            title: Text(plan.name),
                            subtitle: Text(plan.description +
                                '\nPKR ${plan.price} (${plan.duration}), Daily: ${plan.dailyMessageLimit}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _addOrUpdatePlan(plan),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
