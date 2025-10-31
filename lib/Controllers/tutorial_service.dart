import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage app tutorial state for new users
class TutorialService {
  static const String _keyHomeTutorialCompleted = 'home_tutorial_completed';
  static const String _keyInboxTutorialCompleted = 'inbox_tutorial_completed';
  static const String _keyChatTutorialCompleted = 'chat_tutorial_completed';
  static const String _keyOrderTutorialCompleted = 'order_tutorial_completed';
  static const String _keyProfileTutorialCompleted = 'profile_tutorial_completed';
  static const String _keyFirstLaunch = 'is_first_launch';

  /// Check if this is the first time the app is launched
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirst = prefs.getBool(_keyFirstLaunch) ?? true;

    if (isFirst) {
      await prefs.setBool(_keyFirstLaunch, false);
    }

    return isFirst;
  }

  /// Check if home tutorial has been completed
  static Future<bool> isHomeTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHomeTutorialCompleted) ?? false;
  }

  /// Mark home tutorial as completed
  static Future<void> markHomeTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHomeTutorialCompleted, true);
  }

  /// Check if inbox tutorial has been completed
  static Future<bool> isInboxTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyInboxTutorialCompleted) ?? false;
  }

  /// Mark inbox tutorial as completed
  static Future<void> markInboxTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyInboxTutorialCompleted, true);
  }

  /// Check if chat tutorial has been completed
  static Future<bool> isChatTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyChatTutorialCompleted) ?? false;
  }

  /// Mark chat tutorial as completed
  static Future<void> markChatTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyChatTutorialCompleted, true);
  }

  /// Check if order tutorial has been completed
  static Future<bool> isOrderTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOrderTutorialCompleted) ?? false;
  }

  /// Mark order tutorial as completed
  static Future<void> markOrderTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOrderTutorialCompleted, true);
  }

  /// Check if profile tutorial has been completed
  static Future<bool> isProfileTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyProfileTutorialCompleted) ?? false;
  }

  /// Mark profile tutorial as completed
  static Future<void> markProfileTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyProfileTutorialCompleted, true);
  }

  /// Reset all tutorials (useful for testing)
  static Future<void> resetAllTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHomeTutorialCompleted, false);
    await prefs.setBool(_keyInboxTutorialCompleted, false);
    await prefs.setBool(_keyChatTutorialCompleted, false);
    await prefs.setBool(_keyOrderTutorialCompleted, false);
    await prefs.setBool(_keyProfileTutorialCompleted, false);
    await prefs.setBool(_keyFirstLaunch, true);
  }
}
