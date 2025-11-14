import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/meal.dart';
import '../services/meal_service.dart';
import 'add_meal_screen.dart';

class NutritionTrackingScreen extends StatefulWidget {
  const NutritionTrackingScreen({super.key});

  @override
  State<NutritionTrackingScreen> createState() => _NutritionTrackingScreenState();
}

class _NutritionTrackingScreenState extends State<NutritionTrackingScreen> {
  final MealService _mealService = MealService();
  DateTime _selectedDate = DateTime.now();
  DailyNutrition? _dailyNutrition;
  bool _isLoading = true;

  // Daily goals (can be customized based on user profile)
  final double _calorieGoal = 2000;
  final double _proteinGoal = 150;
  final double _carbsGoal = 250;
  final double _fatsGoal = 65;

  @override
  void initState() {
    super.initState();
    _loadDailyNutrition();
  }

  Future<void> _loadDailyNutrition() async {
    setState(() => _isLoading = true);
    final nutrition = await _mealService.getDailyNutrition(_selectedDate);
    setState(() {
      _dailyNutrition = nutrition;
      _isLoading = false;
    });
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _loadDailyNutrition();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadDailyNutrition,
                  color: AppColors.accent,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCalorieOverview(),
                        const SizedBox(height: 20),
                        _buildMacrosOverview(),
                        const SizedBox(height: 24),
                        _buildMealsList(),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddMealScreen(selectedDate: _selectedDate),
            ),
          );
          if (result == true) {
            _loadDailyNutrition();
          }
        },
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nutrition Tracking',
                style: AppTextStyles.heading.copyWith(fontSize: 22),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today, color: AppColors.accent),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
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
                    setState(() {
                      _selectedDate = picked;
                      _loadDailyNutrition();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.text),
                onPressed: () => _changeDate(-1),
              ),
              Text(
                isToday ? 'Today' : dateFormat.format(_selectedDate),
                style: AppTextStyles.subheading.copyWith(
                  fontSize: 16,
                  color: AppColors.accent,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: isToday ? AppColors.mediumGray : AppColors.text,
                ),
                onPressed: isToday ? null : () => _changeDate(1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieOverview() {
    final calories = _dailyNutrition?.totalCalories ?? 0;
    final remaining = _calorieGoal - calories;
    final progress = (calories / _calorieGoal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${calories.toInt()}',
                    style: AppTextStyles.heading.copyWith(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'of ${_calorieGoal.toInt()} kcal',
                    style: AppTextStyles.body.copyWith(color: Colors.white70),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    remaining > 0 ? 'Remaining' : 'Over',
                    style: AppTextStyles.caption.copyWith(color: Colors.white70),
                  ),
                  Text(
                    '${remaining.abs().toInt()} kcal',
                    style: AppTextStyles.subheading.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 1.0 ? AppColors.error : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Macronutrients',
          style: AppTextStyles.subheading.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMacroCard(
                'Protein',
                _dailyNutrition?.totalProtein ?? 0,
                _proteinGoal,
                AppColors.accent,
                Icons.fitness_center,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMacroCard(
                'Carbs',
                _dailyNutrition?.totalCarbs ?? 0,
                _carbsGoal,
                AppColors.accentOrange,
                Icons.bakery_dining,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMacroCard(
                'Fats',
                _dailyNutrition?.totalFats ?? 0,
                _fatsGoal,
                const Color(0xFFFFB800),
                Icons.water_drop,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMacroCard(
                'Meals',
                _dailyNutrition?.mealCount.toDouble() ?? 0,
                6,
                const Color(0xFF8B5CF6),
                Icons.restaurant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroCard(String label, double value, double goal, Color color, IconData icon) {
    final percentage = (value / goal * 100).clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mediumGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${value.toInt()}g',
            style: AppTextStyles.heading.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            'of ${goal.toInt()}g',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 6,
              backgroundColor: AppColors.mediumGray,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meals',
          style: AppTextStyles.subheading.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Meal>>(
          stream: _mealService.getMealsForDate(_selectedDate),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final meals = snapshot.data ?? [];

            if (meals.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.mediumGray),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No meals logged yet',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add your first meal',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Group meals by type
            final breakfast = meals.where((m) => m.mealType == 'breakfast').toList();
            final lunch = meals.where((m) => m.mealType == 'lunch').toList();
            final dinner = meals.where((m) => m.mealType == 'dinner').toList();
            final snacks = meals.where((m) => m.mealType == 'snack').toList();

            return Column(
              children: [
                if (breakfast.isNotEmpty) _buildMealTypeSection('Breakfast', breakfast, '🍳'),
                if (lunch.isNotEmpty) _buildMealTypeSection('Lunch', lunch, '🍽️'),
                if (dinner.isNotEmpty) _buildMealTypeSection('Dinner', dinner, '🍴'),
                if (snacks.isNotEmpty) _buildMealTypeSection('Snacks', snacks, '🍿'),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMealTypeSection(String type, List<Meal> meals, String emoji) {
    final totalCalories = meals.fold(0.0, (sum, meal) => sum + meal.calories);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mediumGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      type,
                      style: AppTextStyles.subheading.copyWith(fontSize: 16),
                    ),
                  ],
                ),
                Text(
                  '${totalCalories.toInt()} kcal',
                  style: AppTextStyles.body.copyWith(color: AppColors.accent),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.mediumGray),
          ...meals.map((meal) => _buildMealItem(meal)),
        ],
      ),
    );
  }

  Widget _buildMealItem(Meal meal) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddMealScreen(
              selectedDate: _selectedDate,
              mealToEdit: meal,
            ),
          ),
        );
        if (result == true) {
          _loadDailyNutrition();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${meal.protein.toInt()}g P • ${meal.carbs.toInt()}g C • ${meal.fats.toInt()}g F',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${meal.calories.toInt()}',
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
                ),
                Text(
                  'kcal',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
