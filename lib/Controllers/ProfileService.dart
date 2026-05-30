import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../Constants/ApiService.dart';
import '../Constants/ApiConstants.dart';
import '../Models/LoginModel.dart';
import '../Models/TrustScoreModel.dart';
import 'AuthService.dart';

class ProfileService {
  final ApiService _api = ApiService();

  // Get user profile by userId
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _api.get(
        '${ApiConstants.getUserProfile}/$userId',
        parser: (json) {
          if (json == null || json['profile'] == null) return null;
          return UserProfile.fromJson(json['profile']);
        },
      );

      if (response.userNotFound) {
        await AuthService.clearUserSession();
        return null;
      }

      return response.data;
    } catch (e) {
      debugPrint('❌ Error fetching user profile: $e');
      return null;
    }
  }

  Future<TrustScore?> getUserTrustScore(String userId) async {
    try {
      final response = await _api.get(
        '${ApiConstants.getUserTrustScore}/$userId',
        parser: (json) => json == null ? null : TrustScore.fromJson(json),
      );

      if (response.userNotFound) {
        await AuthService.clearUserSession();
      }

      return response.data;
    } catch (e) {
      debugPrint('💥 TrustScore ERROR: $e');
      return null;
    }
  }

  // Update user profile by userId
  Future<bool> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    try {
      final response = await _api.put(
        '${ApiConstants.updateUserProfile}/$userId',
        body: updates,
      );

      if (response.userNotFound) {
        await AuthService.clearUserSession();
      }

      return response.success;
    } catch (e) {
      debugPrint('❌ Error updating user profile: $e');
      return false;
    }
  }

  // Upload profile photo
  Future<Map<String, dynamic>?> uploadProfilePhoto(String userId, String filePath) async {
    try {
      final file = await http.MultipartFile.fromPath('photo', filePath);
      
      final response = await _api.postMultipart<Map<String, dynamic>>(
        ApiConstants.uploadProfilePhoto,
        fields: {'userId': userId},
        files: [file],
      );

      if (response.success) {
        return response.data;
      } else {
        if (response.userNotFound) {
          await AuthService.clearUserSession();
        }
        debugPrint('❌ Failed to upload profile photo: ${response.error}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error uploading profile photo: $e');
      return null;
    }
  }
}
