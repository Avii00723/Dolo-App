import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // Create storage instance with secure options
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const String _userIdKey = 'user_id';
  static const String _phoneKey = 'user_phone';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _isProfileCompletedKey = 'is_profile_completed';

  // Save user session after successful login/signup
  static Future<void> saveUserSession({
    required String userId,
    required String phone,
    bool isProfileCompleted = false,
  }) async {
    try {
      await _storage.write(key: _userIdKey, value: userId);
      await _storage.write(key: _phoneKey, value: phone);
      await _storage.write(key: _isLoggedInKey, value: 'true');
      await _storage.write(key: _isProfileCompletedKey, value: isProfileCompleted.toString());
      print('✅ User session saved securely: userId=$userId, phone=$phone, isProfileCompleted=$isProfileCompleted');
    } catch (e) {
      print('❌ Error saving user session: $e');
      rethrow;
    }
  }

  // Set profile completion status
  static Future<void> setProfileCompleted(bool completed) async {
    try {
      await _storage.write(key: _isProfileCompletedKey, value: completed.toString());
      print('✅ Profile completion status updated: $completed');
    } catch (e) {
      print('❌ Error setting profile completion: $e');
    }
  }

  // Check if profile is completed
  static Future<bool> isProfileCompleted() async {
    try {
      final value = await _storage.read(key: _isProfileCompletedKey);
      return value == 'true';
    } catch (e) {
      print('❌ Error checking profile completion: $e');
      return false;
    }
  }

  // Get saved user ID
  static Future<String?> getUserId() async {
    try {
      final userIdString = await _storage.read(key: _userIdKey);
      return userIdString;
    } catch (e) {
      print('❌ Error getting user ID: $e');
      return null;
    }
  }

  // Get saved phone number
  static Future<String?> getPhone() async {
    try {
      return await _storage.read(key: _phoneKey);
    } catch (e) {
      print('❌ Error getting phone: $e');
      return null;
    }
  }

  // Check if user is logged in (OTP verified)
  static Future<bool> isLoggedIn() async {
    try {
      final isLoggedInString = await _storage.read(key: _isLoggedInKey);
      final userId = await getUserId();
      return isLoggedInString == 'true' && userId != null;
    } catch (e) {
      print('❌ Error checking login status: $e');
      return false;
    }
  }

  // Clear user session (logout)
  static Future<void> clearUserSession() async {
    try {
      await _storage.delete(key: _userIdKey);
      await _storage.delete(key: _phoneKey);
      await _storage.delete(key: _isLoggedInKey);
      await _storage.delete(key: _isProfileCompletedKey);
      print('✅ User session cleared securely');
    } catch (e) {
      print('❌ Error clearing user session: $e');
      rethrow;
    }
  }

  // Clear all stored data (complete logout)
  static Future<void> clearAllData() async {
    try {
      await _storage.deleteAll();
      print('✅ All secure data cleared');
    } catch (e) {
      print('❌ Error clearing all data: $e');
      rethrow;
    }
  }

  // Get current user data
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final userId = await getUserId();
      final phone = await getPhone();
      final isLoggedIn = await AuthService.isLoggedIn();
      final isProfileCompleted = await AuthService.isProfileCompleted();

      if (userId != null && isLoggedIn) {
        return {
          'userId': userId,
          'phone': phone,
          'isLoggedIn': isLoggedIn,
          'isProfileCompleted': isProfileCompleted,
        };
      }
      return null;
    } catch (e) {
      print('❌ Error getting current user: $e');
      return null;
    }
  }

  // Update user phone (if needed)
  static Future<void> updatePhone(String phone) async {
    try {
      await _storage.write(key: _phoneKey, value: phone);
      print('✅ Phone updated securely');
    } catch (e) {
      print('❌ Error updating phone: $e');
      rethrow;
    }
  }
}
