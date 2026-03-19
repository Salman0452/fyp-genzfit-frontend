import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/progress_tracking_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/progress_service.dart';
import '../../utils/constants.dart';
import '../../utils/design_utils.dart';
import '../client/avatar_viewer_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fitstreak Design Colors
// ─────────────────────────────────────────────────────────────────────────────
const _kBg = AppColors.background;
const _kSurface = AppColors.surface;
const _kCard = Color(0xFFF7F9FB);
const _kBorder = Color(0xFFE0E0E0);
const _kBrandGreen = AppColors.brandGreen;
const _kBrandBlue = AppColors.brandBlue;
const _kPurple = Color(0xFF6C63FF);
const _kBlue = Color(0xFF3B82F6);
const _kGreen = Color(0xFF10B981);
const _kOrange = Color(0xFFFFA500);
const _kRed = Color(0xFFE53935);
const _kGold = Color(0xFFD5FF5F);

// ─────────────────────────────────────────────────────────────────────────────
// Entry widget
// ─────────────────────────────────────────────────────────────────────────────
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProgressService _svc = ProgressService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Progress',
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _kBrandGreen,
          indicatorWeight: 3,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'TODAY'),
            Tab(text: 'WEEKLY'),
            Tab(text: 'INSIGHTS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TodayTab(svc: _svc),
          _WeeklyTab(svc: _svc),
          _InsightsTab(svc: _svc),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────
Widget _shimmer({double height = 80, double? width, double radius = 12}) {
  return _BlinkingSkeleton(height: height, width: width, radius: radius);
}

class _BlinkingSkeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;

  const _BlinkingSkeleton({
    required this.height,
    this.width,
    required this.radius,
  });

  @override
  State<_BlinkingSkeleton> createState() => _BlinkingSkeletonState();
}

class _BlinkingSkeletonState extends State<_BlinkingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.45,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

