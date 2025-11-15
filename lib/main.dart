import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';
import 'rotes/routes.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  await Firebase.initializeApp(
    options: const FirebaseOptions(
        apiKey: 'AIzaSyDSBPfkd3Hx4Q8jsb0jgbkJEbR5LBHKQlk',
        appId: '1:1088491642353:android:767ed488706c2fd6c97850',
        messagingSenderId: '1088491642353	',
        projectId: 'genzfit-d36f0'
    )
  );
  runApp(const GenZFitApp());
}

class GenZFitApp extends StatelessWidget {
  const GenZFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GenZFit',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: appRoutes,
    );
  }
}

