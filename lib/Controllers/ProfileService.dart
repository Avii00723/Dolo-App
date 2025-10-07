import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Constants/ApiService.dart';
import '../Constants/ApiConstants.dart';
import '../Models/LoginModel.dart';
import 'AuthService.dart';

class ProfileService {
  final ApiService _api = ApiService();

  // Get user profile by userId with error handling
  Future<UserProfile?> getUserProfile(int userId) async {
    try {
      final response = await _api.get(
        '${ApiConstants.getUserProfile}/$userId',
        parser: (json) => UserProfile.fromJson(json['profile']),
      );

      // Check if user doesn't exist (404 or specific error message)
      if (!response.success) {
        // Clear session and return null to trigger logout
        await AuthService.clearUserSession();
        return null;
      }

      return response.data;
    } catch (e) {
      print('❌ Error fetching user profile: $e');
      // If error indicates user doesn't exist, clear session
      if (e.toString().contains('404') ||
          e.toString().contains('user does not exist') ||
          e.toString().contains('not found')) {
        await AuthService.clearUserSession();
      }
      return null;
    }
  }

  // Update user profile by userId
  Future<bool> updateUserProfile(int userId, Map<String, dynamic> updates) async {
    try {
      final response = await _api.put(
        '${ApiConstants.updateUserProfile}/$userId',
        body: updates,
      );

      if (!response.success) {
        // Check if user doesn't exist
        await AuthService.clearUserSession();
        return false;
      }

      return response.success;
    } catch (e) {
      print('❌ Error updating user profile: $e');
      if (e.toString().contains('404') ||
          e.toString().contains('user does not exist')) {
        await AuthService.clearUserSession();
      }
      return false;
    }
  }
}
