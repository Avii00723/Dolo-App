import 'dart:async';
import 'package:flutter/material.dart';
import '../Controllers/NotificationService.dart';
import '../Models/NotificationModel.dart';
import '../Controllers/AuthService.dart';
import '../Controllers/OrderTrackingService.dart';
import '../Controllers/DeviceTokenService.dart';
import '../Controllers/SocketService.dart';
import 'Inbox Section/indoxscreen.dart';
import 'Inbox Section/ChatScreen.dart';
import 'orderSection/OrderTrackingScreen.dart';
import 'orderSection/RatingFeedbackDialog.dart';
import 'orderSection/YourOrders.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  final OrderTrackingService _orderTrackingService = OrderTrackingService();
  final SocketService _socketService = SocketService();
  StreamSubscription? _fcmSubscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    // Not removing socket listener here to avoid interfering with other screens, 
    // but typically you'd want a dedicated event or a scoped listener.
    super.dispose();
  }

  void _setupRealtimeListeners() {
    // 1. Listen for FCM foreground notifications
    _fcmSubscription = DeviceTokenService.onNotificationReceived.listen((message) {
      debugPrint('🔔 NotificationsScreen: FCM message received, refreshing...');
      _loadNotifications(silent: true);
    });

    // 2. Listen for Socket.io messages (which often correspond to notifications)
    try {
      if (_socketService.isConnected) {
        _socketService.onReceiveMessage((data) {
          debugPrint('🔌 NotificationsScreen: Socket message received, refreshing...');
          _loadNotifications(silent: true);
        });
      }
    } catch (e) {
      debugPrint('❌ NotificationsScreen: Error setting up socket listener: $e');
    }
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!mounted) return;

    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final result = await NotificationService.getNotifications();

      if (mounted && result['success'] == true) {
        final List<NotificationModel> notifications = result['notifications'];
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ NotificationsScreen: Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleNotificationNavigation(NotificationModel notification) async {
    final context = this.context;
    final data = notification.data ?? const <String, dynamic>{};
    
    switch (notification.type) {
      case 'NEW_MESSAGE':
        final chatId = _readString(data, const ['chat_id', 'chatId']);
        final orderId = _readOrderId(data);

        if (chatId != null && orderId != null) {
          // Get sender info if available
          final senderData =
              _readMap(data, const ['sender', 'actor', 'from_user']);
          final otherUserName = _readString(
            senderData ?? data,
            const ['name', 'sender_name', 'other_user_name', 'actor_name'],
          );
          final otherUserId = _readString(
            senderData ?? data,
            const [
              'user_id',
              'id',
              'sender_id',
              'other_user_id',
              'actor_user_id',
            ],
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatId,
                orderId: orderId,
                otherUserName: otherUserName,
                otherUserId: otherUserId,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const InboxScreen(initialTab: 0),
            ),
          );
        }
        break;

      case 'TRIP_REQUEST_SENT':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const InboxScreen(initialTab: 1),
          ),
        );
        break;

      case 'ORDER_TRACKING':
        await _openOrderCardScreen(notification);
        break;

      case 'ARRIVED_OTP_REQUIRED':
        await _openTrackingScreen(notification);
        break;

      case 'TRIP_REQUEST_ACCEPTED':
        _openOrdersScreen(1, focusOrderId: _readOrderId(data));
        break;

      case 'RATE_FEEDBACK':
        await _openRatingDialog(notification);
        break;

      case 'ACCOUNT_WARNING':
        _showWarningDialog(notification.title, notification.body);
        break;

      default:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const InboxScreen(initialTab: 0),
          ),
        );
    }
  }

  Future<void> _openOrderCardScreen(NotificationModel notification) async {
    final payloadTab = _ordersTabFromNotification(notification);
    final data = notification.data ?? const <String, dynamic>{};
    final orderId = _readOrderId(data);

    if (payloadTab != null) {
      _openOrdersScreen(payloadTab, focusOrderId: orderId);
      return;
    }

    if (orderId == null) {
      _openOrdersScreen(0);
      return;
    }

    var loadingDialogOpen = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    loadingDialogOpen = true;

    try {
      final orderDetails = await _orderTrackingService.getOrderDetails(orderId);
      final currentUserId = await AuthService.getUserId();

      if (mounted && loadingDialogOpen) {
        Navigator.pop(context);
        loadingDialogOpen = false;
      }

      if (!mounted) return;
      _openOrdersScreen(
        _ordersTabFromOrderDetails(orderDetails, currentUserId) ?? 0,
        focusOrderId: orderId,
      );
    } catch (e) {
      if (mounted && loadingDialogOpen) Navigator.pop(context);
      debugPrint('Error resolving order card tab: $e');
      if (mounted) _openOrdersScreen(0);
    }
  }

  Future<void> _openTrackingScreen(NotificationModel notification) async {
    final data = notification.data ?? const <String, dynamic>{};
    final orderId = _readOrderId(data);

    if (orderId == null) {
      _openOrdersScreen(
        _ordersTabFromNotification(notification) ?? 0,
      );
      return;
    }

    var loadingDialogOpen = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    loadingDialogOpen = true;

    try {
      final orderDetails = await _orderTrackingService.getOrderDetails(orderId);
      if (mounted && loadingDialogOpen) {
        Navigator.pop(context);
        loadingDialogOpen = false;
      }

      if (orderDetails == null) {
        if (mounted) {
          _openOrdersScreen(
            _ordersTabFromNotification(notification) ?? 0,
          );
        }
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTrackingScreen(
            orderId: orderId,
            orderData: orderDetails,
            isTraveller: _isTravellerNotification(notification),
          ),
        ),
      );
    } catch (e) {
      if (mounted && loadingDialogOpen) Navigator.pop(context);
      debugPrint('Error navigating to tracking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open order tracking')),
        );
      }
    }
  }

  Future<void> _openRatingDialog(NotificationModel notification) async {
    final data = notification.data ?? const <String, dynamic>{};
    final orderId = _readOrderId(data);

    if (orderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to find order for rating')),
      );
      return;
    }

    Map<String, dynamic>? orderDetails;
    try {
      orderDetails = await _orderTrackingService.getOrderDetails(orderId);
    } catch (e) {
      debugPrint('Unable to load order details for rating: $e');
    }

    final counterpart = _readMap(data, const [
      'sender',
      'traveller',
      'traveler',
      'delivery_person',
      'rated_user',
      'actor',
    ]);
    final displayName = _readString(counterpart ?? data, const [
          'name',
          'display_name',
          'traveller_name',
          'traveler_name',
          'sender_name',
          'delivery_person_name',
          'rated_user_name',
        ]) ??
        (notification.title.trim().isNotEmpty ? notification.title : 'User');
    final travellerId = _readString(counterpart ?? data, const [
      'traveller_id',
      'traveler_id',
      'traveller_hashed_id',
      'traveler_hashed_id',
      'delivery_person_id',
      'user_id',
      'id',
      'rated_user_id',
    ]);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => RatingFeedbackDialog(
        orderId: orderId,
        displayName: displayName,
        isTraveller: _isTravellerNotification(notification),
        travellerId: travellerId,
        orderDetails: orderDetails,
        onSubmitted: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
      ),
    );
  }

  void _openOrdersScreen(int initialTabIndex, {String? focusOrderId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YourOrdersPage(
          initialTabIndex: initialTabIndex,
          focusOrderId: focusOrderId,
        ),
      ),
    );
  }

  int? _ordersTabFromNotification(NotificationModel notification) {
    final data = notification.data ?? const <String, dynamic>{};
    final explicitTab = int.tryParse(
      _readString(
            data,
            const ['target_tab', 'initial_tab', 'orders_tab', 'tab'],
          ) ??
          '',
    );
    if (explicitTab != null) return explicitTab.clamp(0, 1).toInt();

    final explicitTraveller = data['is_traveller'] ??
        data['is_traveler'] ??
        data['isTraveller'] ??
        data['isTraveler'];
    if (explicitTraveller is bool) return explicitTraveller ? 1 : 0;
    if (explicitTraveller != null) {
      final value = explicitTraveller.toString().toLowerCase();
      if (value == 'true' || value == '1') return 1;
      if (value == 'false' || value == '0') return 0;
    }

    final role = _readString(data, const [
      'role',
      'my_role',
      'user_role',
      'current_user_role',
      'recipient_role',
      'notification_for',
      'order_type',
    ])?.toLowerCase();
    if (role != null) {
      if (role.contains('traveller') ||
          role.contains('traveler') ||
          role.contains('trip') ||
          role.contains('receive')) {
        return 1;
      }
      if (role.contains('sender') ||
          role.contains('creator') ||
          role.contains('send') ||
          role.contains('order')) {
        return 0;
      }
    }

    final order = _readMap(data, const ['order', 'order_details']);
    return _ordersTabFromOrderDetails(order ?? data, null);
  }

  int? _ordersTabFromOrderDetails(
    Map<String, dynamic>? orderDetails,
    String? currentUserId,
  ) {
    if (orderDetails == null) return null;

    final order =
        _readMap(orderDetails, const ['order', 'order_details']) ?? orderDetails;
    final role = _readString(order, const [
      'my_role',
      'role',
      'user_role',
      'current_user_role',
      'order_type',
    ])?.toLowerCase();
    if (role != null) {
      if (role.contains('traveller') ||
          role.contains('traveler') ||
          role.contains('trip') ||
          role.contains('receive')) {
        return 1;
      }
      if (role.contains('sender') ||
          role.contains('creator') ||
          role.contains('owner') ||
          role.contains('send')) {
        return 0;
      }
    }

    if (currentUserId == null || currentUserId.isEmpty) return null;

    final travellerId = _readString(order, const [
          'traveller_id',
          'traveler_id',
          'traveller_hashed_id',
          'traveler_hashed_id',
          'matched_traveller_id',
          'matched_traveler_id',
          'accepted_traveller_id',
          'accepted_traveler_id',
          'delivery_person_id',
          'delivery_person_hashed_id',
        ]) ??
        _readString(orderDetails, const [
          'traveller_id',
          'traveler_id',
          'traveller_hashed_id',
          'traveler_hashed_id',
          'matched_traveller_id',
          'matched_traveler_id',
          'accepted_traveller_id',
          'accepted_traveler_id',
          'delivery_person_id',
          'delivery_person_hashed_id',
        ]);
    if (_sameId(travellerId, currentUserId)) return 1;

    final senderId = _readString(order, const [
          'user_id',
          'user_hashed_id',
          'sender_id',
          'sender_hashed_id',
          'owner_id',
          'owner_hashed_id',
          'order_creator_id',
          'order_creator_hashed_id',
          'creator_id',
          'creator_hashed_id',
        ]) ??
        _readString(orderDetails, const [
          'user_id',
          'user_hashed_id',
          'sender_id',
          'sender_hashed_id',
          'owner_id',
          'owner_hashed_id',
          'order_creator_id',
          'order_creator_hashed_id',
          'creator_id',
          'creator_hashed_id',
        ]);
    if (_sameId(senderId, currentUserId)) return 0;

    return null;
  }

  bool _sameId(String? left, String right) {
    if (left == null || left.isEmpty) return false;
    return left.trim().toLowerCase() == right.trim().toLowerCase();
  }

  bool _isTravellerNotification(NotificationModel notification) {
    final data = notification.data ?? const <String, dynamic>{};
    final explicit = data['is_traveller'] ??
        data['is_traveler'] ??
        data['isTraveller'] ??
        data['isTraveler'];
    if (explicit is bool) return explicit;
    if (explicit != null) {
      final value = explicit.toString().toLowerCase();
      if (value == 'true' || value == '1') return true;
      if (value == 'false' || value == '0') return false;
    }

    final role = _readString(
      data,
      const ['role', 'user_role', 'rater_role', 'order_type'],
    )?.toLowerCase();
    if (role != null) {
      if (role.contains('traveller') ||
          role.contains('traveler') ||
          role.contains('receive')) {
        return true;
      }
      if (role.contains('sender') ||
          role.contains('creator') ||
          role.contains('send')) {
        return false;
      }
    }

    if (notification.type == 'ARRIVED_OTP_REQUIRED') {
      final text = '${notification.title} ${notification.body}'.toLowerCase();
      return !text.contains('show otp') && !text.contains('view otp');
    }

    return false;
  }

  String? _readOrderId(Map<String, dynamic> data) {
    return _readString(data, const [
          'order_id',
          'orderId',
          'order_hashed_id',
          'orderHashedId',
          'order_hash',
        ]) ??
        _readString(_readMap(data, const ['order', 'order_details']), const [
          'id',
          'hashed_id',
          'order_id',
          'orderId',
        ]);
  }

  Map<String, dynamic>? _readMap(
    Map<String, dynamic>? source,
    List<String> keys,
  ) {
    if (source == null) return null;
    for (final key in keys) {
      final value = source[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  String? _readString(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return null;
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return null;
  }

  void _showWarningDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'TRIP_REQUEST_ACCEPTED':
        return Icons.check_circle_outline;
      case 'TRIP_REQUEST_SENT':
        return Icons.send_outlined;
      case 'NEW_MESSAGE':
        return Icons.message_outlined;
      case 'ORDER_TRACKING':
        return Icons.local_shipping_outlined;
      case 'ARRIVED_OTP_REQUIRED':
        return Icons.vpn_key_outlined;
      case 'RATE_FEEDBACK':
        return Icons.star_outline;
      case 'ACCOUNT_WARNING':
        return Icons.warning_amber_outlined;
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
      case 'ORDER_TRACKING':
        return Colors.purple;
      case 'ARRIVED_OTP_REQUIRED':
        return Colors.amber;
      case 'RATE_FEEDBACK':
        return Colors.pink;
      case 'ACCOUNT_WARNING':
        return Colors.red;
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).cardColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => _loadNotifications(),
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25),
              ),
              const SizedBox(height: 24),
              Text(
                'No notifications yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You will be notified about trip requests and messages',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: () => _loadNotifications(),
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
                  setState(() {
                    _notifications[index] = NotificationModel(
                      id: notification.id,
                      hashedId: notification.hashedId,
                      userId: notification.userId,
                      actorUserId: notification.actorUserId,
                      type: notification.type,
                      title: notification.title,
                      body: notification.body,
                      data: notification.data,
                      isRead: true,
                      createdAt: notification.createdAt,
                    );
                  });
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
                      ? Theme.of(context).cardColor
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
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
                            .withValues(alpha: 0.1),
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
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.body,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
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
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDateTime(
                                    notification.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
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
