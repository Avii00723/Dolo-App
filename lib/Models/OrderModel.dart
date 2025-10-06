class Order {
  final int id;
  final String userName;
  final String itemDescription;
  final String origin;
  final double originLatitude;
  final double originLongitude;
  final String destination;
  final double destinationLatitude;
  final double destinationLongitude;
  final String deliveryDate;
  final double weight;
  final int expectedPrice;
  final String imageUrl;
  final String specialInstructions;
  final String status;
  final double? distanceKm;
  final double? calculatedPrice;  // ✅ Changed from int? to double?
  final String? createdAt;

  Order({
    required this.id,
    required this.userName,
    required this.itemDescription,
    required this.origin,
    required this.originLatitude,
    required this.originLongitude,
    required this.destination,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.deliveryDate,
    required this.weight,
    required this.expectedPrice,
    required this.imageUrl,
    required this.specialInstructions,
    required this.status,
    this.distanceKm,
    this.calculatedPrice,
    this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? 0,
      userName: json['user_name'] ?? '',
      itemDescription: json['item_description'] ?? '',
      origin: json['origin'] ?? '',
      originLatitude: _parseDouble(json['origin_latitude']),
      originLongitude: _parseDouble(json['origin_longitude']),
      destination: json['destination'] ?? '',
      destinationLatitude: _parseDouble(json['destination_latitude']),
      destinationLongitude: _parseDouble(json['destination_longitude']),
      deliveryDate: json['delivery_date'] ?? '',
      weight: _parseDouble(json['weight']),
      expectedPrice: _parseInt(json['expected_price']),  // ✅ Use _parseInt
      imageUrl: json['image_url'] ?? '',
      specialInstructions: json['special_instructions'] ?? '',
      status: json['status'] ?? '',
      distanceKm: json['distance_km'] != null ? _parseDouble(json['distance_km']) : null,
      calculatedPrice: json['calculated_price'] != null ? _parseDouble(json['calculated_price']) : null,  // ✅ Use _parseDouble
      createdAt: json['created_at'],
    );
  }

  // Helper method to parse double from String or num
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // ✅ NEW: Helper method to parse int from String or num
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_name': userName,
      'item_description': itemDescription,
      'origin': origin,
      'origin_latitude': originLatitude,
      'origin_longitude': originLongitude,
      'destination': destination,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'delivery_date': deliveryDate,
      'weight': weight,
      'expected_price': expectedPrice,
      'image_url': imageUrl,
      'special_instructions': specialInstructions,
      'status': status,
      'distance_km': distanceKm,
      'calculated_price': calculatedPrice,
      'created_at': createdAt,
    };
  }
}

// Rest of the classes remain the same...
class OrderCreateRequest {
  final int userId;
  final String origin;
  final double originLatitude;
  final double originLongitude;
  final String destination;
  final double destinationLatitude;
  final double destinationLongitude;
  final String deliveryDate;
  final double weight;
  final String imageUrl;
  final String? specialInstructions;

  OrderCreateRequest({
    required this.userId,
    required this.origin,
    required this.originLatitude,
    required this.originLongitude,
    required this.destination,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.deliveryDate,
    required this.weight,
    required this.imageUrl,
    this.specialInstructions,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'userId': userId,
      'origin': origin,
      'origin_latitude': originLatitude,
      'origin_longitude': originLongitude,
      'destination': destination,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'delivery_date': deliveryDate,
      'weight': weight,
      'image_url': imageUrl,
    };

    if (specialInstructions != null && specialInstructions!.isNotEmpty) {
      map['special_instructions'] = specialInstructions;
    }

    print('📤 Request JSON: $map');
    return map;
  }
}

class OrderCreateResponse {
  final String message;
  final int orderId;

  OrderCreateResponse({
    required this.message,
    required this.orderId,
  });

  factory OrderCreateResponse.fromJson(Map<String, dynamic> json) {
    return OrderCreateResponse(
      message: json['message'] ?? '',
      orderId: json['orderId'] ?? 0,
    );
  }
}

class OrderUpdateRequest {
  final String? origin;
  final double? originLatitude;
  final double? originLongitude;
  final String? destination;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? deliveryDate;
  final double? weight;
  final String? imageUrl;
  final String? specialInstructions;
  final String? status;

  OrderUpdateRequest({
    this.origin,
    this.originLatitude,
    this.originLongitude,
    this.destination,
    this.destinationLatitude,
    this.destinationLongitude,
    this.deliveryDate,
    this.weight,
    this.imageUrl,
    this.specialInstructions,
    this.status,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    if (origin != null) map['origin'] = origin;
    if (originLatitude != null) map['origin_latitude'] = originLatitude;
    if (originLongitude != null) map['origin_longitude'] = originLongitude;
    if (destination != null) map['destination'] = destination;
    if (destinationLatitude != null) map['destination_latitude'] = destinationLatitude;
    if (destinationLongitude != null) map['destination_longitude'] = destinationLongitude;
    if (deliveryDate != null) map['delivery_date'] = deliveryDate;
    if (weight != null) map['weight'] = weight;
    if (imageUrl != null) map['image_url'] = imageUrl;
    if (specialInstructions != null) map['special_instructions'] = specialInstructions;
    if (status != null) map['status'] = status;

    print('📤 Update Request JSON: $map');
    return map;
  }

  factory OrderUpdateRequest.fromJson(Map<String, dynamic> json) {
    return OrderUpdateRequest(
      origin: json['origin'],
      originLatitude: json['origin_latitude'] != null
          ? Order._parseDouble(json['origin_latitude'])
          : null,
      originLongitude: json['origin_longitude'] != null
          ? Order._parseDouble(json['origin_longitude'])
          : null,
      destination: json['destination'],
      destinationLatitude: json['destination_latitude'] != null
          ? Order._parseDouble(json['destination_latitude'])
          : null,
      destinationLongitude: json['destination_longitude'] != null
          ? Order._parseDouble(json['destination_longitude'])
          : null,
      deliveryDate: json['delivery_date'],
      weight: json['weight'] != null
          ? Order._parseDouble(json['weight'])
          : null,
      imageUrl: json['image_url'],
      specialInstructions: json['special_instructions'],
      status: json['status'],
    );
  }
}

class OrderUpdateResponse {
  final String message;

  OrderUpdateResponse({required this.message});

  factory OrderUpdateResponse.fromJson(Map<String, dynamic> json) {
    return OrderUpdateResponse(
      message: json['message'] ?? '',
    );
  }
}