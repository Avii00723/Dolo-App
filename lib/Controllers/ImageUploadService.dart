import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../Constants/ApiConstants.dart';

class ImageUploadResponse {
  final String message;
  final String imageUrl;
  final bool success;

  ImageUploadResponse({
    required this.message,
    required this.imageUrl,
    required this.success,
  });

  factory ImageUploadResponse.fromJson(Map<String, dynamic> json) {
    return ImageUploadResponse(
      message: json['message'] ?? '',
      imageUrl: json['photoURL'] ?? json['imageUrl'] ?? json['image_url'] ?? '',
      success: json['photoURL'] != null || json['imageUrl'] != null || json['success'] == true,
    );
  }
}

class ImageUploadService {
  // Upload profile picture to get image URL
  Future<ImageUploadResponse?> uploadProfilePicture({
    required String userId,
    required File imageFile,
    Function(double)? onProgress,
  }) async {
    try {
      // Use the correct endpoint from ApiConstants
      final String url = ApiConstants.uploadProfilePhoto;
      
      print('┌─────────────────────────────────────');
      print('│ 📤 PROFILE IMAGE UPLOAD REQUEST');
      print('├─────────────────────────────────────');
      print('│ URL: $url');
      print('│ User ID: $userId');
      print('│ File Path: ${imageFile.path}');
      print('│ File Name: ${imageFile.path.split('/').last}');
      print('│ File Size: ${imageFile.lengthSync()} bytes');
      print('└─────────────────────────────────────');

      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(url));

      // Add userId field
      request.fields['userId'] = userId;

      // Get file extension and name
      String fileName = imageFile.path.split('/').last;
      String extension = fileName.split('.').last.toLowerCase();

      // Determine content type
      MediaType contentType;
      if (extension == 'jpg' || extension == 'jpeg') {
        contentType = MediaType('image', 'jpeg');
      } else if (extension == 'png') {
        contentType = MediaType('image', 'png');
      } else if (extension == 'gif') {
        contentType = MediaType('image', 'gif');
      } else if (extension == 'webp') {
        contentType = MediaType('image', 'webp');
      } else {
        contentType = MediaType('image', 'jpeg');
      }

      // Add file using the correct field name 'photo' from the API spec
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          imageFile.path,
          contentType: contentType,
          filename: fileName,
        ),
      );

      print('📤 Sending request...');

      // Send request and get streamed response
      var streamedResponse = await request.send();

      // Convert streamed response to regular response
      final responseBytes = await streamedResponse.stream.toBytes();
      final responseString = utf8.decode(responseBytes);

      print('┌─────────────────────────────────────');
      print('│ 📥 PROFILE IMAGE UPLOAD RESPONSE');
      print('├─────────────────────────────────────');
      print('│ Status Code: ${streamedResponse.statusCode}');
      print('│ Response Headers: ${streamedResponse.headers}');
      print('│ Response Body: $responseString');
      print('└─────────────────────────────────────');

      // Update progress to 100% when complete
      if (onProgress != null) {
        onProgress(1.0);
      }

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        print('✅ PROFILE IMAGE UPLOAD SUCCESS');
        final jsonResponse = json.decode(responseString);
        return ImageUploadResponse.fromJson(jsonResponse);
      } else {
        print('❌ PROFILE IMAGE UPLOAD FAILED');
        print('Error: $responseString');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ PROFILE IMAGE UPLOAD EXCEPTION: $e');
      print('Stack Trace: $stackTrace');
      return null;
    }
  }
}