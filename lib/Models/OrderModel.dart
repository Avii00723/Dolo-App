import 'package:flutter/material.dart';
import 'dart:io';

class Order {
  final String id;
  final String userName;
  final String itemDescription;
  final String origin;
  final double originLatitude;
  final double originLongitude;
  final String destination;
  final double destinationLatitude;
  final double destinationLongitude;
  final String deliveryDate;
  final String? deliveryTime;
  final String? departureDate; 
  final String? departureTime; 
  final String weight; // API values: "below 2kg", "2-5kg", "5-10kg", "more than 10kg"
  final int? expectedPrice;
  final String imageUrl;
  final List<String>? imageUrls; 
  final String specialInstructions;
  final String status;
  final String? category; // API values: "technology", "documents", "clothing", "fragile", "food", "other"
  final String? subcategory;
  final double? distanceKm;
  final double? calculatedPrice;
  final String? createdAt;
  final String transportMode;
  final List<String>? preferenceTransport;
  final bool? isUrgent;
  final String? ownerName; 
  final double? ownerRating; 
  final String? deliveryOtp; // Added field

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
    this.deliveryTime,
    this.departureDate,
    this.departureTime,
    required this.weight,
    this.expectedPrice,
    required this.imageUrl,
    this.imageUrls,
    required this.specialInstructions,
    required this.status,
    this.category,
    this.subcategory,
    this.distanceKm,
    this.calculatedPrice,
    this.createdAt,
    this.transportMode = 'Car',
    this.preferenceTransport,
    this.isUrgent,
    this.ownerName,
    this.ownerRating,
    this.deliveryOtp, // Added to constructor
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Parse preference_transport
    List<String>? preferenceTransport;
    if (json['preference_transport'] != null) {
      if (json['preference_transport'] is String) {
        preferenceTransport = [json['preference_transport'] as String];
      } else if (json['preference_transport'] is List) {
        preferenceTransport = List<String>.from(json['preference_transport']);
      }
    }

    // Parse is_urgent
    bool? isUrgent;
    if (json['is_urgent'] != null) {
      if (json['is_urgent'] is bool) {
        isUrgent = json['is_urgent'] as bool;
      } else if (json['is_urgent'] is int) {
        isUrgent = json['is_urgent'] == 1;
      }
    }

    final parsedId = json['orderId']?.toString() ??
        json['hashed_id']?.toString() ??
        json['id']?.toString() ??
        '';

    String deliveryDate = '';
    String? deliveryTime;
    String? departureDate;
    String? departureTime;

    // Parse delivery_datetime
    if (json['delivery_datetime'] != null &&
        json['delivery_datetime'].toString().isNotEmpty) {
      try {
        String datetime = json['delivery_datetime'].toString();
        datetime = datetime.replaceAll('.000Z', '').replaceAll('Z', '').trim();

        if (datetime.contains('T')) {
          final parts = datetime.split('T');
          deliveryDate = parts[0].trim();
          if (parts.length > 1 && parts[1].isNotEmpty) {
            deliveryTime = parts[1].trim();
          }
        } else {
          deliveryDate = datetime;
        }
      } catch (e) {
        debugPrint('Error parsing delivery_datetime: $e');
      }
    }

    // Parse pickup_datetime
    if (json['pickup_datetime'] != null &&
        json['pickup_datetime'].toString().isNotEmpty) {
      try {
        String datetime = json['pickup_datetime'].toString();
        datetime = datetime.replaceAll('.000Z', '').replaceAll('Z', '').trim();

        if (datetime.contains('T')) {
          final parts = datetime.split('T');
          departureDate = parts[0].trim();
          if (parts.length > 1 && parts[1].isNotEmpty) {
            departureTime = parts[1].trim();
          }
        } else {
          departureDate = datetime;
        }
      } catch (e) {
        debugPrint('Error parsing pickup_datetime: $e');
      }
    }

