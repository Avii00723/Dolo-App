import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Add this import
import 'package:mime/mime.dart'; // Add this import
import '../Constants/ApiService.dart';
import '../Constants/ApiConstants.dart';
import '../Models/LoginModel.dart';

class LoginService {
  final ApiService _api = ApiService();

  // Send OTP to phone
  Future<LoginResponse?> sendOtp(String phone) async {
    final response = await _api.post(
      ApiConstants.login,
      body: {'phone': phone},
      parser: (json) => LoginResponse.fromJson(json),
      requiresAuth: false,
    );
    return response.success ? response.data : null;
  }

  // Verify OTP
  Future<VerifyOtpResponse?> verifyOtp(String phone, String otp) async {
    final response = await _api.post(
      ApiConstants.verifyOtp,
      body: {'phone': phone, 'otp': otp},
      parser: (json) => VerifyOtpResponse.fromJson(json),
      requiresAuth: false,
    );
    return response.success ? response.data : null;
  }

  // Complete User Profile
  Future<ProfileUpdateResponse?> completeProfile(ProfileUpdateRequest data) async {
    final response = await _api.post(
      ApiConstants.completeProfile,
      body: data.toJson(),
      parser: (json) => ProfileUpdateResponse.fromJson(json),
    );
    return response.success ? response.data : null;
  }

  // Start KYC process
  Future<KycStartResponse?> startKyc(int userId) async {
    final response = await _api.get(
      ApiConstants.startKyc,
      queryParameters: {'userId': userId.toString()},
      parser: (json) => KycStartResponse.fromJson(json),
    );
    return response.success ? response.data : null;
  }

  Future<UserProfile?> getUserProfile(int userId) async {
    final response = await _api.get(
      '${ApiConstants.getUserProfile}/$userId',
      parser: (json) => UserProfile.fromJson(json['profile']),
    );
    return response.success ? response.data : null;
  }

  // Update User Profile by userId
  Future<bool> updateUserProfile(int userId, ProfileUpdateRequest data) async {
    final response = await _api.put(
      '${ApiConstants.updateUserProfile}/$userId',
      body: data.toJson(),
    );
    return response.success;
  }

  // Upload KYC Document - FIXED VERSION WITH PROPER MIME TYPE
  Future<KycUploadResponse?> uploadKycDocument(int userId, File document) async {
    try {
      // Build the full URL
      final url = '${ApiConstants.baseUrl}/users/upload-kyc';
      debugPrint('=== KYC Upload Started ===');
      debugPrint('URL: $url');
      debugPrint('UserId: $userId');
      debugPrint('Document path: ${document.path}');
      debugPrint('File exists: ${await document.exists()}');

      // Check if file exists
      if (!await document.exists()) {
        debugPrint('ERROR: File does not exist at path: ${document.path}');
        return null;
      }

      // Get the MIME type from file path
      String? mimeType = lookupMimeType(document.path);
      debugPrint('Detected MIME type: $mimeType');

      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(url));

      // Add userId field
      request.fields['userId'] = userId.toString();

      // Determine content type based on file extension
      MediaType? contentType;
      if (mimeType != null) {
        final mimeTypeParts = mimeType.split('/');
        if (mimeTypeParts.length == 2) {
          contentType = MediaType(mimeTypeParts[0], mimeTypeParts[1]);
        }
      }

      // If we couldn't detect MIME type, try to infer from file extension
      if (contentType == null) {
        final extension = document.path.split('.').last.toLowerCase();
        debugPrint('File extension: $extension');

        switch (extension) {
          case 'jpg':
          case 'jpeg':
            contentType = MediaType('image', 'jpeg');
            break;
          case 'png':
            contentType = MediaType('image', 'png');
            break;
          case 'pdf':
            contentType = MediaType('application', 'pdf');
            break;
          default:
            contentType = MediaType('application', 'octet-stream');
        }
      }

      debugPrint('Using content type: $contentType');

      // Add document file with proper content type
      var multipartFile = await http.MultipartFile.fromPath(
        'document',
        document.path,
        contentType: contentType,
      );

      debugPrint('File size: ${multipartFile.length} bytes');
      debugPrint('Content type sent: ${multipartFile.contentType}');

      request.files.add(multipartFile);

      // Send request
      debugPrint('Sending multipart request...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        debugPrint('✅ KYC upload successful!');
        return KycUploadResponse.fromJson(jsonData);
      } else {
        debugPrint('ERROR: KYC upload failed with status ${response.statusCode}');
        debugPrint('Error body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('EXCEPTION in uploadKycDocument: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
}
