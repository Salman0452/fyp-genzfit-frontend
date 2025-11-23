import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/language_provider.dart';
import 'utils/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/client/client_home_screen.dart';
import 'screens/trainer/trainer_home_screen.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyDSBPfkd3Hx4Q8jsb0jgbkJEbR5LBHKQlk',
      appId: '1:1088491642353:android:957691b7dd660419c97850',
      messagingSenderId: '1088491642353',
      projectId: 'genzfit-d36f0',
      storageBucket: 'genzfit-d36f0.firebasestorage.app',
    ),
  );
  
  runApp(const GenZFitApp());
}

class GenZFitApp extends StatelessWidget {
  const GenZFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'GenZFit',
            locale: languageProvider.locale,
            supportedLocales: const [
              Locale('en', ''), // English
              Locale('ur', ''), // Urdu
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: AppConstants.primaryBlack,
              primaryColor: AppConstants.primaryGold,
              colorScheme: const ColorScheme.dark(
                primary: AppConstants.primaryGold,
                secondary: AppConstants.accentGold,
                surface: AppConstants.charcoalGray,
                error: AppConstants.errorRed,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: AppConstants.primaryBlack,
                elevation: 0,
                centerTitle: true,
                titleTextStyle: TextStyle(
                  color: AppConstants.textWhite,
                  fontSize: AppConstants.fontXLarge,
                  fontWeight: FontWeight.bold,
                ),
                iconTheme: IconThemeData(color: AppConstants.textWhite),
              ),
              textTheme: const TextTheme(
                displayLarge: TextStyle(
                  color: AppConstants.textWhite,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                displayMedium: TextStyle(
                  color: AppConstants.textWhite,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                bodyLarge: TextStyle(
                  color: AppConstants.textWhite,
                  fontSize: AppConstants.fontLarge,
                ),
                bodyMedium: TextStyle(
                  color: AppConstants.textGray,
                  fontSize: AppConstants.fontMedium,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryGold,
                  foregroundColor: AppConstants.primaryBlack,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                ),
              ),
            ),
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/role-selection': (context) => const RoleSelectionScreen(),
              '/login': (context) => const LoginScreen(),
              '/forgot-password': (context) => const ForgotPasswordScreen(),
              '/client-home': (context) => const ClientHomeScreen(),
              '/trainer-home': (context) => const TrainerHomeScreen(),
              '/admin-dashboard': (context) => const PlaceholderScreen(title: 'Admin Dashboard'),
            },
          );
        },
      ),
    );
  }
}

// Temporary placeholder screen for routes not yet implemented
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent back button from going to auth screens
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          automaticallyImplyLeading: false, // Remove back button
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await context.read<AuthProvider>().signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.construction,
                size: 64,
                color: AppConstants.primaryGold,
              ),
              const SizedBox(height: AppConstants.paddingLarge),
              Text(
                title,
                style: const TextStyle(
                  color: AppConstants.textWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              const Text(
                'Coming soon...',
                style: TextStyle(
                  color: AppConstants.textGray,
                  fontSize: AppConstants.fontLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