    if (deliveryDate.isEmpty && json['delivery_date'] != null) {
      deliveryDate = json['delivery_date'].toString().trim();
    }

    if ((deliveryTime == null || deliveryTime.isEmpty) &&
        json['delivery_time'] != null) {
      deliveryTime = json['delivery_time'].toString().trim();
    }

    if (deliveryDate.isEmpty) {
      deliveryDate = 'N/A';
    }

    // Improve Category / Item Description mapping logic
    String? apiCategory = json['category']?.toString();
    String? rawItemDesc = json['item_description']?.toString();
    String mappedDescription = 'Package';

    if (rawItemDesc != null && rawItemDesc.isNotEmpty) {
      mappedDescription = rawItemDesc;
    } else if (apiCategory != null && apiCategory.isNotEmpty) {
      // Try to find the user-friendly name from our predefined categories
      try {
        mappedDescription = orderCategories
            .firstWhere((c) => c.apiValue.toLowerCase() == apiCategory.toLowerCase())
            .name;
      } catch (_) {
        // Fallback: Capitalize technical category string
        mappedDescription = apiCategory[0].toUpperCase() + apiCategory.substring(1);
      }
    }

    return Order(
      id: parsedId,
      userName: json['user_name'] ?? json['order_creator_name'] ?? '',
      itemDescription: mappedDescription,
      origin: json['origin'] ?? '',
      originLatitude: _parseDouble(json['origin_latitude']),
      originLongitude: _parseDouble(json['origin_longitude']),
      destination: json['destination'] ?? '',
      destinationLatitude: _parseDouble(json['destination_latitude']),
      destinationLongitude: _parseDouble(json['destination_longitude']),
      deliveryDate: deliveryDate,
      deliveryTime: deliveryTime,
      departureDate: departureDate,
      departureTime: departureTime,
      weight: json['weight']?.toString() ?? '0kg',
      expectedPrice: json['expected_price'] != null
          ? _parseInt(json['expected_price'])
          : null,
      imageUrl: json['image_url'] ?? '',
      imageUrls: json['image_urls'] != null ? List<String>.from(json['image_urls']) : null,
      specialInstructions: json['special_instructions'] ?? '',
      status: json['status'] ?? '',
      category: apiCategory,
      subcategory: json['subcategory'],
      distanceKm: json['distance_km'] != null
          ? _parseDouble(json['distance_km'])
          : null,
      calculatedPrice: json['calculated_price'] != null
          ? _parseDouble(json['calculated_price'])
          : null,
      createdAt: json['created_at'],
      transportMode: json['transport_mode'] ?? 'Car',
      preferenceTransport: preferenceTransport,
      isUrgent: isUrgent,
      ownerName: json['order_creator_name'] ?? json['user_name'],
      ownerRating: _parseDouble(json['owner_rating'] ?? 0.0),
      deliveryOtp: _parseDeliveryOtp(json),
    );
  }

  static String? _parseDeliveryOtp(Map<String, dynamic> json) {
    for (final key in const [
      'delivery_otp',
      'deliveryOtp',
      'otp',
      'order_otp',
      'orderOtp',
    ]) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

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
      'delivery_time': deliveryTime,
      'weight': weight,
      'expected_price': expectedPrice,
      'image_url': imageUrl,
      'special_instructions': specialInstructions,
      'status': status,
      'category': category,
      'subcategory': subcategory,
      'distance_km': distanceKm,
      'calculated_price': calculatedPrice,
      'created_at': createdAt,
      'transport_mode': transportMode,
      'preference_transport': preferenceTransport,
      'is_urgent': isUrgent,
      'delivery_otp': deliveryOtp,
    };
  }
}

class OrderMainCategory {
  final String name;
  final String apiValue;
  final String icon;
  final Color color;
  final List<OrderSubCategory> subCategories;

