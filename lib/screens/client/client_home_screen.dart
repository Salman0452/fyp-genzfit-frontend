import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:genzfit/providers/auth_provider.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/screens/client/body_scan_screen.dart';
import 'package:genzfit/screens/client/client_profile_screen.dart';
import 'package:genzfit/screens/client/avatar_viewer_screen.dart';
import 'package:genzfit/screens/client/recommendations_screen.dart';
import 'package:genzfit/screens/client/trainer_marketplace_screen.dart';
import 'package:genzfit/screens/client/ai_coach_screen.dart';
import 'package:genzfit/screens/chat/chat_list_screen.dart';
import 'package:genzfit/services/body_analysis_service.dart';
import 'package:genzfit/services/notification_service.dart';
import 'package:genzfit/models/measurement_model.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  int _currentIndex = 0;
  final BodyAnalysisService _bodyAnalysisService = BodyAnalysisService();
  final NotificationService _notificationService = NotificationService();
  MeasurementModel? _latestMeasurement;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLatestMeasurement();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
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
        final measurement = await _bodyAnalysisService.getLatestMeasurement(userId);
        setState(() {
          _latestMeasurement = measurement;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildHomeTab(),
      const TrainerMarketplaceScreen(),
      const ChatListScreen(),
      const ClientProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
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
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center),
              label: 'Trainers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
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
                      'Hello, ${user?.name?.split(' ').first ?? 'User'}!',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ready to transform yourself?',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    color: AppColors.background,
                    onPressed: () {
                      // TODO: Navigate to notifications
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Goal card
            _buildGoalCard(user),
            const SizedBox(height: 24),

            // Quick actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
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
                  const Text(
                    'Your Progress',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _currentIndex = 3);
                    },
                    child: const Text(
                      'View All',
                      style: TextStyle(color: AppColors.accent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildProgressCard(_latestMeasurement!),
            ] else if (!_isLoading) ...[
              const Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
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
            child: Icon(
              goalIcon,
              color: AppColors.accent,
              size: 32,
            ),
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
                AppColors.accent,
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
                Colors.purple,
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
                'AI Recommendations',
                Icons.lightbulb,
                Colors.orange,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RecommendationsScreen(),
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
                Colors.blue,
                () {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  if (authProvider.userModel != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AICoachScreen(user: authProvider.userModel!),
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
                AppColors.info,
                () {
                  setState(() => _currentIndex = 1);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(),
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
          color: AppColors.surface,
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
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
        color: AppColors.surface,
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
              color: AppColors.charcoal,
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
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
        Icon(icon, color: AppColors.accent, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyProgressCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
          const Text(
            'No measurements yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Take your first body scan to start tracking your progress',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BodyScanScreen(),
                ),
              ).then((_) => _loadLatestMeasurement());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
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
}
