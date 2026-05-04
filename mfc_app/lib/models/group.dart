import 'user.dart';

class Group {
  final int id;
  final String name;
  final String? description;
  final int memberCount;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;

  Group({
    required this.id,
    required this.name,
    this.description,
    required this.memberCount,
    this.lastMessageAt,
    this.lastMessagePreview,
    required this.unreadCount,
  });

  factory Group.fromJson(Map<String, dynamic> json) => Group(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String?,
    memberCount: json['member_count'] as int? ?? 0,
    lastMessageAt: json['last_message_at'] != null ? DateTime.parse(json['last_message_at']) : null,
    lastMessagePreview: json['last_message_preview'] as String?,
    unreadCount: json['unread_count'] as int? ?? 0,
  );
}

class Message {
  final int id;
  final int groupId;
  final User author;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.groupId,
    required this.author,
    required this.content,
    this.imageUrl,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as int,
    groupId: json['group_id'] as int,
    author: User.fromJson(json['author'] as Map<String, dynamic>),
    content: json['content'] as String,
    imageUrl: json['image_url'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
