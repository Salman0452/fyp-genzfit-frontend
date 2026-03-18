import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/onboarding_data.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_preferences_service.dart';
import '../../screens/client/client_home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme constants for onboarding — aligned with AppColors / AppConstants
// ─────────────────────────────────────────────────────────────────────────────
class _OC {
  static const bg = Color(0xFF0A0B0A); // AppConstants.primaryBlack
  static const surface = Color(0xFF171917); // AppConstants.charcoalGray
  static const accent = Color(0xFF7FFA88); // AppConstants.primaryGold
  static const teal = Color(0xFF83BCB5); // AppConstants.accentGold
  static const white = Color(0xFFFFFFFF);
  static const muted = Color(0xFF5E625F); // AppConstants.textGray
  static const border = Color(0xFF2A2D2B); // AppConstants.accentGray
  static const error = Color(0xFFFF5C5C); // AppConstants.errorRed

  // Single-color solid button — no gradient needed
  static BoxDecoration get buttonDecoration => BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.35),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main OnboardingScreen
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 7;
  final OnboardingData _data = OnboardingData();
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _progressAnimation =
        Tween<double>(begin: 1 / _totalPages, end: 1 / _totalPages)
            .animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    _progressController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) return;

    final targetProgress = (page + 1) / _totalPages;
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: targetProgress,
    ).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _progressController
      ..reset()
      ..forward();

    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = page);
  }

  void _nextPage() => _goToPage(_currentPage + 1);
  void _prevPage() => _goToPage(_currentPage - 1);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _OC.bg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──────────────────────────────────────────────────
              if (_currentPage > 0) _buildTopBar(),
              // ── Progress bar (hidden on welcome screen) ──────────────────
              if (_currentPage > 0) _buildProgressBar(),
              // ── Pages ────────────────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _WelcomePage(onNext: _nextPage),
                    _GoalPage(
                      data: _data,
                      onNext: _nextPage,
                    ),
                    _FitnessLevelPage(
                      data: _data,
                      onNext: _nextPage,
                    ),
                    _WorkoutLocationPage(
                      data: _data,
                      onNext: _nextPage,
                    ),
                    _BodyMeasurementsPage(
                      data: _data,
                      onNext: _nextPage,
                    ),
                    _DietPreferencesPage(
                      data: _data,
                      onNext: _nextPage,
                    ),
                    _CelebrationPage(data: _data),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _prevPage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _OC.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _OC.border),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: _OC.white, size: 18),
            ),
          ),
          const Spacer(),
          Text(
            '${_currentPage} of ${_totalPages - 1}',
            style: const TextStyle(color: _OC.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, _) {
          return LayoutBuilder(builder: (context, constraints) {
            return Stack(
              children: [
                // Background
                Container(
                  height: 6,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: _OC.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // Filled
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  height: 6,
                  width: constraints.maxWidth * _progressAnimation.value,
                  decoration: BoxDecoration(
                    color: _OC.accent,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: _OC.accent.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            );
          });
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _GradientButton({
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: _OC.buttonDecoration,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: _OC.bg,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _OC.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: _OC.muted, fontSize: 15),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen 1 — Welcome
// ─────────────────────────────────────────────────────────────────────────────
class _WelcomePage extends StatefulWidget {
  final VoidCallback onNext;

  const _WelcomePage({required this.onNext});

  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this);
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl, curve: const Interval(0.3, 1.0, curve: Curves.easeIn)),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          // Animated icon
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.scale(
              scale: _scaleAnim.value,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _OC.accent,
                  boxShadow: [
                    BoxShadow(
                      color: _OC.accent.withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child:
                    const Icon(Icons.fitness_center, size: 64, color: _OC.bg),
              ),
            ),
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _fadeAnim,
            builder: (_, __) => Opacity(
              opacity: _fadeAnim.value,
              child: Column(
                children: [
                  const Text(
                    'Welcome to GenZFit',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _OC.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Let's build your perfect fitness profile",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _OC.muted, fontSize: 17),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Takes only 2 minutes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _OC.accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 3),
          AnimatedBuilder(
            animation: _fadeAnim,
            builder: (_, __) => Opacity(
              opacity: _fadeAnim.value,
              child: Column(
                children: [
                  _GradientButton(
                    label: "Let's Go →",
                    onTap: widget.onNext,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacementNamed(
                        context, '/role-selection'),
                    child: const Text(
                      'Already have an account? Sign In',
                      style: TextStyle(color: _OC.muted, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen 2 — Goal Selection
// ─────────────────────────────────────────────────────────────────────────────
class _GoalPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;

  const _GoalPage({required this.data, required this.onNext});

  @override
  State<_GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends State<_GoalPage> {
  static const _goals = [
    {
      'title': 'Lose Weight',
      'subtitle': 'Burn fat, feel lighter',
      'value': 'weight_loss',
    },
    {
      'title': 'Build Muscle',
      'subtitle': 'Get stronger and bigger',
      'value': 'muscle_gain',
    },
    {
      'title': 'Stay Fit',
      'subtitle': 'Maintain and improve',
      'value': 'fitness',
    },
    {
      'title': 'Boost Endurance',
      'subtitle': 'Run farther, last longer',
      'value': 'endurance',
    },
  ];

  void _select(String value) {
    setState(() => widget.data.goal = value);
    Future.delayed(const Duration(milliseconds: 500), widget.onNext);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: "What's your main goal?",
            subtitle: "We'll customize everything for you",
          ),
          const SizedBox(height: 32),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.95,
            children: _goals.map((goal) {
              final selected = widget.data.goal == goal['value'];
              return _AnimatedGoalCard(
                title: goal['title'] as String,
                subtitle: goal['subtitle'] as String,
                selected: selected,
                onTap: () => _select(goal['value'] as String),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _AnimatedGoalCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _AnimatedGoalCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_AnimatedGoalCard> createState() => _AnimatedGoalCardState();
}

class _AnimatedGoalCardState extends State<_AnimatedGoalCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 200), vsync: this);
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_AnimatedGoalCard old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      _ctrl.forward();
    } else if (!widget.selected && old.selected) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (_, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: widget.selected ? _OC.accent.withOpacity(0.12) : _OC.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.selected ? _OC.accent : _OC.border,
              width: widget.selected ? 2.5 : 1,
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: _OC.accent.withOpacity(0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Opacity(
            opacity: widget.selected ? 1.0 : 0.6,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: widget.selected
                        ? Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: _OC.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                color: _OC.bg, size: 14),
                          )
                        : const SizedBox(width: 24, height: 24),
                  ),
                  const Spacer(),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: _OC.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(color: _OC.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen 3 — Fitness Level
// ─────────────────────────────────────────────────────────────────────────────
class _FitnessLevelPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;

  const _FitnessLevelPage({required this.data, required this.onNext});

  @override
  State<_FitnessLevelPage> createState() => _FitnessLevelPageState();
}

class _FitnessLevelPageState extends State<_FitnessLevelPage> {
  static const _levels = [
    {
      'title': 'Beginner',
      'subtitle': 'Just starting out or getting back in shape',
      'bullets': [
        'Simple exercises',
        'Shorter workouts',
        'Step by step guidance'
      ],
      'value': 'beginner',
    },
    {
      'title': 'Intermediate',
      'subtitle': 'Workout regularly, know the basics',
      'bullets': [
        'Moderate intensity',
        'Progressive overload',
        'Varied exercises'
      ],
      'value': 'intermediate',
    },
    {
      'title': 'Advanced',
      'subtitle': 'Train hard, push limits',
      'bullets': ['High intensity', 'Complex movements', 'Maximum results'],
      'value': 'advanced',
    },
  ];

  void _select(String value) {
    setState(() => widget.data.fitnessLevel = value);
    Future.delayed(const Duration(milliseconds: 500), widget.onNext);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: "What's your fitness level?",
            subtitle: "Be honest — we'll match your workouts",
          ),
          const SizedBox(height: 28),
          ...(_levels.map((level) {
            final selected = widget.data.fitnessLevel == level['value'];
            final bullets = level['bullets'] as List;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _LevelCard(
                title: level['title'] as String,
                subtitle: level['subtitle'] as String,
                bullets: bullets.cast<String>(),
                selected: selected,
                onTap: () => _select(level['value'] as String),
              ),
            );
          }).toList()),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> bullets;
  final bool selected;
  final VoidCallback onTap;

  const _LevelCard({
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? _OC.accent.withOpacity(0.10) : _OC.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _OC.accent : _OC.border,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _OC.accent.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Opacity(
          opacity: selected ? 1.0 : 0.6,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _OC.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _OC.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: bullets
                          .map(
                            (b) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _OC.accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                b,
                                style: const TextStyle(
                                    color: _OC.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              if (selected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                      color: _OC.accent, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: _OC.bg, size: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen 4 — Workout Location
// ─────────────────────────────────────────────────────────────────────────────
class _WorkoutLocationPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;

  const _WorkoutLocationPage({required this.data, required this.onNext});

  @override
  State<_WorkoutLocationPage> createState() => _WorkoutLocationPageState();
}

class _WorkoutLocationPageState extends State<_WorkoutLocationPage> {
  static const _locations = [
    {
      'icon': Icons.fitness_center,
      'title': 'Gym',
      'subtitle': 'Full equipment access',
      'value': 'gym',
    },
    {
      'icon': Icons.home,
      'title': 'Home',
      'subtitle': 'No equipment needed',
      'value': 'home',
    },
    {
      'icon': Icons.park,
      'title': 'Outdoor',
      'subtitle': 'Parks and open spaces',
      'value': 'outdoor',
    },
  ];

  static const Map<String, List<String>> _equipmentOptions = {
    'gym': [
      'Barbell',
      'Dumbbells',
      'Cable Machine',
      'Bench Press',
      'Squat Rack',
      'Resistance Machines',
      'Yoga Mat',
      'Treadmill / Cardio',
    ],
    'home': [
      'Dumbbells',
      'Resistance Bands',
      'Pull-up Bar',
      'Yoga Mat',
      'Stability Ball',
      'Jump Rope',
    ],
  };

  void _selectLocation(String value) {
    setState(() {
      widget.data.workoutLocation = value;
      widget.data.availableEquipment.clear();
    });
  }

  void _toggleEquipment(String label) {
    setState(() {
      if (widget.data.availableEquipment.contains(label)) {
        widget.data.availableEquipment.remove(label);
      } else {
        widget.data.availableEquipment.add(label);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.data.workoutLocation;
    final equipment = loc != null ? _equipmentOptions[loc] : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Where do you work out?',
            subtitle: "We'll suggest the right exercises",
          ),
          const SizedBox(height: 28),
          // Location cards
          ..._locations.map((location) {
            final selected = loc == location['value'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _selectLocation(location['value'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        selected ? _OC.accent.withOpacity(0.10) : _OC.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? _OC.accent : _OC.border,
                      width: selected ? 2.5 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: _OC.accent.withOpacity(0.2),
                                blurRadius: 12)
                          ]
                        : [],
                  ),
                  child: Opacity(
                    opacity: selected ? 1.0 : 0.6,
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _OC.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            location['icon'] as IconData,
                            color: _OC.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                location['title'] as String,
                                style: const TextStyle(
                                    color: _OC.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                location['subtitle'] as String,
                                style: const TextStyle(
                                    color: _OC.muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                                color: _OC.accent, shape: BoxShape.circle),
                            child: const Icon(Icons.check,
                                color: _OC.bg, size: 14),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // Equipment section
          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            child: loc != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      if (loc == 'outdoor')
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _OC.accent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: _OC.accent.withOpacity(0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.directions_run,
                                  color: _OC.accent, size: 22),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "We'll create bodyweight workouts tailored for outdoor training",
                                  style:
                                      TextStyle(color: _OC.white, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (equipment != null) ...[
                        const Text(
                          'What equipment do you have?',
                          style: TextStyle(
                            color: _OC.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: equipment.map((label) {
                            final isSelected =
                                widget.data.availableEquipment.contains(label);
                            return GestureDetector(
                              onTap: () => _toggleEquipment(label),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _OC.accent.withOpacity(0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isSelected ? _OC.accent : _OC.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isSelected ? _OC.accent : _OC.muted,
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 28),
                      _GradientButton(
                        label: 'Continue →',
                        onTap: widget.onNext,
                      ),
                      const SizedBox(height: 20),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen 5 — Body Measurements
// ─────────────────────────────────────────────────────────────────────────────
class _BodyMeasurementsPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;

  const _BodyMeasurementsPage({required this.data, required this.onNext});

  @override
  State<_BodyMeasurementsPage> createState() => _BodyMeasurementsPageState();
}

class _BodyMeasurementsPageState extends State<_BodyMeasurementsPage> {
  late TextEditingController _ageCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;

  @override
  void initState() {
    super.initState();
    _ageCtrl = TextEditingController(text: widget.data.age.toString());
    _heightCtrl =
        TextEditingController(text: widget.data.heightCm.toStringAsFixed(0));
    _weightCtrl =
        TextEditingController(text: widget.data.weightKg.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _updateData() {
    widget.data.age = int.tryParse(_ageCtrl.text) ?? widget.data.age;
    widget.data.heightCm =
        double.tryParse(_heightCtrl.text) ?? widget.data.heightCm;
    widget.data.weightKg =
        double.tryParse(_weightCtrl.text) ?? widget.data.weightKg;
  }

  double get _bmi {
    final h = widget.data.heightCm / 100;
    if (h <= 0) return 0;
    return widget.data.weightKg / (h * h);
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
    if (b < 18.5) return _OC.teal;
    if (b < 25) return _OC.accent;
    if (b < 30) return const Color(0xFFFFD166);
    return _OC.error;
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _OC.muted),
      filled: true,
      fillColor: _OC.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _OC.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _OC.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _OC.accent, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Tell us about yourself',
            subtitle: 'For accurate calorie and workout calculations',
          ),
          const SizedBox(height: 28),

          // Row 1: Age + Gender
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Age',
                        style: TextStyle(color: _OC.muted, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: _OC.white),
                      decoration: _fieldDecoration('25'),
                      onChanged: (_) => setState(_updateData),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gender',
                        style: TextStyle(color: _OC.muted, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: _OC.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _OC.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => widget.data.gender = 'male'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: widget.data.gender == 'male'
                                      ? _OC.accent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'Male',
                                    style: TextStyle(
                                      color: widget.data.gender == 'male'
                                          ? _OC.bg
                                          : _OC.muted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => widget.data.gender = 'female'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: widget.data.gender == 'female'
                                      ? _OC.accent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    'Female',
                                    style: TextStyle(
                                      color: widget.data.gender == 'female'
                                          ? _OC.bg
                                          : _OC.muted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
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
          const SizedBox(height: 16),

          // Row 2: Height
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Height',
                  style: TextStyle(color: _OC.muted, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _heightCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: _OC.white),
                decoration: _fieldDecoration('e.g. 170').copyWith(
                  suffixText: 'cm',
                  suffixStyle: const TextStyle(color: _OC.muted),
                ),
                onChanged: (_) => setState(_updateData),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 3: Weight
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Weight',
                  style: TextStyle(color: _OC.muted, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _weightCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: _OC.white),
                decoration: _fieldDecoration('e.g. 70').copyWith(
                  suffixText: 'kg',
                  suffixStyle: const TextStyle(color: _OC.muted),
                ),
                onChanged: (_) => setState(_updateData),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // BMI display
          if (widget.data.heightCm > 0 && widget.data.weightKg > 0)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _bmiColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _bmiColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Text(
                    'Your BMI: ${_bmi.toStringAsFixed(1)}',
                    style: TextStyle(
                        color: _bmiColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '— $_bmiCategory',
                    style: TextStyle(color: _bmiColor, fontSize: 14),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Workout duration slider
          const Text(
            'How long can you work out?',
            style: TextStyle(
                color: _OC.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.data.workoutDurationMinutes} minutes',
            style: const TextStyle(
                color: _OC.accent, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _OC.accent,
              inactiveTrackColor: _OC.border,
              thumbColor: _OC.accent,
              overlayColor: _OC.accent.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: widget.data.workoutDurationMinutes.toDouble(),
              min: 15,
              max: 90,
              divisions: 5,
              onChanged: (v) => setState(
                  () => widget.data.workoutDurationMinutes = v.round()),
            ),
          ),
          const SizedBox(height: 20),

          // Days per week
          const Text(
            'How many days per week?',
            style: TextStyle(
                color: _OC.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final day = i + 1;
              final selected = widget.data.workoutDaysPerWeek == day;
              return GestureDetector(
                onTap: () =>
                    setState(() => widget.data.workoutDaysPerWeek = day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected ? _OC.accent : _OC.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? _OC.accent : _OC.border,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: _OC.accent.withOpacity(0.35),
                                blurRadius: 8)
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: selected ? _OC.bg : _OC.muted,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          _GradientButton(
            label: 'Continue →',
            onTap: widget.onNext,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen 6 — Diet Preferences
// ─────────────────────────────────────────────────────────────────────────────
class _DietPreferencesPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;

  const _DietPreferencesPage({required this.data, required this.onNext});

  @override
  State<_DietPreferencesPage> createState() => _DietPreferencesPageState();
}

class _DietPreferencesPageState extends State<_DietPreferencesPage> {
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Your diet preferences',
            subtitle: "We'll respect your food choices",
          ),
          const SizedBox(height: 28),
          _buildSingleSelectSection(
            title: 'Cuisine Style',
            options: const [
              {'label': 'Pakistani', 'value': 'pakistani'},
              {'label': 'Mixed', 'value': 'mixed'},
              {'label': 'Continental', 'value': 'continental'},
            ],
            selected: d.cuisinePreference,
            onSelect: (v) => setState(() => d.cuisinePreference = v),
          ),
          const SizedBox(height: 22),
          _buildSingleSelectSection(
            title: 'Meals per day',
            options: const [
              {'label': '3 Meals', 'value': '3'},
              {'label': '4 Meals', 'value': '4'},
              {'label': '5 Meals', 'value': '5'},
            ],
            selected: d.mealsPerDay.toString(),
            onSelect: (v) => setState(() => d.mealsPerDay = int.parse(v)),
          ),
          const SizedBox(height: 22),
          _buildMultiSelectSection(
            title: 'Dietary Restrictions',
            options: const [
              {'label': 'No Pork', 'value': 'no_pork'},
              {'label': 'Vegetarian', 'value': 'vegetarian'},
              {'label': 'No Dairy', 'value': 'no_dairy'},
              {'label': 'Gluten Free', 'value': 'gluten_free'},
              {'label': 'No Sugar', 'value': 'no_sugar'},
              {'label': 'Low Sodium', 'value': 'low_sodium'},
            ],
            selected: d.dietaryRestrictions,
            onToggle: (v) => setState(() {
              if (d.dietaryRestrictions.contains(v)) {
                d.dietaryRestrictions.remove(v);
              } else {
                d.dietaryRestrictions.add(v);
              }
            }),
          ),
          const SizedBox(height: 22),
          _buildMultiSelectSection(
            title: 'Food Allergies',
            options: const [
              {'label': 'Nuts', 'value': 'nuts'},
              {'label': 'Shellfish', 'value': 'shellfish'},
              {'label': 'Eggs', 'value': 'eggs'},
              {'label': 'Fish', 'value': 'fish'},
              {'label': 'No Allergies', 'value': 'none'},
            ],
            selected: d.foodAllergies,
            onToggle: (v) => setState(() {
              if (v == 'none') {
                d.foodAllergies.clear();
                d.foodAllergies.add('none');
              } else {
                d.foodAllergies.remove('none');
                if (d.foodAllergies.contains(v)) {
                  d.foodAllergies.remove(v);
                } else {
                  d.foodAllergies.add(v);
                }
              }
            }),
          ),
          const SizedBox(height: 22),
          _buildMultiSelectSection(
            title: 'Health Conditions',
            options: const [
              {'label': 'Diabetes', 'value': 'diabetes'},
              {'label': 'Heart Disease', 'value': 'heart_disease'},
              {'label': 'Hypertension', 'value': 'hypertension'},
              {'label': 'Joint Issues', 'value': 'joint_issues'},
              {'label': 'None', 'value': 'none'},
            ],
            selected: d.healthConditions,
            onToggle: (v) => setState(() {
              if (v == 'none') {
                d.healthConditions.clear();
                d.healthConditions.add('none');
              } else {
                d.healthConditions.remove('none');
                if (d.healthConditions.contains(v)) {
                  d.healthConditions.remove(v);
                } else {
                  d.healthConditions.add(v);
                }
              }
            }),
          ),
          const SizedBox(height: 32),
          _GradientButton(
            label: 'Continue →',
            onTap: widget.onNext,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSingleSelectSection({
    required String title,
    required List<Map<String, String>> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: _OC.white, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected == opt['value'];
            return GestureDetector(
              onTap: () => onSelect(opt['value']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      isSelected ? _OC.accent.withOpacity(0.16) : _OC.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? _OC.accent : _OC.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  opt['label']!,
                  style: TextStyle(
                    color: isSelected ? _OC.accent : _OC.muted,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMultiSelectSection({
    required String title,
    required List<Map<String, String>> options,
    required List<String> selected,
    required ValueChanged<String> onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: _OC.white, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected.contains(opt['value']);
            return GestureDetector(
              onTap: () => onToggle(opt['value']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      isSelected ? _OC.accent.withOpacity(0.16) : _OC.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? _OC.accent : _OC.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  opt['label']!,
                  style: TextStyle(
                    color: isSelected ? _OC.accent : _OC.muted,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen 7 — Celebration + Save
// ─────────────────────────────────────────────────────────────────────────────
class _CelebrationPage extends StatefulWidget {
  final OnboardingData data;

  const _CelebrationPage({required this.data});

  @override
  State<_CelebrationPage> createState() => _CelebrationPageState();
}

class _CelebrationPageState extends State<_CelebrationPage>
    with TickerProviderStateMixin {
  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;

  int _completedSteps = 0;
  bool _saving = false;

  final List<String> _steps = [
    'Profile saved',
    'Preferences configured',
    'First plan generating...',
  ];

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut),
    );
    _checkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkCtrl, curve: const Interval(0.0, 0.5)),
    );
    _checkCtrl.forward();
    _startSaving();
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  Future<void> _startSaving() async {
    if (_saving) return;
    _saving = true;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final prefsService = UserPreferencesService();
    final userId = authProvider.user?.uid;

    // Run saving + minimum 3 second animation in parallel
    final minimumDelay = Future.delayed(const Duration(seconds: 3));

    try {
      // Step 1
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) setState(() => _completedSteps = 1);

      if (userId != null) {
        final prefsMap = widget.data.toPreferencesMap();
        // Step 2
        await prefsService.savePreferences(
          userId: userId,
          preferences: prefsMap,
        );
        if (mounted) setState(() => _completedSteps = 2);

        // Step 3
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'onboarding_completed': true});
        if (mounted) setState(() => _completedSteps = 3);
      } else {
        if (mounted) setState(() => _completedSteps = 3);
      }
    } catch (e) {
      debugPrint('Onboarding save error: $e');
      if (mounted) setState(() => _completedSteps = 3);
    }

    await minimumDelay;
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ClientHomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          // Animated checkmark circle
          AnimatedBuilder(
            animation: _checkCtrl,
            builder: (_, __) => Opacity(
              opacity: _checkOpacity.value,
              child: Transform.scale(
                scale: _checkScale.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _OC.accent,
                    boxShadow: [
                      BoxShadow(
                        color: _OC.accent.withOpacity(0.4),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_circle_outline,
                      size: 64, color: _OC.bg),
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          const Text(
            "You're all set!",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _OC.white, fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Setting up your personalized plan...',
            textAlign: TextAlign.center,
            style: TextStyle(color: _OC.muted, fontSize: 16),
          ),
          const Spacer(flex: 2),

          // Step indicators
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _OC.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _OC.border),
            ),
            child: Column(
              children: List.generate(_steps.length, (i) {
                final done = _completedSteps > i;
                final inProgress = _completedSteps == i;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: done
                              ? _OC.accent
                              : inProgress
                                  ? _OC.accent.withOpacity(0.25)
                                  : _OC.border,
                          shape: BoxShape.circle,
                        ),
                        child: done
                            ? const Icon(Icons.check, color: _OC.bg, size: 16)
                            : inProgress
                                ? const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: CircularProgressIndicator(
                                      color: _OC.accent,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : null,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        _steps[i],
                        style: TextStyle(
                          color: done ? _OC.white : _OC.muted,
                          fontSize: 15,
                          fontWeight:
                              done ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
