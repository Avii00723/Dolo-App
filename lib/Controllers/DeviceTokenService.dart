import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../Constants/ApiConstants.dart';
import 'AuthService.dart';

class DeviceTokenService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize FCM and save device token
  static Future<void> initialize() async {
    try {
      // Request notification permissions (required for iOS)
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
        // Get the FCM token
        await _getAndSaveToken();

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          print('🔄 FCM Token refreshed');
          _saveTokenToServer(newToken);
        });
      } else {
        print('⚠️ Notification permissions denied');
      }
    } catch (e) {
      print('❌ Error initializing FCM: $e');
    }
  }

  /// Get FCM token and save to server
  static Future<void> _getAndSaveToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        print('📱 FCM Token obtained: ${token.substring(0, 20)}...');
        await _saveTokenToServer(token);
      } else {
        print('⚠️ Failed to get FCM token');
      }
    } catch (e) {
      print('❌ Error getting FCM token: $e');
    }
  }

  /// Save device token to server
  static Future<bool> _saveTokenToServer(String fcmToken) async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) {
        print('⚠️ Cannot save device token: User not logged in');
        return false;
      }

      final platform = Platform.isAndroid ? 'android' : 'ios';

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
        print('✅ Device token saved successfully');
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

  /// Manually trigger token save (useful after login)
  static Future<bool> saveCurrentToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        return await _saveTokenToServer(token);
      }
      return false;
    } catch (e) {
      print('❌ Error saving current token: $e');
      return false;
    }
  }

  /// Delete device token (useful for logout)
  static Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      print('🗑️ FCM token deleted');
    } catch (e) {
      print('❌ Error deleting FCM token: $e');
    }
  }
}
