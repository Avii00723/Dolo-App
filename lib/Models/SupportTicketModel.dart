import 'dart:io';
import '../Constants/ApiConstants.dart';

class SupportTicket {
  final String ticketId;
  final String issueType;
  final String description;
  final String? attachmentUrl;
  final String status; // 'submitted', 'in_progress', 'resolved', 'closed'
  final DateTime createdAt;
  final String? orderId;
  final String? origin;
  final String? destination;

  const SupportTicket({
    required this.ticketId,
    required this.issueType,
    required this.description,
    this.attachmentUrl,
    required this.status,
    required this.createdAt,
    this.orderId,
    this.origin,
    this.destination,
  });

  String? get fullAttachmentUrl {
    if (attachmentUrl == null || attachmentUrl!.isEmpty) return null;
    if (attachmentUrl!.startsWith('http')) return attachmentUrl;
    return '${ApiConstants.imagebaseUrl}$attachmentUrl';
  }

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      ticketId: json['ticket_id']?.toString() ?? '',
      issueType: json['issue_type']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      attachmentUrl: json['attachment_url']?.toString(),
      status: json['status']?.toString() ?? 'submitted',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      orderId: json['order_id']?.toString(),
      origin: json['origin']?.toString(),
      destination: json['destination']?.toString(),
    );
  }
}

class SupportMessage {
  final int id;
  final String ticketId;
  final String userId;
  final String? message;
  final String? attachmentUrl;
  final DateTime createdAt;
  final bool isUser; 

  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.userId,
    this.message,
    this.attachmentUrl,
    required this.createdAt,
    required this.isUser,
  });

  String? get fullAttachmentUrl {
    if (attachmentUrl == null || attachmentUrl!.isEmpty) return null;
    if (attachmentUrl!.startsWith('http')) return attachmentUrl;
    return '${ApiConstants.imagebaseUrl}$attachmentUrl';
  }

  factory SupportMessage.fromJson(Map<String, dynamic> json, String currentUserId) {
    final senderId = json['user_id']?.toString();
    return SupportMessage(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      ticketId: json['ticket_id']?.toString() ?? '',
      userId: senderId ?? '',
      message: json['message'],
      attachmentUrl: json['attachment_url'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      isUser: senderId == currentUserId,
    );
  }
}

class CreateTicketRequest {
  final String userId;
  final String? orderId;
  final String issueType;
  final String description;
  final File? attachment;

  CreateTicketRequest({
    required this.userId,
    this.orderId,
    required this.issueType,
    required this.description,
    this.attachment,
  });
}
