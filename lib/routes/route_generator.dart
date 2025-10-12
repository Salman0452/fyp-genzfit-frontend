import 'package:flutter/material.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/auth/role_selection_screen.dart';
import '../features/auth/trainer/trainer_signup_screen.dart';
import '../features/auth/trainer/trainer_login_screen.dart';
import '../features/auth/client/client_signup_screen.dart';
import '../features/auth/client/client_login_screen.dart';
import '../features/dashboard/client/presentation/screens/client_dashboard_screen.dart';
import '../features/dashboard/client/presentation/screens/trainers_list_screen.dart';
import '../features/dashboard/client/presentation/screens/trainer_profile_screen.dart';
import 'app_routes.dart';

/// Centralized route generator for the application
class RouteGenerator {
  // Prevent instantiation
  RouteGenerator._();
  
  /// Generate routes based on route settings
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Get any arguments passed to the route (for future use)
    // final args = settings.arguments;
    
    switch (settings.name) {
      case AppRoutes.splash:
        return _buildRoute(const SplashScreen());
        
      case AppRoutes.welcome:
        return _buildRoute(const WelcomeScreen());
        
      case AppRoutes.roleSelection:
        return _buildRoute(const RoleSelectionScreen());
      
      case AppRoutes.trainerSignup:
        return _buildRoute(const TrainerSignupScreen());
      
      case AppRoutes.trainerLogin:
        return _buildRoute(const TrainerLoginScreen());
      
      case AppRoutes.clientSignup:
        return _buildRoute(const ClientSignupScreen());
      
      case AppRoutes.clientLogin:
        return _buildRoute(const ClientLoginScreen());
      
      case AppRoutes.clientDashboard:
        return _buildRoute(const ClientDashboardScreen());
      
      case AppRoutes.trainersList:
        return _buildRoute(const TrainersListScreen());
      
      case AppRoutes.trainerProfile:
        // Extract trainer data from arguments
        final trainer = settings.arguments as Map<String, dynamic>?;
        if (trainer == null) {
          return _buildRoute(const _ErrorScreen(routeName: 'Trainer data not found'));
        }
        return _buildRoute(TrainerProfileScreen(trainer: trainer));
      
      // TODO: Add more routes here as you build them
      
      default:
        // If route is not found, show error screen
        return _buildRoute(_ErrorScreen(routeName: settings.name ?? 'Unknown'));
    }
  }
  
  /// Build a route with custom page transition
  static Route<dynamic> _buildRoute(Widget widget, {bool fade = true}) {
    if (fade) {
      return PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => widget,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      );
    }
    
    return MaterialPageRoute(builder: (_) => widget);
  }
}

/// Error screen shown when route is not found
class _ErrorScreen extends StatelessWidget {
  final String routeName;
  
  const _ErrorScreen({required this.routeName});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Route not found!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Route: $routeName',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
