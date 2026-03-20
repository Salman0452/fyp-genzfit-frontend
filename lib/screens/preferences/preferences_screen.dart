import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_preferences_service.dart';
import '../../utils/constants.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final UserPreferencesService _prefsService = UserPreferencesService();
  bool _isSaving = false;
  bool _isLoading = true;

  // ── Section 1 — Fitness Profile ──────────────────────────────────────────
  String _goal = 'fitness';

  // ── Section 2 — Workout Setup ────────────────────────────────────────────
  String _workoutLocation = 'gym';
  String _fitnessLevel = 'intermediate';
  double _workoutDuration = 45;
  double _workoutDays = 5;
  final Set<String> _equipment = {};
  final Set<String> _injuryLimitations = {};

  // ── Section 3 — Diet ─────────────────────────────────────────────────────
  String _cuisinePreference = 'pakistani';
  double _mealsPerDay = 4;
  final Set<String> _dietaryRestrictions = {};
  final Set<String> _foodAllergies = {};
  final Set<String> _healthConditions = {};

  // ── Equipment options per location ───────────────────────────────────────
  static const Map<String, List<String>> _equipmentOptions = {
    'gym': [
      'Barbell',
      'Dumbbells',
      'Cable Machine',
      'Bench',
      'Squat Rack',
      'Machines',
    ],
    'home': [
      'Dumbbells',
      'Resistance Bands',
      'Pull-up Bar',
      'Yoga Mat',
    ],
    'outdoor': ['Bodyweight only'],
  };

  @override
  void initState() {
    super.initState();
    _loadExistingPreferences();
  }

  Future<void> _loadExistingPreferences() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final prefs = await _prefsService.loadPreferences(userId);
    if (prefs != null && mounted) {
      setState(() {
        _goal = prefs['goal'] ?? 'fitness';
        _workoutLocation = prefs['workout_location'] ?? 'gym';
        _fitnessLevel = prefs['fitness_level'] ?? 'intermediate';
        _workoutDuration =
            (prefs['workout_duration_minutes'] as num?)?.toDouble() ?? 45;
        _workoutDays =
            (prefs['workout_days_per_week'] as num?)?.toDouble() ?? 5;
        _cuisinePreference = prefs['cuisine_preference'] ?? 'pakistani';
        _mealsPerDay = (prefs['meals_per_day'] as num?)?.toDouble() ?? 4;

        _equipment.clear();
        _equipment.addAll(
          (prefs['available_equipment'] as List? ?? [])
              .map((e) => e.toString()),
        );
        _injuryLimitations.clear();
        _injuryLimitations.addAll(
          (prefs['injury_limitations'] as List? ?? []).map((e) => e.toString()),
        );
        _dietaryRestrictions.clear();
        _dietaryRestrictions.addAll(
          (prefs['dietary_restrictions'] as List? ?? [])
              .map((e) => e.toString()),
        );
        _foodAllergies.clear();
        _foodAllergies.addAll(
          (prefs['food_allergies'] as List? ?? []).map((e) => e.toString()),
        );
        _healthConditions.clear();
        _healthConditions.addAll(
          (prefs['health_conditions'] as List? ?? []).map((e) => e.toString()),
        );
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    if (userId == null) return;

    setState(() => _isSaving = true);

    final equipmentKeys =
        _equipment.map((e) => e.toLowerCase().replaceAll(' ', '_')).toList();
    final injuryKeys = _injuryLimitations
        .map((e) => e.toLowerCase().replaceAll(' ', '_'))
        .toList();
    final dietKeys = _dietaryRestrictions
        .map((e) => e.toLowerCase().replaceAll(' ', '_'))
        .toList();
    final allergyKeys = _foodAllergies
        .map((e) => e.toLowerCase().replaceAll(' ', '_'))
        .toList();
    final healthKeys = _healthConditions
        .map((e) => e.toLowerCase().replaceAll(' ', '_'))
        .toList();

    final prefs = {
      'goal': _goal,
      'workout_location': _workoutLocation,
      'fitness_level': _fitnessLevel,
      'workout_duration_minutes': _workoutDuration.toInt(),
      'workout_days_per_week': _workoutDays.toInt(),
      'available_equipment': equipmentKeys,
      'disliked_exercises': <String>[],
      'injury_limitations': injuryKeys,
      'cuisine_preference': _cuisinePreference,
      'meals_per_day': _mealsPerDay.toInt(),
      'dietary_restrictions': dietKeys,
      'food_allergies': allergyKeys,
      'disliked_foods': <String>[],
      'health_conditions': healthKeys,
      'age': 25,
      'height_cm': 170.0,
      'weight_kg': 70.0,
      'gender': 'male',
    };

    try {
      await _prefsService.savePreferences(userId: userId, preferences: prefs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Preferences saved. Your AI plans will now be personalised.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving preferences: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Fitness Preferences',
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildIntroCard(),
                        const SizedBox(height: 24),
                        _buildSection1(),
                        const SizedBox(height: 24),
                        _buildSection2(),
                        const SizedBox(height: 24),
                        _buildSection3(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                _buildSaveButton(),
              ],
            ),
    );
  }

  // ── Intro card ─────────────────────────────────────────────────────────────
  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.accent, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tell us about yourself so our AI can create a perfectly personalised plan just for you.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── Section 1 — Fitness Goal ──────────────────────────────────────────────
  Widget _buildSection1() {
    final goals = [
      ('weight_loss', 'Weight Loss', Icons.trending_down),
      ('muscle_gain', 'Muscle Gain', Icons.fitness_center),
      ('fitness', 'Stay Fit', Icons.directions_run),
      ('endurance', 'Endurance', Icons.timer),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Fitness Goal', Icons.flag),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.8,
          children: goals.map((g) {
            final selected = _goal == g.$1;
            return _buildSelectCard(
              label: g.$2,
              icon: g.$3,
              selected: selected,
              onTap: () => setState(() => _goal = g.$1),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Section 2 — Workout Setup ─────────────────────────────────────────────
  Widget _buildSection2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Workout Setup', Icons.sports_gymnastics),
        const SizedBox(height: 20),

        // Location
        _buildLabel('Workout Location'),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildToggleChip(
                'Gym',
                'gym',
                Icons.fitness_center,
                _workoutLocation == 'gym',
                () => setState(() {
                      _workoutLocation = 'gym';
                      _equipment.clear();
                    })),
            const SizedBox(width: 8),
            _buildToggleChip(
                'Home',
                'home',
                Icons.home,
                _workoutLocation == 'home',
                () => setState(() {
                      _workoutLocation = 'home';
                      _equipment.clear();
                    })),
            const SizedBox(width: 8),
            _buildToggleChip(
                'Outdoor',
                'outdoor',
                Icons.park,
                _workoutLocation == 'outdoor',
                () => setState(() {
                      _workoutLocation = 'outdoor';
                      _equipment.clear();
                    })),
          ],
        ),
        const SizedBox(height: 16),

        // Equipment
        _buildLabel('Available Equipment'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (_equipmentOptions[_workoutLocation] ?? []).map((eq) {
            final key = eq.toLowerCase().replaceAll(' ', '_');
            final selected =
                _equipment.contains(key) || _equipment.contains(eq);
            return FilterChip(
              label: Text(eq,
                  style: TextStyle(
                      color: selected
                          ? AppColors.background
                          : AppColors.textSecondary,
                      fontSize: 12)),
              selected: selected,
              onSelected: (_) => setState(() =>
                  selected ? _equipment.remove(key) : _equipment.add(key)),
              selectedColor: AppColors.accent,
              backgroundColor: AppColors.surface,
              checkmarkColor: AppColors.background,
              side: BorderSide(
                  color: selected ? AppColors.accent : AppColors.surface),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Fitness level
        _buildLabel('Fitness Level'),
        const SizedBox(height: 10),
        Row(
          children: ['beginner', 'intermediate', 'advanced'].map((level) {
            final selected = _fitnessLevel == level;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _fitnessLevel = level),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: selected ? AppColors.accent : AppColors.surface),
                  ),
                  child: Text(
                    level[0].toUpperCase() + level.substring(1),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? AppColors.background
                          : AppColors.textSecondary,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Duration slider
        _buildLabel('Session Duration — ${_workoutDuration.toInt()} min'),
        Slider(
          value: _workoutDuration,
          min: 15,
          max: 90,
          divisions: 5,
          activeColor: AppColors.accent,
          inactiveColor: AppColors.surface,
          onChanged: (v) => setState(() => _workoutDuration = v),
        ),
        const SizedBox(height: 12),

        // Days slider
        _buildLabel('Workout Days / Week — ${_workoutDays.toInt()} days'),
        Slider(
          value: _workoutDays,
          min: 1,
          max: 7,
          divisions: 6,
          activeColor: AppColors.accent,
          inactiveColor: AppColors.surface,
          onChanged: (v) => setState(() => _workoutDays = v),
        ),
        const SizedBox(height: 16),

        // Injury limitations
        _buildLabel('Injury Limitations'),
        const SizedBox(height: 10),
        _buildMultiSelectChips(
          options: [
            'Bad Knees',
            'Shoulder Pain',
            'Back Pain',
            'Wrist Pain',
            'Hip Pain',
            'None'
          ],
          selected: _injuryLimitations,
          onToggle: (v) {
            final key = v.toLowerCase().replaceAll(' ', '_');
            setState(() => _injuryLimitations.contains(key)
                ? _injuryLimitations.remove(key)
                : _injuryLimitations.add(key));
          },
        ),
      ],
    );
  }

  // ── Section 3 — Diet ──────────────────────────────────────────────────────
  Widget _buildSection3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Diet Preferences', Icons.restaurant_menu),
        const SizedBox(height: 20),

        // Cuisine
        _buildLabel('Cuisine Preference'),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildToggleChip(
                'Pakistani',
                'pakistani',
                Icons.ramen_dining,
                _cuisinePreference == 'pakistani',
                () => setState(() => _cuisinePreference = 'pakistani')),
            const SizedBox(width: 8),
            _buildToggleChip(
                'Mixed',
                'mixed',
                Icons.public,
                _cuisinePreference == 'mixed',
                () => setState(() => _cuisinePreference = 'mixed')),
            const SizedBox(width: 8),
            _buildToggleChip(
                'Continental',
                'continental',
                Icons.dining,
                _cuisinePreference == 'continental',
                () => setState(() => _cuisinePreference = 'continental')),
          ],
        ),
        const SizedBox(height: 20),

        // Meals per day slider
        _buildLabel('Meals per Day — ${_mealsPerDay.toInt()} meals'),
        Slider(
          value: _mealsPerDay,
          min: 3,
          max: 6,
          divisions: 3,
          activeColor: AppColors.accent,
          inactiveColor: AppColors.surface,
          onChanged: (v) => setState(() => _mealsPerDay = v),
        ),
        const SizedBox(height: 16),

        // Dietary restrictions
        _buildLabel('Dietary Restrictions'),
        const SizedBox(height: 10),
        _buildMultiSelectChips(
          options: [
            'No Pork',
            'Vegetarian',
            'Vegan',
            'Lactose Intolerant',
            'Low Carb',
            'Low Fat',
            'Gluten Free'
          ],
          selected: _dietaryRestrictions,
          onToggle: (v) {
            final key = v.toLowerCase().replaceAll(' ', '_');
            setState(() => _dietaryRestrictions.contains(key)
                ? _dietaryRestrictions.remove(key)
                : _dietaryRestrictions.add(key));
          },
        ),
        const SizedBox(height: 16),

        // Food allergies
        _buildLabel('Food Allergies'),
        const SizedBox(height: 10),
        _buildMultiSelectChips(
          options: ['Nuts', 'Shellfish', 'Eggs', 'Dairy', 'Gluten', 'None'],
          selected: _foodAllergies,
          onToggle: (v) {
            final key = v.toLowerCase();
            setState(() => _foodAllergies.contains(key)
                ? _foodAllergies.remove(key)
                : _foodAllergies.add(key));
          },
        ),
        const SizedBox(height: 16),

        // Health conditions
        _buildLabel('Health Conditions'),
        const SizedBox(height: 10),
        _buildMultiSelectChips(
          options: ['Diabetes', 'Hypertension', 'Heart Disease', 'None'],
          selected: _healthConditions,
          onToggle: (v) {
            final key = v.toLowerCase().replaceAll(' ', '_');
            setState(() => _healthConditions.contains(key)
                ? _healthConditions.remove(key)
                : _healthConditions.add(key));
          },
        ),
      ],
    );
  }

  // ── Save button ───────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
              : const Icon(Icons.save, color: Colors.black),
          label: Text(
            _isSaving ? 'Saving...' : 'Save Preferences',
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600));
  }

  Widget _buildSelectCard({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppColors.accent : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? Colors.black : AppColors.textSecondary,
                size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.black : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleChip(String label, String value, IconData icon,
      bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.black : AppColors.textSecondary),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: selected ? Colors.black : AppColors.textSecondary,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectChips({
    required List<String> options,
    required Set<String> selected,
    required void Function(String) onToggle,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final key = opt.toLowerCase().replaceAll(' ', '_');
        final isSelected =
            selected.contains(key) || selected.contains(opt.toLowerCase());
        return FilterChip(
          label: Text(opt,
              style: TextStyle(
                  color: isSelected
                      ? AppColors.background
                      : AppColors.textSecondary,
                  fontSize: 12)),
          selected: isSelected,
          onSelected: (_) => onToggle(opt),
          selectedColor: AppColors.accent,
          backgroundColor: AppColors.surface,
          checkmarkColor: AppColors.background,
          side: BorderSide(
              color: isSelected ? AppColors.accent : AppColors.surface),
        );
      }).toList(),
    );
  }
}
