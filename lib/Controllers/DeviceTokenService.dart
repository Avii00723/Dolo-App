import 'dart:io';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../Constants/ApiConstants.dart';
import 'AuthService.dart';

class DeviceTokenService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _isListenersSet = false;
  
  // Stream to notify app of new foreground messages
  static final StreamController<RemoteMessage> _notificationStreamController = StreamController<RemoteMessage>.broadcast();
  static Stream<RemoteMessage> get onNotificationReceived => _notificationStreamController.stream;

  /// Initialize FCM and save device token
  static Future<void> initialize() async {
    try {
      // Request notification permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('🔔 Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Always try to get and save token when initialize is called (on app start or login)
        await saveCurrentToken();

        // Set up listeners only once to avoid duplicate notifications and token refresh calls
        if (!_isListenersSet) {
          // Listen for token refresh
          _messaging.onTokenRefresh.listen((newToken) {
            print('🔄 FCM Token refreshed: $newToken');
            _saveTokenToServer(newToken);
          });

          // Listen for foreground messages
          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
            print('📩 Foreground message received: ${message.notification?.title}');
            _notificationStreamController.add(message);
          });

          // Handle notification clicks when app is in background
          FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
            print('🖱️ Notification clicked from background: ${message.data}');
          });
          
          _isListenersSet = true;
          print('✅ FCM listeners initialized');
        }
        
      } else {
        print('⚠️ Notification permissions denied');
      }
    } catch (e) {
      print('❌ Error initializing FCM: $e');
    }
  }

  /// Get FCM token and save to server
  static Future<bool> saveCurrentToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        print('📱 Current FCM Token: $token');
        return await _saveTokenToServer(token);
      } else {
        print('⚠️ Failed to get FCM token');
        return false;
      }
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return false;
    }
  }

  /// Save device token to server
  static Future<bool> _saveTokenToServer(String fcmToken) async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) {
        print('⚠️ Cannot save device token: No userId found in secure storage');
        return false;
      }

      final platform = Platform.isAndroid ? 'android' : 'ios';
      
      print('📤 Attempting to save device token for userId: $userId');
      print('📝 Token: $fcmToken');

      final response = await http.post(
        Uri.parse(ApiConstants.saveDeviceToken),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'fcmToken': fcmToken,
          'platform': platform,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Device token saved successfully for user $userId');
        return true;
      } else {
        final errorBody = jsonDecode(response.body);
        print('❌ Failed to save device token: ${errorBody['error'] ?? response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error saving device token: $e');
      return false;
    }
  }

  static Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      print('🗑️ FCM token deleted');
    } catch (e) {
      print('❌ Error deleting FCM token: $e');
    }
  }
}
