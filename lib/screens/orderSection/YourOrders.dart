import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rxdart/rxdart.dart';
import '../Inbox Section/indoxscreen.dart';

class Order {
  final String id;
  final String senderId;
  final String senderName;
  final String senderInitial;
  final String origin;
  final String destination;
  final String date;
  final String itemDescription;
  final String weight;
  final String status;
  final String? profileImageUrl;
  final String? matchedTravellerId;

  Order({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderInitial,
    required this.origin,
    required this.destination,
    required this.date,
    required this.itemDescription,
    required this.weight,
    required this.status,
    this.profileImageUrl,
    this.matchedTravellerId,
  });
}

class TripRequest {
  final String id;
  final String orderId;
  final String travellerId;
  final String travellerName;
  final String vehicleInfo;
  final String availableSpace;
  final String status;

  TripRequest({
    required this.id,
    required this.orderId,
    required this.travellerId,
    required this.travellerName,
    required this.vehicleInfo,
    required this.availableSpace,
    required this.status,
  });
}

class YourOrdersPage extends StatefulWidget {
  const YourOrdersPage({Key? key}) : super(key: key);

  @override
  State<YourOrdersPage> createState() => _YourOrdersPageState();
}

class _YourOrdersPageState extends State<YourOrdersPage> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Stream for user's own orders (orders they created)
  Stream<List<Order>> getMyOrdersStream() {
    if (currentUserId.isEmpty) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('orders')
        .where('sender_id', isEqualTo: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Order> orders = [];
      for (var doc in snapshot.docs) {
        var data = doc.data();
        orders.add(Order(
          id: doc.id,
          senderId: data['sender_id'] ?? '',
          senderName: 'You',
          senderInitial: 'Y',
          origin: data['origin'] ?? '',
          destination: data['destination'] ?? '',
          date: data['date'] ?? '',
          itemDescription: data['item_description'] ?? '',
          weight: data['weight'] ?? '',
          status: data['status'] ?? 'pending',
          matchedTravellerId: data['matched_traveller_id'],
        ));
      }
      return orders;
    });
  }

  // Stream for trip requests on user's orders
  Stream<Map<String, List<TripRequest>>> getTripRequestsStream() {
    if (currentUserId.isEmpty) return Stream.value({});

    return FirebaseFirestore.instance
        .collection('trip_requests')
        .where('sender_id', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      Map<String, List<TripRequest>> requestsByOrder = {};
      for (var doc in snapshot.docs) {
        var data = doc.data();
        String orderId = data['order_id'] ?? '';

        // Get traveller details
        String travellerName = 'Unknown User';
        try {
          final travellerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(data['traveller_id'])
              .get();
          if (travellerDoc.exists) {
            travellerName = travellerDoc.data()?['name'] ?? 'Unknown User';
          }
        } catch (e) {
          print('Error fetching user details: $e');
        }

        final request = TripRequest(
          id: doc.id,
          orderId: orderId,
          travellerId: data['traveller_id'] ?? '',
          travellerName: travellerName,
          vehicleInfo: data['vehicle_info'] ?? '',
          availableSpace: data['available_space'] ?? '',
          status: data['status'] ?? 'pending',
        );

        if (requestsByOrder.containsKey(orderId)) {
          requestsByOrder[orderId]!.add(request);
        } else {
          requestsByOrder[orderId] = [request];
        }
      }
      return requestsByOrder;
    });
  }

  // Stream for all available orders (from other users)
  Stream<List<Order>> getAvailableOrdersStream() {
    if (currentUserId.isEmpty) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Order> orders = [];
      for (var doc in snapshot.docs) {
        var data = doc.data();

        // Skip user's own orders
        if (data['sender_id'] == currentUserId) continue;

        // Get sender details
        String senderName = 'Unknown User';
        String? profileUrl;
        try {
          final senderDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(data['sender_id'])
              .get();
          if (senderDoc.exists) {
            final senderData = senderDoc.data() as Map<String, dynamic>;
            senderName = senderData['name'] ?? 'Unknown User';
            profileUrl = senderData['profileUrl'];
          }
        } catch (e) {
          print('Error fetching sender details: $e');
        }

        orders.add(Order(
          id: doc.id,
          senderId: data['sender_id'] ?? '',
          senderName: senderName,
          senderInitial: senderName.isNotEmpty ? senderName[0] : 'U',
          origin: data['origin'] ?? '',
          destination: data['destination'] ?? '',
          date: data['date'] ?? '',
          itemDescription: data['item_description'] ?? '',
          weight: data['weight'] ?? '',
          status: data['status'] ?? 'pending',
          profileImageUrl: profileUrl,
        ));
      }
      return orders;
    });
  }

  // Add to inbox when trip request is accepted
  Future<void> _addToInbox(String senderId, String travellerId, Order order) async {
    try {
      // Get user details
      final senderDoc = await FirebaseFirestore.instance.collection('users').doc(senderId).get();
      final travellerDoc = await FirebaseFirestore.instance.collection('users').doc(travellerId).get();

      final senderData = senderDoc.exists ? senderDoc.data() : null;
      final travellerData = travellerDoc.exists ? travellerDoc.data() : null;

      final senderName = senderData?['name'] ?? 'Sender';
      final travellerName = travellerData?['name'] ?? 'Traveller';
      final senderImage = senderData?['profileUrl'];
      final travellerImage = travellerData?['profileUrl'];

      // Create chat document in chats collection (for inbox)
      await FirebaseFirestore.instance.collection('chats').add({
        'participants': [senderId, travellerId],
        'buyerId': senderId, // Order creator is the buyer
        'travelerId': travellerId, // Request sender is the traveller
        'buyerName': senderName,
        'travelerName': travellerName,
        'otherUserName': travellerName, // This will be different for each user when they view
        'otherUserImage': travellerImage ?? '',
        'route': '${order.origin} → ${order.destination}',
        'price': '', // Will be negotiated
        'lastMessage': 'Trip request accepted! Start chatting to discuss details.',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'productName': order.itemDescription,
        'orderStatus': 'pending', // Start with pending, will be updated through chat
        'acceptedOfferAmount': '',
        'orderId': order.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding to inbox: $e');
      throw e;
    }
  }

  // Accept trip request method
  Future<void> _acceptTripRequest(TripRequest request, String orderId) async {
    try {
      // Show confirmation dialog
      bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Accept Trip Request'),
          content: Text('Accept trip request from ${request.travellerName}?\n\nThis will add them to your inbox so you can start chatting.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Accept & Add to Inbox'),
            ),
          ],
        ),
      ) ?? false;

      if (!confirm) return;

      // Get order details
      final orderDoc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) throw Exception('Order not found');

      final orderData = orderDoc.data()!;
      final order = Order(
        id: orderId,
        senderId: orderData['sender_id'],
        senderName: 'You',
        senderInitial: 'Y',
        origin: orderData['origin'] ?? '',
        destination: orderData['destination'] ?? '',
        date: orderData['date'] ?? '',
        itemDescription: orderData['item_description'] ?? '',
        weight: orderData['weight'] ?? '',
        status: orderData['status'] ?? 'pending',
      );

      // Add to inbox (create chat entry)
      await _addToInbox(currentUserId, request.travellerId, order);

      // Update the trip request status to accepted
      await FirebaseFirestore.instance
          .collection('trip_requests')
          .doc(request.id)
          .update({'status': 'accepted'});

      // Update the order status to matched
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'matched',
        'matched_traveller_id': request.travellerId,
        'matched_at': FieldValue.serverTimestamp(),
      });

      // Reject all other pending requests for this order
      final otherRequests = await FirebaseFirestore.instance
          .collection('trip_requests')
          .where('order_id', isEqualTo: orderId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (var doc in otherRequests.docs) {
        if (doc.id != request.id) {
          await doc.reference.update({'status': 'rejected'});
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip request accepted! User added to your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Navigate to inbox
  void _openInbox() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InboxScreen(),
      ),
    );
  }

  // Send trip request to other users' orders
  Future<void> _sendTripRequest(Order order) async {
    await showDialog(
      context: context,
      builder: (context) => _buildTripRequestDialog(order),
    );
  }

  Widget _buildTripRequestDialog(Order order) {
    final vehicleController = TextEditingController();
    final availableSpaceController = TextEditingController();

    return AlertDialog(
      title: const Text('Send Trip Request'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Order: ${order.origin} → ${order.destination}'),
          const SizedBox(height: 16),
          TextField(
            controller: vehicleController,
            decoration: const InputDecoration(
              labelText: 'Vehicle Information',
              hintText: 'e.g., Car, Bike, Truck',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: availableSpaceController,
            decoration: const InputDecoration(
              labelText: 'Available Space',
              hintText: 'e.g., 5kg, Small bag',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (vehicleController.text.trim().isEmpty ||
                availableSpaceController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill all fields')),
              );
              return;
            }

            try {
              // Create trip request
              await FirebaseFirestore.instance
                  .collection('trip_requests')
                  .add({
                'order_id': order.id,
                'sender_id': order.senderId,
                'traveller_id': currentUserId,
                'vehicle_info': vehicleController.text.trim(),
                'available_space': availableSpaceController.text.trim(),
                'status': 'pending',
                'created_at': FieldValue.serverTimestamp(),
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trip request sent successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to send request: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Send Request'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        backgroundColor: const Color(0xFF0A1A2A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.inbox),
            onPressed: _openInbox,
            tooltip: 'Inbox',
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              labelColor: Color(0xFF0A1A2A),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF0A1A2A),
              tabs: [
                Tab(text: 'My Orders', icon: Icon(Icons.inventory_2)),
                Tab(text: 'Available Orders', icon: Icon(Icons.search)),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildMyOrdersTab(),
                  _buildAvailableOrdersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyOrdersTab() {
    return StreamBuilder<List<Order>>(
      stream: getMyOrdersStream(),
      builder: (context, orderSnapshot) {
        if (orderSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = orderSnapshot.data ?? [];
        if (orders.isEmpty) {
          return const Center(
            child: Text(
              'No orders created yet.\nCreate your first order!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return StreamBuilder<Map<String, List<TripRequest>>>(
          stream: getTripRequestsStream(),
          builder: (context, requestSnapshot) {
            final tripRequestsByOrder = requestSnapshot.data ?? {};

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final requests = tripRequestsByOrder[order.id] ?? [];
                return SenderOrderCard(
                  order: order,
                  tripRequests: requests,
                  onAcceptRequest: _acceptTripRequest,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAvailableOrdersTab() {
    return StreamBuilder<List<Order>>(
      stream: getAvailableOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const Center(
            child: Text(
              'No orders available at the moment.\nCheck back later!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return TravellerOrderCard(
              order: orders[index],
              onSendRequest: () => _sendTripRequest(orders[index]),
            );
          },
        );
      },
    );
  }
}

// Sender Order Card Widget (for "My Orders" tab)
class SenderOrderCard extends StatelessWidget {
  final Order order;
  final List<TripRequest>? tripRequests;
  final Function(TripRequest, String)? onAcceptRequest;

  const SenderOrderCard({
    Key? key,
    required this.order,
    this.tripRequests,
    this.onAcceptRequest,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Your Order',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(order.status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  order.origin,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.destination,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Date: ${order.date}'),
            Text('Item: ${order.itemDescription}'),
            Text('Weight: ${order.weight}'),

            // Show message for matched orders
            if (order.status == 'matched') ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip Request Accepted!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                          Text(
                            'Check your inbox to chat with the traveller',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.inbox, color: Colors.green[600]),
                  ],
                ),
              ),
            ],

            // Show trip requests if any
            if (tripRequests != null && tripRequests!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              Row(
                children: [
                  Icon(Icons.people, color: Colors.orange[700], size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Trip Requests (${tripRequests!.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...tripRequests!.map((request) => _buildTripRequestItem(request)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTripRequestItem(TripRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blue[100],
                child: Text(
                  request.travellerName.isNotEmpty ? request.travellerName[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.travellerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.directions_car, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          request.vehicleInfo,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.inventory, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Space: ${request.availableSpace}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => onAcceptRequest?.call(request, order.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Accept', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'matched':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

// Traveller Order Card Widget (for "Available Orders" tab)
class TravellerOrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onSendRequest;

  const TravellerOrderCard({
    Key? key,
    required this.order,
    required this.onSendRequest,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blue[100],
                  backgroundImage: order.profileImageUrl?.isNotEmpty == true
                      ? NetworkImage(order.profileImageUrl!)
                      : null,
                  child: order.profileImageUrl?.isEmpty != false
                      ? Text(
                    order.senderInitial,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  )
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.senderName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Order Creator',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  order.origin,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.destination,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Date: ${order.date}'),
            Text('Item: ${order.itemDescription}'),
            Text('Weight: ${order.weight}'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSendRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A1A2A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Send Trip Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
