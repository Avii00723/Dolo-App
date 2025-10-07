import '../Constants/ApiService.dart';
import '../Constants/ApiConstants.dart';
import '../Models/OrderModel.dart';

class OrderService {
  final ApiService _api = ApiService();

  // Create order
  // Create order with error handling
  Future<OrderCreateResponse?> createOrder(OrderCreateRequest order) async {
    print('=== CREATE ORDER API CALL ===');
    print('Endpoint: ${ApiConstants.createOrder}');
    print('Request Body: ${order.toJson()}');

    try {
      final response = await _api.post(
        ApiConstants.createOrder,
        body: order.toJson(),
        parser: (json) => OrderCreateResponse.fromJson(json),
      );

      print('Response Success: ${response.success}');
      print('Response Data: ${response.data}');

      if (!response.success) {
        print('❌ CREATE ORDER FAILED');
        print('Error: ${response.error}');
        print('Status Code: ${response.statusCode}');

        // Throw specific error for KYC
        if (response.statusCode == 403 && response.error?.contains('KYC') == true) {
          throw Exception('KYC_NOT_APPROVED');
        }

        throw Exception(response.error ?? 'Response not successful');
      } else {
        print('✅ CREATE ORDER SUCCESS');
      }

      return response.success ? response.data : null;
    } catch (e, stackTrace) {
      print('❌ CREATE ORDER EXCEPTION: $e');
      print('Stack Trace: $stackTrace');
      rethrow; // Rethrow to handle in UI
    }
  }

// Mark order as completed/delivered
  Future<bool> completeOrder(int orderId, int userId) async {
    final endpoint = '${ApiConstants.completeOrder}/$orderId';
    print('=== COMPLETE ORDER API CALL ===');
    print('Endpoint: $endpoint');
    print('Order ID: $orderId');
    print('User ID: $userId');

    try {
      final response = await _api.put(
        endpoint,
        body: {
          'userId': userId, // ✅ ADDED userId to body
        },
        parser: (json) => json,
      );

      print('Response Success: ${response.success}');
      print('Response Data: ${response.data}');

      if (!response.success) {
        print('❌ COMPLETE ORDER FAILED');
        print('Error: ${response.error}');
        print('Status Code: ${response.statusCode}');

        // Handle specific errors
        if (response.statusCode == 403 && response.error?.contains('KYC') == true) {
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

  // ✅ FIXED: Delete order using query parameters (RECOMMENDED)
  Future<bool> deleteOrder(int orderId, int userId) async {
    final endpoint = '${ApiConstants.deleteOrder}/$orderId';
    print('=== DELETE ORDER API CALL ===');
    print('Endpoint: $endpoint');
    print('Order ID: $orderId');
    print('User ID: $userId');

    try {
      final response = await _api.delete(
        endpoint,
        queryParameters: {
          'userId': userId.toString(),
        },
        parser: (json) => OrderDeleteResponse.fromJson(json),
      );

      print('Response Success: ${response.success}');
      print('Response Data: ${response.data}');

      if (!response.success) {
        print('❌ DELETE ORDER FAILED');
        print('Error: ${response.error}');
        print('Status Code: ${response.statusCode}');

        // Handle specific errors
        if (response.statusCode == 403 && response.error?.contains('KYC') == true) {
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

  // Search orders with vehicle and time_hours parameters
  // ✅ FIXED: Add userId parameter to searchOrders
  Future<List<Order>> searchOrders({
    required String origin,
    required String destination,
    required String deliveryDate,
    required double originLatitude,
    required double originLongitude,
    required String vehicle,
    required double timeHours,
    required int userId, // ✅ ADDED
  }) async {
    print('=== SEARCH ORDERS API CALL ===');
    print('Endpoint: ${ApiConstants.searchOrders}');
    print('Query Parameters:');
    print(' - origin: $origin');
    print(' - destination: $destination');
    print(' - delivery_date: $deliveryDate');
    print(' - origin_latitude: $originLatitude');
    print(' - origin_longitude: $originLongitude');
    print(' - vehicle: $vehicle');
    print(' - time_hours: $timeHours');
    print(' - userId: $userId'); // ✅ ADDED

    try {
      final response = await _api.get(
        ApiConstants.searchOrders,
        queryParameters: {
          'origin': origin,
          'destination': destination,
          'delivery_date': deliveryDate,
          'origin_latitude': originLatitude.toString(),
          'origin_longitude': originLongitude.toString(),
          'vehicle': vehicle,
          'time_hours': timeHours.toString(),
          'userId': userId.toString(), // ✅ ADDED
        },
        parser: (json) {
          print('Raw JSON Response: $json');
          if (json['orders'] is List) {
            final orders = (json['orders'] as List)
                .map((e) => Order.fromJson(e))
                .toList();
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
  Future<OrderUpdateResponse?> updateOrder(int orderId, OrderUpdateRequest order) async {
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

  // Get user's orders - FIXED
  Future<List<Order>> getMyOrders(int userId) async {
    print('=== GET MY ORDERS API CALL ===');
    print('Endpoint: ${ApiConstants.myOrders}');
    print('User ID: $userId');

    try {
      final response = await _api.get(
        ApiConstants.myOrders,
        queryParameters: {'userId': userId.toString()}, // Changed from 'user_id' to 'userId'
        parser: (json) {
          print('Raw JSON Response: $json');
          if (json['orders'] is List) {
            final orders = (json['orders'] as List)
                .map((e) => Order.fromJson(e))
                .toList();
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