Widget _sectionTitle(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Text(
    t,
    style: GoogleFonts.plusJakartaSans(
      color: AppColors.textPrimary,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
  ),
);

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1 — TODAY
// ═════════════════════════════════════════════════════════════════════════════
class _TodayTab extends StatefulWidget {
  final ProgressService svc;
  const _TodayTab({required this.svc});

  @override
  State<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<_TodayTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, int>? _nutrition;
  Map<String, int>? _counts;
  Map<String, int>? _streak;
  List<ExerciseCompletion>? _exercises;
  Map<String, dynamic>? _prefs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid =
        Provider.of<AuthProvider>(context, listen: false).user?.uid ?? '';
    try {
      final results = await Future.wait([
        widget.svc.getTodayNutrition(uid),
        widget.svc.getTodayCompletionCounts(uid),
        widget.svc.getStreakData(uid),
        widget.svc.getTodayExercises(uid),
        _loadPrefs(uid),
      ]);
      if (!mounted) return;
      setState(() {
        _nutrition = results[0] as Map<String, int>;
        _counts = results[1] as Map<String, int>;
        _streak = results[2] as Map<String, int>;
        _exercises = results[3] as List<ExerciseCompletion>;
        _prefs = results[4] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _loadPrefs(String uid) async {
    return widget.svc.loadUserPrefs(uid);
  }

  int get _todayScore {
    final c = _counts;
    if (c == null) return 0;
    final mt = c['meals_total'] ?? 0;
    final mc = c['meals_completed'] ?? 0;
    final et = c['exercises_total'] ?? 0;
    final ec = c['exercises_completed'] ?? 0;
    final mr = mt > 0 ? (mc / mt * 100) : 0;
    final er = et > 0 ? (ec / et * 100) : 0;
    return (mr * 0.5 + er * 0.5).toInt();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return _buildSkeleton();
    final goal = (_prefs?['goal'] as String?) ?? 'fitness';
    final weightKg = (_prefs?['weight_kg'] as num?)?.toDouble() ?? 70.0;
    final targets = ProgressService.getNutritionTargets(
      goal: goal,
      weightKg: weightKg,
    );

    return RefreshIndicator(
      color: _kBrandGreen,
      backgroundColor: _kSurface,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ScoreCard(score: _todayScore),
          const SizedBox(height: 20),
          _sectionTitle('Today\'s Nutrition'),
          _NutritionRings(nutrition: _nutrition ?? {}, targets: targets),
          const SizedBox(height: 20),
          _sectionTitle('Today\'s Workouts'),
          _ExerciseList(exercises: _exercises ?? []),
          const SizedBox(height: 20),
          _sectionTitle('Streaks'),
          _StreakCard(streak: _streak ?? {}),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSkeleton() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _shimmer(height: 140),
      const SizedBox(height: 20),
      _shimmer(height: 130),
      const SizedBox(height: 20),
      _shimmer(height: 100),
      const SizedBox(height: 20),
      _shimmer(height: 80),
    ],
  );
}

// Score card ──────────────────────────────────────────────────────────────────
class _ScoreCard extends StatelessWidget {
  final int score;
  const _ScoreCard({required this.score});

  List<Color> get _gradient {
    if (score >= 80) return [const Color(0xFF10B981), const Color(0xFF059669)];
    if (score >= 60) return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
    return [const Color(0xFFEF4444), const Color(0xFFDC2626)];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 64,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'Today\'s Score',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            score >= 80
                ? 'Excellent consistency'
                : score >= 60
                ? 'Good progress'
                : 'Let\'s catch up',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// Nutrition rings ─────────────────────────────────────────────────────────────
class _NutritionRings extends StatelessWidget {
  final Map<String, int> nutrition;
  final Map<String, int> targets;
  const _NutritionRings({required this.nutrition, required this.targets});

  @override
  Widget build(BuildContext context) {
    final items = [
      _RingItem(
        'Calories',
        nutrition['calories'] ?? 0,
        targets['calories'] ?? 2000,
        _kRed,
        'kcal',
      ),
      _RingItem(
        'Protein',
        nutrition['protein'] ?? 0,
        targets['protein'] ?? 140,
        _kPurple,
        'g',
      ),
      _RingItem(
        'Carbs',
        nutrition['carbs'] ?? 0,
        targets['carbs'] ?? 250,
        _kBlue,
        'g',
      ),
      _RingItem(
        'Fats',
        nutrition['fats'] ?? 0,
        targets['fats'] ?? 65,
        _kGreen,
        'g',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((i) => _RingWidget(item: i)).toList(),
      ),
    );
  }
}

class _RingItem {
  final String label;
  final int current;
  final int target;
  final Color color;
  final String unit;
  _RingItem(this.label, this.current, this.target, this.color, this.unit);
  double get ratio => target > 0 ? (current / target).clamp(0.0, 1.0) : 0;
}

class _RingWidget extends StatelessWidget {
  final _RingItem item;
  const _RingWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 66,
          height: 66,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: item.ratio,
                strokeWidth: 8,
                backgroundColor: _kBorder,
                valueColor: AlwaysStoppedAnimation(item.color),
              ),
              Text(
                '${item.current}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.label,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
        Text(item.unit, style: TextStyle(color: item.color, fontSize: 10)),
      ],
    );
  }
}

// Exercise list ───────────────────────────────────────────────────────────────
class _ExerciseList extends StatelessWidget {
  final List<ExerciseCompletion> exercises;
  const _ExerciseList({required this.exercises});

  Color _diffColor(String d) {
    switch (d.toLowerCase()) {
      case 'beginner':
        return _kGreen;
      case 'intermediate':
        return _kOrange;
      case 'advanced':
        return _kRed;
      default:
        return _kBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (exercises.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: const Center(
          child: Text(
            'No workouts scheduled today',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: exercises.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final ex = exercises[i];
          final done = ex.status == CompletionStatus.completed;
          return Container(
            width: 130,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: done ? _kGreen.withValues(alpha: 0.5) : _kBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      done ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: done ? _kGreen : AppColors.textSecondary,
                      size: 16,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _diffColor(ex.difficulty).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ex.difficulty.isEmpty
                            ? '—'
                            : ex.difficulty[0].toUpperCase(),
                        style: TextStyle(
                          color: _diffColor(ex.difficulty),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  ex.exerciseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${ex.sets}×${ex.reps}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Streak card ─────────────────────────────────────────────────────────────────
class _StreakCard extends StatelessWidget {
  final Map<String, int> streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            icon: 'S',
            value: '${streak['current'] ?? 0}',
            label: 'Day Streak',
            sub: 'Keep it up!',
            color: _kOrange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            icon: 'PB',
            value: '${streak['longest'] ?? 0}',
            label: 'Best Streak',
            sub: 'Personal best',
            color: _kGold,
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final String sub;
  final Color color;
  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 — WEEKLY
// ═════════════════════════════════════════════════════════════════════════════
class _WeeklyTab extends StatefulWidget {
  final ProgressService svc;
  const _WeeklyTab({required this.svc});

  @override
  State<_WeeklyTab> createState() => _WeeklyTabState();
}

class _WeeklyTabState extends State<_WeeklyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>>? _weeklyData;
  Map<String, dynamic>? _prefs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid =
        Provider.of<AuthProvider>(context, listen: false).user?.uid ?? '';
    try {
      final results = await Future.wait([
        widget.svc.getLast7DaysData(uid),
        _loadPrefs(uid),
      ]);
      if (!mounted) return;
      setState(() {
        _weeklyData = results[0] as List<Map<String, dynamic>>;
        _prefs = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _loadPrefs(String uid) async {
    return widget.svc.loadUserPrefs(uid);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return _buildSkeleton();

    final data = _weeklyData ?? [];
    final goal = (_prefs?['goal'] as String?) ?? 'fitness';
    final weightKg = (_prefs?['weight_kg'] as num?)?.toDouble() ?? 70.0;
    final targets = ProgressService.getNutritionTargets(
      goal: goal,
      weightKg: weightKg,
    );

    // Totals
    final totalCal = data.fold<int>(
      0,
      (s, d) => s + (d['calories_consumed'] as int? ?? 0),
    );
    final totalProt = data.fold<int>(
      0,
      (s, d) => s + (d['protein'] as int? ?? 0),
    );
    final totalCarbs = data.fold<int>(
      0,
      (s, d) => s + (d['carbs'] as int? ?? 0),
    );
    final totalFats = data.fold<int>(0, (s, d) => s + (d['fats'] as int? ?? 0));
    final totalBurned = data.fold<int>(
      0,
      (s, d) => s + (d['calories_burned'] as int? ?? 0),
    );
    final totalMealsDone = data.fold<int>(
      0,
      (s, d) => s + (d['meals_completed'] as int? ?? 0),
    );
    final totalMealsAll = data.fold<int>(
      0,
      (s, d) => s + (d['meals_total'] as int? ?? 0),
    );
    final totalExDone = data.fold<int>(
      0,
      (s, d) => s + (d['exercises_completed'] as int? ?? 0),
    );
    final totalExAll = data.fold<int>(
      0,
      (s, d) => s + (d['exercises_total'] as int? ?? 0),
    );

    final mealPct =
        totalMealsAll > 0 ? (totalMealsDone / totalMealsAll * 100).toInt() : 0;
    final exPct = totalExAll > 0 ? (totalExDone / totalExAll * 100).toInt() : 0;
    final netCal = totalCal - totalBurned;

    return RefreshIndicator(
      color: _kPurple,
      backgroundColor: _kSurface,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary cards row
          _sectionTitle('Weekly Overview'),
          _WeeklyOverviewRow(
            totalCal: totalCal,
            mealsDone: totalMealsDone,
            mealsAll: totalMealsAll,
            mealPct: mealPct,
            exDone: totalExDone,
            exAll: totalExAll,
            exPct: exPct,
          ),
          const SizedBox(height: 20),
          _sectionTitle('Daily Completion %'),
          _BarChartSection(weeklyData: data),
          const SizedBox(height: 20),
          _sectionTitle('Weekly Macros'),
          _MacroBars(
            protein: totalProt,
            carbs: totalCarbs,
            fats: totalFats,
            calories: totalCal,
            targets: targets,
          ),
          const SizedBox(height: 20),
          _sectionTitle('Calorie Balance'),
          _CalorieBalanceCard(
            consumed: totalCal,
            burned: totalBurned,
            net: netCal,
            goal: goal,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSkeleton() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _shimmer(height: 90),
      const SizedBox(height: 16),
      _shimmer(height: 200),
      const SizedBox(height: 16),
      _shimmer(height: 160),
      const SizedBox(height: 16),
      _shimmer(height: 100),
    ],
  );
}

// Overview row ────────────────────────────────────────────────────────────────
class _WeeklyOverviewRow extends StatelessWidget {
  final int totalCal;
  final int mealsDone, mealsAll, mealPct;
  final int exDone, exAll, exPct;
  const _WeeklyOverviewRow({
    required this.totalCal,
    required this.mealsDone,
    required this.mealsAll,
    required this.mealPct,
    required this.exDone,
    required this.exAll,
    required this.exPct,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OverviewCard(
            icon: Icons.local_fire_department,
            value: NumberFormat('#,###').format(totalCal),
            unit: 'kcal',
            subtitle: 'this week',
            color: _kRed,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _OverviewCard(
            icon: Icons.restaurant,
            value: '$mealsDone/$mealsAll',
            unit: '',
            subtitle: '$mealPct% meals',
            color: _kGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _OverviewCard(
            icon: Icons.fitness_center,
            value: '$exDone/$exAll',
            unit: '',
            subtitle: '$exPct% workouts',
            color: _kPurple,
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String subtitle;
  final Color color;
  const _OverviewCard({
    required this.icon,
    required this.value,
    required this.unit,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// Bar chart ───────────────────────────────────────────────────────────────────
class _BarChartSection extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyData;
  const _BarChartSection({required this.weeklyData});

  Color _barColor(double pct) {
    if (pct >= 80) return _kGreen;
    if (pct >= 50) return _kOrange;
    return _kRed;
  }

  @override
  Widget build(BuildContext context) {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final bars = List.generate(weeklyData.length, (i) {
      final d = weeklyData[i];
      final mc = d['meals_completed'] as int? ?? 0;
      final mt = d['meals_total'] as int? ?? 0;
      final ec = d['exercises_completed'] as int? ?? 0;
      final et = d['exercises_total'] as int? ?? 0;
      final total = mt + et;
      final done = mc + ec;
      final pct = total > 0 ? done / total * 100 : 0.0;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: pct,
            color: _barColor(pct),
            width: 22,
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 100,
              color: _kBorder,
            ),
          ),
        ],
        showingTooltipIndicators: [],
      );
    });

    // Build day label list
    final labels = List.generate(weeklyData.length, (i) {
      String dayLabel = dayNames[i % 7];
      try {
        final dt = DateTime.parse(weeklyData[i]['date'] as String);
        dayLabel = dayNames[(dt.weekday - 1) % 7];
      } catch (_) {}
      return dayLabel;
    });

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: BarChart(
        BarChartData(
          maxY: 100,
          minY: 0,
          barGroups: bars,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine:
                (_) => FlLine(color: _kBorder, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 25,
                reservedSize: 30,
                getTitlesWidget:
                    (v, _) => Text(
                      '${v.toInt()}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                      ),
                    ),
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= labels.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      labels[idx],
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => _kSurface,
              getTooltipItem:
                  (group, _, rod, __) => BarTooltipItem(
                    '${rod.toY.toInt()}%',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

// Macro bars ──────────────────────────────────────────────────────────────────
class _MacroBars extends StatelessWidget {
  final int protein, carbs, fats, calories;
  final Map<String, int> targets;
  const _MacroBars({
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.calories,
    required this.targets,
  });

  @override
  Widget build(BuildContext context) {
    final weeklyTargets = {
      'protein': (targets['protein'] ?? 140) * 7,
      'carbs': (targets['carbs'] ?? 250) * 7,
      'fats': (targets['fats'] ?? 65) * 7,
      'calories': (targets['calories'] ?? 2000) * 7,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          _MacroBar(
            'Protein',
            protein,
            weeklyTargets['protein']!,
            _kPurple,
            'g',
          ),
          const SizedBox(height: 14),
          _MacroBar('Carbs', carbs, weeklyTargets['carbs']!, _kBlue, 'g'),
          const SizedBox(height: 14),
          _MacroBar('Fats', fats, weeklyTargets['fats']!, _kGreen, 'g'),
          const SizedBox(height: 14),
          _MacroBar(
            'Calories',
            calories,
            weeklyTargets['calories']!,
            _kRed,
            'kcal',
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final int current;
  final int target;
  final Color color;
  final String unit;
  const _MacroBar(this.label, this.current, this.target, this.color, this.unit);

  @override
  Widget build(BuildContext context) {
    final ratio = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: _kBorder,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$current/$target$unit',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}

// Calorie balance card ────────────────────────────────────────────────────────
class _CalorieBalanceCard extends StatelessWidget {
  final int consumed, burned, net;
  final String goal;
  const _CalorieBalanceCard({
    required this.consumed,
    required this.burned,
    required this.net,
    required this.goal,
  });

  String get _status {
    final isLoss = goal == 'weight_loss' || goal == 'weightLoss';
    final isGain = goal == 'muscle_gain' || goal == 'weightGain';
    if (isLoss && net < 0) return 'Good deficit';
    if (isGain && net > 0) return 'Good surplus';
    return 'Adjust your intake';
  }

  Color get _statusColor {
    final isLoss = goal == 'weight_loss' || goal == 'weightLoss';
    final isGain = goal == 'muscle_gain' || goal == 'weightGain';
    if ((isLoss && net < 0) || (isGain && net > 0)) return _kGreen;
    return _kOrange;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          _balanceRow('Consumed', '${fmt.format(consumed)} kcal', Colors.white),
          const SizedBox(height: 8),
          _balanceRow('Burned', '${fmt.format(burned)} kcal', _kGreen),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: _kBorder),
          ),
          _balanceRow(
            'Net',
            '${net >= 0 ? '+' : ''}${fmt.format(net)} kcal',
            _statusColor,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              _status,
              style: TextStyle(
                color: _statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceRow(String label, String value, Color valueColor) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
      Text(
        value,
        style: TextStyle(
          color: valueColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 3 — INSIGHTS (AI)
// ═════════════════════════════════════════════════════════════════════════════
class _InsightsTab extends StatefulWidget {
  final ProgressService svc;
  const _InsightsTab({required this.svc});

  @override
  State<_InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends State<_InsightsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const _cacheKey = 'progress_analysis_cache';
  static const _cacheDateKey = 'progress_analysis_date';

  Map<String, dynamic>? _analysis;
  DateTime? _lastUpdated;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWithCache();
  }

  Future<void> _loadWithCache({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final cachedDate = prefs.getString(_cacheDateKey);
    final cachedJson = prefs.getString(_cacheKey);

    if (!forceRefresh && cachedDate != null && cachedJson != null) {
      final date = DateTime.tryParse(cachedDate);
      if (date != null && DateTime.now().difference(date).inHours < 24) {
        setState(() {
          _analysis = json.decode(cachedJson) as Map<String, dynamic>;
          _lastUpdated = date;
          _loading = false;
        });
        return;
      }
    }

    await _fetchFresh();
  }

  Future<void> _fetchFresh() async {
    if (!mounted) return;
    final uid =
        Provider.of<AuthProvider>(context, listen: false).user?.uid ?? '';
    try {
      final results = await Future.wait([
        widget.svc.getLast7DaysData(uid),
        widget.svc.getRecentMeasurements(uid),
        _loadPrefs(uid),
      ]);

      final weeklyData = results[0] as List<Map<String, dynamic>>;
      final measurements = results[1] as List<Map<String, dynamic>>;
      final prefsData = results[2] as Map<String, dynamic>?;

      final current =
          measurements.isNotEmpty ? measurements[0] : <String, dynamic>{};
      final previous =
          measurements.length > 1 ? measurements[1] : <String, dynamic>{};
      final goal = (prefsData?['goal'] as String?) ?? 'fitness';
      final fitnessLevel =
          (prefsData?['fitness_level'] as String?) ?? 'intermediate';

      final result = await widget.svc.getAIAnalysis(
        userId: uid,
        weeklyData: weeklyData,
        currentMeasurements: current,
        previousMeasurements: previous,
        goal: goal,
        fitnessLevel: fitnessLevel,
      );

      // Cache it
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setString(_cacheKey, json.encode(result));
      await prefs.setString(_cacheDateKey, now.toIso8601String());

      if (!mounted) return;
      setState(() {
        _analysis = result;
        _lastUpdated = now;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _loadPrefs(String uid) async {
    return widget.svc.loadUserPrefs(uid);
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) return _buildSkeleton();
    if (_error != null) return _buildError();

    final analysis = _analysis?['analysis'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      color: _kPurple,
      backgroundColor: _kSurface,
      onRefresh: () => _loadWithCache(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Last updated
          if (_lastUpdated != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Last updated: ${_timeAgo(_lastUpdated!)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _loadWithCache(forceRefresh: true),
                    child: const Text(
                      'Refresh ↺',
                      style: TextStyle(color: _kPurple, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Overall score
          _AiScoreCard(analysis: analysis),
          const SizedBox(height: 16),

          // Nutrition insights
          _NutritionInsightCard(analysis: analysis),
          const SizedBox(height: 16),

          // Exercise insights
          _ExerciseInsightCard(analysis: analysis),
          const SizedBox(height: 16),

          // Body changes
          _BodyChangesCard(analysis: analysis),
          const SizedBox(height: 16),

          // Next week focus
          _NextWeekFocusCard(analysis: analysis),
          const SizedBox(height: 16),

          // Avatar update
          if (analysis['avatar_should_update'] == true)
            _AvatarUpdateCard(reason: analysis['avatar_update_reason'] ?? ''),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSkeleton() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _shimmer(height: 140),
      const SizedBox(height: 16),
      _shimmer(height: 160),
      const SizedBox(height: 16),
      _shimmer(height: 160),
      const SizedBox(height: 16),
      _shimmer(height: 200),
      const SizedBox(height: 16),
      _shimmer(height: 160),
    ],
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: _kRed, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Could not load AI insights',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _loadWithCache(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

// AI Score card ───────────────────────────────────────────────────────────────
class _AiScoreCard extends StatelessWidget {
  final Map<String, dynamic> analysis;
  const _AiScoreCard({required this.analysis});

  Color _gradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A+':
        return _kGold;
      case 'A':
        return _kGreen;
      case 'B':
        return _kBlue;
      case 'C':
        return _kOrange;
      default:
        return _kRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = analysis['overall_score'] ?? 0;
    final grade = (analysis['grade'] ?? 'B') as String;
    final headline = (analysis['headline'] ?? 'Keep pushing!') as String;
    final color = _gradeColor(grade);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Text(
                grade,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$score / 100',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  headline,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Nutrition insight card ──────────────────────────────────────────────────────
class _NutritionInsightCard extends StatelessWidget {
  final Map<String, dynamic> analysis;
  const _NutritionInsightCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final n = analysis['nutrition_analysis'] as Map<String, dynamic>? ?? {};
    final summary = n['summary'] as String? ?? '';
    final proteinStatus = n['protein_status'] as String? ?? '';
    final calStatus = n['calorie_status'] as String? ?? '';
    final fatChange = (n['estimated_fat_change_kg'] as num?)?.toDouble() ?? 0;
    final tip = n['tip'] as String? ?? '';

    return _InsightCard(
      title: 'Nutrition Insights',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _StatusChip(
                'Protein: $proteinStatus',
                proteinStatus == 'adequate' ? _kGreen : _kOrange,
              ),
              _StatusChip(
                'Calories: $calStatus',
                calStatus == 'deficit' ? _kBlue : _kOrange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                size: 16,
                color: _kOrange,
              ),
              const SizedBox(width: 6),
              Text(
                '${fatChange >= 0 ? '+' : ''}${fatChange.toStringAsFixed(2)} kg fat this week',
                style: TextStyle(
                  color: fatChange <= 0 ? _kGreen : _kRed,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (tip.isNotEmpty) ...[const SizedBox(height: 12), _TipBox(tip)],
        ],
      ),
    );
  }
}

// Exercise insight card ───────────────────────────────────────────────────────
class _ExerciseInsightCard extends StatelessWidget {
  final Map<String, dynamic> analysis;
  const _ExerciseInsightCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final e = analysis['exercise_analysis'] as Map<String, dynamic>? ?? {};
    final summary = e['summary'] as String? ?? '';
    final intensity = e['intensity_feedback'] as String? ?? '';
    final muscleImpact = e['estimated_muscle_impact'] as String? ?? '';
    final tip = e['tip'] as String? ?? '';

    return _InsightCard(
      title: 'Exercise Insights',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _StatusChip(
                'Intensity: $intensity',
                intensity == 'good' ? _kGreen : _kOrange,
              ),
              _StatusChip(
                muscleImpact,
                muscleImpact.contains('gain') ? _kGreen : _kBlue,
              ),
            ],
          ),
          if (tip.isNotEmpty) ...[const SizedBox(height: 12), _TipBox(tip)],
        ],
      ),
    );
  }
}

// Body changes card ───────────────────────────────────────────────────────────
class _BodyChangesCard extends StatelessWidget {
  final Map<String, dynamic> analysis;
  const _BodyChangesCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final b = analysis['body_changes'] as Map<String, dynamic>? ?? {};
    final weightChange = (b['weight_change_kg'] as num?)?.toDouble() ?? 0;
    final fatChange = (b['fat_change_kg'] as num?)?.toDouble() ?? 0;
    final muscleChange = (b['muscle_change_kg'] as num?)?.toDouble() ?? 0;
    final meas = b['estimated_measurements'] as Map<String, dynamic>? ?? {};
    final confidence = (b['confidence'] as String?) ?? 'low';
    final note = (b['note'] as String?) ?? '';

    final confColor = switch (confidence) {
      'high' => _kGreen,
      'medium' => _kOrange,
      _ => _kRed,
    };

    return _InsightCard(
      title: 'Estimated Body Changes',
      subtitle: 'Based on your activity (approximate)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChangeRow('WT', 'Weight', weightChange, 'kg'),
          _ChangeRow('FT', 'Fat', fatChange, 'kg'),
          _ChangeRow('MS', 'Muscle', muscleChange, 'kg'),
          if (meas['waist_change_cm'] != null)
            _ChangeRow(
              'WS',
              'Waist',
              (meas['waist_change_cm'] as num).toDouble(),
              'cm',
            ),
          if (meas['chest_change_cm'] != null)
            _ChangeRow(
              'CH',
              'Chest',
              (meas['chest_change_cm'] as num).toDouble(),
              'cm',
            ),
          if (meas['thigh_change_cm'] != null)
            _ChangeRow(
              'TH',
              'Thigh',
              (meas['thigh_change_cm'] as num).toDouble(),
              'cm',
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: confColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: confColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${confidence[0].toUpperCase()}${confidence.substring(1)} Confidence',
                  style: TextStyle(color: confColor, fontSize: 11),
                ),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              note,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  final String emoji;
  final String label;
  final double value;
  final String unit;
  const _ChangeRow(this.emoji, this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    final isPositive = value > 0;
    final color =
        isPositive ? _kGreen : (value < 0 ? _kRed : AppColors.textSecondary);
    final arrow = isPositive ? '↑' : (value < 0 ? '↓' : '→');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text('$emoji ', style: const TextStyle(fontSize: 16)),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Text(
            arrow,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Text(
            '${value.abs().toStringAsFixed(2)} $unit',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// Next week focus card ────────────────────────────────────────────────────────
class _NextWeekFocusCard extends StatelessWidget {
  final Map<String, dynamic> analysis;
  const _NextWeekFocusCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final tips = (analysis['next_week_focus'] as List?)?.cast<String>() ?? [];
    return _InsightCard(
      title: 'Focus for Next Week',
      child: Column(
        children: List.generate(tips.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: _kBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _kPurple,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tips[i],
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// Avatar update card ──────────────────────────────────────────────────────────
class _AvatarUpdateCard extends StatelessWidget {
  final String reason;
  const _AvatarUpdateCard({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kPurple.withValues(alpha: 0.2),
            _kBlue.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPurple.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🎮 ', style: TextStyle(fontSize: 20)),
              Text(
                'Your avatar has evolved!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AvatarViewerScreen(),
                    ),
                  ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Update Avatar Now →'),
            ),
          ),
        ],
      ),
    );
  }
}

// Shared insight card wrapper ─────────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _InsightCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// Status chip ─────────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Tip box ─────────────────────────────────────────────────────────────────────
class _TipBox extends StatelessWidget {
  final String tip;
  const _TipBox(this.tip);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kPurple.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡 ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
