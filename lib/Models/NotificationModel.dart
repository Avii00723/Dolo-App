class NotificationModel {
  final String id;
  final String hashedId;
  final int userId;
  final int? actorUserId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.hashedId,
    required this.userId,
    this.actorUserId,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Helper to parse is_read which can be int (1/0) or bool
    bool parseIsRead(dynamic value) {
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value == '1' || value.toLowerCase() == 'true';
      return false;
    }

    // Helper to parse int fields that might come as strings
    int parseInt(dynamic value, int defaultValue) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    return NotificationModel(
      id: json['id']?.toString() ?? json['hashed_id']?.toString() ?? '',
      hashedId: json['hashed_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: parseInt(json['user_id'], 0),
      actorUserId: json['actor_user_id'] != null ? parseInt(json['actor_user_id'], 0) : null,
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
      isRead: parseIsRead(json['is_read']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hashed_id': hashedId,
      'user_id': userId,
      'actor_user_id': actorUserId,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
