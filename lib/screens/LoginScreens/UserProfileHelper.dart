import 'package:dolo/screens/LoginScreens/signup_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // =========================
  // Public APIs
  // =========================

  // Check if user exists and handle navigation accordingly (robust server read)
  static Future<void> checkUserAndNavigate(BuildContext context) async {
    try {
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        _showErrorAndNavigateToLogin(context, 'User not authenticated');
        return;
      }

      final doc = await _getUserDocByUid(uid);
      if (doc == null || !doc.exists) {
        _showProfileCreationDialog(context);
        return;
      }

      final data = doc.data() ?? {};
      final bool profileCompleted = _asBool(data['profileCompleted']);

      if (profileCompleted) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showProfileCompletionDialog(context);
      }
    } catch (e) {
      _showErrorAndNavigateToLogin(context, 'Error checking user profile: $e');
    }
  }

  // Check profile completion before order/trip creation (robust + KYC gate)
  static Future<bool> checkProfileForAction(BuildContext context, String action) async {
    try {
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first'), backgroundColor: Colors.red),
        );
        return false;
      }

      final doc = await _getUserDocByUid(uid);
      if (doc == null || !doc.exists) {
        _showActionRequiresProfileDialog(context, action, false);
        return false;
      }

      final data = doc.data() ?? {};
      final bool profileCompleted = _asBool(data['profileCompleted']);

      if (!profileCompleted) {
        _showActionRequiresProfileDialog(context, action, false);
        return false;
      }

      // KYC needed only for trip creation
      if (action == 'create_trip') {
        final String kycStatus = (data['kycStatus'] as String?)?.toLowerCase() ?? 'not_required';

        // Only block if KYC is pending (incomplete)
        if (kycStatus == 'pending') {
          _showKycRequiredDialog(context);
          return false;
        }

        // Optional: Recommend KYC for travellers who haven't done it
        final String userType = (data['userType'] as String?)?.toLowerCase() ?? '';
        if (kycStatus == 'not_required' && userType == 'traveller') {
          _showKycRecommendedDialog(context);
          // Still allow trip creation - don't return false
        }
      }

      return true;
    } catch (e, st) {
      debugPrint('checkProfileForAction error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.'), backgroundColor: Colors.red),
      );
      return false;
    }
  }

  // =========================
  // Internal helpers (robust fetch, bool casting)
  // =========================

  /// Force a SERVER read and support both patterns:
  ///   1) users/<uid>
  ///   2) users/<autoId> with a field { uid: <uid> }
  static Future<DocumentSnapshot<Map<String, dynamic>>?> _getUserDocByUid(String uid) async {
    // Try doc with id = uid (server-only to avoid stale cache)
    final byId = await _firestore
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    if (byId.exists) return byId;

    // Fallback: query by field 'uid'
    final query = await _firestore
        .collection('users')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get(const GetOptions(source: Source.server));

    if (query.docs.isNotEmpty) return query.docs.first;
    return null;
  }

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == 'yes' || s == '1';
    }
    return false;
  }

  // =========================
  // UI helpers
  // =========================

  static void _showProfileCreationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Welcome to DOLO!'),
          content: const Text(
            'Please complete your profile to get the best experience and access all features.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: const Text('Skip for now'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToSignup(context, false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001127)),
              child: const Text('Complete Profile', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  static void _showProfileCompletionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Complete Your Profile'),
          content: const Text('Your profile is incomplete. Complete it now to access all features.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToSignup(context, false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001127)),
              child: const Text('Complete Now', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  static void _showActionRequiresProfileDialog(
      BuildContext context, String action, bool isKycRequired) {
    final String actionText = action == 'create_order' ? 'create an order' : 'create a trip';

    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                _navigateToSignup(context, isKycRequired);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001127)),
              child: const Text('Complete Profile', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Updated KYC required dialog - more specific about what's missing
  static void _showKycRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Complete KYC Verification'),
          content: const Text(
            'Your KYC verification is incomplete. Please provide both Aadhaar number and upload your driving license to create trips.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToSignup(context, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001127)),
              child: const Text('Complete KYC', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // New method: Recommend KYC for travellers (optional)
  static void _showKycRecommendedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                _navigateToSignup(context, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001127)),
              child: const Text('Complete KYC', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  static void _navigateToSignup(BuildContext context, bool isKycRequired) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignupScreen(isKycRequired: isKycRequired),
      ),
    ).then((result) {
      if (result == true) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  static void _showErrorAndNavigateToLogin(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
    Navigator.pushReplacementNamed(context, '/login');
  }
}