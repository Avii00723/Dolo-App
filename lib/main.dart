import 'package:dolo/screens/LoginScreens/login_page.dart';
import 'package:flutter/material.dart';
import 'package:dolo/screens/home/homepage.dart';
import 'package:dolo/screens/LoginScreens/LoginSignupScreen.dart';
import 'package:dolo/screens/LoginScreens/signup_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'Controllers/AuthService.dart';
import 'Controllers/DeviceTokenService.dart';
import 'firebase_options.dart';
import 'splash_screen.dart';
import 'theme/theme_provider.dart';
import 'theme/app_theme.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('📩 Background message received: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'DOLO',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AuthWrapper(),
      routes: {
        '/home': (context) => const HomePageWithNav(),
        '/login': (context) => const LoginScreen(),
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
        // Initialize FCM and save device token for push notifications
        await DeviceTokenService.initialize();
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo or icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_shipping,
                  size: 60,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              ),
              const SizedBox(height: 16),
              const Text(
                'Loading...',
                style: TextStyle(
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
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
        ),
      );
    }

    // ❌ If user is not logged in, show splash/login screen
    return const SplashScreen();
  }
}
