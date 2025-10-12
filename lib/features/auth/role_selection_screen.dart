import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../widgets/role_card.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientDecoration(context),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                const SizedBox(height: 60),
                
                // Title
                Text(
                  'FitConnect',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Subtitle
                Text(
                  'Choose your role to get started',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                
                const Spacer(),
                
                // Trainer Role Card
                RoleCard(
                  icon: Icons.fitness_center,
                  title: 'Trainer',
                  description: 'Lead workouts and manage clients',
                  gradientColors: AppTheme.cardGradientColors(context),
                  onTap: () {
                    // Navigate to trainer signup
                    Navigator.of(context).pushNamed(AppRoutes.trainerSignup);
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Client Role Card
                RoleCard(
                  icon: Icons.directions_run,
                  title: 'Client',
                  description: 'Find your perfect trainer\nand achieve your fitness goals',
                  gradientColors: AppTheme.cardGradientColors(context),
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.clientSignup);
                  },
                ),
                
                const Spacer(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
