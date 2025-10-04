// ============================================
// Send Trip Request Models
// ============================================

class TripRequestSendRequest {
  final int travelerId;
  final int orderId;
  final String travelDate;
  final int availableSpace;
  final String vehicleInfo;
  final String vehicleDetails;
  final String source;
  final String destination;
  final String route;

  TripRequestSendRequest({
    required this.travelerId,
    required this.orderId,
    required this.travelDate,
    required this.availableSpace,
    required this.vehicleInfo,
    required this.vehicleDetails,
    required this.source,
    required this.destination,
    required this.route,
  });

  Map<String, dynamic> toJson() {
    return {
      'traveler_id': travelerId,
      'order_id': orderId,
      'travel_date': travelDate,
      'available_space': availableSpace,
      'vehicle_info': vehicleInfo,
      'vehicle_details': vehicleDetails,
      'source': source,
      'destination': destination,
      'route': route,
    };
  }
}

class TripRequestSendResponse {
  final String message;
  final int tripRequestId;

  TripRequestSendResponse({
    required this.message,
    required this.tripRequestId,
  });

  factory TripRequestSendResponse.fromJson(Map<String, dynamic> json) {
    return TripRequestSendResponse(
      message: json['message'] as String,
      tripRequestId: json['tripRequestId'] as int,
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
  final int orderCreatorId;
  final int tripRequestId;
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
  final int transactionId;

  TripRequestAcceptResponse({
    required this.message,
    required this.transactionId,
  });

  factory TripRequestAcceptResponse.fromJson(Map<String, dynamic> json) {
    return TripRequestAcceptResponse(
      message: json['message'] as String,
      transactionId: json['transactionId'] as int,
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
  final int id;
  final int travelerId;
  final int orderId;
  final String travelDate;
  final int availableSpace;
  final String vehicleInfo;
  final String? vehicleDetails;
  final String source;
  final String destination;
  final String? route;
  final String status;
  final String? createdAt;

  TripRequest({
    required this.id,
    required this.travelerId,
    required this.orderId,
    required this.travelDate,
    required this.availableSpace,
    required this.vehicleInfo,
    this.vehicleDetails,
    required this.source,
    required this.destination,
    this.route,
    required this.status,
    this.createdAt,
  });

  factory TripRequest.fromJson(Map<String, dynamic> json) {
    return TripRequest(
      id: json['id'] as int,
      travelerId: json['traveler_id'] as int,
      orderId: json['order_id'] as int,
      travelDate: json['travel_date'] as String,
      availableSpace: json['available_space'] as int,
      vehicleInfo: json['vehicle_info'] as String,
      vehicleDetails: json['vehicle_details'] as String?,
      source: json['source'] as String,
      destination: json['destination'] as String,
      route: json['route'] as String?,
      status: json['status'] as String,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'traveler_id': travelerId,
      'order_id': orderId,
      'travel_date': travelDate,
      'available_space': availableSpace,
      'vehicle_info': vehicleInfo,
      'vehicle_details': vehicleDetails,
      'source': source,
      'destination': destination,
      'route': route,
      'status': status,
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
