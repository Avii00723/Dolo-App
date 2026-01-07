// ============================================
// Send Trip Request Models
// ============================================

class TripRequestSendRequest {
  final String travelerId;
  final String orderId;
  final String travelDate; // Format: YYYY-MM-DDTHH:MM:SSZ (delivery datetime)
  final String vehicleInfo;
  final String vehicleType; // NEW: Vehicle type (train, flight, bus, etc.)
  final String? pnr; // NEW: PNR/Ticket number (optional)
  final String source;
  final String destination;
  final String departureDatetime; // Format: YYYY-MM-DDTHH:MM:SSZ
  final String? comments;

  TripRequestSendRequest({
    required this.travelerId,
    required this.orderId,
    required this.travelDate,
    required this.vehicleInfo,
    required this.vehicleType,
    this.pnr,
    required this.source,
    required this.destination,
    required this.departureDatetime,
    this.comments,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'traveler_id': travelerId,
      'order_id': orderId,
      'travel_date': travelDate, // ISO datetime format
      'vehicle_info': vehicleInfo,
      'vehicle_type': vehicleType.toLowerCase(), // Ensure lowercase
      'source': source,
      'destination': destination,
      'departure_datetime': departureDatetime, // ISO datetime format
    };

    // Add PNR if provided
    if (pnr != null && pnr!.isNotEmpty) {
      json['pnr'] = pnr!;
    }

    // Add comments if provided
    if (comments != null && comments!.isNotEmpty) {
      json['comments'] = comments!;
    }

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
      'order_creator_hashed_id': orderCreatorId,
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
  final String id;
  final String travelerId;
  final String orderId;
  final String travelDate;
  final String vehicleInfo;
  final String vehicleType;
  final String? pnr;
  final String source;
  final String destination;
  final String departureDatetime;
  final String status;
  final String? origin;
  final String? createdAt;
  final String? comments;

  TripRequest({
    required this.id,
    required this.travelerId,
    required this.orderId,
    required this.travelDate,
    required this.vehicleInfo,
    required this.vehicleType,
    this.pnr,
    required this.source,
    required this.destination,
    required this.departureDatetime,
    required this.status,
    this.origin,
    this.createdAt,
    this.comments,
  });

  factory TripRequest.fromJson(Map<String, dynamic> json) {
    return TripRequest(
      id: json['hashed_id']?.toString() ?? '',
      travelerId: json['traveler_id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      travelDate: json['travel_date']?.toString() ?? '',
      vehicleInfo: json['vehicle_info']?.toString() ?? '',
      vehicleType: json['vehicle_type']?.toString() ?? '',
      pnr: json['pnr']?.toString(),
      source: json['source']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      departureDatetime: json['departure_datetime']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      origin: json['origin']?.toString(),
      createdAt: json['created_at']?.toString(),
      comments: json['comments']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hashed_id': id,
      'traveler_hashed_id': travelerId,
      'order_hashed_id': orderId,
      'travel_date': travelDate,
      'vehicle_info': vehicleInfo,
      'vehicle_type': vehicleType,
      'pnr': pnr,
      'source': source,
      'destination': destination,
      'departure_datetime': departureDatetime,
      'status': status,
      'origin': origin,
      'created_at': createdAt,
      'comments': comments,
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

// ============================================
// Withdraw Trip Request Models
// ============================================

class TripRequestWithdrawRequest {
  final String travelerHashedId;
  final String tripRequestHashedId;

  TripRequestWithdrawRequest({
    required this.travelerHashedId,
    required this.tripRequestHashedId,
  });

  Map<String, dynamic> toJson() {
    return {
      'traveler_hashed_id': travelerHashedId,
      'trip_request_hashed_id': tripRequestHashedId,
    };
  }
}

class TripRequestWithdrawResponse {
  final String message;

  TripRequestWithdrawResponse({required this.message});

  factory TripRequestWithdrawResponse.fromJson(Map<String, dynamic> json) {
    return TripRequestWithdrawResponse(
      message: json['message'] as String,
    );
  }
}

// ============================================
// Decline Trip Request Models
// ============================================

class TripRequestDeclineRequest {
  final String orderCreatorHashedId;
  final String tripRequestId;

  TripRequestDeclineRequest({
    required this.orderCreatorHashedId,
    required this.tripRequestId,
  });

  Map<String, dynamic> toJson() {
    return {
      'order_creator_hashed_id': orderCreatorHashedId,
      'trip_request_id': tripRequestId,
    };
  }
}

class TripRequestDeclineResponse {
  final String message;

  TripRequestDeclineResponse({required this.message});

  factory TripRequestDeclineResponse.fromJson(Map<String, dynamic> json) {
    return TripRequestDeclineResponse(
      message: json['message'] as String,
    );
  }
}

// ============================================
// Complete Trip Request Response
// ============================================

class TripRequestCompleteResponse {
  final String message;

  TripRequestCompleteResponse({required this.message});

  factory TripRequestCompleteResponse.fromJson(Map<String, dynamic> json) {
    return TripRequestCompleteResponse(
      message: json['message'] as String,
    );
  }
}