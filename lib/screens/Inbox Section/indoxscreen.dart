import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'ChatScreen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({Key? key}) : super(key: key);

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: currentUserId.isEmpty
          ? const Center(
        child: Text(
          'Please log in to view messages',
          style: TextStyle(fontSize: 16),
        ),
      )
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUserId)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final chat = snapshot.data!.docs[index];
              return ModernChatCard(
                chat: chat,
                currentUserId: currentUserId,
                onTap: () => _openChat(chat),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start chatting by sending a trip request',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openChat(QueryDocumentSnapshot chat) {
    final data = chat.data() as Map<String, dynamic>;
    final participants = List<String>.from(data['participants'] ?? []);
    final otherUserId = participants.firstWhere(
          (id) => id != currentUserId,
      orElse: () => '',
    );

    if (otherUserId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            otherUserId: otherUserId,
            orderId: data['orderId'],
          ),
        ),
      );
    }
  }
}

class ModernChatCard extends StatelessWidget {
  final QueryDocumentSnapshot chat;
  final String currentUserId;
  final VoidCallback onTap;

  const ModernChatCard({
    Key? key,
    required this.chat,
    required this.currentUserId,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = chat.data() as Map<String, dynamic>;
    final participants = List<String>.from(data['participants'] ?? []);
    final otherUserId = participants.firstWhere(
          (id) => id != currentUserId,
      orElse: () => '',
    );

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchChatData(data, otherUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildLoadingCard();
        }

        final chatData = snapshot.data!;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Profile Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade600],
                        ),
                      ),
                      child: chatData['profileUrl']?.isNotEmpty == true
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Image.network(
                          chatData['profileUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildAvatarFallback(chatData['userName']),
                        ),
                      )
                          : _buildAvatarFallback(chatData['userName']),
                    ),
                    const SizedBox(width: 16),

                    // Chat Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name and Time Row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  chatData['userName'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _formatTime(data['lastMessageTime']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Order Info Chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_shipping,
                                  size: 12,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${chatData['origin']} → ${chatData['destination']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Last Message
                          Text(
                            data['lastMessage'] ?? 'No messages yet',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Order Status and Details
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildStatusChip(chatData['orderStatus']),
                                const SizedBox(width: 8),
                                _buildDetailChip(
                                    Icons.calendar_today, chatData['date']),
                                const SizedBox(width: 8),
                                _buildDetailChip(
                                    Icons.scale, '${chatData['weight']}kg'),
                                if (chatData['expectedPrice'] != null) ...[
                                  const SizedBox(width: 8),
                                  _buildDetailChip(Icons.currency_rupee,
                                      '₹${chatData['expectedPrice']}'),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Unread indicator
                    if (data['unreadCount'] != null && data['unreadCount'] > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade500,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${data['unreadCount']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    // Define specific colors for each status
    Color backgroundColor;
    Color borderColor;
    Color iconColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade200;
        iconColor = Colors.orange.shade700;
        textColor = Colors.orange.shade700;
        icon = Icons.schedule;
        break;
      case 'matched':
        backgroundColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade200;
        iconColor = Colors.blue.shade700;
        textColor = Colors.blue.shade700;
        icon = Icons.handshake;
        break;
      case 'in_transit':
        backgroundColor = Colors.purple.shade50;
        borderColor = Colors.purple.shade200;
        iconColor = Colors.purple.shade700;
        textColor = Colors.purple.shade700;
        icon = Icons.local_shipping;
        break;
      case 'arrived':
        backgroundColor = Colors.deepPurple.shade50;
        borderColor = Colors.deepPurple.shade200;
        iconColor = Colors.deepPurple.shade700;
        textColor = Colors.deepPurple.shade700;
        icon = Icons.location_on;
        break;
      case 'delivered':
        backgroundColor = Colors.green.shade50;
        borderColor = Colors.green.shade200;
        iconColor = Colors.green.shade700;
        textColor = Colors.green.shade700;
        icon = Icons.check_circle;
        break;
      default:
        backgroundColor = Colors.grey.shade50;
        borderColor = Colors.grey.shade200;
        iconColor = Colors.grey.shade700;
        textColor = Colors.grey.shade700;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: iconColor),
          const SizedBox(width: 3),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              color: textColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.grey.shade600),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';

    final time = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.parse(timestamp.toString());

    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(time);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(time);
    } else {
      return DateFormat('MMM dd').format(time);
    }
  }

  Future<Map<String, dynamic>> _fetchChatData(
      Map<String, dynamic> data, String otherUserId) async {
    try {
      // Fetch other user's data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .get();

      final userData = userDoc.data() ?? {};

      // Fetch order data
      final orderId = data['orderId'];
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      final orderData = orderDoc.data() ?? {};

      return {
        'userName': userData['name'] ?? 'Unknown User',
        'profileUrl': userData['profileUrl'] ?? '',
        'origin': orderData['origin'] ?? 'Unknown',
        'destination': orderData['destination'] ?? 'Unknown',
        'date': orderData['date'] ?? '',
        'weight': orderData['weight'] ?? '0',
        'orderStatus': orderData['status'] ?? 'pending',
        'expectedPrice': orderData['expected_price'],
      };
    } catch (e) {
      return {
        'userName': 'Unknown User',
        'profileUrl': '',
        'origin': 'Unknown',
        'destination': 'Unknown',
        'date': '',
        'weight': '0',
        'orderStatus': 'pending',
        'expectedPrice': null,
      };
    }
  }
}
