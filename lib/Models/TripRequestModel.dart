// ============================================
// Send Trip Request Models
// ============================================

class TripRequestSendRequest {
  final String travelerId;
  final String orderId;
  final String travelDate;
  final String vehicleInfo;
  final String source;
  final String destination;
  final String pickupTime;  // ✅ Changed from startTripTime
  final String dropoffTime; // ✅ Changed from endTripTime

  TripRequestSendRequest({
    required this.travelerId,
    required this.orderId,
    required this.travelDate,
    required this.vehicleInfo,
    required this.source,
    required this.destination,
    required this.pickupTime,
    required this.dropoffTime,
  });

  Map<String, dynamic> toJson() {
    // Format date to YYYY-MM-DD only (remove timestamp if present)
    String formattedDate = travelDate;
    if (travelDate.contains('T')) {
      formattedDate = travelDate.split('T')[0];
    }

    final json = {
      'traveler_id': travelerId,
      'order_id': orderId,
      'travel_date': formattedDate,
      'vehicle_info': vehicleInfo,
      'source': source,
      'destination': destination,
      'pickup_time': pickupTime,   // ✅ API field name
      'dropoff_time': dropoffTime, // ✅ API field name
    };

    print('📤 Trip Request JSON: $json');
    return json;
  }
}

class TripRequestSendResponse {
  final String message;
  final String tripRequestId;

  TripRequestSendResponse({
    required this.message,
    required this.tripRequestId,
  });

  factory TripRequestSendResponse.fromJson(Map<String, dynamic> json) {
    print('📥 Trip Request Response: $json');
    return TripRequestSendResponse(
      message: json['message'] as String,
      tripRequestId: json['tripRequestId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'tripRequestId': tripRequestId,
    };
  }
}
// ============================================
// Accept Trip Request Models
// ============================================

class TripRequestAcceptRequest {
  final String orderCreatorId;
  final String tripRequestId;
  final int negotiatedPrice;

  TripRequestAcceptRequest({
    required this.orderCreatorId,
    required this.tripRequestId,
    required this.negotiatedPrice,
  });

  Map<String, dynamic> toJson() {
    return {
      'order_creator_id': orderCreatorId,
      'trip_request_id': tripRequestId,
      'negotiatedPrice': negotiatedPrice,
    };
  }
}

class TripRequestAcceptResponse {
  final String message;
  final String transactionId;

  TripRequestAcceptResponse({
    required this.message,
    required this.transactionId,
  });

  factory TripRequestAcceptResponse.fromJson(Map<String, dynamic> json) {
    return TripRequestAcceptResponse(
      message: json['message'] as String,
      transactionId: json['transactionId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'transactionId': transactionId,
    };
  }
}

// ============================================
// Trip Request Model (For List Response)
// ============================================

class TripRequest {
  final String id; // Maps to hashed_id from API
  final String travelerId; // Maps to traveler_hashed_id from API
  final String orderId; // Maps to order_hashed_id from API
  final String travelDate;
  final String vehicleInfo;
  final String source;
  final String destination;
  final String pickupTime;
  final String dropoffTime;
  final String status;
  final String? origin; // Additional field from API (same as source typically)
  final String? createdAt;

  TripRequest({
    required this.id,
    required this.travelerId,
    required this.orderId,
    required this.travelDate,
    required this.vehicleInfo,
    required this.source,
    required this.destination,
    required this.pickupTime,
    required this.dropoffTime,
    required this.status,
    this.origin,
    this.createdAt,
  });

  factory TripRequest.fromJson(Map<String, dynamic> json) {
    return TripRequest(
      id: json['hashed_id']?.toString() ?? '', // Updated from 'id'
      travelerId: json['traveler_hashed_id']?.toString() ?? '', // Updated from 'traveler_id'
      orderId: json['order_hashed_id']?.toString() ?? '', // Updated from 'order_id'
      travelDate: json['travel_date'] as String,
      vehicleInfo: json['vehicle_info'] as String,
      source: json['source'] as String,
      destination: json['destination'] as String,
      pickupTime: json['pickup_time'] as String,
      dropoffTime: json['dropoff_time'] as String,
      status: json['status'] as String,
      origin: json['origin'] as String?, // New field
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hashed_id': id, // Updated from 'id'
      'traveler_hashed_id': travelerId, // Updated from 'traveler_id'
      'order_hashed_id': orderId, // Updated from 'order_id'
      'travel_date': travelDate,
      'vehicle_info': vehicleInfo,
      'source': source,
      'destination': destination,
      'pickup_time': pickupTime,
      'dropoff_time': dropoffTime,
      'status': status,
      'origin': origin, // New field
      'created_at': createdAt,
    };
  }
}

// ============================================
// Trip Request List Response Wrapper
// ============================================

class TripRequestListResponse {
  final List<TripRequest> tripRequests;

  TripRequestListResponse({
    required this.tripRequests,
  });

  factory TripRequestListResponse.fromJson(Map<String, dynamic> json) {
    return TripRequestListResponse(
      tripRequests: (json['tripRequests'] as List)
          .map((e) => TripRequest.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tripRequests': tripRequests.map((e) => e.toJson()).toList(),
    };
  }
}
