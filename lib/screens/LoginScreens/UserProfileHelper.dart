import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import
import '../../Controllers/LoginService.dart';
import 'package:dolo/screens/LoginScreens/signup_page.dart';
import 'package:dolo/screens/LoginScreens/LoginSignupScreen.dart';
import 'package:dolo/screens/home/homepage.dart';
import '../../Models/LoginModel.dart';

class UserProfileHelper {
  static final LoginService _loginService = LoginService();

  // Check if user exists and handle navigation accordingly via API
  static Future<void> checkUserAndNavigate(
      BuildContext context, {
        required String userId,
        String? kycStatus,
        bool? showProfilePrompt,
      }) async {
    try {
      if (userId.isEmpty) {
        _showErrorAndNavigateToLogin(context, 'User not authenticated');
        return;
      }

      // Save userId to SharedPreferences for later use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);

      // Use the flags from login/verify API if provided
      if (showProfilePrompt == true) {
        _showProfileCreationDialog(context, userId);
        return;
      }

      // If showProfilePrompt is false and kycStatus is provided,
      // the backend is indicating profile is complete - skip profile fetch
      if (showProfilePrompt == false && kycStatus != null) {
        debugPrint('✅ Profile already complete (from verify-otp), navigating to home');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePageWithNav()),
        );
        return;
      }

      // Fetch user profile from API to get complete information
      final profile = await _loginService.getUserProfile(userId);

      if (profile == null) {
        _showProfileCreationDialog(context, userId);
        return;
      }

      // Check if basic profile fields are complete
      final isProfileComplete = _isProfileComplete(profile);

      if (!isProfileComplete) {
        _showProfileCompletionDialog(context, userId);
        return;
      }

      // Profile is complete, check KYC status if needed
      final userKycStatus = kycStatus ?? profile.kycStatus;

      if (userKycStatus.toLowerCase() == 'pending') {
        // KYC is pending, but user can still access the app
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePageWithNav()),
        );
      } else if (userKycStatus.toLowerCase() == 'approved' ||
          userKycStatus.toLowerCase() == 'not_required') {
        // Approved or not required - full access
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePageWithNav()),
        );
      } else {
        // Any other status, navigate to home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePageWithNav()),
        );
      }
    } catch (e) {
      _showErrorAndNavigateToLogin(context, 'Error checking user profile: $e');
    }
  }

  static Future<bool> checkProfileForAction(
      BuildContext context,
      String action,
      String userId,
      ) async {
    try {
      if (userId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login first'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      final profile = await _loginService.getUserProfile(userId);

      if (profile == null) {
        _showActionRequiresProfileDialog(context, action, false, userId);
        return false;
      }

      // Check if basic profile is complete
      if (!_isProfileComplete(profile)) {
        _showActionRequiresProfileDialog(context, action, false, userId);
        return false;
      }

      // Additional checks for creating trips
      if (action == 'create_trip') {
        final kycStatus = profile.kycStatus.toLowerCase();

        if (kycStatus == 'pending') {
          _showKycPendingDialog(context);
          return false;
        }

        if (kycStatus == 'rejected') {
          _showKycRejectedDialog(context, userId);
          return false;
        }

        // If KYC is not required or approved, show recommendation
        if (kycStatus == 'not_required') {
          _showKycRecommendedDialog(context, userId);
          // Still allow the action to proceed, just show recommendation
        }
      }
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  // Helper method to check if profile is complete
  static bool _isProfileComplete(UserProfile profile) {
    return profile.name.isNotEmpty &&
        profile.email.isNotEmpty &&
        profile.phone.isNotEmpty;
  }

  static void _showProfileCreationDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Welcome to DOLO!'),
          content: const Text(
            'Please complete your profile to get the best experience and access all features.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePageWithNav()),
                );
              },
              child: const Text('Skip for now'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToSignup(context, false, userId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF001127),
              ),
              child: const Text(
                'Complete Profile',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  static void _showProfileCompletionDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Complete Your Profile'),
          content: const Text(
            'Your profile is incomplete. Complete it now to access all features.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePageWithNav()),
                );
              },
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToSignup(context, false, userId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF001127),
              ),
              child: const Text(
                'Complete Now',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  static void _showActionRequiresProfileDialog(
      BuildContext context,
      String action,
      bool isKycRequired,
      String userId,
      ) {
    final actionText = action == 'create_order' ? 'create an order' : 'create a trip';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Profile Required'),
          content: Text('Please complete your profile to $actionText.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToSignup(context, isKycRequired, userId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF001127),
              ),
              child: const Text(
                'Complete Profile',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  static void _showKycPendingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('KYC Verification Pending'),
          content: const Text(
            'Your KYC verification is under review. You can create trips once it\'s approved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  static void _showKycRejectedDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('KYC Verification Required'),
          content: const Text(
            'Your previous KYC verification was not approved. Please complete the KYC process again to create trips.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToSignup(context, true, userId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF001127),
              ),
              child: const Text(
                'Complete KYC',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  static void _showKycRecommendedDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('KYC Recommended'),
          content: const Text(
            'While KYC is not mandatory, completing it helps build trust with package senders and may result in more trip requests.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue Without KYC'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToSignup(context, true, userId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF001127),
              ),
              child: const Text(
                'Complete KYC',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  static void _navigateToSignup(BuildContext context, bool isKycRequired, String userId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SignupScreen(
          isKycRequired: isKycRequired,
          userId: userId, // Pass userId to signup screen
        ),
      ),
    );
  }

  static void _showErrorAndNavigateToLogin(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginSignupScreen()),
      );
    });
  }
}
