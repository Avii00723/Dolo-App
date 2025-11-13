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
  // Uses the mytrip endpoint - returns ALL trip requests related to the user
  Future<List<TripRequest>> getTripRequestsForMyOrders(
      String userHashedId) async {
    print('🔍 Fetching trip requests for user orders: $userHashedId');

    final response = await _api.get(
      ApiConstants.getMyTripRequests, // Use mytrip endpoint
      queryParameters: {'userHashedId': userHashedId},
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
      print('✅ Successfully fetched ${(response.data as List).length} trip requests');
      return response.data as List<TripRequest>;
    } else {
      print('❌ Failed to fetch trip requests: ${response.error}');
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

  // ✅ NEW: Withdraw a trip request (traveler cancels their own request)
  Future<TripRequestWithdrawResponse?> withdrawTripRequest(
      TripRequestWithdrawRequest request) async {
    print('🚫 Withdrawing trip request: ${request.tripRequestHashedId}');

    final response = await _api.post(
      ApiConstants.withdrawTripRequest,
      body: request.toJson(),
      parser: (json) => TripRequestWithdrawResponse.fromJson(json),
    );

    if (response.success) {
      print('✅ Trip request withdrawn successfully');
      return response.data;
    } else {
      print('❌ Failed to withdraw trip request: ${response.error}');
      return null;
    }
  }

  // ✅ NEW: Decline a trip request (order creator declines)
  Future<TripRequestDeclineResponse?> declineTripRequest(
      TripRequestDeclineRequest request) async {
    print('👎 Declining trip request: ${request.tripRequestId}');

    final response = await _api.post(
      ApiConstants.declineTripRequest,
      body: request.toJson(),
      parser: (json) => TripRequestDeclineResponse.fromJson(json),
    );

    if (response.success) {
      print('✅ Trip request declined successfully');
      return response.data;
    } else {
      print('❌ Failed to decline trip request: ${response.error}');
      return null;
    }
  }

  // ✅ NEW: Complete a trip request
  Future<TripRequestCompleteResponse?> completeTripRequest(
      String tripId) async {
    print('✅ Completing trip request: $tripId');

    final response = await _api.put(
      '${ApiConstants.completeTripRequest}/$tripId',
      parser: (json) => TripRequestCompleteResponse.fromJson(json),
    );

    if (response.success) {
      print('✅ Trip request completed successfully');
      return response.data;
    } else {
      print('❌ Failed to complete trip request: ${response.error}');
      return null;
    }
  }
}
