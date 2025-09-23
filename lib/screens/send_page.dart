import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Constants/colorconstant.dart';

class SendPage extends StatefulWidget {
  const SendPage({Key? key}) : super(key: key);

  @override
  _SendPageState createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController dateController = TextEditingController();

  String? userType;
  bool isLoading = true;
  bool isSearching = false;
  List<Map<String, dynamic>> availableOrders = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadUserType();
  }

  // Load user type from Firebase
  Future<void> _loadUserType() async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId != null) {
        final DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            userType = data['userType'] ?? 'sender';
            isLoading = false;
          });
        } else {
          setState(() {
            userType = 'sender';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          userType = 'sender';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        userType = 'sender';
        isLoading = false;
      });
    }
  }

  bool get isTraveller => userType?.toLowerCase() == 'traveller';

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        dateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  // NEW: Search for available orders (for travellers)
  Future<void> _searchAvailableOrders() async {
    if (fromController.text.trim().isEmpty ||
        toController.text.trim().isEmpty ||
        dateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields to search'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSearching = true;
      availableOrders.clear();
    });

    try {
      // Search for orders matching the route and date
      final QuerySnapshot ordersSnapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: 'pending')
          .where('origin', isEqualTo: fromController.text.trim())
          .where('destination', isEqualTo: toController.text.trim())
          .where('date', isEqualTo: dateController.text.trim())
          .get();

      List<Map<String, dynamic>> orders = [];

      for (var doc in ordersSnapshot.docs) {
        final orderData = doc.data() as Map<String, dynamic>;

        // Get sender details
        try {
          final senderDoc = await _firestore
              .collection('users')
              .doc(orderData['sender_id'])
              .get();

          String senderName = 'Unknown Sender';
          String? senderPhone;

          if (senderDoc.exists) {
            final senderData = senderDoc.data() as Map<String, dynamic>;
            senderName = senderData['name'] ?? 'Unknown Sender';
            senderPhone = senderData['phone'];
          }

          orders.add({
            'orderId': doc.id,
            'senderId': orderData['sender_id'],
            'senderName': senderName,
            'senderPhone': senderPhone,
            'origin': orderData['origin'],
            'destination': orderData['destination'],
            'date': orderData['date'],
            'itemDescription': orderData['item_description'] ?? 'Package',
            'weight': orderData['weight'] ?? 'Not specified',
          });
        } catch (e) {
          print('Error fetching sender details: $e');
        }
      }

      setState(() {
        availableOrders = orders;
        isSearching = false;
      });

      if (orders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No orders found for this route and date'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching orders: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // NEW: Send request to sender
  Future<void> _sendRequestToSender(Map<String, dynamic> order) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show dialog to collect traveller details
      await _showTravellerDetailsDialog(order, userId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show dialog for traveller to enter their details
  Future<void> _showTravellerDetailsDialog(Map<String, dynamic> order, String userId) async {
    final vehicleController = TextEditingController();
    final spaceController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Trip Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Order: ${order['origin']} → ${order['destination']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Item: ${order['itemDescription']}'),
            Text('Weight: ${order['weight']}'),
            const SizedBox(height: 16),
            TextField(
              controller: vehicleController,
              decoration: const InputDecoration(
                labelText: 'Vehicle Details',
                hintText: 'e.g., Car, Bike, Bus',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: spaceController,
              decoration: const InputDecoration(
                labelText: 'Available Space',
                hintText: 'e.g., 10kg, Small bag',
                border: OutlineInputBorder(),
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
                  spaceController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              try {
                // Create trip request
                await _firestore.collection('trip_requests').add({
                  'order_id': order['orderId'],
                  'sender_id': order['senderId'],
                  'traveller_id': userId,
                  'route': '${order['origin']} → ${order['destination']}',
                  'date': order['date'],
                  'vehicle_info': vehicleController.text.trim(),
                  'available_space': spaceController.text.trim(),
                  'status': 'pending',
                  'created_at': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Request sent successfully!'),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Header with logo and notifications
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'assets/images/doloooo.png',
                      height: 40,
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      iconSize: 28,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Title - changes based on user type
              Text(
                isTraveller
                    ? 'Search Available Orders'
                    : 'Find a Trip for Your Package',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 20),

              // Common input fields for both users
              buildInputBox('From', fromController, Icons.location_on),
              const SizedBox(height: 15),
              buildInputBox('To', toController, Icons.location_on),
              const SizedBox(height: 15),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: buildInputBox('Date', dateController, Icons.calendar_today),
                ),
              ),

              const SizedBox(height: 30),

              // Search button for both user types
              SizedBox(
                width: 260,
                height: 50,
                child: ElevatedButton(
                  onPressed: isSearching ? null : (isTraveller ? _searchAvailableOrders : () {
                    // Sender logic - navigate to create order or search trips
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sender functionality - navigate to create order'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSearching
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                      : Text(
                    isTraveller ? 'Search Orders' : 'Find a trip',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Available Orders List (only for travellers)
              if (isTraveller && availableOrders.isNotEmpty)
                _buildAvailableOrdersList(),

              const SizedBox(height: 30),

              // Illustration and description
              Image.asset(
                'assets/images/truck.png',
                height: 130,
              ),

              const SizedBox(height: 10),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'How it works',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 5),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  isTraveller
                      ? 'Search for package delivery orders on your route and send requests to earn money.'
                      : 'Describe a package, find a traveler going the same route, and get it delivered.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // Build list of available orders with Send Request buttons
  Widget _buildAvailableOrdersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Available Orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: availableOrders.length,
          itemBuilder: (context, index) {
            final order = availableOrders[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          order['senderName'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          order['origin'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          order['destination'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Date: ${order['date']}'),
                    Text('Item: ${order['itemDescription']}'),
                    Text('Weight: ${order['weight']}'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _sendRequestToSender(order),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Send Request',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget buildInputBox(String label, TextEditingController controller, IconData icon) {
    return Container(
      width: 320,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          style: const TextStyle(fontSize: 16, color: Colors.black),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.black54),
            icon: Icon(icon, color: Colors.black),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    dateController.dispose();
    super.dispose();
  }
}
