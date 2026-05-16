import 'package:flutter/material.dart';

import 'PublicProfileSection/publicprofilescreen.dart';


import 'PublicProfileSection/publicprofilescreen.dart';

/// Kept for backward compatibility with ChatScreen navigation.
/// Now it loads real public profile data from backend.
class UserProfileScreen extends StatelessWidget {
  final String userId;
  final String userName;
  final String? profileUrl;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.profileUrl,
  });

  @override
  Widget build(BuildContext context) {
    return PublicProfileScreen(
      targetUserHashedId: userId,
    );
  }
}

