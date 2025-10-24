import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../Constants/ApiConstants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;
  final String? endpoint;

  ApiException(this.message, {this.statusCode, this.details, this.endpoint});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int? statusCode;
  final String? endpoint;
  final bool userNotFound; // ✅ NEW: Flag for user not found

  ApiResponse.success(this.data, {this.statusCode, this.endpoint})
      : success = true,
        error = null,
        userNotFound = false;

  ApiResponse.error(this.error, {this.statusCode, this.endpoint, this.userNotFound = false})
      : success = false,
        data = null;
}

class ApiService {
  static const String baseUrl = ApiConstants.baseUrl;

  final Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Helper to build the full endpoint URL
  String buildUrl(String endpoint) {
    if (endpoint.startsWith('http')) return endpoint;
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return '$cleanBase$cleanEndpoint';
  }

  // ✅ Helper method to check if response indicates user doesn't exist
  bool _isUserNotFoundError(int statusCode, dynamic responseBody) {
    if (statusCode == 404) return true;

    if (responseBody is Map<String, dynamic>) {
      final message = responseBody['message']?.toString().toLowerCase() ?? '';
      final error = responseBody['error']?.toString().toLowerCase() ?? '';

      return message.contains('user does not exist') ||
          message.contains('user not found') ||
          message.contains('not found') ||
          error.contains('user does not exist') ||
          error.contains('user not found');
    }

    return false;
  }

