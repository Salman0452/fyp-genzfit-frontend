import 'package:flutter/material.dart';
import 'package:genzfit/core/theme/app_theme.dart';
import 'package:genzfit/core/theme/app_colors.dart';
import 'package:genzfit/features/onboarding/role_selection_screen.dart';
import 'package:genzfit/rotes/routes.dart';


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> onboardingData = [
    {
      "image": "assets/images/onboard-img-1.png",
      "title": "Track Your Fitness Journey",
      "subtitle": "Monitor your progress and stay consistent with personalized AI guidance.",
    },
    {
      "image": "assets/images/onboard-img-2.png",
      "title": "AI-Powered Coaching",
      "subtitle": "Your smart trainer adapts to your goals and helps you perform better every day.",
    },
    {
      "image": "assets/images/onboard-img-3.png",
      "title": "Achieve Your Goals",
      "subtitle": "Stay motivated, crush milestones, and build your dream physique with GenZFit.",
    },
  ];

  void _nextPage() {
    if (_currentPage < onboardingData.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.ease,
      );
    } else {
      // TODO: Navigate to Login or Home screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: onboardingData.length,
                  itemBuilder: (context, index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedOpacity(
                            opacity: _currentPage == index ? 1 : 0,
                            duration: const Duration(milliseconds: 600),
                            child: Image.asset(
                              onboardingData[index]['image']!,
                              height: 280,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            onboardingData[index]['title']!,
                            style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                              color: AppColors.text,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            onboardingData[index]['subtitle']!,
                            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Dots Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  onboardingData.length,
                      (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                    height: 8,
                    width: _currentPage == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.accent
                          : AppColors.textMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              // Button
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cta,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: (){
                    if (_currentPage == onboardingData.length - 1) {
                      // ✨ Custom fade transition
                      Navigator.of(context).pushReplacement(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                          const  RoleSelectionScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 700),
                        ),
                      );
                    } else {
                      _nextPage();
                    }
                  },
                  child: Text(
                    _currentPage == onboardingData.length - 1
                        ? "Get Started"
                        : "Next",
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
}
