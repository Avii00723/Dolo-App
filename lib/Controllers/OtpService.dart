import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

/// Service class for handling OTP generation and management
class OtpService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate a 6-digit OTP
  String generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Create order with OTP
  Future<String> createOrderWithOtp({
    required String origin,
    required String destination,
    required Map<String, double> pickupCoordinates,
    required Map<String, double> dropoffCoordinates,
    required String senderPhone,
    required String deliveryPersonId,
    required String deliveryPersonName,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Generate OTP
      final otp = generateOtp();

      // Create order document
      final orderRef = await _firestore.collection('orders').add({
        'user_id': FirebaseAuth.instance.currentUser?.uid,
        'origin': origin,
        'destination': destination,
        'pickup_coordinates': pickupCoordinates,
        'dropoff_coordinates': dropoffCoordinates,
        'delivery_person_id': deliveryPersonId,
        'delivery_person_name': deliveryPersonName,
        'status': 'pending',
        'delivery_otp': otp,
        'otp_generated_at': FieldValue.serverTimestamp(),
        'sender_phone': senderPhone,
        'created_at': FieldValue.serverTimestamp(),
        ...?additionalData,
      });

      // Send OTP to sender
      await sendOtpNotification(
        phone: senderPhone,
        otp: otp,
        orderId: orderRef.id,
      );

      return orderRef.id;
    } catch (e) {
      print('Error creating order with OTP: $e');
      rethrow;
    }
  }

  /// Resend OTP for an existing order
  Future<void> resendOtp(String orderId) async {
    try {
      // Get order document
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      final senderPhone = orderData['sender_phone'] as String?;

      if (senderPhone == null) {
        throw Exception('Sender phone not found');
      }

      // Generate new OTP
      final newOtp = generateOtp();

      // Update order with new OTP
      await _firestore.collection('orders').doc(orderId).update({
        'delivery_otp': newOtp,
        'otp_generated_at': FieldValue.serverTimestamp(),
      });

      // Send new OTP to sender
      await sendOtpNotification(
        phone: senderPhone,
        otp: newOtp,
        orderId: orderId,
      );
    } catch (e) {
      print('Error resending OTP: $e');
      rethrow;
    }
  }

  /// Send OTP notification to sender
  /// This is a placeholder - implement based on your notification system
  Future<void> sendOtpNotification({
    required String phone,
    required String otp,
    required String orderId,
  }) async {
    // OPTION 1: SMS via Twilio
    // await TwilioService.sendSms(
    //   to: phone,
    //   body: 'Your delivery OTP for order #$orderId is: $otp. Share this with the traveler upon delivery.',
    // );

    // OPTION 2: Firebase Cloud Messaging (Push Notification)
    // await FirebaseMessaging.instance.sendMessage(
    //   to: senderDeviceToken,
    //   data: {
    //     'type': 'delivery_otp',
    //     'order_id': orderId,
    //     'otp': otp,
    //   },
    //   notification: {
    //     'title': 'Delivery OTP',
    //     'body': 'Your OTP is: $otp',
    //   },
    // );

    // OPTION 3: In-app notification via Firestore
    await _firestore.collection('notifications').add({
      'user_id': FirebaseAuth.instance.currentUser?.uid,
      'type': 'delivery_otp',
      'order_id': orderId,
      'title': 'Delivery OTP',
      'message': 'Your delivery OTP is: $otp. Share this with the traveler upon delivery.',
      'otp': otp,
      'created_at': FieldValue.serverTimestamp(),
      'read': false,
    });

    // OPTION 4: Email via SendGrid or Firebase Extensions
    // await EmailService.sendEmail(
    //   to: senderEmail,
    //   subject: 'Delivery OTP for Order #$orderId',
    //   body: 'Your delivery OTP is: $otp',
    // );

    print('OTP sent to $phone: $otp');
  }

  /// Verify OTP
  Future<bool> verifyOtp({
    required String orderId,
    required String enteredOtp,
  }) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();

      if (!orderDoc.exists) {
        return false;
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      final storedOtp = orderData['delivery_otp'] as String?;

      return storedOtp == enteredOtp;
    } catch (e) {
      print('Error verifying OTP: $e');
      return false;
    }
  }

  /// Mark order as delivered after OTP verification
  Future<void> markAsDelivered(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'delivered',
        'delivered_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking order as delivered: $e');
      rethrow;
    }
  }

  /// Save rating and feedback
  Future<void> saveRating({
    required String orderId,
    required int rating,
    String? feedback,
  }) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Save to order_ratings collection
      await _firestore.collection('order_ratings').doc(orderId).set({
        'order_id': orderId,
        'user_id': userId,
        'rating': rating,
        'feedback': feedback ?? '',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Update order document
      await _firestore.collection('orders').doc(orderId).update({
        'rating': rating,
        'feedback': feedback ?? '',
        'rated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving rating: $e');
      rethrow;
    }
  }

  /// Get average rating for a delivery person
  Future<double> getDeliveryPersonAverageRating(String deliveryPersonId) async {
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where('delivery_person_id', isEqualTo: deliveryPersonId)
          .where('rating', isGreaterThan: 0)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return 0.0;
      }

      double totalRating = 0;
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        totalRating += (data['rating'] as num).toDouble();
      }

      return totalRating / querySnapshot.docs.length;
    } catch (e) {
      print('Error getting average rating: $e');
      return 0.0;
    }
  }

  /// Get all ratings for a delivery person
  Future<List<Map<String, dynamic>>> getDeliveryPersonRatings(
      String deliveryPersonId, {
        int limit = 10,
      }) async {
    try {
      final querySnapshot = await _firestore
          .collection('order_ratings')
          .where('delivery_person_id', isEqualTo: deliveryPersonId)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error getting ratings: $e');
      return [];
    }
  }
}

