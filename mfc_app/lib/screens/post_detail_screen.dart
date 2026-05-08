import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/post.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/avatar.dart';
import 'feed_screen.dart';

/// Detail postu — celý obsah + komentáře.
/// `focusComposer: true` ihned po otevření zacílí input pro nový komentář.
class PostDetailScreen extends StatefulWidget {
  final Post post;
  final void Function(Post updated) onPostChanged;
  final bool focusComposer;
  const PostDetailScreen({
    super.key,
    required this.post,
    required this.onPostChanged,
    this.focusComposer = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post _post;
  List<PostComment>? _comments;
  String? _commentsError;
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadComments();
    if (widget.focusComposer) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _composerFocus.requestFocus());
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final res = await context.read<ApiClient>().get('/posts/${_post.id}/comments');
      setState(() {
        _comments = (res as List).map((j) => PostComment.fromJson(j as Map<String, dynamic>)).toList();
        _commentsError = null;
      });
    } catch (e) {
      setState(() => _commentsError = e.toString());
    }
  }

  void _replacePost(Post updated) {
    setState(() => _post = updated);
    widget.onPostChanged(updated);
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final res = await context.read<ApiClient>().post('/posts/${_post.id}/comments', {'content': text});
      final created = PostComment.fromJson(res as Map<String, dynamic>);
      setState(() {
        _comments = [...?_comments, created];
        _composer.clear();
        _post = Post(
          id: _post.id,
          author: _post.author,
          content: _post.content,
          imageUrl: _post.imageUrl,
          pinned: _post.pinned,
          createdAt: _post.createdAt,
          reactions: _post.reactions,
          myReactions: _post.myReactions,
          commentCount: _post.commentCount + 1,
          poll: _post.poll,
        );
      });
      widget.onPostChanged(_post);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $e'), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(PostComment c) async {
    try {
      await context.read<ApiClient>().delete('/posts/${_post.id}/comments/${c.id}');
      setState(() {
        _comments?.removeWhere((x) => x.id == c.id);
        _post = Post(
          id: _post.id,
          author: _post.author,
          content: _post.content,
          imageUrl: _post.imageUrl,
          pinned: _post.pinned,
          createdAt: _post.createdAt,
          reactions: _post.reactions,
          myReactions: _post.myReactions,
          commentCount: (_post.commentCount - 1).clamp(0, 1 << 30),
          poll: _post.poll,
        );
      });
      widget.onPostChanged(_post);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('Příspěvek')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Post sám (znovu render — same widget jako ve Feedu, ale rozbalený)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Avatar(user: _post.author, size: 44),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_post.author.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                Text(_relative(_post.createdAt), style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (_post.pinned)
                            const Icon(Icons.push_pin, size: 16, color: AppTheme.primary),
                        ]),
                        if (_post.content.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(_post.content, style: const TextStyle(fontSize: 16, height: 1.4)),
                        ],
                        if (_post.imageUrl != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(imageUrl: ApiClient.absoluteUrl(_post.imageUrl)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Komentář header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    _post.commentCount == 0 ? 'KOMENTÁŘE' : 'KOMENTÁŘE (${_post.commentCount})',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                if (_commentsError != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_commentsError!, style: const TextStyle(color: AppTheme.danger)),
                  )
                else if (_comments == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  )
                else if (_comments!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Center(child: Text('Zatím žádný komentář — buď první!', style: TextStyle(color: AppTheme.textMuted))),
                  )
                else
                  ..._comments!.map((c) {
                    final canDelete = me != null && (c.author.id == me.id || me.role == 'admin' || me.role == 'captain');
                    return _CommentTile(
                      comment: c,
                      canDelete: canDelete,
                      onDelete: () => _deleteComment(c),
                    );
                  }),

                const SizedBox(height: 80),
              ],
            ),
          ),

          // Composer
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).viewPadding.bottom + 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _composer,
                    focusNode: _composerFocus,
                    minLines: 1, maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Přidat komentář...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, size: 18),
                  style: IconButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'právě teď';
    if (diff.inMinutes < 60) return 'před ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'před ${diff.inHours} h';
    if (diff.inDays < 7) return 'před ${diff.inDays} dny';
    return DateFormat('d.M.yyyy HH:mm').format(dt);
  }
}

class _CommentTile extends StatelessWidget {
  final PostComment comment;
  final bool canDelete;
  final VoidCallback onDelete;
  const _CommentTile({required this.comment, required this.canDelete, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(user: comment.author, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(comment.author.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(comment.content, style: const TextStyle(fontSize: 14, height: 1.3)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 0, 0),
                  child: Text(_relative(comment.createdAt), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textMuted),
              tooltip: 'Smazat',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Smazat komentář?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušit')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Smazat', style: TextStyle(color: AppTheme.danger))),
                    ],
                  ),
                );
                if (ok == true) onDelete();
              },
            ),
        ],
      ),
    );
  }

  static String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'právě teď';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) return '${diff.inDays} dní';
    return DateFormat('d.M. HH:mm').format(dt);
  }
}
