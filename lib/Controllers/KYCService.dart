import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../Constants/ApiConstants.dart';
import '../Models/LoginModel.dart';

class KycService {
  // Save KYC personal information
  Future<KycPersonalInfoResponse?> saveKycPersonalInfo(KycPersonalInfoRequest data) async {
    try {
      print('┌─────────────────────────────────────');
      print('│ 📤 SAVE KYC INFO REQUEST');
      print('├─────────────────────────────────────');
      print('│ URL: ${ApiConstants.saveKycPersonalInfo}');
      print('│ Body: ${json.encode(data.toJson())}');
      print('└─────────────────────────────────────');

      final response = await http.post(
        Uri.parse(ApiConstants.saveKycPersonalInfo),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data.toJson()),
      );

      print('┌─────────────────────────────────────');
      print('│ 📥 SAVE KYC INFO RESPONSE');
      print('├─────────────────────────────────────');
      print('│ Status Code: ${response.statusCode}');
      print('│ Body: ${response.body}');
      print('└─────────────────────────────────────');

      if (response.statusCode == 200) {
        return KycPersonalInfoResponse.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      print('❌ SAVE KYC INFO ERROR: $e');
      return null;
    }
  }

  // Upload KYC document
  Future<KycUploadResponse?> uploadKyc({
    required String userId,
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
      print('└─────────────────────────────────────');

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.uploadKyc),
      );

      // Add userId field
      request.fields['userId'] = userId;

      // Get file extension and determine content type
      String fileName = file.path.split('/').last;
      String extension = fileName.split('.').last.toLowerCase();

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

      // Send request
      var streamedResponse = await request.send();
      final responseBytes = await streamedResponse.stream.toBytes();
      final responseString = String.fromCharCodes(responseBytes);

      print('┌─────────────────────────────────────');
      print('│ 📥 KYC UPLOAD RESPONSE');
      print('├─────────────────────────────────────');
      print('│ Status Code: ${streamedResponse.statusCode}');
      print('│ Response Body: $responseString');
      print('└─────────────────────────────────────');

      if (onProgress != null) onProgress(1.0);

      if (streamedResponse.statusCode == 200) {
        final jsonResponse = json.decode(responseString);
        return KycUploadResponse.fromJson(jsonResponse);
      }
      return null;
    } catch (e) {
      print('❌ KYC UPLOAD EXCEPTION: $e');
      return null;
    }
  }
}
