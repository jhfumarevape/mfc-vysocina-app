class Rule {
  final int id;
  final String title;
  final String content;
  final String? category;
  final String? documentUrl;
  final int sortOrder;
  final DateTime updatedAt;
  final DateTime createdAt;

  Rule({
    required this.id,
    required this.title,
    required this.content,
    this.category,
    this.documentUrl,
    required this.sortOrder,
    required this.updatedAt,
    required this.createdAt,
  });

  factory Rule.fromJson(Map<String, dynamic> j) => Rule(
        id: j['id'] as int,
        title: j['title'] as String,
        content: j['content'] as String,
        category: j['category'] as String?,
        documentUrl: j['document_url'] as String?,
        sortOrder: j['sort_order'] as int? ?? 0,
        updatedAt: DateTime.parse(j['updated_at'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
