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
  final String? deliveryTime; // Delivery time (HH:mm:ss format)
  final String weight; // Weight as string: "less than 5kg", "5-10kg", "more than 10kg"
  final int? expectedPrice; // Optional, not always returned by API
  final String imageUrl;
  final String specialInstructions;
  final String status;
  final String? category;
  final String? subcategory;
  final double? distanceKm;
  final double? calculatedPrice;
  final String? createdAt;
  final String transportMode;
  final List<String>? preferenceTransport; // Preferred transport modes
  final bool? isUrgent; // Urgent delivery flag

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
    required this.weight,
    this.expectedPrice,
    required this.imageUrl,
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
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Parse preference_transport (can be array or single string)
    List<String>? preferenceTransport;
    if (json['preference_transport'] != null) {
      if (json['preference_transport'] is String) {
        preferenceTransport = [json['preference_transport'] as String];
      } else if (json['preference_transport'] is List) {
        preferenceTransport = List<String>.from(json['preference_transport']);
      }
    }

    // Parse is_urgent (can be int 0/1 or boolean)
    bool? isUrgent;
    if (json['is_urgent'] != null) {
      if (json['is_urgent'] is bool) {
        isUrgent = json['is_urgent'] as bool;
      } else if (json['is_urgent'] is int) {
        isUrgent = json['is_urgent'] == 1;
      }
    }

    return Order(
      id: json['hashed_id']?.toString() ?? json['id']?.toString() ?? '',
      userName: json['user_name'] ?? '',
      itemDescription: json['item_description'] ?? 'Package',
      origin: json['origin'] ?? '',
      originLatitude: _parseDouble(json['origin_latitude']),
      originLongitude: _parseDouble(json['origin_longitude']),
      destination: json['destination'] ?? '',
      destinationLatitude: _parseDouble(json['destination_latitude']),
      destinationLongitude: _parseDouble(json['destination_longitude']),
      deliveryDate: json['delivery_date'] ?? '',
      deliveryTime: json['delivery_time'],
      weight: json['weight']?.toString() ?? '0kg',
      expectedPrice: json['expected_price'] != null ? _parseInt(json['expected_price']) : null,
      imageUrl: json['image_url'] ?? '',
      specialInstructions: json['special_instructions'] ?? '',
      status: json['status'] ?? '',
      category: json['category'],
      subcategory: json['subcategory'],
      distanceKm: json['distance_km'] != null ? _parseDouble(json['distance_km']) : null,
      calculatedPrice: json['calculated_price'] != null ? _parseDouble(json['calculated_price']) : null,
      createdAt: json['created_at'],
      transportMode: json['transport_mode'] ?? 'Car',
      preferenceTransport: preferenceTransport,
      isUrgent: isUrgent,
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
    };
  }
}

// Main Category Class
class OrderMainCategory {
  final String name;
  final String apiValue; // NEW: API category value
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

// SubCategory Class
class OrderSubCategory {
  final String name;
  final String apiValue; // NEW: API subcategory value
  final String description;
  final String icon;

