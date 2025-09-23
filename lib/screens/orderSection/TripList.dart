import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripsListScreen extends StatelessWidget {
  final String senderOrderId;

   TripsListScreen({Key? key, required this.senderOrderId}) : super(key: key);

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Trips"),
        backgroundColor: Colors.indigo[900],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.collection('trips').orderBy('date_time').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final trips = snapshot.data!.docs;
          if (trips.isEmpty) return const Center(child: Text("No trips available"));

          return ListView.separated(
            itemCount: trips.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final trip = trips[index];
              final data = trip.data() as Map<String, dynamic>;

              return ListTile(
                title: Text("${data['departure'] ?? ''} → ${data['arrival'] ?? ''}"),
                subtitle: Text("Date: ${data['date_time'] ?? ''}\nVehicle: ${data['vehicle_info'] ?? ''}\nSpace Left: ${data['available_space'] ?? ''}"),
                trailing: ElevatedButton(
                  child: const Text("Request"),
                  onPressed: () => _sendRequest(context, trip.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _sendRequest(BuildContext context, String tripId) async {
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in'), backgroundColor: Colors.red),
      );
      return;
    }
    try {
      // Add tripRequest subcollection document under the trip
      await firestore
          .collection('trips')
          .doc(tripId)
          .collection('tripRequests')
          .add({
        'order_id': senderOrderId,
        'sender_id': currentUserId,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Optionally update order with matched tripId (you can also handle this elsewhere)
      await firestore.collection('orders').doc(senderOrderId).update({
        'matched_trip_id': tripId,
        'status': 'requested',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent to traveler!'), backgroundColor: Colors.green),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
