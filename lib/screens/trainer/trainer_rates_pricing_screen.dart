import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genzfit/providers/auth_provider.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/widgets/custom_button.dart';

class TrainerRatesPricingScreen extends StatefulWidget {
  const TrainerRatesPricingScreen({super.key});

  @override
  State<TrainerRatesPricingScreen> createState() =>
      _TrainerRatesPricingScreenState();
}

class _TrainerRatesPricingScreenState extends State<TrainerRatesPricingScreen> {
  late TextEditingController _hourlyRateController;
  late TextEditingController _packageNameController;
  late TextEditingController _packagePriceController;
  late TextEditingController _packageSessionsController;

  List<Map<String, dynamic>> _packages = [];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _hourlyRateController = TextEditingController();
    _packageNameController = TextEditingController();
    _packagePriceController = TextEditingController();
    _packageSessionsController = TextEditingController();
    _loadRatesAndPricing();
  }

  @override
  void dispose() {
    _hourlyRateController.dispose();
    _packageNameController.dispose();
    _packagePriceController.dispose();
    _packageSessionsController.dispose();
    super.dispose();
  }

  Future<void> _loadRatesAndPricing() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        _hourlyRateController.text = (userData['hourlyRate'] ?? 0).toString();
      }

      final trainerSnapshot = await FirebaseFirestore.instance
          .collection('trainers')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (trainerSnapshot.docs.isNotEmpty) {
        final trainerData = trainerSnapshot.docs.first.data();
        final packages = trainerData['packages'] as List<dynamic>? ?? [];

        setState(() {
          _packages =
              packages.map((p) => Map<String, dynamic>.from(p as Map)).toList();
        });
      }
    } catch (e) {
      print('Error loading rates: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRatesAndPricing() async {
    if (_hourlyRateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter hourly rate'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) throw Exception('User not authenticated');

      final hourlyRate = double.parse(_hourlyRateController.text);

      // Update user hourly rate
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'hourlyRate': hourlyRate});

      // Update trainer packages
      final trainerSnapshot = await FirebaseFirestore.instance
          .collection('trainers')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (trainerSnapshot.docs.isNotEmpty) {
        final trainerId = trainerSnapshot.docs.first.id;
        await FirebaseFirestore.instance
            .collection('trainers')
            .doc(trainerId)
            .update({'packages': _packages});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rates and pricing updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save rates: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _addPackage() {
    if (_packageNameController.text.isEmpty ||
        _packagePriceController.text.isEmpty ||
        _packageSessionsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all package fields'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _packages.add({
        'name': _packageNameController.text,
        'price': double.parse(_packagePriceController.text),
        'sessions': int.parse(_packageSessionsController.text),
      });
      _packageNameController.clear();
      _packagePriceController.clear();
      _packageSessionsController.clear();
    });
  }

  void _removePackage(int index) {
    setState(() => _packages.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Rates & Pricing'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hourly Rate Section
                  Text(
                    'Hourly Rate',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hourlyRateController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Enter hourly rate',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.borderRadius),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.borderRadius),
                        borderSide: const BorderSide(
                          color: AppColors.brandGreen,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Packages Section
                  Text(
                    'Package Pricing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Create session packages at discounted rates',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0B0B0)
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Add Package Form
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1A1A1A)
                          : AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppSizes.borderRadius),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF333333)
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add New Package',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFFFFFFF)
                                    : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _packageNameController,
                          decoration: InputDecoration(
                            hintText: 'Package name (e.g., 5-Session Pack)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _packageSessionsController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Sessions',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _packagePriceController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Total Price',
                                  prefixText: '\$ ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _addPackage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandGreen,
                            ),
                            child: const Text('Add Package'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Packages List
                  if (_packages.isNotEmpty) ...[
                    Text(
                      'Current Packages',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _packages.length,
                      itemBuilder: (context, index) {
                        final package = _packages[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF1A1A1A)
                                    : AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(AppSizes.borderRadius),
                            border: Border.all(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF333333)
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      package['name'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFFFFFFF)
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${package['sessions']} sessions - \$${package['price']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFB0B0B0)
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _removePackage(index),
                                icon: const Icon(Icons.delete_outline),
                                color: AppColors.error,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: _isSaving ? 'Saving...' : 'Save Rates & Pricing',
                      isLoading: _isSaving,
                      onPressed: _saveRatesAndPricing,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
