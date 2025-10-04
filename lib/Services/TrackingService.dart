import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrackingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static StreamSubscription<Position>? _positionSubscription;

  // Start tracking for delivery person
  static Future<void> startTracking(String orderId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      updateDeliveryLocation(orderId, position);
    });
  }

  // Update delivery person location in real-time
  static Future<void> updateDeliveryLocation(String orderId, Position position) async {
    try {
      await _firestore.collection('order_tracking').doc(orderId).set({
        'order_id': orderId,
        'delivery_person_id': FirebaseAuth.instance.currentUser?.uid,
        'current_latitude': position.latitude,
        'current_longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'heading': position.heading,
        'speed': position.speed,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating delivery location: $e');
    }
  }

  // Stop tracking
  static void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  // Get real-time location stream for an order
  static Stream<DocumentSnapshot> getLocationStream(String orderId) {
    return _firestore.collection('order_tracking').doc(orderId).snapshots();
  }

  // Calculate distance between two points
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Update order status
  static Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': status,
        'status_updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating order status: $e');
    }
  }
}
