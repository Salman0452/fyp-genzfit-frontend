import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/meal.dart';
import '../services/meal_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddMealScreen extends StatefulWidget {
  final DateTime selectedDate;
  final Meal? mealToEdit;

  const AddMealScreen({
    super.key,
    required this.selectedDate,
    this.mealToEdit,
  });

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final _formKey = GlobalKey<FormState>();
  final MealService _mealService = MealService();

  late TextEditingController _nameController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatsController;
  late TextEditingController _notesController;

  String _selectedMealType = 'breakfast';
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isSaving = false;

  final List<Map<String, dynamic>> _mealTypes = [
    {'value': 'breakfast', 'label': 'Breakfast', 'emoji': '🍳'},
    {'value': 'lunch', 'label': 'Lunch', 'emoji': '🍽️'},
    {'value': 'dinner', 'label': 'Dinner', 'emoji': '🍴'},
    {'value': 'snack', 'label': 'Snack', 'emoji': '🍿'},
  ];

  @override
  void initState() {
    super.initState();
    
    final meal = widget.mealToEdit;
    _nameController = TextEditingController(text: meal?.name ?? '');
    _caloriesController = TextEditingController(
      text: meal?.calories.toStringAsFixed(0) ?? '',
    );
    _proteinController = TextEditingController(
      text: meal?.protein.toStringAsFixed(0) ?? '',
    );
    _carbsController = TextEditingController(
      text: meal?.carbs.toStringAsFixed(0) ?? '',
    );
    _fatsController = TextEditingController(
      text: meal?.fats.toStringAsFixed(0) ?? '',
    );
    _notesController = TextEditingController(text: meal?.notes ?? '');

    if (meal != null) {
      _selectedMealType = meal.mealType;
      _selectedTime = TimeOfDay.fromDateTime(meal.timestamp);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveMeal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
      }
      return;
    }

    // Combine selected date with selected time
    final timestamp = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final meal = Meal(
      id: widget.mealToEdit?.id ?? '',
      userId: userId,
      name: _nameController.text.trim(),
      mealType: _selectedMealType,
      calories: double.parse(_caloriesController.text),
      protein: double.parse(_proteinController.text),
      carbs: double.parse(_carbsController.text),
      fats: double.parse(_fatsController.text),
      timestamp: timestamp,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    bool success;
    if (widget.mealToEdit != null) {
      success = await _mealService.updateMeal(meal);
    } else {
      final id = await _mealService.addMeal(meal);
      success = id != null;
    }

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.mealToEdit != null
                  ? 'Meal updated successfully'
                  : 'Meal added successfully',
            ),
            backgroundColor: AppColors.accent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save meal'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteMeal() async {
    if (widget.mealToEdit == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Delete Meal', style: AppTextStyles.subheading),
        content: Text(
          'Are you sure you want to delete this meal?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    final success = await _mealService.deleteMeal(widget.mealToEdit!.id);
    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal deleted successfully'),
            backgroundColor: AppColors.accent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete meal'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.mealToEdit != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Meal' : 'Add Meal',
          style: AppTextStyles.heading.copyWith(fontSize: 20),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.error),
              onPressed: _deleteMeal,
            ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMealTypeSelector(),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Meal Name',
                      hint: 'e.g., Grilled Chicken Salad',
                      icon: Icons.restaurant,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter meal name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTimePicker(),
                    const SizedBox(height: 24),
                    Text(
                      'Nutrition Information',
                      style: AppTextStyles.subheading.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _caloriesController,
                      label: 'Calories (kcal)',
                      hint: 'e.g., 450',
                      icon: Icons.local_fire_department,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter calories';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _proteinController,
                            label: 'Protein (g)',
                            hint: '0',
                            icon: Icons.fitness_center,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _carbsController,
                            label: 'Carbs (g)',
                            hint: '0',
                            icon: Icons.bakery_dining,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _fatsController,
                      label: 'Fats (g)',
                      hint: '0',
                      icon: Icons.water_drop,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter fats';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _notesController,
                      label: 'Notes (Optional)',
                      hint: 'Add any additional notes...',
                      icon: Icons.notes,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveMeal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isEditing ? 'Update Meal' : 'Save Meal',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMealTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meal Type',
          style: AppTextStyles.subheading.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _mealTypes.map((type) {
            final isSelected = _selectedMealType == type['value'];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedMealType = type['value']),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : AppColors.mediumGray,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        type['emoji'],
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        type['label'],
                        style: AppTextStyles.caption.copyWith(
                          color: isSelected ? Colors.white : AppColors.text,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTimePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _selectedTime,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.accent,
                  surface: AppColors.cardBackground,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _selectedTime = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.mediumGray),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    _selectedTime.format(context),
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.accent),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.mediumGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.mediumGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      style: AppTextStyles.body,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
          : null,
    );
  }
}
