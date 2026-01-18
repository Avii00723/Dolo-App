import '../Constants/ApiService.dart';
import '../Constants/ApiConstants.dart';
import '../Models/LoginModel.dart';
import '../Models/TrustScoreModel.dart';
import 'AuthService.dart';

class ProfileService {
  final ApiService _api = ApiService();

  // Get user profile by userId with error handling
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _api.get(
        '${ApiConstants.getUserProfile}/$userId',
        parser: (json) => UserProfile.fromJson(json['profile']),
      );

      if (!response.success) {
        await AuthService.clearUserSession();
        return null;
      }

      return response.data;
    } catch (e) {
      print('❌ Error fetching user profile: $e');
      if (e.toString().contains('404') ||
          e.toString().contains('user does not exist') ||
          e.toString().contains('not found')) {
        await AuthService.clearUserSession();
      }
      return null;
    }
  }
  Future<TrustScore?> getUserTrustScore(String userId) async {
    try {
      print('🌐 TrustScore API URL: ${ApiConstants.getUserTrustScore}/$userId');
      final response = await _api.get(
        '${ApiConstants.getUserTrustScore}/$userId',
        parser: (json) => TrustScore.fromJson(json), // Add this parser
      );

      print('📡 TrustScore Response: success=${response.success}, data=${response.data}');

      if (response.success) {
        print('✅ TrustScore fetched: ${response.data}');
        return response.data as TrustScore?;
      }
      print('❌ TrustScore API returned !success');
      return null;
    } catch (e) {
      print('💥 TrustScore ERROR: $e');
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

      if (!response.success) {
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
