import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Constants/ApiConstants.dart';
import '../Controllers/AuthService.dart';
import '../Models/NotificationModel.dart';

class NotificationService {
  // Get current user ID from AuthService
  static Future<String?> _getCurrentUserId() async {
    return await AuthService.getUserId();
  }

  // Get all notifications for the current user
  static Future<Map<String, dynamic>> getNotifications() async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
          'notifications': <NotificationModel>[],
        };
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.getNotifications}/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('📬 Get Notifications Response: ${response.statusCode}');
      print('📬 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> notificationsJson = data['notifications'] ?? [];

        final List<NotificationModel> notifications = notificationsJson
            .map((json) => NotificationModel.fromJson(json))
            .toList();

        return {
          'success': true,
          'notifications': notifications,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to load notifications',
          'notifications': <NotificationModel>[],
        };
      }
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      return {
        'success': false,
        'error': e.toString(),
        'notifications': <NotificationModel>[],
      };
    }
  }

  // Get unread notifications count
  static Future<int> getUnreadCount() async {
    try {
      final result = await getNotifications();
      if (result['success'] == true) {
        final List<NotificationModel> notifications = result['notifications'];
        return notifications.where((n) => !n.isRead).length;
      }
      return 0;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  // Mark a notification as read
  static Future<Map<String, dynamic>> markAsRead(String notificationId) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConstants.markNotificationAsRead}/$notificationId/read'),
        headers: {'Content-Type': 'application/json'},
      );

      print('✅ Mark as Read Response: ${response.statusCode}');
      print('✅ Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Notification marked as read',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to mark notification as read',
        };
      }
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
