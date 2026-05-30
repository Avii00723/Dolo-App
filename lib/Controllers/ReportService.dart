import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../Constants/ApiService.dart';
import '../Controllers/AuthService.dart';
import '../Models/ReportModel.dart';

class ReportService {
  final ApiService _apiService = ApiService();

  // POST /reports/create-report
  Future<Map<String, dynamic>> createReport({
    required String reportedUserId,
    required String orderId,
    required String category,
    required String subReason,
    String? description,
    File? attachment,
  }) async {
    try {
      final reporterUserId = await AuthService.getUserId();

      if (reporterUserId == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final Map<String, String> fields = {
        'reporterUserId': reporterUserId,
        'reportedUserId': reportedUserId,
        'orderId': orderId,
        'category': category,
        'sub_reason': subReason,
      };

      if (description != null && description.trim().isNotEmpty) {
        fields['description'] = description.trim();
      }

      List<http.MultipartFile>? files;
      if (attachment != null) {
        final ext = attachment.path.split('.').last.toLowerCase();
        files = [
          await http.MultipartFile.fromPath(
            'attachment',
            attachment.path,
            filename: 'evidence.$ext',
          )
        ];
      }

      final response = await _apiService.postMultipart<Map<String, dynamic>>(
        '/reports/create-report',
        fields: fields,
        files: files,
      );

      if (response.success) {
        return {'success': true, 'message': 'Report submitted successfully'};
      } else {
        if (response.userNotFound) {
          await AuthService.clearUserSession();
        }
        return {
          'success': false,
          'message': response.error ?? 'Failed to submit report',
        };
      }
    } catch (e) {
      debugPrint('❌ Report creation error: $e');
      return {'success': false, 'message': 'Something went wrong. Please try again.'};
    }
  }

  // GET /reports/my-reports?userId=...
  Future<Map<String, dynamic>> getMyReports() async {
    try {
      final userId = await AuthService.getUserId();

      if (userId == null) {
        return {'success': false, 'message': 'User not authenticated', 'reports': []};
      }

      final response = await _apiService.get<List<ReportModel>>(
        '/reports/my-reports',
        queryParameters: {'userId': userId},
        parser: (data) {
          final List<dynamic> rawList = data['reports'] ?? data['data'] ?? [];
          return rawList.map((r) => ReportModel.fromJson(r as Map<String, dynamic>)).toList();
        },
      );

      if (response.success) {
        return {'success': true, 'reports': response.data ?? []};
      } else {
        if (response.userNotFound) {
          await AuthService.clearUserSession();
        }
        return {
          'success': false,
          'message': response.error ?? 'Failed to fetch reports',
          'reports': [],
        };
      }
    } catch (e) {
      debugPrint('❌ Error fetching reports: $e');
      return {'success': false, 'message': 'Something went wrong.', 'reports': []};
    }
  }
}
