import 'package:flutter/material.dart';
import '../Controllers/NotificationService.dart';
import '../screens/NotificationsScreen.dart';

class NotificationBellIcon extends StatefulWidget {
  final VoidCallback? onNotificationHandled;
  final Color? iconColor;

  const NotificationBellIcon({
    Key? key,
    this.onNotificationHandled,
    this.iconColor,
  }) : super(key: key);

  @override
  State<NotificationBellIcon> createState() => _NotificationBellIconState();
}

class _NotificationBellIconState extends State<NotificationBellIcon> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    print('🔧 NotificationBellIcon: initState() called');
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await NotificationService.getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (e) {
      print('❌ Error loading unread count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔧 NotificationBellIcon: build() called - iconColor: ${widget.iconColor}, unreadCount: $_unreadCount');

    return Stack(
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications_outlined,
            color: widget.iconColor,
          ),
          onPressed: () {
            print('═══════════════════════════════════════');
            print('🔔 NOTIFICATION BUTTON CLICKED');
            print('🔔 Widget mounted: $mounted');
            print('🔔 Context mounted: ${context.mounted}');
            print('🔔 Unread count: $_unreadCount');
            print('═══════════════════════════════════════');

            try {
              print('🔔 Attempting to navigate to NotificationsScreen...');

              final result = Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    print('🔔 Building NotificationsScreen...');
                    return const NotificationsScreen();
                  },
                ),
              );

              print('🔔 Navigation initiated successfully');

              result.then((_) {
                print('🔔 Returned from NotificationsScreen');
                _loadUnreadCount(); // Reload count after returning
                if (widget.onNotificationHandled != null) {
                  widget.onNotificationHandled!();
                }
              }).catchError((error) {
                print('❌ Error after navigation: $error');
              });
            } catch (e, stackTrace) {
              print('❌ ERROR DURING NAVIGATION:');
              print('❌ Error: $e');
              print('❌ Stack trace: $stackTrace');
            }
          },
          tooltip: 'Notifications',
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
