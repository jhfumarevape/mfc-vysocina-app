import 'user.dart';

/// Anketa připojená k postu (volitelná).
class Poll {
  final int id;
  final String question;
  final bool multipleChoice;
  final DateTime? closesAt;
  final int totalVotes;
  final List<PollOption> options;

  Poll({
    required this.id,
    required this.question,
    required this.multipleChoice,
    this.closesAt,
    required this.totalVotes,
    required this.options,
  });

  factory Poll.fromJson(Map<String, dynamic> json) => Poll(
    id: json['id'] as int,
    question: json['question'] as String,
    multipleChoice: json['multiple_choice'] as bool? ?? false,
    closesAt: json['closes_at'] != null ? DateTime.parse(json['closes_at']) : null,
    totalVotes: json['total_votes'] as int? ?? 0,
    options: (json['options'] as List? ?? []).map((o) => PollOption.fromJson(o as Map<String, dynamic>)).toList(),
  );

  bool get isClosed => closesAt != null && closesAt!.isBefore(DateTime.now());
}

class PollOption {
  final int id;
  final String label;
  final int voteCount;
  final bool voted;

  PollOption({required this.id, required this.label, required this.voteCount, required this.voted});

  factory PollOption.fromJson(Map<String, dynamic> json) => PollOption(
    id: json['id'] as int,
    label: json['label'] as String,
    voteCount: json['vote_count'] as int? ?? 0,
    voted: json['voted'] as bool? ?? false,
  );
}

/// Komentář pod postem.
class PostComment {
  final int id;
  final int postId;
  final User author;
  final String content;
  final DateTime createdAt;

  PostComment({required this.id, required this.postId, required this.author, required this.content, required this.createdAt});

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
    id: json['id'] as int,
    postId: json['post_id'] as int,
    author: User.fromJson(json['author'] as Map<String, dynamic>),
    content: json['content'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

/// Hlavní post v Feedu.
class Post {
  final int id;
  final User author;
  final String content;
  final String? imageUrl;
  final bool pinned;
  final DateTime createdAt;
  /// emoji -> count (např. {"👍": 3, "💪": 1})
  final Map<String, int> reactions;
  /// Emoji co tenhle uživatel zatleskal (může jich být víc).
  final Set<String> myReactions;
  final int commentCount;
  final Poll? poll;

  Post({
    required this.id,
    required this.author,
    required this.content,
    this.imageUrl,
    required this.pinned,
    required this.createdAt,
    Map<String, int>? reactions,
    Set<String>? myReactions,
    this.commentCount = 0,
    this.poll,
  })  : reactions = reactions ?? const {},
        myReactions = myReactions ?? const {};

  factory Post.fromJson(Map<String, dynamic> json) {
    final raw = (json['reactions'] as Map?)?.cast<String, dynamic>() ?? const {};
    final reactionsMap = <String, int>{ for (final e in raw.entries) e.key: (e.value as num).toInt() };
    final myList = (json['my_reactions'] as List?)?.cast<String>() ?? const [];
    return Post(
      id: json['id'] as int,
      author: User.fromJson(json['author'] as Map<String, dynamic>),
      content: json['content'] as String,
      imageUrl: json['image_url'] as String?,
      pinned: json['pinned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      reactions: reactionsMap,
      myReactions: myList.toSet(),
      commentCount: json['comment_count'] as int? ?? 0,
      poll: json['poll'] != null ? Poll.fromJson(json['poll'] as Map<String, dynamic>) : null,
    );
  }
}
