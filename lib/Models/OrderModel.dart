import 'package:flutter/material.dart';
import 'dart:io';

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
  final String? category; // Will store "category,subcategory" format
  final double? distanceKm;
  final double? calculatedPrice;
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
    this.category,
    this.distanceKm,
    this.calculatedPrice,
    this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? 0,
      userName: json['user_name'] ?? '',
      itemDescription: json['item_description'] ?? 'Package',
      origin: json['origin'] ?? '',
      originLatitude: _parseDouble(json['origin_latitude']),
      originLongitude: _parseDouble(json['origin_longitude']),
      destination: json['destination'] ?? '',
      destinationLatitude: _parseDouble(json['destination_latitude']),
      destinationLongitude: _parseDouble(json['destination_longitude']),
      deliveryDate: json['delivery_date'] ?? '',
      weight: _parseDouble(json['weight']),
      expectedPrice: _parseInt(json['expected_price']),
      imageUrl: json['image_url'] ?? '',
      specialInstructions: json['special_instructions'] ?? '',
      status: json['status'] ?? '',
      category: json['category'],
      distanceKm: json['distance_km'] != null ? _parseDouble(json['distance_km']) : null,
      calculatedPrice: json['calculated_price'] != null ? _parseDouble(json['calculated_price']) : null,
      createdAt: json['created_at'],
    );
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
      'weight': weight,
      'expected_price': expectedPrice,
      'image_url': imageUrl,
      'special_instructions': specialInstructions,
      'status': status,
      'category': category,
      'distance_km': distanceKm,
      'calculated_price': calculatedPrice,
      'created_at': createdAt,
    };
  }
}

// Main Category Class
class OrderMainCategory {
  final String name;
  final String icon;
  final Color color;
  final List<OrderSubCategory> subCategories;

  OrderMainCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.subCategories,
  });
}

// SubCategory Class
class OrderSubCategory {
  final String name;
  final String description;
  final String icon;

  OrderSubCategory({
    required this.name,
    required this.description,
    required this.icon,
  });
}

