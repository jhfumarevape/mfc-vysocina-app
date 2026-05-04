import 'user.dart';

class Post {
  final int id;
  final User author;
  final String content;
  final String? imageUrl;
  final bool pinned;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.author,
    required this.content,
    this.imageUrl,
    required this.pinned,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as int,
    author: User.fromJson(json['author'] as Map<String, dynamic>),
    content: json['content'] as String,
    imageUrl: json['image_url'] as String?,
    pinned: json['pinned'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
