import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../Constants/ApiConstants.dart';
import '../Controllers/AuthService.dart';

class ChatService {
  // Get current user ID from AuthService
  static Future<int?> _getCurrentUserId() async {
    return await AuthService.getUserId();
  }

  // ✅ UPDATED: Send a chat message with optional images and reply_to support
  static Future<Map<String, dynamic>> sendMessage({
    required int chatId,
    String? message,
    int? negotiatedPrice,
    List<File>? images,
    int? replyTo, // ✅ NEW: Added reply_to parameter
  }) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
        };
      }

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.sendChatMessage),
      );

      // Add required fields
      request.fields['chat_id'] = chatId.toString();
      request.fields['user_id'] = userId.toString();

      // Add optional message
      if (message != null && message.isNotEmpty) {
        request.fields['message'] = message;
      }

      // Add optional negotiated price
      if (negotiatedPrice != null) {
        request.fields['negotiatedPrice'] = negotiatedPrice.toString();
      }

      // ✅ NEW: Add optional reply_to
      if (replyTo != null) {
        request.fields['reply_to'] = replyTo.toString();
        print('📤 Replying to message ID: $replyTo');
      }

      // Add images if provided
      if (images != null && images.isNotEmpty) {
        print('📤 Adding ${images.length} images to request');

        for (int i = 0; i < images.length; i++) {
          final file = images[i];

          // Get file extension
          final extension = file.path.split('.').last.toLowerCase();
          String mimeType = 'image/jpeg';

          if (extension == 'png') {
            mimeType = 'image/png';
          } else if (extension == 'jpg' || extension == 'jpeg') {
            mimeType = 'image/jpeg';
          } else if (extension == 'gif') {
            mimeType = 'image/gif';
          }

          var stream = http.ByteStream(file.openRead());
          var length = await file.length();

          var multipartFile = http.MultipartFile(
            'images',
            stream,
            length,
            filename: 'image_${DateTime.now().millisecondsSinceEpoch}_$i.$extension',
            contentType: MediaType.parse(mimeType),
          );

          request.files.add(multipartFile);
        }
      }

      print('📤 Sending message with fields: ${request.fields}');
      print('📤 Number of files: ${request.files.length}');

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('📤 Send Message Response: ${response.statusCode}');
      print('📤 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['error'] ?? 'Missing required fields',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'error': 'You are not a participant in this chat',
        };
      } else if (response.statusCode == 500) {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['error'] ?? 'Internal server error',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to send message: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Send Message Exception: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ✅ Get all messages for a specific chat
  static Future<Map<String, dynamic>> getChatMessages({
    required int chatId,
  }) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
          'messages': [],
        };
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.getChatMessages}/$chatId/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('📥 Get Messages Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'messages': data['messages'] ?? [],
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'error': 'You are not a participant in this chat',
          'messages': [],
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'Chat not found',
          'messages': [],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch messages: ${response.statusCode}',
          'messages': [],
        };
      }
    } catch (e) {
      print('❌ Get Messages Exception: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
        'messages': [],
      };
    }
  }

  // Get inbox conversations for the current user
  static Future<Map<String, dynamic>> getInbox() async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
          'inbox': [],
        };
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.getChatInbox}/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('📬 Get Inbox Response: ${response.statusCode}');
      print('📬 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'inbox': data['inbox'] ?? [],
        };
      } else if (response.statusCode == 500) {
        return {
          'success': false,
          'error': 'Server error occurred',
          'inbox': [],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch inbox: ${response.statusCode}',
          'inbox': [],
        };
      }
    } catch (e) {
      print('❌ Get Inbox Exception: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
        'inbox': [],
      };
    }
  }

  // Send message with price negotiation
  static Future<Map<String, dynamic>> sendNegotiationMessage({
    required int chatId,
    required String message,
    required int negotiatedPrice,
  }) async {
    return await sendMessage(
      chatId: chatId,
      message: message,
      negotiatedPrice: negotiatedPrice,
    );
  }

  // ✅ NEW: Send only images without text message
  static Future<Map<String, dynamic>> sendImages({
    required int chatId,
    required List<File> images,
    int? replyTo, // ✅ Added reply support
  }) async {
    return await sendMessage(
      chatId: chatId,
      images: images,
      replyTo: replyTo,
    );
  }

  // ✅ NEW: Send message with both text and images
  static Future<Map<String, dynamic>> sendMessageWithImages({
    required int chatId,
    required String message,
    required List<File> images,
    int? replyTo, // ✅ Added reply support
  }) async {
    return await sendMessage(
      chatId: chatId,
      message: message,
      images: images,
      replyTo: replyTo,
    );
  }

  // ✅ NEW: Send reply to a message
  static Future<Map<String, dynamic>> sendReply({
    required int chatId,
    required int replyToMessageId,
    String? message,
    List<File>? images,
  }) async {
    return await sendMessage(
      chatId: chatId,
      message: message,
      images: images,
      replyTo: replyToMessageId,
    );
  }

  // Convenience method to check if user is authenticated
  static Future<bool> isUserAuthenticated() async {
    return await AuthService.isLoggedIn();
  }

  // Get current user for chat purposes
  static Future<Map<String, dynamic>?> getCurrentChatUser() async {
    final userData = await AuthService.getCurrentUser();
    if (userData != null) {
      return {
        'userId': userData['userId'],
        'phone': userData['phone'],
      };
    }
    return null;
  }
}