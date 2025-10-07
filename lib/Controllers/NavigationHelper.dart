import 'package:flutter/material.dart';
import 'AuthService.dart';
import '../screens/LoginScreens/LoginSignupScreen.dart';

class NavigationHelper {
  // Navigate to login and clear all routes
  static Future<void> navigateToLogin(BuildContext context) async {
    // Clear user session
    await AuthService.clearUserSession();

    // Navigate to login and remove all previous routes
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginSignupScreen(),
        ),
            (Route<dynamic> route) => false,
      );
    }
  }
}
