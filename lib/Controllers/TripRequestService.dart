import '../Constants/ApiService.dart';
import '../Constants/ApiConstants.dart';
import '../Models/TripRequestModel.dart';

class TripRequestService {
  final ApiService _api = ApiService();

  // Send a trip request
  Future<TripRequestSendResponse?> sendTripRequest(
      TripRequestSendRequest request) async {
    final response = await _api.post(
      ApiConstants.sendTripRequest,
      body: request.toJson(),
      parser: (json) => TripRequestSendResponse.fromJson(json),
    );
    return response.success ? response.data : null;
  }

  // Accept a trip request
  Future<TripRequestAcceptResponse?> acceptTripRequest(
      TripRequestAcceptRequest request) async {
    final response = await _api.post(
      ApiConstants.acceptTripRequest,
      body: request.toJson(),
      parser: (json) => TripRequestAcceptResponse.fromJson(json),
    );
    return response.success ? response.data : null;
  }

  // Get all trip requests sent BY a user (as traveler)
  Future<List<TripRequest>> getMyTripRequests(String userHashedId) async {
    final response = await _api.get(
      ApiConstants.getMyTripRequests,
      queryParameters: {
        'userHashedId': userHashedId
      }, // Backend expects userHashedId parameter
      parser: (json) {
        if (json['tripRequests'] is List) {
          return (json['tripRequests'] as List)
              .map((e) => TripRequest.fromJson(e))
              .toList();
        }
        return [];
      },
    );
    return response.success ? (response.data as List<TripRequest>) : [];
  }

  // Get all trip requests FOR a user's orders (as order creator/sender)
  // Note: This uses the same mytrip endpoint since the backend doesn't have a separate for-orders endpoint
  Future<List<TripRequest>> getTripRequestsForMyOrders(
      String userHashedId) async {
    try {
      print(
          '🔍 Fetching trip requests for user orders using mytrip endpoint: $userHashedId');

      final response = await _api.get(
        ApiConstants.getOrderTripRequests, // Now points to mytrip endpoint
        queryParameters: {
          'userHashedId': userHashedId
        }, // Backend expects userHashedId parameter
        parser: (json) {
          print('📦 Trip requests response: $json');
          if (json['tripRequests'] is List) {
            return (json['tripRequests'] as List)
                .map((e) => TripRequest.fromJson(e))
                .toList();
          }
          return [];
        },
      );

      if (response.success) {
        print(
            '✅ Successfully fetched ${(response.data as List).length} trip requests');
        return response.data as List<TripRequest>;
      } else {
        print('! Failed to fetch trip requests for orders: ${response.error}');
        print(
            '! The endpoint http://51.20.193.95:3000/api/trip-requests/for-orders may not be implemented yet');
        print(
            '! Please ensure the backend has this endpoint or use the mytrip endpoint with proper filtering');
        return [];
      }
    } catch (e) {
      print('! Failed to fetch trip requests for orders: $e');
      print(
          '! The endpoint http://51.20.193.95:3000/api/trip-requests/for-orders may not be implemented yet');
      print(
          '! Please ensure the backend has this endpoint or use the mytrip endpoint with proper filtering');
      return [];
    }
  }

  // ✅ NEW: Delete a trip request
  Future<bool> deleteTripRequest(String tripRequestId) async {
    try {
      print('🗑️ Deleting trip request ID: $tripRequestId');

      final response = await _api.delete(
        '${ApiConstants.deleteTripRequest}/$tripRequestId',
        parser: (json) => json['message'] as String,
      );

      if (response.success) {
        print('✅ Trip request deleted successfully');
        return true;
      } else {
        print('❌ Failed to delete trip request: ${response.error}');
        return false;
      }
    } catch (e) {
      print('❌ Error deleting trip request: $e');
      rethrow;
    }
  }
}