  // Generic GET request
  Future<ApiResponse<T>> get<T>(
      String endpoint, {
        Map<String, String>? headers,
        Map<String, dynamic>? queryParameters,
        T Function(dynamic)? parser,
        bool requiresAuth = true,
      }) async {
    try {
      final url = buildUrlWithQuery(endpoint, queryParameters);
      print('┌─────────────────────────────────────');
      print('│ 📡 GET REQUEST');
      print('├─────────────────────────────────────');
      print('│ URL: $url');
      print('│ Headers: ${{...defaultHeaders, ...?headers}}');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        print('│ Query Params: $queryParameters');
      }
      print('└─────────────────────────────────────');

      final response = await http.get(
        Uri.parse(url),
        headers: {...defaultHeaders, ...?headers},
      );

      return _processResponse(response, endpoint, parser);
    } on SocketException {
      print('❌ Network error - check your connection');
      return ApiResponse.error('Network error - check your connection', endpoint: endpoint);
    } catch (e, stackTrace) {
      print('❌ GET Exception: $e');
      print('Stack Trace: $stackTrace');
      return ApiResponse.error('Request failed: $e', endpoint: endpoint);
    }
  }

  // Generic POST request
  Future<ApiResponse<T>> post<T>(
      String endpoint, {
        dynamic body,
        Map<String, String>? headers,
        Map<String, dynamic>? queryParameters,
        T Function(dynamic)? parser,
        bool requiresAuth = true,
      }) async {
    try {
      final url = buildUrlWithQuery(endpoint, queryParameters);
      final encodedBody = body != null ? jsonEncode(body) : null;

      print('┌─────────────────────────────────────');
      print('│ 📡 POST REQUEST');
      print('├─────────────────────────────────────');
      print('│ URL: $url');
      print('│ Headers: ${{...defaultHeaders, ...?headers}}');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        print('│ Query Params: $queryParameters');
      }
      print('│ Body: ${body ?? 'null'}');
      print('│ Encoded Body: ${encodedBody ?? 'null'}');
      print('└─────────────────────────────────────');

      final response = await http.post(
        Uri.parse(url),
        headers: {...defaultHeaders, ...?headers},
        body: encodedBody,
      );

      return _processResponse(response, endpoint, parser);
    } on SocketException {
      print('❌ Network error - check your connection');
      return ApiResponse.error('Network error - check your connection', endpoint: endpoint);
    } catch (e, stackTrace) {
      print('❌ POST Exception: $e');
      print('Stack Trace: $stackTrace');
      return ApiResponse.error('Request failed: $e', endpoint: endpoint);
    }
  }

  // Generic PUT request
  Future<ApiResponse<T>> put<T>(
      String endpoint, {
        dynamic body,
        Map<String, String>? headers,
        Map<String, dynamic>? queryParameters,
        T Function(dynamic)? parser,
        bool requiresAuth = true,
      }) async {
    try {
      final url = buildUrlWithQuery(endpoint, queryParameters);
      final encodedBody = body != null ? jsonEncode(body) : null;

      print('┌─────────────────────────────────────');
      print('│ 📡 PUT REQUEST');
      print('├─────────────────────────────────────');
      print('│ URL: $url');
      print('│ Headers: ${{...defaultHeaders, ...?headers}}');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        print('│ Query Params: $queryParameters');
      }
      print('│ Body: ${body ?? 'null'}');
      print('│ Encoded Body: ${encodedBody ?? 'null'}');
      print('└─────────────────────────────────────');

      final response = await http.put(
        Uri.parse(url),
        headers: {...defaultHeaders, ...?headers},
        body: encodedBody,
      );

      return _processResponse(response, endpoint, parser);
    } on SocketException {
      print('❌ Network error - check your connection');
      return ApiResponse.error('Network error - check your connection', endpoint: endpoint);
    } catch (e, stackTrace) {
      print('❌ PUT Exception: $e');
      print('Stack Trace: $stackTrace');
      return ApiResponse.error('Request failed: $e', endpoint: endpoint);
    }
  }

  // Generic DELETE request
  Future<ApiResponse<T>> delete<T>(
      String endpoint, {
        Map<String, String>? headers,
        Map<String, dynamic>? queryParameters,
        T Function(dynamic)? parser,
        bool requiresAuth = true,
      }) async {
    try {
      final url = buildUrlWithQuery(endpoint, queryParameters);

      print('┌─────────────────────────────────────');
      print('│ 📡 DELETE REQUEST');
      print('├─────────────────────────────────────');
      print('│ URL: $url');
      print('│ Headers: ${{...defaultHeaders, ...?headers}}');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        print('│ Query Params: $queryParameters');
      }
      print('└─────────────────────────────────────');

      final response = await http.delete(
        Uri.parse(url),
        headers: {...defaultHeaders, ...?headers},
      );

      return _processResponse(response, endpoint, parser);
    } on SocketException {
      print('❌ Network error - check your connection');
      return ApiResponse.error('Network error - check your connection', endpoint: endpoint);
    } catch (e, stackTrace) {
      print('❌ DELETE Exception: $e');
      print('Stack Trace: $stackTrace');
      return ApiResponse.error('Request failed: $e', endpoint: endpoint);
    }
  }

  String buildUrlWithQuery(
      String endpoint,
      Map<String, dynamic>? params,
      ) {
    String url = buildUrl(endpoint);
    if (params != null && params.isNotEmpty) {
      final queryString = params.entries
          .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value.toString())}')
          .join('&');
      url += '?$queryString';
    }
    return url;
  }

  // ✅ MODIFIED: Enhanced response processing with user existence checking
  ApiResponse<T> _processResponse<T>(
      http.Response response,
      String endpoint,
      T Function(dynamic)? parser,
      ) {
    final statusCode = response.statusCode;
    print('┌─────────────────────────────────────');
    print('│ 📥 RESPONSE');
    print('├─────────────────────────────────────');
    print('│ Endpoint: $endpoint');
    print('│ Status Code: $statusCode');
    print('│ Response Headers: ${response.headers}');
    print('│ Response Body Length: ${response.body.length} bytes');
    print('│ Response Body: ${response.body.isEmpty ? 'EMPTY' : response.body}');
    print('└─────────────────────────────────────');

    final responseBody = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (statusCode >= 200 && statusCode < 300) {
      print('✅ SUCCESS - Status: $statusCode');
      try {
        final parsed = parser != null ? parser(responseBody) : responseBody;
        print('✅ Data parsed successfully');
        return ApiResponse.success(parsed, statusCode: statusCode, endpoint: endpoint);
      } catch (e, stackTrace) {
        print('❌ Parser Exception: $e');
        print('Stack Trace: $stackTrace');
        return ApiResponse.error('Failed to parse response: $e', statusCode: statusCode, endpoint: endpoint);
      }
    } else {
      print('❌ ERROR - Status: $statusCode');

      // ✅ Check if user doesn't exist
      final userNotFound = _isUserNotFoundError(statusCode, responseBody);

      final errorMsg = responseBody is Map && responseBody['message'] != null
          ? responseBody['message'].toString()
          : 'Request failed: HTTP $statusCode';

      print('❌ Error Message: $errorMsg');
      if (responseBody is Map) {
        print('❌ Error Details: $responseBody');
      }

      // Specific error handling based on status code
      switch (statusCode) {
        case 400:
          print('⚠️ BAD REQUEST - Check if all required fields are present and valid');
          break;
        case 401:
          print('⚠️ UNAUTHORIZED - Authentication required or invalid token');
          break;
        case 403:
          print('⚠️ FORBIDDEN - KYC not approved or insufficient permissions');
          break;
        case 404:
          print('⚠️ NOT FOUND - Resource does not exist');
          if (userNotFound) {
            print('🚨 USER DOES NOT EXIST - Will trigger logout');
          }
          break;
        case 500:
          print('⚠️ INTERNAL SERVER ERROR - Backend issue');
          break;
        default:
          print('⚠️ UNKNOWN ERROR - Status code: $statusCode');
      }

      return ApiResponse.error(
        errorMsg,
        statusCode: statusCode,
        endpoint: endpoint,
        userNotFound: userNotFound, 
      );
    }
  }
}
