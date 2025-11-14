import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/services/auth_service.dart';
import '../../ai/presentation/ai_assistant_screen.dart';
import '../../nutrition/presentation/nutrition_tracking_screen.dart';
import 'trainers_screen.dart';
import 'seeker_settings_screen.dart';

class SeekerDashboardScreen extends StatefulWidget {
  const SeekerDashboardScreen({super.key});

  @override
  State<SeekerDashboardScreen> createState() => _SeekerDashboardScreenState();
}

class _SeekerDashboardScreenState extends State<SeekerDashboardScreen> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHome(),
      const AIAssistantScreen(),
      const NutritionTrackingScreen(),
      const TrainersScreen(),
      _buildProfile(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('GenZFit'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) => setState(() => _currentIndex = idx),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.transparent,
          elevation: 0,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'AI Coach'),
            BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Nutrition'),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Trainers'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildHome() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _authService.getSeekerData(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final name = data?['name'] ?? 'User';
        final goal = data?['fitnessGoal'] ?? 'Get Fit';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, $name! 👋',
                style: AppTextStyles.heading.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                'Goal: $goal',
                style: AppTextStyles.body.copyWith(color: AppColors.accent),
              ),
              const SizedBox(height: 24),

              // AI Coach card
              _buildFeatureCard(
                title: 'AI Fitness Coach',
                description: 'Get personalized workout and meal plans',
                icon: Icons.smart_toy,
                gradient: AppColors.accentGradient,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              const SizedBox(height: 16),

              // Trainers card
              _buildFeatureCard(
                title: 'Find Trainers',
                description: 'Connect with professional trainers',
                icon: Icons.people,
                gradient: AppColors.purpleOrangeGradient,
                onTap: () => setState(() => _currentIndex = 2),
              ),
              const SizedBox(height: 24),

              Text(
                'Quick Stats',
                style: AppTextStyles.subheading.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Weight',
                      '${data?['weight'] ?? 0} kg',
                      Icons.monitor_weight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Height',
                      '${data?['height'] ?? 0} cm',
                      Icons.height,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String description,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.subheading.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPrograms() {
    return Center(
      child: Text('Programs - Coming Soon', style: AppTextStyles.subheading),
    );
  }

  Widget _buildProfile() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _authService.getSeekerData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data;
        final name = data != null && data['name'] != null ? data['name'] as String : 'Your Profile';
        final email = data?['email'] ?? '';
        final age = data?['age']?.toString() ?? 'N/A';
        final weight = data?['weight']?.toString() ?? 'N/A';
        final goal = data?['fitnessGoal'] ?? 'Not set';

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.accent,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'S',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: AppTextStyles.heading.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Quick stats
              Text(
                'Quick Stats',
                style: AppTextStyles.subheading.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Age', age, Icons.cake),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard('Weight', '$weight kg', Icons.monitor_weight),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatCard('Goal', goal, Icons.flag, fullWidth: true),
              
              const SizedBox(height: 32),
              ListTile(
                tileColor: AppColors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.settings, color: AppColors.accent),
                title: const Text('Settings & Edit Profile', style: TextStyle(color: AppColors.text)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SeekerSettingsScreen(),
                    ),
                  ).then((_) => setState(() {})); // Refresh on return
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                tileColor: AppColors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Logout', style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  await _authService.logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/role-selection', (route) => false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {bool fullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mediumGray),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
