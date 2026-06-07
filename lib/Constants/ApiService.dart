import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
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
  final bool userNotFound;
  final dynamic details;

  ApiResponse.success(this.data, {this.statusCode, this.endpoint, this.details})
      : success = true,
        error = null,
        userNotFound = false;

  ApiResponse.error(this.error,
      {this.statusCode,
      this.endpoint,
      this.userNotFound = false,
      this.details})
      : success = false,
        data = null;
}

class ApiService {
  static const String baseUrl = ApiConstants.baseUrl;

  final Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Tunnel-Skip-AntiCsrf-Check': '1', 
  };

  String buildUrl(String endpoint) {
    if (endpoint.startsWith('http')) return endpoint;
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return '$cleanBase$cleanEndpoint';
  }

  bool _isUserNotFoundError(int statusCode, dynamic responseBody) {
    if (responseBody is Map<String, dynamic>) {
      final message = (responseBody['message'] ?? responseBody['error'] ?? '').toString().toLowerCase();
      return message.contains('user does not exist') ||
             message.contains('user not found');
    }
    return false;
  }

  Future<ApiResponse<T>> get<T>(
      String endpoint, {
        Map<String, String>? headers,
        Map<String, dynamic>? queryParameters,
        T Function(dynamic)? parser,
        bool requiresAuth = true,
      }) async {
    try {
      final url = buildUrlWithQuery(endpoint, queryParameters);
      final response = await http.get(
        Uri.parse(url),
        headers: {...defaultHeaders, ...?headers},
      );
      return _processResponse(response, endpoint, parser);
    } on SocketException {
      return ApiResponse.error(
        'App is temporarily unavailable. It will resume shortly.',
        endpoint: endpoint,
      );
    } catch (e) {
      return ApiResponse.error('Request failed: $e', endpoint: endpoint);
    }
  }

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
      final response = await http.post(
        Uri.parse(url),
        headers: {...defaultHeaders, ...?headers},
        body: encodedBody,
      );
      return _processResponse(response, endpoint, parser);
    } on SocketException {
      return ApiResponse.error(
        'App is temporarily unavailable. It will resume shortly.',
        endpoint: endpoint,
      );
    } catch (e) {
      return ApiResponse.error('Request failed: $e', endpoint: endpoint);
    }
  }

  Future<ApiResponse<T>> postMultipart<T>(
      String endpoint, {
        Map<String, String>? fields,
        List<http.MultipartFile>? files,
        Map<String, String>? headers,
        T Function(dynamic)? parser,
      }) async {
    try {
      final url = buildUrl(endpoint);
      final request = http.MultipartRequest('POST', Uri.parse(url));

      request.headers.addAll(defaultHeaders);
      if (headers != null) {
        request.headers.addAll(headers);
      }
      if (!request.headers.containsKey('Accept')) {
        request.headers['Accept'] = 'application/json';
      }

      if (fields != null) {
        request.fields.addAll(fields);
      }

      if (files != null) {
        request.files.addAll(files);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _processResponse(response, endpoint, parser);
    } on SocketException {
      return ApiResponse.error(
        'App is temporarily unavailable. It will resume shortly.',
        endpoint: endpoint,
      );
    } catch (e) {
      return ApiResponse.error('Request failed: $e', endpoint: endpoint);
    }
  }

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
      final response = await http.put(
        Uri.parse(url),
        headers: {...defaultHeaders, ...?headers},
        body: encodedBody,
      );
      return _processResponse(response, endpoint, parser);
    } on SocketException {
      return ApiResponse.error('Network error - check your connection', endpoint: endpoint);
    } catch (e) {
      return ApiResponse.error('Request failed: $e', endpoint: endpoint);
    }
  }

  Future<ApiResponse<T>> delete<T>(
      String endpoint, {
        Map<String, String>? headers,
        Map<String, dynamic>? queryParameters,
        T Function(dynamic)? parser,
        bool requiresAuth = true,
      }) async {
    try {
      final url = buildUrlWithQuery(endpoint, queryParameters);
      final response = await http.delete(
        Uri.parse(url),
        headers: {...defaultHeaders, ...?headers},
      );
      return _processResponse(response, endpoint, parser);
    } on SocketException {
      return ApiResponse.error(
        'App is temporarily unavailable. It will resume shortly.',
        endpoint: endpoint,
      );
    } catch (e) {
      return ApiResponse.error('Request failed: $e', endpoint: endpoint);
    }
  }

  String buildUrlWithQuery(String endpoint, Map<String, dynamic>? params) {
    String url = buildUrl(endpoint);
    if (params != null && params.isNotEmpty) {
      final List<String> queryParts = [];
      params.forEach((key, value) {
        if (value is Iterable) {
          for (var item in value) {
            queryParts.add('${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(item.toString())}');
          }
        } else {
          queryParts.add('${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value.toString())}');
        }
      });
      url += '?${queryParts.join('&')}';
    }
    return url;
  }

  ApiResponse<T> _processResponse<T>(
      http.Response response,
      String endpoint,
      T Function(dynamic)? parser,
      ) {
    final statusCode = response.statusCode;
    dynamic responseBody;
    final rawBody = response.body;

    if (rawBody.isNotEmpty) {
      try {
        responseBody = jsonDecode(rawBody);
      } catch (_) {
        responseBody = rawBody;
      }
    }

    if (statusCode >= 200 && statusCode < 300) {
      try {
        final parsed = parser != null ? parser(responseBody) : responseBody;
        return ApiResponse.success(parsed, statusCode: statusCode, endpoint: endpoint);
      } catch (e) {
        final errorDetails = rawBody.isNotEmpty ? rawBody : responseBody;
        return ApiResponse.error(
          'Failed to parse response: $e',
          statusCode: statusCode,
          endpoint: endpoint,
          details: errorDetails,
        );
      }
    } else {
      if (statusCode >= 500 && statusCode < 600) {
        return ApiResponse.error(
          'App is temporarily unavailable. It will resume shortly.',
          statusCode: statusCode,
          endpoint: endpoint,
          details: responseBody is String ? responseBody : rawBody,
        );
      }
      final userNotFound = _isUserNotFoundError(statusCode, responseBody);
      final errorMsg = responseBody is Map && responseBody['message'] != null
          ? responseBody['message'].toString()
          : (responseBody is Map && responseBody['error'] != null
              ? responseBody['error'].toString()
              : rawBody.isNotEmpty
                  ? rawBody
                  : 'Request failed: HTTP $statusCode');

      return ApiResponse.error(
        errorMsg,
        statusCode: statusCode,
        endpoint: endpoint,
        userNotFound: userNotFound,
        details: responseBody is String ? responseBody : rawBody,
      );
    }
  }
}
