import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
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

  // Verify OTP - Strictly following documentation schema
  Future<VerifyOtpResponse?> verifyOtp(String phone, String otp) async {
    final response = await _api.post(
      ApiConstants.verifyOtp,
      body: {
        'phone': phone,
        'otp': otp,
      },
      parser: (json) => VerifyOtpResponse.fromJson(json),
      requiresAuth: false,
    );
    return response.success ? response.data : null;
  }

  // Complete User Profile
  Future<SignupResponse?> completeSignup(SignupRequest request) async {
    try {
      debugPrint('📤 Calling /users/signup API');
      final response = await _api.post(
        ApiConstants.completeSignup,
        body: request.toJson(),
        parser: (json) => SignupResponse.fromJson(json),
      );
      return response.data;
    } catch (e) {
      debugPrint('❌ Error completing signup: $e');
      return null;
    }
  }

  // Complete Profile (Profile Image)
  Future<CompleteProfileResponse?> completeProfile(CompleteProfileRequest request) async {
    try {
      final response = await _api.post(
        ApiConstants.completeProfile,
        body: request.toJson(),
        parser: (json) => CompleteProfileResponse.fromJson(json),
      );
      return response.data;
    } catch (e) {
      debugPrint('❌ Error completing profile: $e');
      return null;
    }
  }

  // Start KYC process
  Future<KycStartResponse?> startKyc(String userId) async {
    final response = await _api.get(
      ApiConstants.startKyc,
      queryParameters: {'userId': userId},
      parser: (json) => KycStartResponse.fromJson(json),
    );
    return response.success ? response.data : null;
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    final response = await _api.get(
      '${ApiConstants.getUserProfile}/$userId',
      parser: (json) => UserProfile.fromJson(json['profile']),
    );
    return response.success ? response.data : null;
  }

  Future<bool> updateUserProfile(String userId, ProfileUpdateRequest data) async {
    final response = await _api.put(
      '${ApiConstants.updateUserProfile}/$userId',
      body: data.toJson(),
    );
    return response.success;
  }

  // Upload KYC Document
  Future<KycUploadResponse?> uploadKycDocument(String userId, File document) async {
    try {
      final url = ApiConstants.uploadKyc;
      debugPrint('=== KYC Upload Started === URL: $url');

      if (!await document.exists()) return null;

      String? mimeType = lookupMimeType(document.path);
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['userId'] = userId;

      MediaType contentType = MediaType('application', 'octet-stream');
      if (mimeType != null) {
        final parts = mimeType.split('/');
        if (parts.length == 2) contentType = MediaType(parts[0], parts[1]);
      }

      var multipartFile = await http.MultipartFile.fromPath(
        'document',
        document.path,
        contentType: contentType,
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return KycUploadResponse.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('❌ KYC upload Exception: $e');
      return null;
    }
  }
}
