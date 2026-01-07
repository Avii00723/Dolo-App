import '../Constants/ApiService.dart';
import '../Constants/ApiConstants.dart';

class OrderTrackingService {
  final ApiService _api = ApiService();

  /// Confirm an order (Stage 0 -> Stage 1)
  /// POST /order-tracking/{orderId}/confirm
  Future<bool> confirmOrder(String orderId) async {
    final endpoint = '/order-tracking/$orderId/confirm';
    print('=== CONFIRM ORDER API CALL ===');
    print('Endpoint: $endpoint');
    print('Order ID: $orderId');

    try {
      final response = await _api.post(
        endpoint,
        parser: (json) => json,
      );

      print('Response Success: ${response.success}');
      print('Response Data: ${response.data}');

      if (!response.success) {
        print('❌ CONFIRM ORDER FAILED');
        print('Error: ${response.error}');
        print('Status Code: ${response.statusCode}');
        throw Exception(response.error ?? 'Failed to confirm order');
      } else {
        print('✅ CONFIRM ORDER SUCCESS');
      }

      return response.success;
    } catch (e, stackTrace) {
      print('❌ CONFIRM ORDER EXCEPTION: $e');
      print('Stack Trace: $stackTrace');
      rethrow;
    }
  }

  /// Mark order as picked (Stage 1 -> Stage 2)
  /// POST /order-tracking/{orderId}/picked
  Future<bool> markOrderAsPicked(String orderId) async {
    final endpoint = '/order-tracking/$orderId/picked';
    print('=== MARK ORDER AS PICKED API CALL ===');
    print('Endpoint: $endpoint');
    print('Order ID: $orderId');

    try {
      final response = await _api.post(
        endpoint,
        parser: (json) => json,
      );

      print('Response Success: ${response.success}');
      print('Response Data: ${response.data}');

      if (!response.success) {
        print('❌ MARK ORDER AS PICKED FAILED');
        print('Error: ${response.error}');
        print('Status Code: ${response.statusCode}');
        throw Exception(response.error ?? 'Failed to mark order as picked');
      } else {
        print('✅ MARK ORDER AS PICKED SUCCESS');
      }

      return response.success;
    } catch (e, stackTrace) {
      print('❌ MARK ORDER AS PICKED EXCEPTION: $e');
      print('Stack Trace: $stackTrace');
      rethrow;
    }
  }

  /// Mark order as arrived (Stage 2 -> Stage 3)
  /// POST /order-tracking/{orderId}/arrived
  Future<bool> markOrderAsArrived(String orderId) async {
    final endpoint = '/order-tracking/$orderId/arrived';
    print('=== MARK ORDER AS ARRIVED API CALL ===');
    print('Endpoint: $endpoint');
    print('Order ID: $orderId');

    try {
      final response = await _api.post(
        endpoint,
        parser: (json) => json,
      );

      print('Response Success: ${response.success}');
      print('Response Data: ${response.data}');

      if (!response.success) {
        print('❌ MARK ORDER AS ARRIVED FAILED');
        print('Error: ${response.error}');
        print('Status Code: ${response.statusCode}');
        throw Exception(response.error ?? 'Failed to mark order as arrived');
      } else {
        print('✅ MARK ORDER AS ARRIVED SUCCESS');
      }

      return response.success;
    } catch (e, stackTrace) {
      print('❌ MARK ORDER AS ARRIVED EXCEPTION: $e');
      print('Stack Trace: $stackTrace');
      rethrow;
    }
  }

  /// Mark order as delivered (Stage 3 -> Completed)
  /// POST /order-tracking/{orderId}/delivered
  /// This is the final step that also sends rating notification
  Future<bool> markOrderAsDelivered(String orderId) async {
    final endpoint = '/order-tracking/$orderId/delivered';
    print('=== MARK ORDER AS DELIVERED API CALL ===');
    print('Endpoint: $endpoint');
    print('Order ID: $orderId');

    try {
      final response = await _api.post(
        endpoint,
        parser: (json) => json,
      );

      print('Response Success: ${response.success}');
      print('Response Data: ${response.data}');

      if (!response.success) {
        print('❌ MARK ORDER AS DELIVERED FAILED');
        print('Error: ${response.error}');
        print('Status Code: ${response.statusCode}');
        throw Exception(response.error ?? 'Failed to mark order as delivered');
      } else {
        print('✅ MARK ORDER AS DELIVERED SUCCESS');
        print('📬 Rating notification sent to order creator');
      }

      return response.success;
    } catch (e, stackTrace) {
      print('❌ MARK ORDER AS DELIVERED EXCEPTION: $e');
      print('Stack Trace: $stackTrace');
      rethrow;
    }
  }

  /// Helper method to update tracking stage based on current stage
  /// Returns the new stage number after successful update
  Future<int?> updateTrackingStage(String orderId, int currentStage) async {
    try {
      bool success = false;

      switch (currentStage) {
        case 0: // Order Confirmed -> Picked Up
          success = await confirmOrder(orderId);
          return success ? 1 : null;
        case 1: // Picked Up -> In Transit
          success = await markOrderAsPicked(orderId);
          return success ? 2 : null;
        case 2: // In Transit -> Arrived
          success = await markOrderAsArrived(orderId);
          return success ? 3 : null;
        case 3: // Arrived -> Delivered
          success = await markOrderAsDelivered(orderId);
          return success ? 4 : null; // Stage 4 = Completed/Delivered
        default:
          print('⚠️ Invalid tracking stage: $currentStage');
          return null;
      }
    } catch (e) {
      print('❌ Error updating tracking stage: $e');
      return null;
    }
  }
}