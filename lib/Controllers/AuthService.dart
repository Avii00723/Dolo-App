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

  // Save user session after successful login/signup
  static Future<void> saveUserSession({
    required int userId,
    required String phone,
  }) async {
    try {
      await _storage.write(key: _userIdKey, value: userId.toString());
      await _storage.write(key: _phoneKey, value: phone);
      await _storage.write(key: _isLoggedInKey, value: 'true');
      print('✅ User session saved securely: userId=$userId, phone=$phone');
    } catch (e) {
      print('❌ Error saving user session: $e');
      rethrow;
    }
  }

  // Get saved user ID
  static Future<int?> getUserId() async {
    try {
      final userIdString = await _storage.read(key: _userIdKey);
      if (userIdString != null) {
        return int.tryParse(userIdString);
      }
      return null;
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

  // Check if user is logged in
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

      if (userId != null && isLoggedIn) {
        return {
          'userId': userId,
          'phone': phone,
          'isLoggedIn': isLoggedIn,
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
