import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'package:genzfit/rotes/routes.dart';


class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Text(
                  "Let’s Personalize Your Experience",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  "Choose your role to continue",
                  style: AppTextStyles.subheading
                      .copyWith(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 60),

                // Trainer Card
                _buildRoleCard(
                  role: "Trainer",
                  icon: Icons.fitness_center,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),

                // Seeker Card
                _buildRoleCard(
                  role: "Fitness Seeker",
                  icon: Icons.self_improvement,
                  color: Colors.white,
                ),

                const Spacer(),
                ElevatedButton(
                  onPressed: selectedRole == null
                      ? null
                      : () {
                    // TODO: Navigate to signup/login
                    // Navigator.pushNamed(context, '/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cta,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    "Continue",
                    style: AppTextStyles.subheading
                        .copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = selectedRole == role;
    return GestureDetector(
      onTap: () {
        setState(() => selectedRole = role);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        width: double.infinity,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.white.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(width: 16),
            Text(
              role,
              style: AppTextStyles.subheading
                  .copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
