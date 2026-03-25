import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:provider/provider.dart';
import '../../models/onboarding_data.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_preferences_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EditPreferencesScreen — Same content as onboarding screens 2-6 but as a
// single scrollable settings page with pre-filled existing preferences.
// ─────────────────────────────────────────────────────────────────────────────
class EditPreferencesScreen extends StatefulWidget {
  const EditPreferencesScreen({super.key});

  @override
  State<EditPreferencesScreen> createState() => _EditPreferencesScreenState();
}

class _EditPreferencesScreenState extends State<EditPreferencesScreen> {
  final UserPreferencesService _prefsService = UserPreferencesService();
  bool _isLoading = true;
  bool _isSaving = false;
  OnboardingData _data = OnboardingData();

  late TextEditingController _ageCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;

  // ── Theme-aware color getters ──────────────────────────────────────────────
  Color get _bg => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0A0A0A)
      : const Color(0xFFFAFAFA);
  Color get _surface => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF1A1A1A)
      : AppColors.surface;
  Color get _purple => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF6C63FF)
      : const Color(0xFF5A52D5);
  Color get _blue => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF3B82F6)
      : const Color(0xFF2563EB);
  Color get _red => const Color(0xFFEF4444);
  Color get _green => const Color(0xFF10B981);
  Color get _white => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFFFFFFF)
      : AppColors.textPrimary;
  Color get _muted => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF9CA3AF)
      : AppColors.textSecondary;
  Color get _border => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF2A2A2A)
      : const Color(0xFFE0E0E0);

  LinearGradient get _btnGradient => LinearGradient(
        colors: [_purple, _blue],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  @override
  void initState() {
    super.initState();
    _ageCtrl = TextEditingController(text: '25');
    _heightCtrl = TextEditingController(text: '170');
    _weightCtrl = TextEditingController(text: '70');
    _loadPreferences();
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final map = await _prefsService.loadPreferences(uid);
      if (map != null && mounted) {
        final loaded = OnboardingData.fromMap(map);
        setState(() {
          _data = loaded;
          _ageCtrl.text = loaded.age.toString();
          _heightCtrl.text = loaded.heightCm.toStringAsFixed(0);
          _weightCtrl.text = loaded.weightKg.toStringAsFixed(0);
        });
      }
    } catch (e) {
      debugPrint('EditPrefs load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _syncTextControllers() {
    _data.age = int.tryParse(_ageCtrl.text) ?? _data.age;
    _data.heightCm = double.tryParse(_heightCtrl.text) ?? _data.heightCm;
    _data.weightKg = double.tryParse(_weightCtrl.text) ?? _data.weightKg;
  }

  Future<void> _savePreferences() async {
    _syncTextControllers();
    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    try {
      if (uid != null) {
        await _prefsService.savePreferences(
          userId: uid,
          preferences: _data.toPreferencesMap(),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Preferences updated. Your next plan will reflect these changes.',
            ),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('EditPrefs save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── BMI helpers ────────────────────────────────────────────────────────────
  double get _bmi {
    final h = _data.heightCm / 100;
    if (h <= 0) return 0;
    return _data.weightKg / (h * h);
  }

  String get _bmiCategory {
    final b = _bmi;
    if (b < 18.5) return 'Underweight';
    if (b < 25) return 'Normal';
    if (b < 30) return 'Overweight';
    return 'Obese';
  }

  Color get _bmiColor {
    final b = _bmi;
    if (b < 18.5) return _blue;
    if (b < 25) return _green;
    if (b < 30) {
      return Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFF59E0B)
          : const Color(0xFFD97706);
    }
    return _red;
  }

  // ── Shared decoration ──────────────────────────────────────────────────────
  InputDecoration _fieldDecoration(String hint, {String? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _muted),
        suffixText: suffix,
        suffixStyle: TextStyle(color: _muted),
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _purple, width: 2),
        ),
      );

  // ── Shared chip builder ────────────────────────────────────────────────────
  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? selectedColor,
  }) {
    final c = selectedColor ?? _purple;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? c : _border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _white : _muted,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: TextStyle(
            color: _white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget _sectionCard({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: child,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 0,
          title: Text(
            'Edit Preferences',
            style: TextStyle(
              color: _white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: _white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(_purple)))
            : Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGoalSection(),
                        _buildFitnessLevelSection(),
                        _buildWorkoutSetupSection(),
                        _buildBodyMeasurementsSection(),
                        _buildDietSection(),
                      ],
                    ),
                  ),
                  // Sticky save button
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      decoration: BoxDecoration(
                        color: _bg,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: _buildSaveButton(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Section 1: Fitness Goal ─────────────────────────────────────────────────
  static const _goals = [
    {
      'title': 'Lose Weight',
      'value': 'weight_loss',
      'color': Color(0xFFEF4444)
    },
    {
      'title': 'Build Muscle',
      'value': 'muscle_gain',
      'color': Color(0xFF6C63FF)
    },
    {'title': 'Stay Fit', 'value': 'fitness', 'color': Color(0xFF10B981)},
    {
      'title': 'Boost Endurance',
      'value': 'endurance',
      'color': Color(0xFF3B82F6)
    },
  ];

  Widget _buildGoalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Fitness Goal'),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _goals.map((g) {
              final selected = _data.goal == g['value'];
              final color = g['color'] as Color;
              return GestureDetector(
                onTap: () => setState(() => _data.goal = g['value'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(right: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.15) : _surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? color : _border,
                      width: selected ? 2.5 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: color.withOpacity(0.3), blurRadius: 10)
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        g['title'] as String,
                        style: TextStyle(
                          color: selected ? _white : _muted,
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Section 2: Fitness Level ────────────────────────────────────────────────
  static const _levels = [
    {'title': 'Beginner', 'value': 'beginner', 'color': Color(0xFF10B981)},
    {
      'title': 'Intermediate',
      'value': 'intermediate',
      'color': Color(0xFF6C63FF)
    },
    {'title': 'Advanced', 'value': 'advanced', 'color': Color(0xFFEF4444)},
  ];

  Widget _buildFitnessLevelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Fitness Level'),
        Row(
          children: _levels.map((l) {
            final selected = _data.fitnessLevel == l['value'];
            final color = l['color'] as Color;
            return Expanded(
              child: GestureDetector(
                onTap: () =>
                    setState(() => _data.fitnessLevel = l['value'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.15) : _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? color : _border,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        l['title'] as String,
                        style: TextStyle(
                          color: selected ? _white : _muted,
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Section 3: Workout Setup ────────────────────────────────────────────────
  static const Map<String, List<Map<String, String>>> _equipmentOptions = {
    'gym': [
      {'label': 'Barbell'},
      {'label': 'Dumbbells'},
      {'label': 'Cable Machine'},
      {'label': 'Bench Press'},
      {'label': 'Squat Rack'},
      {'label': 'Resistance Machines'},
      {'label': 'Yoga Mat'},
      {'label': 'Treadmill/Cardio'},
    ],
    'home': [
      {'label': 'Dumbbells'},
      {'label': 'Resistance Bands'},
      {'label': 'Pull-up Bar'},
      {'label': 'Yoga Mat'},
      {'label': 'Stability Ball'},
      {'label': 'Jump Rope'},
    ],
  };

  Widget _buildWorkoutSetupSection() {
    final loc = _data.workoutLocation;
    final equipment = loc != null ? _equipmentOptions[loc] : null;

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Workout Setup'),

          // Location chips
          Text('Location', style: TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              {'label': 'Gym', 'value': 'gym'},
              {'label': 'Home', 'value': 'home'},
              {'label': 'Outdoor', 'value': 'outdoor'},
            ].map((l) {
              final selected = loc == l['value'];
              return _chip(
                label: '${l['label']}',
                selected: selected,
                onTap: () => setState(() {
                  _data.workoutLocation = l['value'];
                  _data.availableEquipment.clear();
                }),
              );
            }).toList(),
          ),

          // Equipment
          if (loc != null) ...[
            const SizedBox(height: 16),
            if (loc == 'outdoor')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.park_outlined, color: _blue, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "We'll create bodyweight workouts for you",
                        style: TextStyle(color: _white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else if (equipment != null) ...[
              Text('Equipment available',
                  style: TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: equipment.map((item) {
                  final label = item['label']!;
                  final isSelected = _data.availableEquipment.contains(label);
                  return _chip(
                    label: label,
                    selected: isSelected,
                    onTap: () => setState(() {
                      if (isSelected) {
                        _data.availableEquipment.remove(label);
                      } else {
                        _data.availableEquipment.add(label);
                      }
                    }),
                  );
                }).toList(),
              ),
            ],
          ],

          const SizedBox(height: 20),

          // Duration slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Workout duration',
                  style: TextStyle(color: _muted, fontSize: 13)),
              Text(
                '${_data.workoutDurationMinutes} min',
                style: TextStyle(
                    color: _purple, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _purple,
              inactiveTrackColor: _border,
              thumbColor: _purple,
              overlayColor: _purple.withOpacity(0.2),
            ),
            child: Slider(
              value: _data.workoutDurationMinutes.toDouble(),
              min: 15,
              max: 90,
              divisions: 5,
              onChanged: (v) =>
                  setState(() => _data.workoutDurationMinutes = v.round()),
            ),
          ),

          const SizedBox(height: 12),

          // Days per week
          Text('Days per week', style: TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final day = i + 1;
              final selected = _data.workoutDaysPerWeek == day;
              return GestureDetector(
                onTap: () => setState(() => _data.workoutDaysPerWeek = day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? _purple : _surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? _purple : _border,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: _purple.withOpacity(0.4), blurRadius: 6)
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: selected ? _white : _muted,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Section 4: Body Measurements ────────────────────────────────────────────
  Widget _buildBodyMeasurementsSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Body Measurements'),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Age', style: TextStyle(color: _muted, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: _white),
                      decoration: _fieldDecoration('25'),
                      onChanged: (_) => setState(() {
                        _data.age = int.tryParse(_ageCtrl.text) ?? _data.age;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gender',
                        style: TextStyle(color: _muted, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _data.gender = 'male'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _data.gender == 'male'
                                      ? _purple
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'M',
                                    style: TextStyle(
                                      color: _data.gender == 'male'
                                          ? _white
                                          : _muted,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _data.gender = 'female'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _data.gender == 'female'
                                      ? _purple
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'F',
                                    style: TextStyle(
                                      color: _data.gender == 'female'
                                          ? _white
                                          : _muted,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Height',
                        style: TextStyle(color: _muted, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _heightCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: _white),
                      decoration: _fieldDecoration('170', suffix: 'cm'),
                      onChanged: (_) => setState(() {
                        _data.heightCm =
                            double.tryParse(_heightCtrl.text) ?? _data.heightCm;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weight',
                        style: TextStyle(color: _muted, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _weightCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: _white),
                      decoration: _fieldDecoration('70', suffix: 'kg'),
                      onChanged: (_) => setState(() {
                        _data.weightKg =
                            double.tryParse(_weightCtrl.text) ?? _data.weightKg;
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_data.heightCm > 0 && _data.weightKg > 0) ...[
            const SizedBox(height: 14),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bmiColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _bmiColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Text(
                    'BMI: ${_bmi.toStringAsFixed(1)}',
                    style: TextStyle(
                        color: _bmiColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '— $_bmiCategory',
                    style: TextStyle(color: _bmiColor, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Section 5: Diet Preferences ─────────────────────────────────────────────
  Widget _buildDietSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Diet Preferences'),
          _subLabel('Cuisine Style'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              {'label': 'Pakistani', 'value': 'pakistani'},
              {'label': 'Mixed', 'value': 'mixed'},
              {'label': 'Continental', 'value': 'continental'},
            ]
                .map((c) => _chip(
                      label: '${c['label']}',
                      selected: _data.cuisinePreference == c['value'],
                      onTap: () =>
                          setState(() => _data.cuisinePreference = c['value']!),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          _subLabel('Meals per day'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              {'label': '3 Meals', 'value': '3'},
              {'label': '4 Meals', 'value': '4'},
              {'label': '5 Meals', 'value': '5'},
            ]
                .map((m) => _chip(
                      label: m['label']!,
                      selected: _data.mealsPerDay.toString() == m['value'],
                      onTap: () => setState(
                          () => _data.mealsPerDay = int.parse(m['value']!)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          _subLabel('Dietary Restrictions'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              {'label': 'No Pork', 'value': 'no_pork'},
              {'label': 'Vegetarian', 'value': 'vegetarian'},
              {'label': 'No Dairy', 'value': 'no_dairy'},
              {'label': 'Gluten Free', 'value': 'gluten_free'},
              {'label': 'No Sugar', 'value': 'no_sugar'},
              {'label': 'Low Sodium', 'value': 'low_sodium'},
            ].map((item) {
              final v = item['value']!;
              return _chip(
                label: '${item['label']}',
                selected: _data.dietaryRestrictions.contains(v),
                onTap: () => setState(() {
                  if (_data.dietaryRestrictions.contains(v)) {
                    _data.dietaryRestrictions.remove(v);
                  } else {
                    _data.dietaryRestrictions.add(v);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _subLabel('Food Allergies'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              {'label': 'Nuts', 'value': 'nuts'},
              {'label': 'Shellfish', 'value': 'shellfish'},
              {'label': 'Eggs', 'value': 'eggs'},
              {'label': 'Fish', 'value': 'fish'},
              {'label': 'No Allergies', 'value': 'none'},
            ].map((item) {
              final v = item['value']!;
              return _chip(
                label: '${item['label']}',
                selected: _data.foodAllergies.contains(v),
                onTap: () => setState(() {
                  if (v == 'none') {
                    _data.foodAllergies
                      ..clear()
                      ..add('none');
                  } else {
                    _data.foodAllergies.remove('none');
                    if (_data.foodAllergies.contains(v)) {
                      _data.foodAllergies.remove(v);
                    } else {
                      _data.foodAllergies.add(v);
                    }
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _subLabel('Health Conditions'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              {'label': 'Diabetes', 'value': 'diabetes'},
              {'label': 'Heart Disease', 'value': 'heart_disease'},
              {'label': 'Hypertension', 'value': 'hypertension'},
              {'label': 'Joint Issues', 'value': 'joint_issues'},
              {'label': 'None', 'value': 'none'},
            ].map((item) {
              final v = item['value']!;
              return _chip(
                label: '${item['label']}',
                selected: _data.healthConditions.contains(v),
                onTap: () => setState(() {
                  if (v == 'none') {
                    _data.healthConditions
                      ..clear()
                      ..add('none');
                  } else {
                    _data.healthConditions.remove('none');
                    if (_data.healthConditions.contains(v)) {
                      _data.healthConditions.remove(v);
                    } else {
                      _data.healthConditions.add(v);
                    }
                  }
                }),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _subLabel(String text) => Text(
        text,
        style: TextStyle(color: _muted, fontSize: 13),
      );

  // ── Save Button ─────────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _savePreferences,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: _btnGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _purple.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Color(0xFFFFFFFF), strokeWidth: 2.5),
                )
              : Text(
                  'Save Preferences 💾',
                  style: TextStyle(
                    color: _white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
