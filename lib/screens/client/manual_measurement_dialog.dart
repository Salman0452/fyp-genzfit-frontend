import 'package:flutter/material.dart';
import 'package:genzfit/models/measurement_model.dart';
import 'package:genzfit/services/body_analysis_service.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/widgets/custom_button.dart';

class ManualMeasurementDialog extends StatefulWidget {
  final String userId;
  final MeasurementModel? existingMeasurement;
  final VoidCallback onMeasurementSaved;

  const ManualMeasurementDialog({
    super.key,
    required this.userId,
    this.existingMeasurement,
    required this.onMeasurementSaved,
  });

  @override
  State<ManualMeasurementDialog> createState() =>
      _ManualMeasurementDialogState();
}

class _ManualMeasurementDialogState extends State<ManualMeasurementDialog> {
  final BodyAnalysisService _bodyAnalysisService = BodyAnalysisService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _shoulderController;
  late TextEditingController _chestController;
  late TextEditingController _waistController;
  late TextEditingController _hipController;
  late TextEditingController _armLengthController;
  late TextEditingController _legLengthController;
  late TextEditingController _neckController;
  late TextEditingController _thighController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadExistingMeasurements();
  }

  void _initializeControllers() {
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _shoulderController = TextEditingController();
    _chestController = TextEditingController();
    _waistController = TextEditingController();
    _hipController = TextEditingController();
    _armLengthController = TextEditingController();
    _legLengthController = TextEditingController();
    _neckController = TextEditingController();
    _thighController = TextEditingController();
  }

  void _loadExistingMeasurements() async {
    setState(() => _isLoading = true);
    try {
      final measurement =
          await _bodyAnalysisService.getLatestMeasurement(widget.userId);
      if (measurement != null && mounted) {
        _heightController.text = measurement.height.toStringAsFixed(1);
        _weightController.text = measurement.weight.toStringAsFixed(1);

        // Pre-fill estimated measurements
        final estimated = measurement.estimatedMeasurements;
        if (estimated.containsKey('shoulders')) {
          _shoulderController.text = estimated['shoulders']!.toStringAsFixed(1);
        }
        if (estimated.containsKey('chest')) {
          _chestController.text = estimated['chest']!.toStringAsFixed(1);
        }
        if (estimated.containsKey('waist')) {
          _waistController.text = estimated['waist']!.toStringAsFixed(1);
        }
        if (estimated.containsKey('hips')) {
          _hipController.text = estimated['hips']!.toStringAsFixed(1);
        }
        if (estimated.containsKey('arm_length')) {
          _armLengthController.text =
              estimated['arm_length']!.toStringAsFixed(1);
        }
        if (estimated.containsKey('leg_length')) {
          _legLengthController.text =
              estimated['leg_length']!.toStringAsFixed(1);
        }
        if (estimated.containsKey('neck')) {
          _neckController.text = estimated['neck']!.toStringAsFixed(1);
        }
        if (estimated.containsKey('thigh')) {
          _thighController.text = estimated['thigh']!.toStringAsFixed(1);
        }
        setState(() => _isLoading = false);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load existing measurements: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _handleSave() {
    _saveMeasurements();
  }

  Future<void> _saveMeasurements() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final height = double.parse(_heightController.text);
      final weight = double.parse(_weightController.text);

      final estimatedMeasurements = <String, double>{};
      if (_shoulderController.text.isNotEmpty) {
        estimatedMeasurements['shoulders'] =
            double.parse(_shoulderController.text);
      }
      if (_chestController.text.isNotEmpty) {
        estimatedMeasurements['chest'] = double.parse(_chestController.text);
      }
      if (_waistController.text.isNotEmpty) {
        estimatedMeasurements['waist'] = double.parse(_waistController.text);
      }
      if (_hipController.text.isNotEmpty) {
        estimatedMeasurements['hips'] = double.parse(_hipController.text);
      }
      if (_armLengthController.text.isNotEmpty) {
        estimatedMeasurements['arm_length'] =
            double.parse(_armLengthController.text);
      }
      if (_legLengthController.text.isNotEmpty) {
        estimatedMeasurements['leg_length'] =
            double.parse(_legLengthController.text);
      }
      if (_neckController.text.isNotEmpty) {
        estimatedMeasurements['neck'] = double.parse(_neckController.text);
      }
      if (_thighController.text.isNotEmpty) {
        estimatedMeasurements['thigh'] = double.parse(_thighController.text);
      }

      // Save manual measurement using existing service method
      await _bodyAnalysisService.saveMeasurement(
        userId: widget.userId,
        height: height,
        weight: weight,
        bodyLandmarks: {}, // Empty landmarks for manual entry
        photos: [], // No photos for manual entry
        estimatedMeasurements: estimatedMeasurements,
        notes: 'Manual measurement entry',
      );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Measurements saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onMeasurementSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save measurements: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _shoulderController.dispose();
    _chestController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    _armLengthController.dispose();
    _legLengthController.dispose();
    _neckController.dispose();
    _thighController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1A1A)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.brandGreen),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color:
                              (Theme.of(context).brightness == Brightness.dark
                                      ? AppColors.brandGreen
                                      : AppColors.brandGreenDeep)
                                  .withOpacity(0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Manual Measurements',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFFFFFFF)
                                    : AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFB0B0B0)
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  // Form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Height & Weight Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    label: 'Height (cm)',
                                    controller: _heightController,
                                    hint: 'e.g., 175',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    label: 'Weight (kg)',
                                    controller: _weightController,
                                    hint: 'e.g., 75',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Shoulders & Chest Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    label: 'Shoulders (cm)',
                                    controller: _shoulderController,
                                    hint: 'Optional',
                                    isRequired: false,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    label: 'Chest (cm)',
                                    controller: _chestController,
                                    hint: 'Optional',
                                    isRequired: false,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Waist & Hips Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    label: 'Waist (cm)',
                                    controller: _waistController,
                                    hint: 'Optional',
                                    isRequired: false,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    label: 'Hips (cm)',
                                    controller: _hipController,
                                    hint: 'Optional',
                                    isRequired: false,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Arm Length & Leg Length Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    label: 'Arm Length (cm)',
                                    controller: _armLengthController,
                                    hint: 'Optional',
                                    isRequired: false,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    label: 'Leg Length (cm)',
                                    controller: _legLengthController,
                                    hint: 'Optional',
                                    isRequired: false,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Neck & Thigh Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    label: 'Neck (cm)',
                                    controller: _neckController,
                                    hint: 'Optional',
                                    isRequired: false,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    label: 'Thigh (cm)',
                                    controller: _thighController,
                                    hint: 'Optional',
                                    isRequired: false,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Footer with buttons
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color:
                              (Theme.of(context).brightness == Brightness.dark
                                      ? AppColors.brandGreen
                                      : AppColors.brandGreenDeep)
                                  .withOpacity(0.2),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton(
                          onPressed:
                              _isSaving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.brandGreen
                                      : AppColors.brandGreenDeep)
                                  .withOpacity(0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.brandGreen
                                  : AppColors.brandGreenDeep,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CustomButton(
                          text: _isSaving ? 'Saving...' : 'Save',
                          onPressed: _isSaving ? () {} : _handleSave,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFFFFFFF)
            : AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFB0B0B0)
              : AppColors.textSecondary,
          fontSize: 12,
        ),
        hintStyle: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF666666)
              : AppColors.textSecondary.withOpacity(0.5),
          fontSize: 12,
        ),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Required';
        }
        if (value != null && value.isNotEmpty) {
          try {
            double.parse(value);
          } catch (e) {
            return 'Invalid number';
          }
        }
        return null;
      },
    );
  }
}
