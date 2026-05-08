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
      itemBuilder: (_, i) => _PostCard(post: _posts![i], onChanged: _load),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onChanged;
  const _PostCard({required this.post, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().user;
    final canManage = me != null && (me.id == post.author.id || me.role == 'admin' || me.role == 'captain');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      Text(_relativeDate(post.createdAt), style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                if (post.pinned)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.push_pin, size: 16, color: AppTheme.primary),
                  ),
                if (canManage)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, color: AppTheme.textMuted),
                    onSelected: (v) async {
                      if (v == 'delete') {
                        await context.read<ApiClient>().delete('/posts/${post.id}');
                        onChanged();
                      } else if (v == 'pin') {
                        await context.read<ApiClient>().post('/posts/${post.id}/pin');
                        onChanged();
                      }
                    },
                    itemBuilder: (_) => [
                      if (me?.role == 'admin' || me?.role == 'captain')
                        PopupMenuItem(value: 'pin', child: Text(post.pinned ? 'Odepnout' : 'Připnout')),
                      const PopupMenuItem(value: 'delete', child: Text('Smazat')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(post.content, style: const TextStyle(fontSize: 15, height: 1.4)),
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
          ],
        ),
      ),
    );
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'právě teď';
    if (diff.inMinutes < 60) return 'před ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'před ${diff.inHours} h';
    if (diff.inDays < 7) return 'před ${diff.inDays} dny';
    return DateFormat('d.M.yyyy').format(dt);
  }
}

class _NewPostScreen extends StatefulWidget {
  const _NewPostScreen();
  @override
  State<_NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<_NewPostScreen> {
  final _content = TextEditingController();
  bool _busy = false;
  XFile? _picked;

  Future<void> _pickPhoto({required ImageSource source}) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, maxWidth: 2000, imageQuality: 85);
      if (file != null) setState(() => _picked = file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nelze vybrat fotku: $e')));
      }
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

  Future<void> _submit() async {
    final text = _content.text.trim();
    if (text.isEmpty && _picked == null) return;
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
      await api.post('/posts', {
        'content': text,
        if (imageUrl != null) 'image_url': imageUrl,
      });
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
    final canSubmit = !_busy && (_content.text.trim().isNotEmpty || _picked != null);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nový příspěvek'),
        actions: [
          TextButton(
            onPressed: canSubmit ? _submit : null,
            child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
              : const Text('Odeslat', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _content,
                autofocus: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Co je nového v týmu?',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          if (_picked != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                      ? Image.network(_picked!.path, height: 220, width: double.infinity, fit: BoxFit.cover)
                      : Image.file(File(_picked!.path), height: 220, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _picked = null),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Toolbar dole — přidat fotku
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
                const Spacer(),
                if (_picked != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('1 fotka', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