// Predefined Categories with Subcategories
final List<OrderMainCategory> orderCategories = [
  OrderMainCategory(
    name: 'Electronics',
    icon: '⚡',
    color: const Color(0xFF2196F3),
    subCategories: [
      OrderSubCategory(name: 'Refrigerator', description: 'Fridge or freezer', icon: '🧊'),
      OrderSubCategory(name: 'Television', description: 'TV or monitor', icon: '📺'),
      OrderSubCategory(name: 'Washing Machine', description: 'Washer or dryer', icon: '🧺'),
      OrderSubCategory(name: 'Air Conditioner', description: 'AC unit', icon: '❄️'),
      OrderSubCategory(name: 'Microwave', description: 'Microwave oven', icon: '🔥'),
      OrderSubCategory(name: 'Laptop', description: 'Computer or laptop', icon: '💻'),
      OrderSubCategory(name: 'Other Electronics', description: 'Other electronic items', icon: '📱'),
    ],
  ),
  OrderMainCategory(
    name: 'Furniture',
    icon: '🛋️',
    color: const Color(0xFF795548),
    subCategories: [
      OrderSubCategory(name: 'Sofa', description: 'Couch or sofa set', icon: '🛋️'),
      OrderSubCategory(name: 'Bed', description: 'Bed or mattress', icon: '🛏️'),
      OrderSubCategory(name: 'Table', description: 'Dining or coffee table', icon: '🪑'),
      OrderSubCategory(name: 'Chair', description: 'Chair or stool', icon: '💺'),
      OrderSubCategory(name: 'Wardrobe', description: 'Closet or wardrobe', icon: '🚪'),
      OrderSubCategory(name: 'Other Furniture', description: 'Other furniture items', icon: '🪑'),
    ],
  ),
  OrderMainCategory(
    name: 'Documents',
    icon: '📄',
    color: const Color(0xFF4CAF50),
    subCategories: [
      OrderSubCategory(name: 'Legal Papers', description: 'Contracts, agreements', icon: '📝'),
      OrderSubCategory(name: 'Certificates', description: 'Educational, medical docs', icon: '🎓'),
      OrderSubCategory(name: 'Files & Folders', description: 'Office documents', icon: '📁'),
      OrderSubCategory(name: 'Books', description: 'Books or magazines', icon: '📚'),
      OrderSubCategory(name: 'Other Documents', description: 'Other paper items', icon: '📄'),
    ],
  ),
  OrderMainCategory(
    name: 'Fragile Items',
    icon: '📦',
    color: const Color(0xFFE91E63),
    subCategories: [
      OrderSubCategory(name: 'Glassware', description: 'Glass items, mirrors', icon: '🍷'),
      OrderSubCategory(name: 'Ceramics', description: 'Pottery, vases', icon: '🏺'),
      OrderSubCategory(name: 'Artwork', description: 'Paintings, sculptures', icon: '🎨'),
      OrderSubCategory(name: 'Antiques', description: 'Vintage collectibles', icon: '🏛️'),
      OrderSubCategory(name: 'Other Fragile', description: 'Other delicate items', icon: '⚠️'),
    ],
  ),
  OrderMainCategory(
    name: 'Others',
    icon: '📦',
    color: const Color(0xFF9E9E9E),
    subCategories: [
      OrderSubCategory(name: 'Clothing', description: 'Clothes, textiles', icon: '👕'),
      OrderSubCategory(name: 'Sports Equipment', description: 'Sports gear', icon: '⚽'),
      OrderSubCategory(name: 'Kitchen Items', description: 'Utensils, cookware', icon: '🍳'),
      OrderSubCategory(name: 'Plants', description: 'Indoor or outdoor plants', icon: '🪴'),
      OrderSubCategory(name: 'Miscellaneous', description: 'Other items', icon: '📦'),
    ],
  ),
];

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
  final String category; // Will be "Electronics,Refrigerator" format
  final List<File> images;
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
    required this.category,
    this.images = const [],
    this.specialInstructions,
  });

  Map<String, dynamic> toJson() {
    final map = {
      'userId': userId,
      'origin': origin,
      'origin_latitude': originLatitude,
      'origin_longitude': originLongitude,
      'destination': destination,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'delivery_date': deliveryDate,
      'weight': weight,
      'category': category, // Sends "Electronics,Refrigerator"
    };

    if (specialInstructions != null && specialInstructions!.isNotEmpty) {
      map['special_instructions'] = specialInstructions as Object;
    }

    print('📤 Request JSON: $map');
    return map;
  }
}

class OrderCreateResponse {
  final String message;
  final int orderId;
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
      print('📸 Parsed image_urls (array): $urls');
    } else if (json['image_url'] != null && json['image_url'] is String) {
      urls = [json['image_url'] as String];
      print('📸 Parsed image_url (string): ${json['image_url']}');
    }

    return OrderCreateResponse(
      message: json['message'] ?? '',
      orderId: json['orderId'] ?? 0,
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
  final int userId;
  final String origin;
  final double originLatitude;
  final double originLongitude;
  final String destination;
  final double destinationLatitude;
  final double destinationLongitude;
  final String deliveryDate;
  final double weight;
  final String? category;
  final String? imageUrl;
  final String? specialInstructions;

  OrderUpdateRequest({
    required this.userId,
    required this.origin,
    required this.originLatitude,
    required this.originLongitude,
    required this.destination,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.deliveryDate,
    required this.weight,
    this.category,
    this.imageUrl,
    this.specialInstructions,
  });

  Map<String, dynamic> toJson() {
    final map = {
      'userId': userId,
      'origin': origin,
      'origin_latitude': originLatitude,
      'origin_longitude': originLongitude,
      'destination': destination,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'delivery_date': deliveryDate,
      'weight': weight,
    };

    if (category != null) {
      map['category'] = category!;
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      map['image_url'] = imageUrl!;
    }

    if (specialInstructions != null && specialInstructions!.isNotEmpty) {
      map['special_instructions'] = specialInstructions!;
    }

    return map;
  }
}

class OrderDeleteRequest {
  final int userId;

  OrderDeleteRequest({required this.userId});

  Map<String, dynamic> toJson() {
    return {'userId': userId};
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