  OrderMainCategory({
    required this.name,
    required this.apiValue,
    required this.icon,
    required this.color,
    required this.subCategories,
  });
}

class OrderSubCategory {
  final String name;
  final String apiValue;
  final String description;
  final String icon;

  OrderSubCategory({
    required this.name,
    required this.apiValue,
    required this.description,
    required this.icon,
  });
}

final List<OrderMainCategory> orderCategories = [
  OrderMainCategory(
    name: 'Electronics',
    apiValue: 'technology', 
    icon: '⚡',
    color: const Color(0xFF2196F3),
    subCategories: [
      OrderSubCategory(
          name: 'Refrigerator',
          apiValue: 'technology',
          description: 'Fridge or freezer',
          icon: '🧊'),
      OrderSubCategory(
          name: 'Television',
          apiValue: 'technology',
          description: 'TV or monitor',
          icon: '📺'),
      OrderSubCategory(
          name: 'Washing Machine',
          apiValue: 'technology',
          description: 'Washer or dryer',
          icon: '🧺'),
      OrderSubCategory(
          name: 'Air Conditioner',
          apiValue: 'technology',
          description: 'AC unit',
          icon: '❄️'),
      OrderSubCategory(
          name: 'Microwave',
          apiValue: 'technology',
          description: 'Microwave oven',
          icon: '🔥'),
      OrderSubCategory(
          name: 'Laptop',
          apiValue: 'technology',
          description: 'Computer or laptop',
          icon: '💻'),
      OrderSubCategory(
          name: 'Other Electronics',
          apiValue: 'technology',
          description: 'Other electronic items',
          icon: '📱'),
    ],
  ),
  OrderMainCategory(
    name: 'Furniture',
    apiValue: 'other', 
    icon: '🛋️',
    color: const Color(0xFF795548),
    subCategories: [
      OrderSubCategory(
          name: 'Sofa',
          apiValue: 'other',
          description: 'Couch or sofa set',
          icon: '🛋️'),
      OrderSubCategory(
          name: 'Bed',
          apiValue: 'other',
          description: 'Bed or mattress',
          icon: '🛏️'),
      OrderSubCategory(
          name: 'Table',
          apiValue: 'other',
          description: 'Dining or coffee table',
          icon: '🪑'),
      OrderSubCategory(
          name: 'Chair',
          apiValue: 'other',
          description: 'Chair or stool',
          icon: '💺'),
      OrderSubCategory(
          name: 'Wardrobe',
          apiValue: 'other',
          description: 'Closet or wardrobe',
          icon: '🚪'),
      OrderSubCategory(
          name: 'Other Furniture',
          apiValue: 'other',
          description: 'Other furniture items',
          icon: '🪑'),
    ],
  ),
  OrderMainCategory(
    name: 'Documents',
    apiValue: 'documents', 
    icon: '📄',
    color: const Color(0xFF4CAF50),
    subCategories: [
      OrderSubCategory(
          name: 'Legal Papers',
          apiValue: 'documents',
          description: 'Contracts, agreements',
          icon: '📃'),
      OrderSubCategory(
          name: 'Certificates',
          apiValue: 'documents',
          description: 'Educational, medical docs',
          icon: '🎓'),
      OrderSubCategory(
          name: 'Files & Folders',
          apiValue: 'documents',
          description: 'Office documents',
          icon: '📁'),
      OrderSubCategory(
          name: 'Books',
          apiValue: 'documents',
          description: 'Books or magazines',
          icon: '📚'),
      OrderSubCategory(
          name: 'Other Documents',
          apiValue: 'documents',
          description: 'Other paper items',
          icon: '📄'),
    ],
  ),
  OrderMainCategory(
    name: 'Fragile Items',
    apiValue: 'fragile', 
    icon: '📦',
    color: const Color(0xFFE91E63),
    subCategories: [
      OrderSubCategory(
          name: 'Glassware',
          apiValue: 'fragile',
          description: 'Glass items, mirrors',
          icon: '🍷'),
      OrderSubCategory(
          name: 'Ceramics',
          apiValue: 'fragile',
          description: 'Pottery, vases',
          icon: '🏺'),
      OrderSubCategory(
          name: 'Artwork',
          apiValue: 'fragile',
          description: 'Paintings, sculptures',
          icon: '🎨'),
      OrderSubCategory(
          name: 'Antiques',
          apiValue: 'fragile',
          description: 'Vintage collectibles',
          icon: '🛍️'),
      OrderSubCategory(
          name: 'Other Fragile',
          apiValue: 'fragile',
          description: 'Other delicate items',
          icon: '⚠️'),
    ],
  ),
  OrderMainCategory(
    name: 'Clothing',
    apiValue: 'clothing', 
    icon: '👕',
    color: const Color(0xFF9C27B0),
    subCategories: [
      OrderSubCategory(
          name: 'Clothes',
          apiValue: 'clothing',
          description: 'Shirts, pants, dresses',
          icon: '👕'),
      OrderSubCategory(
          name: 'Shoes',
          apiValue: 'clothing',
          description: 'Footwear',
          icon: '👟'),
      OrderSubCategory(
          name: 'Accessories',
          apiValue: 'clothing',
          description: 'Bags, belts, jewelry',
          icon: '👜'),
      OrderSubCategory(
          name: 'Textiles',
          apiValue: 'clothing',
          description: 'Fabrics, linens',
          icon: '🧵'),
    ],
  ),
  OrderMainCategory(
    name: 'Food Items',
    apiValue: 'food', 
    icon: '🍱',
    color: const Color(0xFFFF9800),
    subCategories: [
      OrderSubCategory(
          name: 'Perishable Food',
          apiValue: 'food',
          description: 'Fresh food items',
          icon: '🥗'),
      OrderSubCategory(
          name: 'Packaged Food',
          apiValue: 'food',
          description: 'Sealed packages',
          icon: '📦'),
      OrderSubCategory(
          name: 'Beverages',
          apiValue: 'food',
          description: 'Drinks and liquids',
          icon: '🥤'),
    ],
  ),
  OrderMainCategory(
    name: 'Others',
    apiValue: 'other',
    icon: '📦',
    color: const Color(0xFF9E9E9E),
    subCategories: [
      OrderSubCategory(
          name: 'Sports Equipment',
          apiValue: 'other',
          description: 'Sports gear',
          icon: '⚽'),
      OrderSubCategory(
          name: 'Kitchen Items',
          apiValue: 'other',
          description: 'Utensils, cookware',
          icon: '🍳'),
      OrderSubCategory(
          name: 'Plants',
          apiValue: 'other',
          description: 'Indoor or outdoor plants',
          icon: '🪴'),
      OrderSubCategory(
          name: 'Miscellaneous',
          apiValue: 'other',
          description: 'Other items',
          icon: '📦'),
    ],
  ),
];

