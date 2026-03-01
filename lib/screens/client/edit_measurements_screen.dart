import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

/// Screen that lets the user manually enter / edit their body measurements.
///
/// The measurements are stored in Firestore under the `measurements`
/// collection using the same keys the avatar backend expects:
///   chest, waist, hips, shoulderWidth, neck
///
/// After saving, the caller can optionally trigger avatar regeneration by
/// awaiting the returned Future<bool> (true = saved, false = cancelled).
class EditMeasurementsScreen extends StatefulWidget {
  /// Pre-fill fields from an existing measurement document.
  final Map<String, double> initialMeasurements;
  final double initialHeight;
  final double initialWeight;
  final String? existingDocId; // Firestore doc ID to update, or null to create

  const EditMeasurementsScreen({
    super.key,
    this.initialMeasurements = const {},
    this.initialHeight = 0,
    this.initialWeight = 0,
    this.existingDocId,
  });

  @override
  State<EditMeasurementsScreen> createState() => _EditMeasurementsScreenState();
}

class _EditMeasurementsScreenState extends State<EditMeasurementsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Controllers for every field
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _chestCtrl;
  late final TextEditingController _waistCtrl;
  late final TextEditingController _hipsCtrl;
  late final TextEditingController _shoulderCtrl;
  late final TextEditingController _neckCtrl;
  late final TextEditingController _bicepCtrl;
  late final TextEditingController _thighCtrl;

  @override
  void initState() {
    super.initState();
    final m = widget.initialMeasurements;

    String fmt(double? v) => (v != null && v > 0) ? v.toStringAsFixed(1) : '';

    _heightCtrl   = TextEditingController(text: widget.initialHeight > 0 ? widget.initialHeight.toStringAsFixed(1) : '');
    _weightCtrl   = TextEditingController(text: widget.initialWeight > 0 ? widget.initialWeight.toStringAsFixed(1) : '');
    _chestCtrl    = TextEditingController(text: fmt(m['chest']));
    _waistCtrl    = TextEditingController(text: fmt(m['waist']));
    _hipsCtrl     = TextEditingController(text: fmt(m['hips']));
    _shoulderCtrl = TextEditingController(text: fmt(m['shoulderWidth'] ?? m['shoulders']));
    _neckCtrl     = TextEditingController(text: fmt(m['neck']));
    _bicepCtrl    = TextEditingController(text: fmt(m['bicep']));
    _thighCtrl    = TextEditingController(text: fmt(m['thigh']));
  }

  @override
  void dispose() {
    for (final c in [
      _heightCtrl, _weightCtrl, _chestCtrl, _waistCtrl, _hipsCtrl,
      _shoulderCtrl, _neckCtrl, _bicepCtrl, _thighCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  double? _parse(TextEditingController c) {
    final v = double.tryParse(c.text.trim());
    return (v != null && v > 0) ? v : null;
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.uid;
    if (userId == null) {
      _showError('Not authenticated.');
      return;
    }

    final height = _parse(_heightCtrl);
    final weight = _parse(_weightCtrl);

    if (height == null || weight == null) {
      _showError('Height and weight are required.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Build the estimatedMeasurements map with only non-empty values
      final meas = <String, dynamic>{};
      void add(String key, TextEditingController c) {
        final v = _parse(c);
        if (v != null) meas[key] = v;
      }

      add('chest',         _chestCtrl);
      add('waist',         _waistCtrl);
      add('hips',          _hipsCtrl);
      add('shoulderWidth', _shoulderCtrl);
      add('shoulders',     _shoulderCtrl); // alias so both keys exist
      add('neck',          _neckCtrl);
      add('bicep',         _bicepCtrl);
      add('thigh',         _thighCtrl);

      final docData = {
        'userId':                userId,
        'date':                  Timestamp.now(),
        'height':                height,
        'weight':                weight,
        'bodyLandmarks':         {},
        'photoUrls':             [],
        'estimatedMeasurements': meas,
        'notes':                 'Manual entry',
        'source':                'manual',
      };

      final db = FirebaseFirestore.instance;
      if (widget.existingDocId != null) {
        await db.collection('measurements').doc(widget.existingDocId).set(
          docData,
          SetOptions(merge: false),
        );
      } else {
        await db.collection('measurements').add(docData);
      }

      if (mounted) {
        Navigator.pop(context, true); // signal "saved"
      }
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Edit Measurements'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Info banner ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enter your measurements in centimetres (cm) and weight in kg. '
                      'These values are sent directly to the avatar engine — '
                      'save and regenerate your avatar to see the result.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Section: Basic ───────────────────────────────────────────
            _sectionHeader('Basic Info'),
            Row(children: [
              Expanded(
                child: _field(
                  controller: _heightCtrl,
                  label: 'Height',
                  unit: 'cm',
                  icon: Icons.height,
                  required: true,
                  min: 50,
                  max: 250,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  controller: _weightCtrl,
                  label: 'Weight',
                  unit: 'kg',
                  icon: Icons.monitor_weight_outlined,
                  required: true,
                  min: 20,
                  max: 300,
                ),
              ),
            ]),

            const SizedBox(height: 24),

            // ── Section: Circumferences ──────────────────────────────────
            _sectionHeader('Body Circumferences (cm)'),
            _field(
              controller: _chestCtrl,
              label: 'Chest / Bust',
              unit: 'cm',
              icon: Icons.accessibility,
              hint: 'e.g. 95',
              min: 40,
              max: 200,
            ),
            _field(
              controller: _waistCtrl,
              label: 'Waist',
              unit: 'cm',
              icon: Icons.accessibility_new,
              hint: 'e.g. 78',
              min: 40,
              max: 200,
            ),
            _field(
              controller: _hipsCtrl,
              label: 'Hips',
              unit: 'cm',
              icon: Icons.accessibility,
              hint: 'e.g. 95',
              min: 40,
              max: 200,
            ),

            const SizedBox(height: 24),

            // ── Section: Width / Other ────────────────────────────────────
            _sectionHeader('Other Measurements (cm)'),
            _field(
              controller: _shoulderCtrl,
              label: 'Shoulder Width',
              unit: 'cm',
              icon: Icons.open_in_full,
              hint: 'e.g. 42',
              min: 20,
              max: 80,
            ),
            _field(
              controller: _neckCtrl,
              label: 'Neck',
              unit: 'cm',
              icon: Icons.circle_outlined,
              hint: 'e.g. 37',
              min: 20,
              max: 60,
            ),
            _field(
              controller: _bicepCtrl,
              label: 'Bicep',
              unit: 'cm',
              icon: Icons.fitness_center,
              hint: 'e.g. 32',
              min: 15,
              max: 60,
            ),
            _field(
              controller: _thighCtrl,
              label: 'Thigh',
              unit: 'cm',
              icon: Icons.directions_walk,
              hint: 'e.g. 55',
              min: 25,
              max: 100,
            ),

            const SizedBox(height: 40),

            // ── Save button ──────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_alt),
                label: Text(_isSaving ? 'Saving…' : 'Save Measurements'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String unit,
    required IconData icon,
    String? hint,
    bool required = false,
    double min = 0,
    double max = 9999,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
          suffixText: unit,
          suffixStyle: const TextStyle(color: AppColors.textSecondary),
          prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            borderSide:
                BorderSide(color: AppColors.textSecondary.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            borderSide: const BorderSide(color: AppColors.error),
          ),
        ),
        validator: (v) {
          if (required && (v == null || v.trim().isEmpty)) {
            return '$label is required';
          }
          if (v != null && v.trim().isNotEmpty) {
            final d = double.tryParse(v.trim());
            if (d == null) return 'Enter a valid number';
            if (d < min) return 'Min $min';
            if (d > max) return 'Max $max';
          }
          return null;
        },
      ),
    );
  }
}
