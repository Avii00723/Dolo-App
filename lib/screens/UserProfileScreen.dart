import 'package:flutter/material.dart';
import 'PublicProfileSection/publicprofilescreen.dart';

/// Kept for backward compatibility with ChatScreen navigation.
/// Now it loads real public profile data from backend.
class UserProfileScreen extends StatelessWidget {
  final String userId;
  final String userName;
  final String? profileUrl;
  
  /// Pass orderId when navigating from a chat/order context so the
  /// Report option becomes available.
  final String? orderId;

  /// Whether the order linked to this profile has been accepted.
  final bool isOrderAccepted;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.profileUrl,
    this.orderId,
    this.isOrderAccepted = false,
  });

  @override
  Widget build(BuildContext context) {
    return PublicProfileScreen(
      targetUserHashedId: userId,
      orderId: orderId,
      isOrderAccepted: isOrderAccepted,
    );
  }
}