class OrderCreateRequest {
  final String userHashedId;
  final String itemDescription;
  final String origin;
  final double originLatitude;
  final double originLongitude;
  final String destination;
  final double destinationLatitude;
  final double destinationLongitude;
  final String pickupDate;
  final String pickupTime;
  final String deliveryDate;
  final String deliveryTime;
  final String weight;
  final double? actualWeight;
  final String category;
  final String? customCategory;
  final List<String>? preferenceTransport;
  final bool isUrgent;
  final List<File> images;
  final String? specialInstructions;

  OrderCreateRequest({
    required this.userHashedId,
    required this.itemDescription,
    required this.origin,
    required this.originLatitude,
    required this.originLongitude,
    required this.destination,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.pickupDate,
    required this.pickupTime,
    required this.deliveryDate,
    required this.deliveryTime,
    required this.weight,
    this.actualWeight,
    required this.category,
    this.customCategory,
    this.preferenceTransport,
    this.isUrgent = false,
    this.images = const [],
    this.specialInstructions,
  });

  Map<String, dynamic> toJson() {
    final map = {
      'userHashedId': userHashedId,
      'item_description': itemDescription,
      'origin': origin,
      'origin_latitude': originLatitude,
      'origin_longitude': originLongitude,
      'destination': destination,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'pickup_date': pickupDate,
      'pickup_time': pickupTime,
      'delivery_date': deliveryDate,
      'delivery_time': deliveryTime,
      'weight': weight,
      'category': category,
      'is_urgent': isUrgent,
    };

    if (actualWeight != null) map['actual_weight'] = actualWeight!;
    if (customCategory != null && customCategory!.isNotEmpty)
      map['customCategory'] = customCategory!;
    if (preferenceTransport != null && preferenceTransport!.isNotEmpty)
      map['preference_transport'] = preferenceTransport!;
    if (specialInstructions != null && specialInstructions!.isNotEmpty)
      map['special_instructions'] = specialInstructions!;

    return map;
  }
}

