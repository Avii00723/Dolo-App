import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Constants/ApiConstants.dart';
import '../Controllers/AuthService.dart';

class ChatService {
  // Get current user ID from AuthService
  static Future<int?> _getCurrentUserId() async {
    return await AuthService.getUserId();
  }

  // ✅ NEW: Send a chat message using the new API structure
  static Future<Map<String, dynamic>> sendMessage({
    required int chatId,
    required String message,
    int? negotiatedPrice,
  }) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
        };
      }

      final Map<String, dynamic> body = {
        'chat_id': chatId,
        'user_id': userId,
        'message': message,
      };

      // Add negotiated price only if provided
      if (negotiatedPrice != null) {
        body['negotiatedPrice'] = negotiatedPrice;
      }

      print('📤 Sending message with body: $body');

      final response = await http.post(
        Uri.parse(ApiConstants.sendChatMessage),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      print('📤 Send Message Response: ${response.statusCode}');
      print('📤 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'error': 'Missing required fields',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'error': 'You are not a participant in this chat',
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

  // ✅ NEW: Get all messages for a specific chat using the new API structure
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
      print('📥 Response Body: ${response.body}');

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
