import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:genzfit/providers/auth_provider.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/utils/design_utils.dart';
import 'package:genzfit/screens/client/body_scan_screen.dart';
import 'package:genzfit/screens/client/client_profile_screen.dart';
import 'package:genzfit/screens/client/avatar_viewer_screen.dart';
import 'package:genzfit/screens/client/trainer_marketplace_screen.dart';
import 'package:genzfit/screens/client/ai_coach_screen.dart';
import 'package:genzfit/screens/client/daily_plan_screen.dart';
import 'package:genzfit/screens/chat/chat_list_screen.dart';
import 'package:genzfit/screens/progress/progress_screen.dart';
import 'package:genzfit/screens/preferences/preferences_screen.dart';
import 'package:genzfit/services/body_analysis_service.dart';
import 'package:genzfit/services/notification_service.dart';
import 'package:genzfit/services/notifications_service.dart';
import 'package:genzfit/models/measurement_model.dart';
import 'package:genzfit/screens/client/notifications_screen.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  int _currentIndex = 0;
  int _carouselIndex = 0;
  final BodyAnalysisService _bodyAnalysisService = BodyAnalysisService();
  final NotificationService _notificationService = NotificationService();
  final NotificationsService _notificationsService = NotificationsService();
  MeasurementModel? _latestMeasurement;
  bool _isLoading = true;

  final List<Map<String, String>> _carouselItems = [
    {
      'title': 'AI-Powered Coaching',
      'subtitle': 'Get personalized fitness plans powered by advanced AI',
      'image': 'assets/images/carousel_1.jpg',
    },
    {
      'title': 'Real-Time Progress',
      'subtitle': 'Track your transformation with 3D body scans',
      'image': 'assets/images/carousel_2.jpg',
    },
    {
      'title': 'Expert Trainers',
      'subtitle': 'Connect with certified fitness professionals',
      'image': 'assets/images/carousel_3.webp',
    },
    {
      'title': 'Community Driven',
      'subtitle': 'Join millions transforming their fitness journey',
      'image': 'assets/images/carousel_4.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadLatestMeasurement();
    _saveTokenToDatabase();
  }

  Future<void> _saveTokenToDatabase() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    if (userId != null) {
      await _notificationService.saveTokenToDatabase(userId);
    }
  }

  Future<void> _loadLatestMeasurement() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId != null) {
        final measurement = await _bodyAnalysisService.getLatestMeasurement(
          userId,
        );
        setState(() {
          _latestMeasurement = measurement;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _getGoalFocus(String? goalValue) {
    final goal = (goalValue ?? '').toLowerCase();
    if (goal == 'weightloss' || goal == 'weight loss') {
      return 'Today\'s focus is consistent nutrition and clean training volume.';
    }
    if (goal == 'weightgain' || goal == 'weight gain') {
      return 'Today\'s focus is progressive overload and quality calorie intake.';
    }
    if (goal == 'fitness') {
      return 'Today\'s focus is balanced strength, mobility, and recovery.';
    }
    return 'Today\'s focus is building a repeatable high-performance routine.';
  }

  String _getReadinessLabel() {
    if (_latestMeasurement == null) return 'Assessment Pending';
    final bmi = _latestMeasurement!.bmi;
    if (bmi < 18.5) return 'Build Phase';
    if (bmi < 25) return 'Performance Range';
    return 'Cut Phase';
  }

  Future<void> _openTodaysPlan() async {
    await HapticFeedback.selectionClick();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DailyPlanScreen()),
    );
  }

  Future<void> _openAiCoach() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userModel == null) return;

    await HapticFeedback.selectionClick();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AICoachScreen(user: authProvider.userModel!),
      ),
    );
  }

  Widget _buildNotificationIcon(BuildContext context, String? userId) {
    if (userId == null) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.brandGreen
              : AppColors.brandGreenDeep,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.notifications_outlined),
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF010101)
              : AppColors.textPrimary,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationsScreen(),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<int>(
      stream: _notificationsService.getUnreadNotificationsCount(userId),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandGreen
                    : AppColors.brandGreenDeep,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined),
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF010101)
                    : AppColors.textPrimary,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                },
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildHomeTab(),
      const ProgressScreen(),
      const TrainerMarketplaceScreen(),
      const ChatListScreen(),
      const ClientProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomAppBarTheme.color ??
              Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          selectedItemColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.brandGreen
              : AppColors.brandGreenDeep,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart),
              label: 'Progress',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center),
              label: 'Trainers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Messages',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${user?.name.split(' ').first ?? 'User'}!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ready to transform yourself?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFB0B0B0)
                                : AppColors.textSecondary)
                            .withOpacity(0.8),
                      ),
                    ),
                  ],
                _buildNotificationIcon(context, authProvider.user?.uid  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Feature Carousel
            _buildFeatureCarousel(),
            const SizedBox(height: 32),

            _buildMotivationHero(user),
            const SizedBox(height: 20),

            // Quick actions
            Text(
              'Quick Actions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildQuickActions(),
            const SizedBox(height: 24),

            // Latest measurement
            if (_latestMeasurement != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Progress',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _currentIndex = 1);
                    },
                    child: Text(
                      'View All',
                      style: GoogleFonts.plusJakartaSans(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildProgressCard(_latestMeasurement!),
            ] else if (!_isLoading) ...[
              Text(
                'Get Started',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildEmptyProgressCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMotivationHero(user) {
    final userName = user?.name?.toString().split(' ').first ?? 'User';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentTeal.withOpacity(0.2),
            AppColors.accentCyan.withOpacity(0.16),
            AppColors.accentViolet.withOpacity(0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(color: AppColors.accentTeal.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getGreeting()}, $userName',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getGoalFocus(user?.goals?.toString()),
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFB0B0B0)
                            : AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.accentViolet.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  _getReadinessLabel(),
                  style: const TextStyle(
                    color: AppColors.accentViolet,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _openTodaysPlan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: AppColors.background,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSmall,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Open Today\'s Plan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _openAiCoach,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.accentCyan.withOpacity(0.6),
                  ),
                  foregroundColor: AppColors.accentCyan,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusSmall,
                    ),
                  ),
                ),
                child: const Text(
                  'AI Coach',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(user) {
    final goal = user?.goals ?? 'Not set';
    final IconData goalIcon;
    final String goalDescription;

    switch (goal.toLowerCase()) {
      case 'fitness':
        goalIcon = Icons.fitness_center;
        goalDescription = 'Build strength and endurance';
        break;
      case 'weightgain':
      case 'weight gain':
        goalIcon = Icons.trending_up;
        goalDescription = 'Gain healthy muscle mass';
        break;
      case 'weightloss':
      case 'weight loss':
        goalIcon = Icons.trending_down;
        goalDescription = 'Lose weight and get lean';
        break;
      default:
        goalIcon = Icons.flag;
        goalDescription = 'Set your fitness goal';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withOpacity(0.2),
            AppColors.accent.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(goalIcon, color: AppColors.accent, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Goal',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  goal,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  goalDescription,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Body Scan',
                Icons.camera_alt,
                Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandGreen
                    : AppColors.brandGreenDeep,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BodyScanScreen(),
                    ),
                  ).then((_) => _loadLatestMeasurement());
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                '3D Avatar',
                Icons.view_in_ar,
                AppColors.accentViolet,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AvatarViewerScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Today\'s Plan',
                Icons.today,
                AppColors.accentViolet,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DailyPlanScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'AI Coach',
                Icons.smart_toy,
                AppColors.accentCyan,
                () {
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  if (authProvider.userModel != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AICoachScreen(user: authProvider.userModel!),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Find Trainer',
                Icons.search,
                AppColors.accentTeal,
                () {
                  setState(() => _currentIndex = 2);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Preferences',
                Icons.tune,
                AppColors.accentGray,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PreferencesScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1A1A)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(MeasurementModel measurement) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildProgressStat(
                'Weight',
                '${measurement.weight.toStringAsFixed(1)} kg',
                Icons.monitor_weight,
              ),
              _buildProgressStat(
                'Height',
                '${measurement.height.toStringAsFixed(0)} cm',
                Icons.height,
              ),
              _buildProgressStat(
                'BMI',
                measurement.bmi.toStringAsFixed(1),
                Icons.analytics,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.charcoal
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  measurement.bmi < 18.5
                      ? Icons.trending_down
                      : measurement.bmi < 25
                          ? Icons.check_circle
                          : Icons.trending_up,
                  color: measurement.bmi < 18.5
                      ? AppColors.info
                      : measurement.bmi < 25
                          ? AppColors.success
                          : AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  measurement.bmiCategory,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.brandGreen
                : AppColors.brandGreenDeep,
            size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFB0B0B0)
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyProgressCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.photo_camera,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No measurements yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Take your first body scan to start tracking your progress',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFB0B0B0)
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BodyScanScreen()),
              ).then((_) => _loadLatestMeasurement());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.brandGreen
                  : AppColors.brandGreenDeep,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              ),
            ),
            icon: const Icon(Icons.camera_alt, color: AppColors.background),
            label: const Text(
              'Start Body Scan',
              style: TextStyle(
                color: AppColors.background,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            onPageChanged: (index) {
              setState(() => _carouselIndex = index);
            },
            itemCount: _carouselItems.length,
            itemBuilder: (context, index) {
              final item = _carouselItems[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Background Image
                      Image.asset(
                        item['image'] ?? '',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                      // Dark Overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.6),
                            ],
                          ),
                        ),
                      ),
                      // Text Content
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Text(
                                item['title'] ?? '',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Subtitle
                              Text(
                                item['subtitle'] ?? '',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white.withOpacity(0.9)
                                      : AppColors.textSecondary,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Carousel Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _carouselItems.length,
            (index) => GestureDetector(
              onTap: () {
                // Jump to page
                final controller = PageController(initialPage: index);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _carouselIndex == index ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _carouselIndex == index
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep)
                      : AppColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
