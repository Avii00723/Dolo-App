import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../Constants/ApiConstants.dart';
import '../Models/LoginModel.dart';

class KycService {
  // Upload KYC document along with personal information
  Future<KycUploadResponse?> uploadKyc({
    required String userId,
    required String permanentAddress,
    required String homeCity,
    required File file,
    Function(double)? onProgress,
  }) async {
    try {
      print('┌─────────────────────────────────────');
      print('│ 📤 KYC UPLOAD REQUEST (WITH INFO)');
      print('├─────────────────────────────────────');
      print('│ URL: ${ApiConstants.uploadKyc}');
      print('│ User ID: $userId');
      print('│ Address: $permanentAddress');
      print('│ City: $homeCity');
      print('│ File Path: ${file.path}');
      print('└─────────────────────────────────────');

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.uploadKyc),
      );

      // Add text fields
      request.fields['userId'] = userId;
      request.fields['permanant_address'] = permanentAddress;
      request.fields['home_city'] = homeCity;

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

  // Deprecated: Keeping for backward compatibility if needed, but updated to use combined logic
  Future<KycPersonalInfoResponse?> saveKycPersonalInfo(KycPersonalInfoRequest data) async {
    // This is now redundant as uploadKyc handles it, but we can keep the stub
    return KycPersonalInfoResponse(message: "Info will be saved during upload");
  }
}
