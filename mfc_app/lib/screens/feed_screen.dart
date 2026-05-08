import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/avatar.dart';
import 'post_detail_screen.dart';

/// Povolená emoji — musí odpovídat ALLOWED_EMOJI v backendu.
const kReactionEmojis = ['👍', '❤️', '💪', '😄', '🔥', '🛡️', '⚔️', '🏆'];

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Post>? _posts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiClient>();
      final res = await api.get('/posts');
      setState(() {
        _posts = (res as List).map((j) => Post.fromJson(j as Map<String, dynamic>)).toList();
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _newPost() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _NewPostScreen()),
    );
    if (result == true) _load();
  }

  void _replacePost(Post updated) {
    setState(() {
      final idx = _posts!.indexWhere((p) => p.id == updated.id);
      if (idx != -1) _posts![idx] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Domů'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: _newPost,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    if (_posts == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_posts!.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.forum_outlined, size: 64, color: AppTheme.textMuted),
          SizedBox(height: 12),
          Center(child: Text('Zatím žádné příspěvky', style: TextStyle(color: AppTheme.textMuted))),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _posts!.length,
      itemBuilder: (_, i) => PostCard(post: _posts![i], onChanged: _load, onReplaced: _replacePost),
    );
  }
}

// ─── Post card ──────────────────────────────────────────────────────────

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onChanged;
  final void Function(Post updated) onReplaced;
  const PostCard({super.key, required this.post, required this.onChanged, required this.onReplaced});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().user;
    final canManage = me != null && (me.id == post.author.id || me.role == 'admin' || me.role == 'captain');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PostDetailScreen(post: post, onPostChanged: onReplaced),
        )),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Avatar(user: post.author, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.author.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(_relativeDate(post.createdAt),
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (post.pinned)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.push_pin, size: 16, color: AppTheme.primary),
                    ),
                  if (canManage) _PostMenu(post: post, onChanged: onChanged, onReplaced: onReplaced),
                ],
              ),
              if (post.content.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(post.content, style: const TextStyle(fontSize: 15, height: 1.4)),
              ],
              if (post.imageUrl != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: ApiClient.absoluteUrl(post.imageUrl),
                    placeholder: (_, __) => Container(height: 200, color: AppTheme.surfaceAlt),
                  ),
                ),
              ],
              if (post.poll != null) ...[
                const SizedBox(height: 12),
                _PollWidget(post: post, onReplaced: onReplaced),
              ],
              const SizedBox(height: 10),
              _ReactionsRow(post: post, onReplaced: onReplaced),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'právě teď';
    if (diff.inMinutes < 60) return 'před ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'před ${diff.inHours} h';
    if (diff.inDays < 7) return 'před ${diff.inDays} dny';
    return DateFormat('d.M.yyyy').format(dt);
  }
}

class _PostMenu extends StatelessWidget {
  final Post post;
  final VoidCallback onChanged;
  final void Function(Post) onReplaced;
  const _PostMenu({required this.post, required this.onChanged, required this.onReplaced});
  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().user;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, color: AppTheme.textMuted),
      onSelected: (v) async {
        try {
          if (v == 'delete') {
            await context.read<ApiClient>().delete('/posts/${post.id}');
            onChanged();
          } else if (v == 'pin') {
            final updated = await context.read<ApiClient>().post('/posts/${post.id}/pin');
            onReplaced(Post.fromJson(updated as Map<String, dynamic>));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $e')));
          }
        }
      },
      itemBuilder: (_) => [
        if (me?.role == 'admin' || me?.role == 'captain')
          PopupMenuItem(value: 'pin', child: Text(post.pinned ? 'Odepnout' : 'Připnout')),
        const PopupMenuItem(value: 'delete', child: Text('Smazat')),
      ],
    );
  }
}

// ─── Reactions row + komentář link ──────────────────────────────────────

class _ReactionsRow extends StatelessWidget {
  final Post post;
  final void Function(Post) onReplaced;
  const _ReactionsRow({required this.post, required this.onReplaced});

