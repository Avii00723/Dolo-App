import 'package:flutter/material.dart';
import 'package:dolo/screens/home/homepage.dart';
import 'package:dolo/screens/LoginScreens/LoginSignupScreen.dart';
import 'Controllers/AuthService.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DOLO',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF001127)),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        '/home': (context) => const HomePageWithNav(),
        '/login': (context) => const LoginSignupScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Add a small delay to show the loading animation
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if user is logged in using secure storage
      final isLoggedIn = await AuthService.isLoggedIn();
      final userData = await AuthService.getCurrentUser();

      if (isLoggedIn && userData != null) {
        print('✅ User is logged in: userId=${userData['userId']}, phone=${userData['phone']}');
      } else {
        print('ℹ️ No user session found - showing login screen');
      }

      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error checking auth status: $e');
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking auth status
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF001127),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo or icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ If user is logged in, navigate directly to home page
    if (_isLoggedIn) {
      // Use WidgetsBinding to ensure navigation happens after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomePageWithNav(),
          ),
        );
      });
      // Show loading while navigating
      return const Scaffold(
        backgroundColor: Color(0xFF001127),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    // ❌ If user is not logged in, show splash/login screen
    return const SplashScreen();
  }
}
