import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // for demo purposes, sign in anonymously
  await FirebaseAuth.instance.signInAnonymously();

  runApp(const MarketplaceApp());
}

class MarketplaceApp extends StatelessWidget {
  const MarketplaceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
      ),
      home: const ChatScreen(chatId: 'chat_demo_1'),
    );
  }
}

enum OrderStatus {
  pending,
  priceNegotiated,
  orderConfirmed,
  pickedUp,
  inTransit,
  delivered,
  completed
}

enum UserRole {
  sender,
  traveller, // traveler who will deliver
}

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserRole? userRole;

  const ChatScreen({Key? key, required this.chatId, this.userRole}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  bool _isPriceMode = false;
  late TabController _tabController;
  OrderStatus _currentOrderStatus = OrderStatus.pending;
  String _negotiatedPrice = '';
  String _deliveryId = '';
  UserRole _currentUserRole = UserRole.sender;
  String _otherUserName = '';
  String _itemDescription = '';
  String _route = '';
  String _weight = '';
  String _deliveryDate = '';

  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _isPriceMode = _tabController.index == 1;
      });
    });
    _loadChatData();
  }

  Future<void> _loadChatData() async {
    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();

      if (chatDoc.exists) {
        final data = chatDoc.data() as Map<String, dynamic>;

        final buyerId = data['buyerId'] ?? ''; // Sender
        final travelerId = data['travelerId'] ?? ''; // Traveller

        setState(() {
          _currentOrderStatus = OrderStatus.values.firstWhere(
                (e) => e.toString() == data['orderStatus'],
            orElse: () => OrderStatus.pending,
          );
          _negotiatedPrice = data['negotiatedPrice'] ?? '';
          _deliveryId = data['deliveryId'] ?? '';

          // Determine current user's role
          if (currentUserId == travelerId) {
            _currentUserRole = UserRole.traveller;
            _otherUserName = data['buyerName'] ?? 'Sender';
          } else {
            _currentUserRole = UserRole.sender;
            _otherUserName = data['travelerName'] ?? 'Traveller';
          }

          _itemDescription = data['productName'] ?? 'Package';
          _route = data['route'] ?? '';
          _weight = data['weight'] ?? '';
          _deliveryDate = data['deliveryDate'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading chat data: $e');
    }
  }

  Future<void> _updateOrderStatus(OrderStatus newStatus, {String? additionalData}) async {
    try {
      final updateData = {
        'orderStatus': newStatus.toString(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastMessage': _getStatusMessage(newStatus),
        'lastMessageTime': FieldValue.serverTimestamp(),
      };

      if (additionalData != null) {
        if (newStatus == OrderStatus.orderConfirmed) {
          updateData['deliveryId'] = additionalData;
          _deliveryId = additionalData;
        } else if (newStatus == OrderStatus.priceNegotiated) {
          updateData['negotiatedPrice'] = additionalData;
          _negotiatedPrice = additionalData;
        }
      }

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update(updateData);

      setState(() {
        _currentOrderStatus = newStatus;
      });

      // Send system message about status change
      await _sendSystemMessage(_getStatusMessage(newStatus));
    } catch (e) {
      print('Error updating order status: $e');
    }
  }

  String _getStatusMessage(OrderStatus status) {
    switch (status) {
      case OrderStatus.priceNegotiated:
        return _currentUserRole == UserRole.sender
            ? 'Price agreed: $_negotiatedPrice - Please confirm the delivery'
            : 'Price agreed: $_negotiatedPrice - Waiting for sender to confirm';
      case OrderStatus.orderConfirmed:
        return _currentUserRole == UserRole.sender
            ? 'Delivery confirmed! Tracking ID: $_deliveryId'
            : 'New delivery confirmed! Tracking ID: $_deliveryId - Please prepare for pickup';
      case OrderStatus.pickedUp:
        return _currentUserRole == UserRole.traveller
            ? 'You picked up the package'
            : 'Package has been picked up by the traveller';
      case OrderStatus.inTransit:
        return _currentUserRole == UserRole.traveller
            ? 'Package is now in transit'
            : 'Your package is now in transit';
      case OrderStatus.delivered:
        return _currentUserRole == UserRole.traveller
            ? 'Package delivered successfully'
            : 'Package has been delivered! Please confirm receipt';
      case OrderStatus.completed:
        return 'Delivery completed successfully. Thank you for using our service!';
      default:
        return 'Status updated.';
    }
  }

  Future<void> _sendMessage({String? text, String? priceOffer}) async {
    if ((text == null || text.trim().isEmpty) && priceOffer == null) return;

    final messageData = {
      'sender_id': currentUserId,
      'text': text ?? '',
      'priceOffer': priceOffer ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'messageType': priceOffer != null ? 'price_offer' : 'text',
    };

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(messageData);

    // Update last message in chat document
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage': priceOffer != null ? 'Price offer: $priceOffer' : text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
    _priceController.clear();
  }

  Future<void> _sendSystemMessage(String message) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'sender_id': 'system',
      'text': message,
      'timestamp': FieldValue.serverTimestamp(),
      'messageType': 'system',
    });
  }

  Future<void> _acceptPrice(String price) async {
    // Both users can accept price, but typically traveller accepts sender's offer
    await _updateOrderStatus(OrderStatus.priceNegotiated, additionalData: price);
  }

  Future<void> _confirmDelivery() async {
    // Generate delivery tracking ID
    final deliveryId = 'DEL${DateTime.now().millisecondsSinceEpoch}';

    // Create delivery document
    await FirebaseFirestore.instance
        .collection('deliveries')
        .doc(deliveryId)
        .set({
      'deliveryId': deliveryId,
      'chatId': widget.chatId,
      'senderId': _currentUserRole == UserRole.sender ? currentUserId : _otherUserName,
      'travellerId': _currentUserRole == UserRole.traveller ? currentUserId : _otherUserName,
      'price': _negotiatedPrice,
      'status': 'confirmed',
      'itemDescription': _itemDescription,
      'route': _route,
      'weight': _weight,
      'deliveryDate': _deliveryDate,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _updateOrderStatus(OrderStatus.orderConfirmed, additionalData: deliveryId);
  }

  Future<void> _markAsPickedUp() async {
    await _updateOrderStatus(OrderStatus.pickedUp);

    // Update delivery document
    if (_deliveryId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(_deliveryId)
          .update({
        'status': 'picked_up',
        'pickedUpAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _markAsInTransit() async {
    await _updateOrderStatus(OrderStatus.inTransit);

    // Update delivery document
    if (_deliveryId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(_deliveryId)
          .update({
        'status': 'in_transit',
        'transitStartedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _markAsDelivered() async {
    await _updateOrderStatus(OrderStatus.delivered);

    // Update delivery document
    if (_deliveryId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(_deliveryId)
          .update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _completeDelivery() async {
    await _updateOrderStatus(OrderStatus.completed);

    // Update delivery document
    if (_deliveryId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(_deliveryId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _priceController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1A2A),
        foregroundColor: Colors.white,
        leading: const BackButton(),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue[100],
              radius: 16,
              child: Text(
                _otherUserName.isNotEmpty ? _otherUserName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _otherUserName.isNotEmpty ? _otherUserName : 'Chat Partner',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_route.isNotEmpty)
                    Text(
                      _route,
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    _currentUserRole == UserRole.traveller ? '🚚 You are the Traveller' : '📦 You are the Sender',
                    style: const TextStyle(fontSize: 9, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), onPressed: _showDeliveryInfo),
        ],
      ),
      body: Column(
        children: [
          // Status Banner
          if (_currentOrderStatus != OrderStatus.pending) _buildStatusBanner(),

          // Chat Messages
          Expanded(child: _isPriceMode ? _buildPriceNegotiationView() : _buildChatView()),
          const Divider(height: 1),

          // Action Buttons
          _buildActionButtons(),

          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0A1A2A),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF0A1A2A),
              tabs: const [
                Tab(icon: Icon(Icons.chat_bubble_outline), text: 'CHAT'),
                Tab(icon: Icon(Icons.attach_money), text: 'PRICE'),
              ],
            ),
          ),

          // Message Input
          if (!_isPriceMode) _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    Color backgroundColor;
    IconData icon;
    String statusText;

    switch (_currentOrderStatus) {
      case OrderStatus.priceNegotiated:
        backgroundColor = Colors.green.shade100;
        icon = Icons.handshake;
        statusText = 'Price agreed: $_negotiatedPrice';
        break;
      case OrderStatus.orderConfirmed:
        backgroundColor = Colors.blue.shade100;
        icon = Icons.check_circle;
        statusText = 'Delivery confirmed - $_deliveryId';
        break;
      case OrderStatus.pickedUp:
        backgroundColor = Colors.orange.shade100;
        icon = Icons.inventory;
        statusText = 'Package picked up';
        break;
      case OrderStatus.inTransit:
        backgroundColor = Colors.purple.shade100;
        icon = Icons.local_shipping;
        statusText = 'In transit';
        break;
      case OrderStatus.delivered:
        backgroundColor = Colors.teal.shade100;
        icon = Icons.done_all;
        statusText = 'Delivered successfully';
        break;
      case OrderStatus.completed:
        backgroundColor = Colors.green.shade200;
        icon = Icons.star;
        statusText = 'Delivery completed';
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        icon = Icons.info;
        statusText = 'Negotiating';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_currentUserRole == UserRole.sender && _currentOrderStatus == OrderStatus.priceNegotiated) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _confirmDelivery,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Confirm Delivery - $_negotiatedPrice',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      );
    }

    if (_currentUserRole == UserRole.traveller && _currentOrderStatus == OrderStatus.orderConfirmed) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _markAsPickedUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Mark as Picked Up',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      );
    }

    if (_currentUserRole == UserRole.traveller && _currentOrderStatus == OrderStatus.pickedUp) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _markAsInTransit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Start Transit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      );
    }

    if (_currentUserRole == UserRole.traveller && _currentOrderStatus == OrderStatus.inTransit) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _markAsDelivered,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Mark as Delivered',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      );
    }

    if (_currentUserRole == UserRole.sender && _currentOrderStatus == OrderStatus.delivered) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _completeDelivery,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Confirm Receipt & Complete',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildChatView() {
    final messagesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: messagesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final messages = snapshot.data!.docs;
        if (messages.isEmpty) {
          return const Center(
            child: Text(
              'Start the conversation!\nDiscuss pickup location, delivery details, and price.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final data = messages[index].data() as Map<String, dynamic>;
            final senderId = data['sender_id'] ?? '';
            final messageType = data['messageType'] ?? 'text';
            final isMe = senderId == currentUserId;
            final isSystem = senderId == 'system';
            final text = data['text'] ?? '';
            final priceOffer = data['priceOffer'] ?? '';

            if (isSystem) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (messageType == 'price_offer') {
              return _buildPriceOfferMessage(priceOffer, isMe);
            }

            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF0A1A2A) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: isMe ? Colors.white : Colors.black,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPriceOfferMessage(String price, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.green[100] : Colors.orange[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? Colors.green : Colors.orange,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '💰 Price Offer: $price',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (!isMe && _currentOrderStatus == OrderStatus.pending) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _acceptPrice(price),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Accept Price', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriceNegotiationView() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Spacer(),

          // Price input section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  '💰 Suggest Your Price',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    labelText: 'Enter amount',
                    border: OutlineInputBorder(),
                    hintText: '1500',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_priceController.text.isNotEmpty) {
                        _sendMessage(priceOffer: '₹${_priceController.text}');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A1A2A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Send Price Offer',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Quick price suggestions
          const Text('Quick Suggestions:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickPriceChip('₹500'),
              _buildQuickPriceChip('₹1000'),
              _buildQuickPriceChip('₹1500'),
              _buildQuickPriceChip('₹2000'),
              _buildQuickPriceChip('₹2500'),
              _buildQuickPriceChip('₹3000'),
            ],
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildQuickPriceChip(String price) {
    return InkWell(
      onTap: () => _sendMessage(priceOffer: price),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Text(
          price,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            color: Colors.grey,
            onPressed: () {},
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type your message...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (val) => _sendMessage(text: val),
              maxLines: null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            color: const Color(0xFF0A1A2A),
            onPressed: () => _sendMessage(text: _messageController.text),
          ),
        ],
      ),
    );
  }

  void _showDeliveryInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delivery Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item: $_itemDescription'),
            Text('Route: $_route'),
            if (_weight.isNotEmpty) Text('Weight: $_weight'),
            if (_deliveryDate.isNotEmpty) Text('Expected Date: $_deliveryDate'),
            if (_deliveryId.isNotEmpty) Text('Tracking ID: $_deliveryId'),
            if (_negotiatedPrice.isNotEmpty) Text('Price: $_negotiatedPrice'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
