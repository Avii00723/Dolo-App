import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'ChatScreen.dart';

enum OrderStatus {
  pending,
  priceNegotiated,
  orderConfirmed,
  pickedUp,
  inTransit,
  delivered,
  completed
}

class InboxScreen extends StatelessWidget {
  const InboxScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text("Please sign in to view your messages")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1A2A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Inbox',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(
                Icons.chat_bubble_outline,
                size: 24,
              ),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No conversations yet",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Your accepted trip requests will appear here",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final chats = snapshot.data!.docs;

          // Sort chats by lastMessageTime
          chats.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['lastMessageTime'] as Timestamp?;
            final bTime = bData['lastMessageTime'] as Timestamp?;

            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;

            return bTime.compareTo(aTime);
          });

          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
            itemBuilder: (context, index) {
              final chatData = chats[index].data() as Map<String, dynamic>;
              final chatId = chats[index].id;

              // FIXED: Properly determine other user info
              final participants = List<String>.from(chatData['participants'] ?? []);
              final otherUserId = participants.firstWhere(
                    (id) => id != currentUserId,
                orElse: () => '',
              );

              // Get proper user info based on current user role
              String name = 'Unknown User';
              String? profileImage;
              String userRole = '';

              if (currentUserId == chatData['buyerId']) {
                // Current user is sender/buyer, show traveller info
                name = chatData['travelerName'] ?? 'Traveller';
                userRole = 'Traveller';
                // Fetch traveller's profile image from users collection or use stored data
                profileImage = chatData['travelerImage'] ?? chatData['otherUserImage'];
              } else if (currentUserId == chatData['travelerId']) {
                // Current user is traveller, show sender/buyer info
                name = chatData['buyerName'] ?? 'Sender';
                userRole = 'Sender';
                // Fetch sender's profile image from users collection or use stored data
                profileImage = chatData['buyerImage'] ?? chatData['otherUserImage'];
              }

              final String route = chatData['route'] ?? '';
              final lastMessage = chatData['lastMessage'] ?? '';
              final timestamp = chatData['lastMessageTime'] as Timestamp?;
              final timeStr = timestamp != null
                  ? _formatTime(timestamp.toDate())
                  : '';

              // Get order status - Updated for new enum
              final orderStatusStr = chatData['orderStatus'] ?? 'pending';
              final orderStatus = OrderStatus.values.firstWhere(
                    (e) => e.toString() == orderStatusStr,
                orElse: () => OrderStatus.pending,
              );

              final negotiatedPrice = chatData['negotiatedPrice'] ?? '';
              final deliveryId = chatData['deliveryId'] ?? '';
              final productName = chatData['productName'] ?? '';

              return _buildMessageItem(
                context: context,
                profileImage: profileImage,
                name: name,
                userRole: userRole,
                time: timeStr,
                route: route,
                message: lastMessage,
                productName: productName,
                chatId: chatId,
                orderStatus: orderStatus,
                negotiatedPrice: negotiatedPrice,
                deliveryId: deliveryId,
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    if (now.difference(dateTime).inDays == 0) {
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return "${hour == 0 ? 12 : hour}:${dateTime.minute.toString().padLeft(2, '0')} $period";
    } else if (now.difference(dateTime).inDays == 1) {
      return "Yesterday";
    } else {
      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    }
  }

  String _getOrderStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'New Chat';
      case OrderStatus.priceNegotiated:
        return 'Price Agreed';
      case OrderStatus.orderConfirmed:
        return 'Order Confirmed';
      case OrderStatus.pickedUp:
        return 'Picked Up';
      case OrderStatus.inTransit:
        return 'In Transit';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.completed:
        return 'Completed';
    }
  }

  Color _getOrderStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.blue;
      case OrderStatus.priceNegotiated:
        return Colors.green;
      case OrderStatus.orderConfirmed:
        return Colors.blue;
      case OrderStatus.pickedUp:
        return Colors.orange;
      case OrderStatus.inTransit:
        return Colors.purple;
      case OrderStatus.delivered:
        return Colors.teal;
      case OrderStatus.completed:
        return Colors.green;
    }
  }

  Widget _buildOrderStatusChip(OrderStatus status, String negotiatedPrice, String deliveryId) {
    String displayText = _getOrderStatusText(status);

    if (status == OrderStatus.priceNegotiated && negotiatedPrice.isNotEmpty) {
      displayText += ' • $negotiatedPrice';
    } else if ((status == OrderStatus.orderConfirmed ||
        status == OrderStatus.pickedUp ||
        status == OrderStatus.inTransit ||
        status == OrderStatus.delivered ||
        status == OrderStatus.completed) && deliveryId.isNotEmpty) {
      displayText += ' • #${deliveryId.substring(deliveryId.length - 6)}';
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getOrderStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getOrderStatusColor(status),
          width: 1,
        ),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 11,
          color: _getOrderStatusColor(status),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMessageItem({
    required BuildContext context,
    String? profileImage,
    required String name,
    required String userRole,
    required String time,
    required String route,
    required String message,
    required String productName,
    required String chatId,
    required OrderStatus orderStatus,
    required String negotiatedPrice,
    required String deliveryId,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(chatId: chatId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: (profileImage != null && profileImage.isNotEmpty)
                      ? NetworkImage(profileImage)
                      : null,
                  backgroundColor: Colors.blue[100],
                  child: (profileImage == null || profileImage.isEmpty)
                      ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                  )
                      : null,
                ),
                // Order status indicator
                if (orderStatus != OrderStatus.pending)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _getOrderStatusColor(orderStatus),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        _getOrderStatusIcon(orderStatus),
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              userRole,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),

                  // Route information
                  if (route.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              route,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Product name
                  if (productName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.inventory_2, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            productName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 6),

                  // Last message
                  Text(
                    message.isNotEmpty ? message : 'No messages yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: message.isNotEmpty ? Colors.black87 : Colors.grey[500],
                      fontStyle: message.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Order status chip
                  _buildOrderStatusChip(orderStatus, negotiatedPrice, deliveryId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getOrderStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.chat;
      case OrderStatus.priceNegotiated:
        return Icons.handshake;
      case OrderStatus.orderConfirmed:
        return Icons.check_circle;
      case OrderStatus.pickedUp:
        return Icons.inventory;
      case OrderStatus.inTransit:
        return Icons.local_shipping;
      case OrderStatus.delivered:
        return Icons.done_all;
      case OrderStatus.completed:
        return Icons.star;
    }
  }
}
