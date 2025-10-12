/// Route names for the application
class AppRoutes {
  // Prevent instantiation
  AppRoutes._();
  
  // Auth routes
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String roleSelection = '/role-selection';
  
  // Trainer auth routes
  static const String trainerSignup = '/trainer/signup';
  static const String trainerLogin = '/trainer/login';
  
  // Client auth routes
  static const String clientSignup = '/client/signup';
  static const String clientLogin = '/client/login';
  
  // Dashboard routes
  static const String clientDashboard = '/client/dashboard';
  static const String trainerDashboard = '/trainer/dashboard';
  
  // Trainer discovery routes
  static const String trainersList = '/trainers/list';
  static const String trainerProfile = '/trainers/profile';
  
  // TODO: Add more routes as you build the app
  // static const String home = '/home';
  // static const String profile = '/profile';
}
