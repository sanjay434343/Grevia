import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'pages/onboarding_page.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grevia Focus',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuthStateAndNavigate();
  }

  Future<void> _checkAuthStateAndNavigate() async {
    // Wait for splash screen duration
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;

    try {
      // Check if user was previously logged in
      bool isLoggedIn = await _authService.isUserPreviouslyLoggedIn();
      
      if (isLoggedIn) {
        // Get user data from Firebase
        Map<String, dynamic>? userData = await _authService.getUserDataFromFirestore();
        
        String userName = 'Focus User';
        if (userData != null && userData['profile'] != null && userData['profile']['name'] != null) {
          userName = userData['profile']['name'];
        }
        
        // User is logged in - go to home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(
              userName: userName,
              focusTime: 25,
              treeType: 'Oak',
            ),
          ),
        );
      } else {
        // User not logged in - show onboarding
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
        );
      }
    } catch (e) {
      debugPrint('Error checking auth state: $e');
      // On error, go to onboarding
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade900,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.spa,
              size: 100,
              color: Colors.white,
            ),
            SizedBox(height: 20),
            Text(
              'Grevia Focus',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Turn Focus into Growth',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
