import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Your Orders',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
        fontFamily: 'SF Pro Display',
      ),
      home: const YourOrdersPage(),
    );
  }
}

class Order {
  final String travelerName;
  final String travelerInitial;
  final String source;
  final String destination;
  final String date;
  final String departureTime;
  final String profileImageUrl;

  Order({
    required this.travelerName,
    required this.travelerInitial,
    required this.source,
    required this.destination,
    required this.date,
    required this.departureTime,
    required this.profileImageUrl,
  });
}

class YourOrdersPage extends StatefulWidget {
  const YourOrdersPage({Key? key}) : super(key: key);

  @override
  State<YourOrdersPage> createState() => _YourOrdersPageState();
}

class _YourOrdersPageState extends State<YourOrdersPage> {
  List<Order> inProgressOrders = [];

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    List<Order> orders = [];

    try {
      // Fetch from sender_orders
      var senderSnapshot = await FirebaseFirestore.instance
          .collection('sender_orders')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in senderSnapshot.docs) {
        var data = doc.data();
        orders.add(Order(
          travelerName: data['travelerName'] ?? 'Unknown',
          travelerInitial: data['travelerName']?[0] ?? '?',
          source: data['source'] ?? 'Unknown',
          destination: data['destination'] ?? 'Unknown',
          date: data['date'] ?? '',
          departureTime: data['departureTime'] ?? '',
          profileImageUrl: data['profileImageUrl'] ?? '',
        ));
      }

      // Fetch from Traveller_trip_details
      var travelerSnapshot = await FirebaseFirestore.instance
          .collection('Traveller_trip_details')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in travelerSnapshot.docs) {
        var data = doc.data();
        orders.add(Order(
          travelerName: data['name'] ?? 'Unknown',
          travelerInitial: data['name']?[0] ?? '?',
          source: data['source'] ?? 'Unknown',
          destination: data['destination'] ?? 'Unknown',
          date: data['date'] ?? '',
          departureTime: data['departureTime'] ?? '',
          profileImageUrl: data['profileImageUrl'] ?? '',
        ));
      }

      setState(() {
        inProgressOrders = orders;
      });
    } catch (e) {
      print('Error fetching orders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Orders'),
        backgroundColor: const Color(0xFF0A1A2A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: inProgressOrders.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: inProgressOrders.length,
                itemBuilder: (context, index) {
                  return OrderCard(order: inProgressOrders[index]);
                },
              ),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final Order order;

  const OrderCard({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Traveler Row
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(order.profileImageUrl),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.travelerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Traveler',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Route Info
            Row(
              children: [
                Text(
                  order.source,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 20),
                const SizedBox(width: 8),
                Text(
                  order.destination,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  order.date,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Departure Time
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  'Leaves at ${order.departureTime}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // View Trip Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  print('View Trip for ${order.source} to ${order.destination}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A1A2A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'View Trip',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
