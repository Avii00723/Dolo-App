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
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.createOrder}'),
      );

      // Add text fields
      request.fields['userHashedId'] = order.userHashedId;
      request.fields['item_description'] = order.itemDescription;
      request.fields['origin'] = order.origin;
      request.fields['origin_latitude'] = order.originLatitude.toString();
      request.fields['origin_longitude'] = order.originLongitude.toString();
      request.fields['destination'] = order.destination;
      request.fields['destination_latitude'] = order.destinationLatitude.toString();
      request.fields['destination_longitude'] = order.destinationLongitude.toString();

      // Datetimes
      request.fields['pickup_datetime'] = '${order.pickupDate}T${order.pickupTime}';
      request.fields['delivery_datetime'] = '${order.deliveryDate}T${order.deliveryTime}';

      request.fields['weight'] = order.weight;
      request.fields['category'] = order.category;
      request.fields['is_urgent'] = order.isUrgent.toString();

      if (order.actualWeight != null) {
        request.fields['actual_weight'] = order.actualWeight.toString();
      }

      if (order.customCategory != null && order.customCategory!.isNotEmpty) {
        request.fields['customCategory'] = order.customCategory!;
      }

      if (order.preferenceTransport != null && order.preferenceTransport!.isNotEmpty) {
        for (int i = 0; i < order.preferenceTransport!.length; i++) {
          request.fields['preference_transport[$i]'] = order.preferenceTransport![i];
        }
      }

      if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) {
        request.fields['special_instructions'] = order.specialInstructions!;
      }

      // Add images
      if (order.images.isNotEmpty) {
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
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        return OrderCreateResponse.fromJson(jsonData);
      } else if (response.statusCode == 403) {
        throw Exception('KYC_NOT_APPROVED');
      } else if (response.statusCode == 400) {
        final jsonData = json.decode(response.body);
        throw Exception(jsonData['error'] ?? jsonData['message'] ?? 'Missing required fields');
      } else {
        throw Exception('Failed to create order: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ CREATE ORDER EXCEPTION: $e');
      rethrow;
    }
  }

  Future<bool> completeOrder(String orderId, String userHashedId) async {
    final endpoint = '${ApiConstants.completeOrder}/$orderId';
    try {
      final response = await _api.put(
        endpoint,
        queryParameters: {'userHashedId': userHashedId},
        parser: (json) => json,
      );

      if (!response.success) {
        if (response.statusCode == 403 && response.error?.contains('KYC') == true) {
          throw Exception('KYC_NOT_APPROVED');
        }
        if (response.statusCode == 404) throw Exception('ORDER_NOT_FOUND');
        throw Exception(response.error ?? 'Failed to complete order');
      }
      return response.success;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteOrder(String orderId, String userHashedId) async {
    final endpoint = '${ApiConstants.deleteOrder}/$orderId';
    try {
      final response = await _api.delete(
        endpoint,
        queryParameters: {'userHashedId': userHashedId},
        parser: (json) => OrderDeleteResponse.fromJson(json),
      );

      if (!response.success) {
        if (response.statusCode == 403 && response.error?.contains('KYC') == true) {
          throw Exception('KYC_NOT_APPROVED');
        }
        if (response.statusCode == 404) throw Exception('ORDER_NOT_FOUND');
        throw Exception(response.error ?? 'Failed to delete order');
      }
      return response.success;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Order>> searchOrders({
    required String origin,
    required String destination,
    required String departureDate,
    required String departureTime,
    required String pickupDate,
    required String pickupTime,
    required String deliveryDate,
    required String deliveryTime,
    required double originLatitude,
    required double originLongitude,
    required String vehicle,
    required String userId,
    List<String>? stopovers,
  }) async {
    String departureDatetime = '${departureDate}T$departureTime';
    String pickupDatetime = '${pickupDate}T$pickupTime';
    String deliveryDatetime = '${deliveryDate}T$deliveryTime';

    try {
      final Map<String, dynamic> queryParams = {
        'origin': origin,
        'destination': destination,
        'departure_datetime': departureDatetime,
        'pickup_datetime': pickupDatetime,
        'delivery_datetime': deliveryDatetime,
        'origin_latitude': originLatitude.toString(),
        'origin_longitude': originLongitude.toString(),
        'vehicle': vehicle,
        'userId': userId,
      };

      if (stopovers != null && stopovers.isNotEmpty) {
        queryParams['stopovers'] = stopovers;
      }

      final response = await _api.get(
        ApiConstants.searchOrders,
        queryParameters: queryParams,
        parser: (json) {
          if (json['orders'] is List) {
            return (json['orders'] as List).map((e) => Order.fromJson(e)).toList();
          }
          return <Order>[];
        },
      );

      return response.success ? (response.data as List<Order>) : [];
    } catch (e) {
      return [];
    }
  }

  Future<OrderUpdateResponse?> updateOrder(String orderId, OrderUpdateRequest order) async {
    final endpoint = '${ApiConstants.updateOrder}/$orderId';
    try {
      final response = await _api.put(
        endpoint,
        body: order.toJson(),
        parser: (json) => OrderUpdateResponse.fromJson(json),
      );
      return response.success ? response.data : null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Order>> getMyOrders(String userHashedId) async {
    try {
      final response = await _api.get(
        ApiConstants.myOrders,
        queryParameters: {'userHashedId': userHashedId},
        parser: (json) {
          if (json != null && json['orders'] is List) {
            final List<Order> orders = [];
            for (var item in (json['orders'] as List)) {
              try {
                orders.add(Order.fromJson(item));
              } catch (e) {
                print('Error parsing order: $e');
              }
            }
            return orders;
          }
          return <Order>[];
        },
      );
      return response.success ? (response.data as List<Order>? ?? []) : [];
    } catch (e) {
      return [];
    }
  }
}
