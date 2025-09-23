// Import Firestore
import 'package:cloud_firestore/cloud_firestore.dart';

final parcelRequests = FirebaseFirestore.instance.collection('parcelRequests');

// Create a Parcel Request
Future<void> createParcelRequest(Map<String, dynamic> data) async {
  await parcelRequests.add(data);
}

// Read Parcel Requests by user
Stream<QuerySnapshot> getParcelRequestsBySender(String senderId) {
  return parcelRequests.where('sender_id', isEqualTo: senderId).snapshots();
}

// Update a Parcel Request
Future<void> updateParcelRequest(String requestId, Map<String, dynamic> data) async {
  await parcelRequests.doc(requestId).update(data);
}

// Delete
Future<void> deleteParcelRequest(String requestId) async {
  await parcelRequests.doc(requestId).delete();
}
