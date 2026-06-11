import 'package:dolo/screens/LoginScreens/login_page.dart';
import 'package:flutter/material.dart';
import 'package:dolo/screens/home/homepage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'Controllers/AuthService.dart';
import 'Controllers/DeviceTokenService.dart';
import 'Controllers/UnreadCountService.dart';
import 'Constants/ApiService.dart';
import 'firebase_options.dart';
import 'screens/BackendDownScreen.dart';
import 'splash_screen.dart';
import 'theme/theme_provider.dart';
import 'theme/app_theme.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ── Local notifications plugin (singleton) ──────────────────────────────────
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ── Android notification channel for chat messages ───────────────────────────
const AndroidNotificationChannel _chatChannel = AndroidNotificationChannel(
  'chat_messages', // id — must match what your server sends
  'Chat Messages', // name shown in system settings
  description: 'Incoming chat messages from other users',
  importance: Importance.high,
);

// ── Background message handler (must be a top-level function) ────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📩 Background message received: ${message.messageId}');
  // Background messages are shown automatically by FCM on Android/iOS.
  // No UI update needed here — the app is not running in the foreground.
}

// ── Initialise local notifications ───────────────────────────────────────────
Future<void> _initLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false, // already requested via FirebaseMessaging
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  const initSettings =
      InitializationSettings(android: androidSettings, iOS: iosSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // Create the Android channel once so heads-up banners work on Android 8+.
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_chatChannel);
}

// ── Wire foreground FCM listener ─────────────────────────────────────────────
void _initForegroundMessageListener() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint(
        '📩 Foreground message received: ${message.notification?.title}');

    // 1. Bump the inbox badge so the bottom-nav tab shows a red dot.
    UnreadCountService.increment();

    // 2. Show a heads-up local notification (FCM suppresses its own UI when
    //    the app is in the foreground on Android).
    final notification = message.notification;
    if (notification != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _chatChannel.id,
            _chatChannel.name,
            channelDescription: _chatChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    }
  });
}

// ── main ─────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Background handler must be registered before runApp.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Local notifications (heads-up banners while app is open).
  await _initLocalNotifications();

  // Foreground FCM listener — updates badge + shows local notification.
  _initForegroundMessageListener();

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

// ── App ───────────────────────────────────────────────────────────────────────
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

// ── Auth wrapper ──────────────────────────────────────────────────────────────
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _isBackendDown = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final isBackendReachable = await ApiService().isBackendReachable();
      if (!isBackendReachable) {
        if (mounted) {
          setState(() {
            _isBackendDown = true;
            _isLoading = false;
          });
        }
        return;
      }

      final isLoggedIn = await AuthService.isLoggedIn();
      final userData = await AuthService.getCurrentUser();

      if (isLoggedIn && userData != null) {
        debugPrint(
            '✅ User is logged in: userId=${userData['userId']}, phone=${userData['phone']}');
        await DeviceTokenService.initialize();
      } else {
        debugPrint('ℹ️ No user session found - showing login screen');
      }

      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
          _isBackendDown = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error checking auth status: $e');
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor),
              ),
              const SizedBox(height: 16),
              const Text('Loading...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    if (_isBackendDown) {
      return BackendDownScreen(
        canGoBack: false,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _isBackendDown = false;
          });
          _checkAuthStatus();
        },
      );
    }

    if (_isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePageWithNav()),
        );
      });
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            valueColor:
                AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
        ),
      );
    }

    return const SplashScreen();
  }
}
