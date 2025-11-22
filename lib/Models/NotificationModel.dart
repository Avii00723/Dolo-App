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
    return NotificationModel(
      id: json['id'] ?? json['hashed_id'] ?? '',
      hashedId: json['hashed_id'] ?? json['id'] ?? '',
      userId: json['user_id'] ?? 0,
      actorUserId: json['actor_user_id'],
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
      isRead: (json['is_read'] ?? 0) == 1,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
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
