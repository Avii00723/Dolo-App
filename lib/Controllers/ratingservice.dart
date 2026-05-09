import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Constants/ApiService.dart';
import '../Constants/ApiConstants.dart';
import '../Models/RatingModel.dart';

class RatingService {

  // NOTE: submitRating currently relies on RatingRequest.toJson() to send
  // required fields (order_id, traveller_id, rater_id, rating, feedback).

  final ApiService _api = ApiService();

  /// Submit rating for a delivered order
  /// Returns true if successful, throws exception otherwise
  Future<bool> submitRating(RatingRequest request) async {
    print('=== SUBMIT RATING API CALL ===');
    print('Endpoint: ${ApiConstants.submitRating}');
    print('Request Body: ${request.toJson()}');

    // Client-side validation to prevent obvious bad requests.
    if (!request.isValid()) {
      throw Exception('INVALID_INPUT');
    }

    try {
      final apiResponse = await _api.post(
        ApiConstants.submitRating,
        body: request.toJson(),
        parser: (json) => RatingResponse.fromJson(json),
      );

      print('Response Success: ${apiResponse.success}');
      print('Response Data: ${apiResponse.data}');

      if (apiResponse.success) {
        return true;
      }

      final statusCode = apiResponse.statusCode;
      final backendMessage = apiResponse.error;

      print('SUBMIT RATING FAILED. statusCode=$statusCode error=$backendMessage');

      switch (statusCode) {
        case 400:
          // invalid input, invalid traveller, or duplicate rating
          final msg = backendMessage?.toLowerCase() ?? '';
          if (msg.contains('already') || msg.contains('duplicate')) {
            throw Exception('RATING_ALREADY_SUBMITTED');
          }
          throw Exception('INVALID_INPUT');
        case 403:
          // order not delivered or unauthorized
          final msg = backendMessage?.toLowerCase() ?? '';
          if (msg.contains('not delivered') ||
              msg.contains('not_delivered') ||
              msg.contains('delivered') && msg.contains('not')) {
            throw Exception('ORDER_NOT_DELIVERED');
          }
          throw Exception('UNAUTHORIZED');
        case 404:
          throw Exception('NOT_FOUND');
        case 500:
          throw Exception('INTERNAL_SERVER_ERROR');
        default:
          throw Exception(backendMessage ?? 'Failed to submit rating');
      }
    } catch (e, stackTrace) {
      print('❌ SUBMIT RATING EXCEPTION: $e');
      print('Stack Trace: $stackTrace');
      rethrow;
    }
  }


  /// Get ratings for a user (optional - if you need to fetch ratings)
  Future<List<Rating>> getUserRatings(String userId) async {
    print('=== GET USER RATINGS API CALL ===');
    print('Endpoint: ${ApiConstants.getUserRatings}');
    print('User ID: $userId');

    try {
      final response = await _api.get(
        ApiConstants.getUserRatings,
        queryParameters: {'userId': userId},
        parser: (json) {
          if (json['ratings'] is List) {
            return (json['ratings'] as List)
                .map((e) => Rating.fromJson(e))
                .toList();
          }
          return <Rating>[];
        },
      );

      return response.success ? (response.data as List<Rating>) : [];
    } catch (e) {
      print('❌ GET USER RATINGS EXCEPTION: $e');
      return [];
    }
  }
}