  OrderSubCategory({
    required this.name,
    required this.apiValue,
    required this.description,
    required this.icon,
  });
}

// Predefined Categories with Subcategories (Updated for API)
final List<OrderMainCategory> orderCategories = [
  OrderMainCategory(
    name: 'Electronics',
    apiValue: 'technology', // Maps to API category
    icon: '⚡',
    color: const Color(0xFF2196F3),
    subCategories: [
      OrderSubCategory(name: 'Refrigerator', apiValue: 'Electronics', description: 'Fridge or freezer', icon: '🧊'),
      OrderSubCategory(name: 'Television', apiValue: 'Electronics', description: 'TV or monitor', icon: '📺'),
      OrderSubCategory(name: 'Washing Machine', apiValue: 'Electronics', description: 'Washer or dryer', icon: '🧺'),
      OrderSubCategory(name: 'Air Conditioner', apiValue: 'Electronics', description: 'AC unit', icon: '❄️'),
      OrderSubCategory(name: 'Microwave', apiValue: 'Electronics', description: 'Microwave oven', icon: '🔥'),
      OrderSubCategory(name: 'Laptop', apiValue: 'Electronics', description: 'Computer or laptop', icon: '💻'),
      OrderSubCategory(name: 'Other Electronics', apiValue: 'Electronics', description: 'Other electronic items', icon: '📱'),
    ],
  ),
  OrderMainCategory(
    name: 'Furniture',
    apiValue: 'other', // Maps to API category
    icon: '🛋️',
    color: const Color(0xFF795548),
    subCategories: [
      OrderSubCategory(name: 'Sofa', apiValue: 'Furniture', description: 'Couch or sofa set', icon: '🛋️'),
      OrderSubCategory(name: 'Bed', apiValue: 'Furniture', description: 'Bed or mattress', icon: '🛏️'),
      OrderSubCategory(name: 'Table', apiValue: 'Furniture', description: 'Dining or coffee table', icon: '🪑'),
      OrderSubCategory(name: 'Chair', apiValue: 'Furniture', description: 'Chair or stool', icon: '💺'),
      OrderSubCategory(name: 'Wardrobe', apiValue: 'Furniture', description: 'Closet or wardrobe', icon: '🚪'),
      OrderSubCategory(name: 'Other Furniture', apiValue: 'Furniture', description: 'Other furniture items', icon: '🪑'),
    ],
  ),
  OrderMainCategory(
    name: 'Documents',
    apiValue: 'documents', // Maps to API category
    icon: '📄',
    color: const Color(0xFF4CAF50),
    subCategories: [
      OrderSubCategory(name: 'Legal Papers', apiValue: 'Documents', description: 'Contracts, agreements', icon: '📃'),
      OrderSubCategory(name: 'Certificates', apiValue: 'Documents', description: 'Educational, medical docs', icon: '🎓'),
      OrderSubCategory(name: 'Files & Folders', apiValue: 'Documents', description: 'Office documents', icon: '📁'),
      OrderSubCategory(name: 'Books', apiValue: 'Documents', description: 'Books or magazines', icon: '📚'),
      OrderSubCategory(name: 'Other Documents', apiValue: 'Documents', description: 'Other paper items', icon: '📄'),
    ],
  ),
  OrderMainCategory(
    name: 'Fragile Items',
    apiValue: 'fragile', // Maps to API category
    icon: '📦',
    color: const Color(0xFFE91E63),
    subCategories: [
      OrderSubCategory(name: 'Glassware', apiValue: 'Others', description: 'Glass items, mirrors', icon: '🍷'),
      OrderSubCategory(name: 'Ceramics', apiValue: 'Others', description: 'Pottery, vases', icon: '🏺'),
      OrderSubCategory(name: 'Artwork', apiValue: 'Others', description: 'Paintings, sculptures', icon: '🎨'),
      OrderSubCategory(name: 'Antiques', apiValue: 'Others', description: 'Vintage collectibles', icon: '🛍️'),
      OrderSubCategory(name: 'Other Fragile', apiValue: 'Others', description: 'Other delicate items', icon: '⚠️'),
    ],
  ),
  OrderMainCategory(
    name: 'Clothing',
    apiValue: 'clothing', // Maps to API category
    icon: '👕',
    color: const Color(0xFF9C27B0),
    subCategories: [
      OrderSubCategory(name: 'Clothes', apiValue: 'Others', description: 'Shirts, pants, dresses', icon: '👕'),
      OrderSubCategory(name: 'Shoes', apiValue: 'Others', description: 'Footwear', icon: '👟'),
      OrderSubCategory(name: 'Accessories', apiValue: 'Others', description: 'Bags, belts, jewelry', icon: '👜'),
      OrderSubCategory(name: 'Textiles', apiValue: 'Others', description: 'Fabrics, linens', icon: '🧵'),
    ],
  ),
  OrderMainCategory(
    name: 'Food Items',
    apiValue: 'food', // Maps to API category
    icon: '🍱',
    color: const Color(0xFFFF9800),
    subCategories: [
      OrderSubCategory(name: 'Perishable Food', apiValue: 'Others', description: 'Fresh food items', icon: '🥗'),
      OrderSubCategory(name: 'Packaged Food', apiValue: 'Others', description: 'Sealed packages', icon: '📦'),
      OrderSubCategory(name: 'Beverages', apiValue: 'Others', description: 'Drinks and liquids', icon: '🥤'),
    ],
  ),
  OrderMainCategory(
    name: 'Others',
    apiValue: 'other', // Maps to API category
    icon: '📦',
    color: const Color(0xFF9E9E9E),
    subCategories: [
      OrderSubCategory(name: 'Sports Equipment', apiValue: 'Others', description: 'Sports gear', icon: '⚽'),
      OrderSubCategory(name: 'Kitchen Items', apiValue: 'Others', description: 'Utensils, cookware', icon: '🍳'),
      OrderSubCategory(name: 'Plants', apiValue: 'Others', description: 'Indoor or outdoor plants', icon: '🪴'),
      OrderSubCategory(name: 'Miscellaneous', apiValue: 'Others', description: 'Other items', icon: '📦'),
    ],
  ),
];

class OrderCreateRequest {
  final String userHashedId;
  final String origin;
  final double originLatitude;
  final double originLongitude;
  final String destination;
  final double destinationLatitude;
  final double destinationLongitude;
  final String deliveryDate;
  final String deliveryTime; // Required time field (HH:mm:ss format)
  final String weight; // String value: "less than 5kg", "5-10kg", "more than 10kg"
  final double? actualWeight; // Required only if weight is "more than 10kg"
  final String category; // API category value (fragile, technology, documents, food, clothing, other)
  final String? customCategory; // Required only if category is "other"
  final List<String>? preferenceTransport; // Optional: User's preferred transport modes (Car, Bike, Truck, etc.)
  final bool isUrgent; // If true, order is urgent. Default false
  final List<File> images;
  final String? specialInstructions;