  Future<void> _toggle(BuildContext context, String emoji) async {
    try {
      final updated = await context.read<ApiClient>().post('/posts/${post.id}/react/$emoji');
      onReplaced(Post.fromJson(updated as Map<String, dynamic>));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $e')));
      }
    }
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8, runSpacing: 8,
            children: kReactionEmojis.map((e) {
              final selected = post.myReactions.contains(e);
              return InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () { Navigator.pop(sheetCtx); _toggle(context, e); },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary.withValues(alpha: 0.18) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? AppTheme.primary : AppTheme.border),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 28)),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Existující reakce s počty
    final entries = post.reactions.entries.toList();
    return Row(
      children: [
        // Add reaction button
        InkWell(
          onTap: () => _showPicker(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_reaction_outlined, size: 16, color: AppTheme.textMuted),
                SizedBox(width: 4),
                Text('Reakce', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Existing reactions
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final e in entries) ...[
                  _ReactionChip(
                    emoji: e.key,
                    count: e.value,
                    selected: post.myReactions.contains(e.key),
                    onTap: () => _toggle(context, e.key),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
        // Comments badge
        InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: post, onPostChanged: onReplaced, focusComposer: true),
          )),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mode_comment_outlined, size: 16, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text('${post.commentCount}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _ReactionChip({required this.emoji, required this.count, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withValues(alpha: 0.18) : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.primary : AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text('$count', style: TextStyle(fontSize: 12, color: selected ? AppTheme.primary : AppTheme.text, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Poll widget ────────────────────────────────────────────────────────

class _PollWidget extends StatelessWidget {
  final Post post;
  final void Function(Post) onReplaced;
  const _PollWidget({required this.post, required this.onReplaced});

  Future<void> _vote(BuildContext context, int optionId) async {
    try {
      final newPoll = await context.read<ApiClient>().post('/posts/${post.id}/poll/options/$optionId/vote');
      // Server vrací jen Poll, takže si poskládám nový Post.
      final updatedPost = Post(
        id: post.id,
        author: post.author,
        content: post.content,
        imageUrl: post.imageUrl,
        pinned: post.pinned,
        createdAt: post.createdAt,
        reactions: post.reactions,
        myReactions: post.myReactions,
        commentCount: post.commentCount,
        poll: Poll.fromJson(newPoll as Map<String, dynamic>),
      );
      onReplaced(updatedPost);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = post.poll!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(poll.question, style: const TextStyle(fontWeight: FontWeight.w700))),
              if (poll.isClosed)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text('Uzavřeno', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...poll.options.map((opt) {
            final pct = poll.totalVotes == 0 ? 0.0 : opt.voteCount / poll.totalVotes;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: poll.isClosed ? null : () => _vote(context, opt.id),
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    // Background bar
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: opt.voted ? AppTheme.primary : AppTheme.border),
                      ),
                    ),
                    // Filled bar
                    FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: opt.voted ? AppTheme.primary.withValues(alpha: 0.35) : AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    // Label
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              opt.voted ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 16,
                              color: opt.voted ? AppTheme.primary : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(opt.label, style: const TextStyle(fontSize: 14))),
                            Text('${opt.voteCount}', style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: opt.voted ? FontWeight.w700 : FontWeight.w400)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          Text(
            poll.totalVotes == 1 ? '1 hlas' : '${poll.totalVotes} hlasů',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── New post screen ────────────────────────────────────────────────────

class _NewPostScreen extends StatefulWidget {
  const _NewPostScreen();
  @override
  State<_NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<_NewPostScreen> {
  final _content = TextEditingController();
  bool _busy = false;
  XFile? _picked;
  // Poll state
  bool _showPoll = false;
  final _pollQuestion = TextEditingController();
  final List<TextEditingController> _pollOptions = [
    TextEditingController(), TextEditingController(),
  ];
  bool _multipleChoice = false;

  @override
  void dispose() {
    _content.dispose();
    _pollQuestion.dispose();
    for (final c in _pollOptions) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto({required ImageSource source}) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, maxWidth: 2000, imageQuality: 85);
      if (file != null) setState(() => _picked = file);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nelze vybrat fotku: $e')));
    }
  }

  void _showPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
                title: const Text('Vyfotit'),
                onTap: () { Navigator.pop(context); _pickPhoto(source: ImageSource.camera); },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
              title: const Text('Z galerie'),
              onTap: () { Navigator.pop(context); _pickPhoto(source: ImageSource.gallery); },
            ),
            if (_picked != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
                title: const Text('Odstranit fotku', style: TextStyle(color: AppTheme.danger)),
                onTap: () { Navigator.pop(context); setState(() => _picked = null); },
              ),
          ],
        ),
      ),
    );
  }

  bool get _canSubmit {
    if (_busy) return false;
    final hasContentOrImage = _content.text.trim().isNotEmpty || _picked != null;
    final pollValid = !_showPoll || (
      _pollQuestion.text.trim().isNotEmpty
      && _pollOptions.where((c) => c.text.trim().isNotEmpty).length >= 2
    );
    return hasContentOrImage && pollValid;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _busy = true);
    try {
      final api = context.read<ApiClient>();
      String? imageUrl;
      if (_picked != null) {
        if (kIsWeb) {
          final bytes = await _picked!.readAsBytes();
          imageUrl = (await api.uploadImageBytes(bytes, _picked!.name))['url'] as String?;
        } else {
          imageUrl = (await api.uploadImage(File(_picked!.path)))['url'] as String?;
        }
      }
      final body = <String, dynamic>{
        'content': _content.text.trim(),
        if (imageUrl != null) 'image_url': imageUrl,
      };
      if (_showPoll) {
        body['poll'] = {
          'question': _pollQuestion.text.trim(),
          'options': _pollOptions
              .where((c) => c.text.trim().isNotEmpty)
              .map((c) => {'label': c.text.trim()})
              .toList(),
          'multiple_choice': _multipleChoice,
        };
      }
      await api.post('/posts', body);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $e'), backgroundColor: AppTheme.danger));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nový příspěvek'),
        actions: [
          TextButton(
            onPressed: _canSubmit ? _submit : null,
            child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
              : const Text('Odeslat', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _content,
                  autofocus: true,
                  maxLines: null,
                  minLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Co je nového v týmu?',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 16),
                  onChanged: (_) => setState(() {}),
                ),
                if (_picked != null) ...[
                  const SizedBox(height: 12),
                  Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                        ? Image.network(_picked!.path, height: 220, width: double.infinity, fit: BoxFit.cover)
                        : Image.file(File(_picked!.path), height: 220, width: double.infinity, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _picked = null),
                          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close, size: 18, color: Colors.white)),
                        ),
                      ),
                    ),
                  ]),
                ],
                if (_showPoll) _buildPollEditor(),
              ],
            ),
          ),
          // Toolbar
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            padding: EdgeInsets.fromLTRB(8, 4, 8, MediaQuery.of(context).viewPadding.bottom + 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  tooltip: 'Přidat fotku',
                  onPressed: _busy ? null : _showPickerSheet,
                ),
                IconButton(
                  icon: Icon(Icons.bar_chart, color: _showPoll ? AppTheme.primary : null),
                  tooltip: 'Anketa',
                  onPressed: _busy ? null : () => setState(() => _showPoll = !_showPoll),
                ),
                const Spacer(),
                if (_picked != null)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text('1 fotka', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollEditor() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 18, color: AppTheme.primary),
              const SizedBox(width: 6),
              const Text('Anketa', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _showPoll = false),
              ),
            ],
          ),
          TextField(
            controller: _pollQuestion,
            decoration: const InputDecoration(hintText: 'Otázka', border: InputBorder.none),
            onChanged: (_) => setState(() {}),
          ),
          const Divider(color: AppTheme.border),
          for (var i = 0; i < _pollOptions.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _pollOptions[i],
                    decoration: InputDecoration(hintText: 'Možnost ${i + 1}', isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_pollOptions.length > 2)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppTheme.textMuted),
                    onPressed: () => setState(() {
                      _pollOptions[i].dispose();
                      _pollOptions.removeAt(i);
                    }),
                  ),
              ]),
            ),
          if (_pollOptions.length < 10)
            TextButton.icon(
              onPressed: () => setState(() => _pollOptions.add(TextEditingController())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Další možnost'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Switch(
                value: _multipleChoice,
                activeColor: AppTheme.primary,
                onChanged: (v) => setState(() => _multipleChoice = v),
              ),
              const SizedBox(width: 8),
              const Text('Více možností najednou', style: TextStyle(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Error view ─────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
        const SizedBox(height: 12),
        Center(child: Text(message, style: const TextStyle(color: AppTheme.textMuted))),
        const SizedBox(height: 16),
        Center(child: OutlinedButton(onPressed: onRetry, child: const Text('Zkusit znovu'))),
      ],
    );
  }
}
