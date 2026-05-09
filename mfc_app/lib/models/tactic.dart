class Tactic {
  final int id;
  final String title;
  final String? description;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? category;
  final int sortOrder;
  final DateTime createdAt;

  Tactic({
    required this.id,
    required this.title,
    this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    this.category,
    required this.sortOrder,
    required this.createdAt,
  });

  factory Tactic.fromJson(Map<String, dynamic> j) => Tactic(
        id: j['id'] as int,
        title: j['title'] as String,
        description: j['description'] as String?,
        videoUrl: j['video_url'] as String,
        thumbnailUrl: j['thumbnail_url'] as String?,
        category: j['category'] as String?,
        sortOrder: j['sort_order'] as int? ?? 0,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  /// YouTube video ID extrakce — pro thumbnail i embed.
  String? get youtubeId {
    final reg = RegExp(
      r'(?:youtube\.com/(?:watch\?v=|embed/|shorts/)|youtu\.be/)([A-Za-z0-9_-]{11})',
    );
    final m = reg.firstMatch(videoUrl);
    return m?.group(1);
  }

  /// Auto-generovaná YouTube thumbnail (pokud video je YT).
  String? get effectiveThumbnail {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl;
    final id = youtubeId;
    if (id != null) return 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
    return null;
  }
}
