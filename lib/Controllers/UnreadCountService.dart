import 'package:flutter/foundation.dart';

/// A lightweight global notifier that holds the total unread chat message count.
/// Any widget can listen to [unreadCount] and rebuild automatically when the
/// badge changes — no Provider, no BLoC, no extra dependencies needed.
class UnreadCountService {
  UnreadCountService._();

  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// Called when a foreground FCM message arrives.
  static void increment() {
    unreadCount.value += 1;
  }

  /// Called when the user opens the Inbox tab — clears the badge.
  static void reset() {
    unreadCount.value = 0;
  }

  /// Called after inbox loads — syncs the badge to real API unread counts.
  static void setCount(int count) {
    unreadCount.value = count;
  }
}