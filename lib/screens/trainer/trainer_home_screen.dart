import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:genzfit/providers/auth_provider.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/screens/trainer/trainer_profile_screen.dart';
import 'package:genzfit/screens/trainer/dashboard_screen.dart';
import 'package:genzfit/screens/chat/chat_list_screen.dart';
import 'package:genzfit/services/notification_service.dart';

class TrainerHomeScreen extends StatefulWidget {
  const TrainerHomeScreen({super.key});

  @override
  State<TrainerHomeScreen> createState() => _TrainerHomeScreenState();
}

class _TrainerHomeScreenState extends State<TrainerHomeScreen> {
  int _currentIndex = 0;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final trainer = authProvider.userModel;

    final List<Widget> screens = [
      _buildHomeTab(),
      const ChatListScreen(),
      trainer != null 
          ? TrainerDashboardScreen(trainer: trainer) 
          : const Center(child: CircularProgressIndicator()),
      const TrainerProfileScreen(),
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
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
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
                      'Welcome back, ${user?.name?.split(' ').first ?? 'Trainer'}!',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Help your clients achieve their goals',
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

            // Verification status banner
            if (!(user?.verified ?? false))
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  border: Border.all(
                    color: AppColors.warning.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Complete Your Profile',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Upload certifications to get verified and attract more clients',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _currentIndex = 3);
                      },
                      child: const Text(
                        'Complete',
                        style: TextStyle(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),

            // Stats overview
            _buildStatsOverview(user),
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

            // Recent activity placeholder
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview(user) {
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Clients',
                '${user?.clients ?? 0}',
                Icons.people,
                AppColors.info,
              ),
              Container(
                width: 1,
                height: 50,
                color: AppColors.accent.withOpacity(0.3),
              ),
              _buildStatItem(
                'Rating',
                (user?.rating ?? 0.0).toStringAsFixed(1),
                Icons.star,
                AppColors.accent,
              ),
              Container(
                width: 1,
                height: 50,
                color: AppColors.accent.withOpacity(0.3),
              ),
              _buildStatItem(
                'Earnings',
                '\$${user?.totalEarnings ?? 0}',
                Icons.monetization_on,
                AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
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

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'View Clients',
                Icons.people_outline,
                AppColors.info,
                () {
                  setState(() => _currentIndex = 1);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Dashboard',
                Icons.analytics_outlined,
                AppColors.success,
                () {
                  setState(() => _currentIndex = 2);
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
                'Messages',
                Icons.chat_bubble_outline,
                AppColors.accent,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatListScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Schedule',
                Icons.calendar_today_outlined,
                AppColors.warning,
                () {
                  // TODO: Navigate to schedule
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
              child: Icon(icon, color: color, size: 24),
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

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.timeline,
            size: 64,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 16),
          Text(
            'No recent activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your client activities will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
