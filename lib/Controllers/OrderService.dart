import 'dart:convert';

import 'package:http/http.dart' as http;

import '../Constants/ApiService.dart';
import '../Constants/ApiConstants.dart';
import '../Models/OrderModel.dart';

class OrderService {
  final ApiService _api = ApiService();

  Future<OrderCreateResponse?> createOrder(OrderCreateRequest order) async {
    print('=== CREATE ORDER API CALL (MULTIPART) ===');
    print('Endpoint: ${ApiConstants.createOrder}');

    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.createOrder}'),
      );

      // Add text fields
      request.fields['userHashedId'] = order.userHashedId;
      request.fields['origin'] = order.origin;
      request.fields['origin_latitude'] = order.originLatitude.toString();
      request.fields['origin_longitude'] = order.originLongitude.toString();
      request.fields['destination'] = order.destination;
      request.fields['destination_latitude'] =
          order.destinationLatitude.toString();
      request.fields['destination_longitude'] =
          order.destinationLongitude.toString();

      // Combine date and time into delivery_datetime in ISO 8601 format
      // Format: YYYY-MM-DDTHH:MM:SS (as per API documentation)
      String deliveryDatetime = '${order.deliveryDate}T${order.deliveryTime}';
      request.fields['delivery_datetime'] = deliveryDatetime;
      print('📅 delivery_datetime: $deliveryDatetime');

      request.fields['weight'] = order.weight; // String value now
      request.fields['category'] = order
          .category; // fragile, technology, documents, food, clothing, other
      request.fields['is_urgent'] = order.isUrgent.toString(); // Urgent flag

      // Add actual_weight if weight is "more than 10kg"
      if (order.actualWeight != null) {
        request.fields['actual_weight'] = order.actualWeight.toString();
      }

      // Add customCategory if category is "other"
      if (order.customCategory != null && order.customCategory!.isNotEmpty) {
        request.fields['customCategory'] = order.customCategory!;
      }

      // Add preference_transport if provided (array of strings)
      if (order.preferenceTransport != null &&
          order.preferenceTransport!.isNotEmpty) {
        for (int i = 0; i < order.preferenceTransport!.length; i++) {
          request.fields['preference_transport[$i]'] =
              order.preferenceTransport![i];
        }
        print(
            '✅ Added ${order.preferenceTransport!.length} preferred transport modes');
      }

      if (order.specialInstructions != null &&
          order.specialInstructions!.isNotEmpty) {
        request.fields['special_instructions'] = order.specialInstructions!;
      }

      // Add images if available
      if (order.images.isNotEmpty) {
        print('📸 Adding ${order.images.length} images to request');
        for (var image in order.images) {
          var stream = http.ByteStream(image.openRead());
          var length = await image.length();
          var multipartFile = http.MultipartFile(
            'images',
            stream,
            length,
            filename: image.path.split('/').last,
          );
          request.files.add(multipartFile);
          print('✅ Added image: ${image.path.split('/').last}');
        }
      } else {
        print('⚠️ No images to upload');
      }

      print('Request Fields: ${request.fields}');
      print('Request Files Count: ${request.files.length} images');

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('✅ CREATE ORDER SUCCESS');
        print('📦 Order ID: ${jsonData['orderId']}');

        // Log image URLs
        if (jsonData['image_urls'] != null) {
          print('📸 Uploaded images (array): ${jsonData['image_urls']}');
        } else if (jsonData['image_url'] != null) {
          print('📸 Uploaded image (single): ${jsonData['image_url']}');
        }

        return OrderCreateResponse.fromJson(jsonData);
      } else if (response.statusCode == 403) {
        json.decode(response.body);
        print('❌ CREATE ORDER FAILED - KYC NOT APPROVED');
        throw Exception('KYC_NOT_APPROVED');
      } else if (response.statusCode == 400) {
        final jsonData = json.decode(response.body);
        print('❌ CREATE ORDER FAILED - BAD REQUEST');
        throw Exception(jsonData['error'] ?? 'Missing required fields');
      } else {
        print('❌ CREATE ORDER FAILED');
        throw Exception('Failed to create order: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌ CREATE ORDER EXCEPTION: $e');
      print('Stack Trace: $stackTrace');
      rethrow;
    }
  }

  // Mark order as completed/delivered
  Future<bool> completeOrder(String orderId, String userHashedId) async {
    final endpoint = '${ApiConstants.completeOrder}/$orderId';
    print('=== COMPLETE ORDER API CALL ===');
    print('Endpoint: $endpoint');
    print('Order ID: $orderId');
    print('User Hashed ID: $userHashedId');

    try {
      final response = await _api.put(
        endpoint,
        queryParameters: {
          'userHashedId': userHashedId,
        },
        parser: (json) => json,
      );

      print('Response Success: ${response.success}');
      print('Response Data: ${response.data}');

      if (!response.success) {
        print('❌ COMPLETE ORDER FAILED');
        print('Error: ${response.error}');
        print('Status Code: ${response.statusCode}');

        if (response.statusCode == 403 &&
            response.error?.contains('KYC') == true) {
          throw Exception('KYC_NOT_APPROVED');
        }

        if (response.statusCode == 404) {
          throw Exception('ORDER_NOT_FOUND');
        }

        throw Exception(response.error ?? 'Failed to complete order');
      } else {
        print('✅ COMPLETE ORDER SUCCESS');
      }

      return response.success;
    } catch (e, stackTrace) {
      print('❌ COMPLETE ORDER EXCEPTION: $e');
      print('Stack Trace: $stackTrace');
      rethrow;
    }
  }

  // Delete order using query parameters
  Future<bool> deleteOrder(String orderId, String userHashedId) async {
    final endpoint = '${ApiConstants.deleteOrder}/$orderId';
    print('=== DELETE ORDER API CALL ===');
    print('Endpoint: $endpoint');
    print('Order ID: $orderId');
    print('User Hashed ID: $userHashedId');

    try {
      final response = await _api.delete(
        endpoint,
        queryParameters: {
          'userHashedId': userHashedId,
        },
        parser: (json) => OrderDeleteResponse.fromJson(json),
      );

      print('Response Success: ${response.success}');
      print('Response Data: ${response.data}');

      if (!response.success) {
        print('❌ DELETE ORDER FAILED');
        print('Error: ${response.error}');
        print('Status Code: ${response.statusCode}');

        if (response.statusCode == 403 &&
            response.error?.contains('KYC') == true) {
          throw Exception('KYC_NOT_APPROVED');
        }

        if (response.statusCode == 404) {
          throw Exception('ORDER_NOT_FOUND');
        }

        if (response.statusCode == 400) {
          throw Exception('USER_ID_REQUIRED');
        }

        throw Exception(response.error ?? 'Failed to delete order');
      } else {
        print('✅ DELETE ORDER SUCCESS');
      }

      return response.success;
    } catch (e, stackTrace) {
      print('❌ DELETE ORDER EXCEPTION: $e');
      print('Stack Trace: $stackTrace');
      rethrow;
    }
  }

  // Search orders with vehicle parameter
  Future<List<Order>> searchOrders({
    required String origin,
    required String destination,
    required String departureDate, // NEW: Departure date
    required String departureTime, // NEW: Departure time
    required String deliveryDate,
    required String deliveryTime,
    required double originLatitude,
    required double originLongitude,
    required String vehicle,
    required String userId,
    String? stopovers, // Optional: Comma-separated list of stopover cities
  }) async {
    print('=== SEARCH ORDERS API CALL ===');
    print('Endpoint: ${ApiConstants.searchOrders}');

    // Combine date and time into ISO 8601 format (YYYY-MM-DDTHH:MM:SS)
    String departureDatetime = '${departureDate}T$departureTime';
    String deliveryDatetime = '${deliveryDate}T$deliveryTime';

    print('Query Parameters:');
    print(' - origin: $origin');
    print(' - destination: $destination');
    print(' - departure_datetime: $departureDatetime'); // NEW
    print(' - delivery_datetime: $deliveryDatetime');
    print(' - origin_latitude: $originLatitude');
    print(' - origin_longitude: $originLongitude');
    print(' - vehicle: $vehicle');
    print(' - userId: $userId');
    if (stopovers != null && stopovers.isNotEmpty) {
      print(' - stopovers: $stopovers');
    }

    try {
      // Build query parameters
      final queryParams = {
        'origin': origin,
        'destination': destination,
        'departure_datetime': departureDatetime, // NEW
        'delivery_datetime': deliveryDatetime,
        'origin_latitude': originLatitude.toString(),
        'origin_longitude': originLongitude.toString(),
        'vehicle': vehicle,
        'userId': userId,
      };

      // Add stopovers if provided
      if (stopovers != null && stopovers.isNotEmpty) {
        queryParams['stopovers'] = stopovers;
      }

      final response = await _api.get(
        ApiConstants.searchOrders,
        queryParameters: queryParams,
        parser: (json) {
          print('Raw JSON Response: $json');
          if (json['orders'] is List) {
            final orders =
                (json['orders'] as List).map((e) => Order.fromJson(e)).toList();
            print('Parsed Orders Count: ${orders.length}');
            return orders;
          }
          print('⚠️ No orders found in response');
          return [];
        },
      );

      print('Response Success: ${response.success}');
      if (!response.success) {
        print('❌ SEARCH ORDERS FAILED');
      } else {
        print('✅ SEARCH ORDERS SUCCESS');
        print('Total Orders: ${(response.data as List).length}');
      }

      return response.success ? (response.data as List<Order>) : [];
    } catch (e, stackTrace) {
      print('❌ SEARCH ORDERS EXCEPTION: $e');
      print('Stack Trace: $stackTrace');
      return [];
    }
  }

  // Update order
  Future<OrderUpdateResponse?> updateOrder(
      String orderId, OrderUpdateRequest order) async {
    final endpoint = '${ApiConstants.updateOrder}/$orderId';
    print('=== UPDATE ORDER API CALL ===');
    print('Endpoint: $endpoint');
    print('Order ID: $orderId');
    print('Request Body: ${order.toJson()}');

    try {
      final response = await _api.put(
        endpoint,
        body: order.toJson(),
        parser: (json) => OrderUpdateResponse.fromJson(json),
      );

      print('Response Success: ${response.success}');
      print('Response Data: ${response.data}');

      if (!response.success) {
        print('❌ UPDATE ORDER FAILED');
      } else {
        print('✅ UPDATE ORDER SUCCESS');
      }

      return response.success ? response.data : null;
    } catch (e, stackTrace) {
      print('❌ UPDATE ORDER EXCEPTION: $e');
      print('Stack Trace: $stackTrace');
      return null;
    }
  }

  // Get user's orders
  Future<List<Order>> getMyOrders(String userHashedId) async {
    print('=== GET MY ORDERS API CALL ===');
    print('Endpoint: ${ApiConstants.myOrders}');
    print('User Hashed ID: $userHashedId');

    try {
      final response = await _api.get(
        ApiConstants.myOrders,
        queryParameters: {'userHashedId': userHashedId},
        parser: (json) {
          print('Raw JSON Response: $json');
          if (json['orders'] is List) {
            final orders =
                (json['orders'] as List).map((e) => Order.fromJson(e)).toList();
            print('Parsed Orders Count: ${orders.length}');
            return orders;
          }
          print('⚠️ No orders found in response');
          return [];
        },
      );

      print('Response Success: ${response.success}');

      if (!response.success) {
        print('❌ GET MY ORDERS FAILED');
        print('Error: ${response.error}');
      } else {
        print('✅ GET MY ORDERS SUCCESS');
        print('Total Orders: ${(response.data as List<Order>).length}');
      }

      return response.success ? (response.data as List<Order>) : [];
    } catch (e, stackTrace) {
      print('❌ GET MY ORDERS EXCEPTION: $e');
      print('Stack Trace: $stackTrace');
      return [];
    }
  }
}
