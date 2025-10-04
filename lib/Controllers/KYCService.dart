import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../Constants/ApiConstants.dart';

class KycUploadResponse {
  final String message;
  final String kycStatus;
  final String fileUrl;

  KycUploadResponse({
    required this.message,
    required this.kycStatus,
    required this.fileUrl,
  });

  factory KycUploadResponse.fromJson(Map<String, dynamic> json) {
    return KycUploadResponse(
      message: json['message'] ?? '',
      kycStatus: json['kycStatus'] ?? '',
      fileUrl: json['fileURL'] ?? '',
    );
  }
}

class KycService {
  // Upload KYC document
  Future<KycUploadResponse?> uploadKyc({
    required int userId,
    required File file,
    Function(double)? onProgress,
  }) async {
    try {
      print('┌─────────────────────────────────────');
      print('│ 📤 KYC UPLOAD REQUEST');
      print('├─────────────────────────────────────');
      print('│ URL: ${ApiConstants.uploadKyc}');
      print('│ User ID: $userId');
      print('│ File Path: ${file.path}');
      print('│ File Name: ${file.path.split('/').last}');
      print('│ File Size: ${file.lengthSync()} bytes');
      print('└─────────────────────────────────────');

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.uploadKyc),
      );

      // Add userId field
      request.fields['userId'] = userId.toString();

      // Get file extension and name
      String fileName = file.path.split('/').last;
      String extension = fileName.split('.').last.toLowerCase();

      // Determine content type
      MediaType contentType;
      if (extension == 'pdf') {
        contentType = MediaType('application', 'pdf');
      } else if (extension == 'jpg' || extension == 'jpeg') {
        contentType = MediaType('image', 'jpeg');
      } else if (extension == 'png') {
        contentType = MediaType('image', 'png');
      } else {
        contentType = MediaType('application', 'octet-stream');
      }

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'document',
          file.path,
          contentType: contentType,
        ),
      );

      print('📤 Sending request...');

      // Send request and get streamed response
      var streamedResponse = await request.send();

      // Convert streamed response to regular response
      // Note: We read the bytes directly instead of listening to the stream multiple times
      final responseBytes = await streamedResponse.stream.toBytes();
      final responseString = String.fromCharCodes(responseBytes);

      print('┌─────────────────────────────────────');
      print('│ 📥 KYC UPLOAD RESPONSE');
      print('├─────────────────────────────────────');
      print('│ Status Code: ${streamedResponse.statusCode}');
      print('│ Response Headers: ${streamedResponse.headers}');
      print('│ Response Body: $responseString');
      print('└─────────────────────────────────────');

      // Update progress to 100% when complete
      if (onProgress != null) {
        onProgress(1.0);
      }

      if (streamedResponse.statusCode == 200) {
        print('✅ KYC UPLOAD SUCCESS');
        final jsonResponse = json.decode(responseString);
        return KycUploadResponse.fromJson(jsonResponse);
      } else {
        print('❌ KYC UPLOAD FAILED');
        print('Error: $responseString');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ KYC UPLOAD EXCEPTION: $e');
      print('Stack Trace: $stackTrace');
      return null;
    }
  }
}
