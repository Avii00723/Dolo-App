import '../Constants/ApiService.dart';
import '../Constants/ApiConstants.dart';
import '../Models/TripRequestModel.dart';

class TripRequestService {
  final ApiService _api = ApiService();

  // Send a trip request
  Future<TripRequestSendResponse?> sendTripRequest(TripRequestSendRequest request) async {
    final response = await _api.post(
      ApiConstants.sendTripRequest,
      body: request.toJson(),
      parser: (json) => TripRequestSendResponse.fromJson(json),
    );
    return response.success ? response.data : null;
  }

  // Accept a trip request
  Future<TripRequestAcceptResponse?> acceptTripRequest(TripRequestAcceptRequest request) async {
    final response = await _api.post(
      ApiConstants.acceptTripRequest,
      body: request.toJson(),
      parser: (json) => TripRequestAcceptResponse.fromJson(json),
    );
    return response.success ? response.data : null;
  }

  // Get all trip requests for a user
  Future<List<TripRequest>> getMyTripRequests(String userHashedId) async {
    final response = await _api.get(
      ApiConstants.getMyTripRequests,
      queryParameters: {'userHashedId': userHashedId},
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