/// Example usage
class OrderServiceExample {
  final OtpService _otpService = OtpService();

  /// Example: Create a new order
  Future<void> createNewOrder() async {
    try {
      final orderId = await _otpService.createOrderWithOtp(
        origin: 'Mumbai, Maharashtra',
        destination: 'Delhi, India',
        pickupCoordinates: {
          'latitude': 19.0760,
          'longitude': 72.8777,
        },
        dropoffCoordinates: {
          'latitude': 28.7041,
          'longitude': 77.1025,
        },
        senderPhone: '+91 9876543210',
        deliveryPersonId: 'delivery_person_123',
        deliveryPersonName: 'Kavya Shinde',
        additionalData: {
          'package_type': 'Documents',
          'package_weight': 0.5,
          'delivery_fee': 500,
        },
      );

      print('Order created with ID: $orderId');
    } catch (e) {
      print('Error creating order: $e');
    }
  }

  /// Example: Verify OTP and complete delivery
  Future<void> completeDelivery(String orderId, String enteredOtp) async {
    try {
      // Verify OTP
      final isValid = await _otpService.verifyOtp(
        orderId: orderId,
        enteredOtp: enteredOtp,
      );

      if (isValid) {
        // Mark as delivered
        await _otpService.markAsDelivered(orderId);
        print('Delivery completed successfully');
      } else {
        print('Invalid OTP');
      }
    } catch (e) {
      print('Error completing delivery: $e');
    }
  }

  /// Example: Submit rating
  Future<void> submitRating(String orderId, int rating, String feedback) async {
    try {
      await _otpService.saveRating(
        orderId: orderId,
        rating: rating,
        feedback: feedback,
      );
      print('Rating submitted successfully');
    } catch (e) {
      print('Error submitting rating: $e');
    }
  }

  /// Example: Get delivery person stats
  Future<void> getDeliveryPersonStats(String deliveryPersonId) async {
    try {
      final averageRating = await _otpService.getDeliveryPersonAverageRating(
        deliveryPersonId,
      );

      final recentRatings = await _otpService.getDeliveryPersonRatings(
        deliveryPersonId,
        limit: 5,
      );

      print('Average Rating: ${averageRating.toStringAsFixed(1)}');
      print('Recent Ratings: ${recentRatings.length}');
    } catch (e) {
      print('Error getting stats: $e');
    }
  }
}