class OrderCreateResponse {
  final String message;
  final String orderId;
  final List<String>? imageUrls;

  OrderCreateResponse({
    required this.message,
    required this.orderId,
    this.imageUrls,
  });

  factory OrderCreateResponse.fromJson(Map<String, dynamic> json) {
    List<String>? urls;
    if (json['image_urls'] != null && json['image_urls'] is List) {
      urls = List<String>.from(json['image_urls']);
    } else if (json['image_url'] != null && json['image_url'] is String) {
      urls = [json['image_url'] as String];
    }

    return OrderCreateResponse(
      message: json['message'] ?? '',
      orderId: json['orderId']?.toString() ?? '',
      imageUrls: urls,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'orderId': orderId,
      'image_urls': imageUrls,
    };
  }
}

class OrderUpdateRequest {
  final String userHashedId;
  final String itemDescription;
  final String origin;
  final double originLatitude;
  final double originLongitude;
  final String destination;
  final double destinationLatitude;
  final double destinationLongitude;
  final String deliveryDate;
  final String weight;
  final String? category;
  final String? subcategory;
  final String? imageUrl;
  final String? specialInstructions;

  OrderUpdateRequest({
    required this.userHashedId,
    required this.itemDescription,
    required this.origin,
    required this.originLatitude,
    required this.originLongitude,
    required this.destination,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.deliveryDate,
    required this.weight,
    this.category,
    this.subcategory,
    this.imageUrl,
    this.specialInstructions,
  });

  Map<String, dynamic> toJson() {
    final map = {
      'userHashedId': userHashedId,
      'item_description': itemDescription,
      'origin': origin,
      'origin_latitude': originLatitude,
      'origin_longitude': originLongitude,
      'destination': destination,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'delivery_date': deliveryDate,
      'weight': weight,
    };

    if (category != null) map['category'] = category!;
    if (subcategory != null) map['subcategory'] = subcategory!;
    if (imageUrl != null && imageUrl!.isNotEmpty) map['image_url'] = imageUrl!;
    if (specialInstructions != null && specialInstructions!.isNotEmpty)
      map['special_instructions'] = specialInstructions!;

    return map;
  }
}

class OrderDeleteResponse {
  final String message;

  OrderDeleteResponse({required this.message});

  factory OrderDeleteResponse.fromJson(Map<String, dynamic> json) {
    return OrderDeleteResponse(
      message: json['message'] ?? 'Order deleted successfully',
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

enum OrderStatus {
  pending,
  accepted,
  booked,
  delivered;

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.booked:
        return 'Booked';
      case OrderStatus.delivered:
        return 'Delivered';
    }
  }

  Color get statusColor {
    switch (this) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.accepted:
        return Colors.blue;
      case OrderStatus.booked:
        return Colors.purple;
      case OrderStatus.delivered:
        return Colors.green;

    }
  }
}
