class User {
  final int id;
  final String username;
  final String email;
  final String? fullName;
  final String role;
  final String? avatarUrl;
  final String? bio;
  final DateTime createdAt;
  final DateTime? lastSeen;
  final bool isBanned;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.fullName,
    required this.role,
    this.avatarUrl,
    this.bio,
    required this.createdAt,
    this.lastSeen,
    this.isBanned = false,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    username: json['username'] as String,
    email: json['email'] as String,
    fullName: json['full_name'] as String?,
    role: json['role'] as String? ?? 'member',
    avatarUrl: json['avatar_url'] as String?,
    bio: json['bio'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
    isBanned: json['is_banned'] as bool? ?? false,
  );

  String get displayName => fullName?.isNotEmpty == true ? fullName! : username;

  String get initials {
    final name = displayName;
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  bool get isAdmin => role == 'admin';
  bool get isCaptain => role == 'captain';
  bool get isModerator => role == 'admin' || role == 'captain';

  /// Online if last activity in past 5 minutes.
  bool get isOnline {
    if (lastSeen == null) return false;
    return DateTime.now().toUtc().difference(lastSeen!.toUtc()).inMinutes < 5;
  }

  String get roleLabel {
    switch (role) {
      case 'admin':   return 'Admin';
      case 'captain': return 'Kapitán';
      default:        return 'Člen';
    }
  }
}