  OrderCreateRequest({
    required this.userHashedId,
    required this.origin,
    required this.originLatitude,
    required this.originLongitude,
    required this.destination,
    required this.destinationLatitude,
    required this.destinationLongitude,
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
      'origin': origin,
      'origin_latitude': originLatitude,
      'origin_longitude': originLongitude,
      'destination': destination,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'delivery_date': deliveryDate,
      'delivery_time': deliveryTime,
      'weight': weight,
      'category': category,
      'is_urgent': isUrgent,
    };

    // Add actual_weight if weight is "more than 10kg"
    if (actualWeight != null) {
      map['actual_weight'] = actualWeight!;
    }

    // Add customCategory if category is "other"
    if (customCategory != null && customCategory!.isNotEmpty) {
      map['customCategory'] = customCategory!;
    }

    // Add preference_transport if provided
    if (preferenceTransport != null && preferenceTransport!.isNotEmpty) {
      map['preference_transport'] = preferenceTransport!;
    }

    if (specialInstructions != null && specialInstructions!.isNotEmpty) {
      map['special_instructions'] = specialInstructions!;
    }

    print('📤 Request JSON: $map');
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
      print('📸 Parsed image_urls (array): $urls');
    } else if (json['image_url'] != null && json['image_url'] is String) {
      urls = [json['image_url'] as String];
      print('📸 Parsed image_url (string): ${json['image_url']}');
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
  final String origin;
  final double originLatitude;
  final double originLongitude;
  final String destination;
  final double destinationLatitude;
  final double destinationLongitude;
  final String deliveryDate;
  final double weight;
  final String? category;
  final String? subcategory;
  final String? imageUrl;
  final String? specialInstructions;

  OrderUpdateRequest({
    required this.userHashedId,
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

    if (subcategory != null) {
      map['subcategory'] = subcategory!;
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
  final String userHashedId;

  OrderDeleteRequest({required this.userHashedId});

  Map<String, dynamic> toJson() {
    return {'userHashedId': userHashedId};
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