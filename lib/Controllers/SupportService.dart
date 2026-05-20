import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../Constants/ApiConstants.dart';
import '../Constants/ApiService.dart';
import '../Models/SupportTicketModel.dart';
import 'AuthService.dart';

class SupportService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> createTicket(CreateTicketRequest request) async {
    try {
      final result = await _api.postMultipart<Map<String, dynamic>>(
        ApiConstants.createSupportTicket,
        fields: {
          'userId': request.userId,
          'issue_type': request.issueType,
          'description': request.description,
          if (request.orderId != null) 'orderId': request.orderId!,
        },
        files: request.attachment != null
            ? [
                await http.MultipartFile.fromPath(
                  'attachment',
                  request.attachment!.path,
                  contentType: MediaType('image', 'jpeg'),
                )
              ]
            : null,
      );

      if (result.success) {
        return {'success': true, 'data': result.data};
      } else {
        return {
          'success': false,
          'error': result.error ?? 'Failed to create ticket'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, List<SupportTicket>>> getMyTickets() async {
    final userId = await AuthService.getUserId();
    if (userId == null) {
      return {
        'ongoing': <SupportTicket>[],
        'previous': <SupportTicket>[],
      };
    }

    final response = await _api.get<Map<String, List<SupportTicket>>>(
      ApiConstants.getMySupportTickets,
      queryParameters: {'userId': userId},
      parser: (json) {
        if (json is! Map<String, dynamic>) {
          return {
            'ongoing': <SupportTicket>[],
            'previous': <SupportTicket>[],
          };
        }

        final ongoingRaw = json['ongoing'] as List?;
        final ongoing = ongoingRaw
                ?.map((e) => SupportTicket.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <SupportTicket>[];

        final previousRaw = json['previous'] as List?;
        final previous = previousRaw
                ?.map((e) => SupportTicket.fromJson(e as Map<String, dynamic>))
                .toList() ??
            <SupportTicket>[];

        return {'ongoing': ongoing, 'previous': previous};
      },
    );

    return response.data ??
        {
          'ongoing': <SupportTicket>[],
          'previous': <SupportTicket>[],
        };
  }

  Future<List<SupportMessage>> getTicketMessages(String ticketId) async {
    final userId = await AuthService.getUserId();
    if (userId == null) return <SupportMessage>[];

    final response = await _api.get<List<SupportMessage>>(
      '${ApiConstants.getSupportMessages}/$ticketId',
      parser: (json) {
        if (json is! Map<String, dynamic>) return <SupportMessage>[];
        
        final messagesRaw = json['messages'] as List?;
        final messages = messagesRaw
                ?.map((e) => SupportMessage.fromJson(
                    e as Map<String, dynamic>, userId))
                .toList() ??
            <SupportMessage>[];
        return messages;
      },
    );

    return response.data ?? <SupportMessage>[];
  }

  Future<Map<String, dynamic>> sendSupportMessage({
    required String ticketId,
    required String message,
    File? attachment,
  }) async {
    final userId = await AuthService.getUserId();
    if (userId == null) return {'success': false, 'error': 'User not logged in'};

    try {
      final result = await _api.postMultipart<Map<String, dynamic>>(
        ApiConstants.sendSupportMessage,
        fields: {
          'ticketId': ticketId,
          'userId': userId,
          'message': message,
        },
        files: attachment != null
            ? [
                await http.MultipartFile.fromPath(
                  'attachment',
                  attachment.path,
                  contentType: MediaType('image', 'jpeg'),
                )
              ]
            : null,
      );

      if (result.success) {
        return {'success': true, 'data': result.data};
      } else {
        return {
          'success': false,
          'error': result.error ?? 'Failed to send message'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
