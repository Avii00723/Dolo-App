import 'package:flutter/material.dart';
import '../Controllers/NotificationService.dart';
import '../Models/NotificationModel.dart';
import 'Inbox Section/indoxscreen.dart';
import 'Inbox Section/ChatScreen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print('📱 NotificationsScreen: initState called');
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    print('📱 NotificationsScreen: Loading notifications...');

    setState(() {
      _isLoading = true;
    });

    try {
      print('📱 NotificationsScreen: Calling NotificationService.getNotifications()');
      final result = await NotificationService.getNotifications();

      print('📱 NotificationsScreen: API result success: ${result['success']}');
      print('📱 NotificationsScreen: Notifications count: ${result['notifications']?.length ?? 0}');

      if (mounted && result['success'] == true) {
        final List<NotificationModel> notifications = result['notifications'];
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
        print('📱 NotificationsScreen: Notifications loaded successfully');
      } else {
        setState(() {
          _isLoading = false;
        });
        print('📱 NotificationsScreen: No notifications or API failed');
      }
    } catch (e) {
      print('❌ NotificationsScreen: Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleNotificationNavigation(NotificationModel notification) {
    switch (notification.type) {
      case 'TRIP_REQUEST_ACCEPTED':
      case 'TRIP_REQUEST_SENT':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const InboxScreen(initialTab: 1),
          ),
        );
        break;

      case 'NEW_MESSAGE':
        if (notification.data != null &&
            notification.data!['chat_id'] != null &&
            notification.data!['order_id'] != null) {
          final chatId = notification.data!['chat_id'];
          final orderId = notification.data!['order_id'];
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatId,
                orderId: orderId,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const InboxScreen(initialTab: 0),
            ),
          );
        }
        break;

      default:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const InboxScreen(initialTab: 0),
          ),
        );
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'TRIP_REQUEST_ACCEPTED':
        return Icons.check_circle_outline;
      case 'TRIP_REQUEST_SENT':
        return Icons.send_outlined;
      case 'NEW_MESSAGE':
        return Icons.message_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'TRIP_REQUEST_ACCEPTED':
        return Colors.green;
      case 'TRIP_REQUEST_SENT':
        return Colors.blue;
      case 'NEW_MESSAGE':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    print('📱 NotificationsScreen: build() called, isLoading: $_isLoading, notifications count: ${_notifications.length}');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadNotifications,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You will be notified about trip requests and messages',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return InkWell(
                        onTap: () async {
                          // Mark as read
                          if (!notification.isRead) {
                            await NotificationService.markAsRead(
                                notification.hashedId);
                          }
                          // Navigate
                          _handleNotificationNavigation(notification);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: notification.isRead
                                ? Colors.white
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _getNotificationColor(
                                          notification.type)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getNotificationIcon(notification.type),
                                  color:
                                      _getNotificationColor(notification.type),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notification.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: notification.isRead
                                            ? FontWeight.w500
                                            : FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notification.body,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 12,
                                          color: Colors.grey[500],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDateTime(
                                              notification.createdAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (!notification.isRead)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
