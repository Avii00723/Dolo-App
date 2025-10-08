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
  Future<List<TripRequest>> getMyTripRequests(int userId) async {
    final response = await _api.get(
      ApiConstants.getMyTripRequests,
      queryParameters: {'user_id': userId.toString()},
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
}
