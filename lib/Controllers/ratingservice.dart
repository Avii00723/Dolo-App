import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Constants/ApiService.dart';
import '../Constants/ApiConstants.dart';
import '../Models/RatingModel.dart';

class RatingService {
  final ApiService _api = ApiService();

  /// Submit rating for a delivered order
  /// Returns true if successful, throws exception otherwise
  Future<bool> submitRating(RatingRequest request) async {
    print('=== SUBMIT RATING API CALL ===');
    print('Endpoint: ${ApiConstants.submitRating}');
    print('Request Body: ${request.toJson()}');

    try {
      final response = await _api.post(
        ApiConstants.submitRating,
        body: request.toJson(),
        parser: (json) => RatingResponse.fromJson(json),
      );

      print('Response Success: ${response.success}');
      print('Response Data: ${response.data}');

      if (!response.success) {
        print('❌ SUBMIT RATING FAILED');
        print('Error: ${response.error}');
        print('Status Code: ${response.statusCode}');

        if (response.statusCode == 400) {
          if (response.error?.contains('already submitted') == true) {
            throw Exception('RATING_ALREADY_SUBMITTED');
          }
          throw Exception('INVALID_INPUT');
        }

        if (response.statusCode == 403) {
          if (response.error?.contains('not delivered') == true) {
            throw Exception('ORDER_NOT_DELIVERED');
          }
          throw Exception('UNAUTHORIZED');
        }

        throw Exception(response.error ?? 'Failed to submit rating');
      } else {
        print('✅ SUBMIT RATING SUCCESS');
      }

      return response.success;
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