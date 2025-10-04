import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Constants/ApiService.dart';
import '../Constants/ApiConstants.dart';
import '../Models/LoginModel.dart';

class ProfileService {
  final ApiService _api = ApiService();

  // Get user profile by userId
  Future<UserProfile?> getUserProfile(int userId) async {
    final response = await _api.get(
      '${ApiConstants.getUserProfile}/$userId',
      parser: (json) => UserProfile.fromJson(json['profile']),
    );
    return response.success ? response.data : null;
  }

  // Update user profile by userId
  Future<bool> updateUserProfile(int userId, Map<String, dynamic> updates) async {
    final response = await _api.put(
      '${ApiConstants.updateUserProfile}/$userId',
      body: updates,
    );
    return response.success;
  }
}
