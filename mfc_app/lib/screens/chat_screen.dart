import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/avatar.dart';

class ChatScreen extends StatefulWidget {
  final Group group;
  const ChatScreen({super.key, required this.group});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final _scroll = ScrollController();
  final _input = TextEditingController();
  WebSocketChannel? _ws;
  bool _loading = true;
  bool _sending = false;
  XFile? _picked;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final api = context.read<ApiClient>();
    try {
      final res = await api.get('/groups/${widget.group.id}/messages', query: {'limit': '50'});
      final msgs = (res as List).map((j) => Message.fromJson(j as Map<String, dynamic>)).toList();
      setState(() { _messages.addAll(msgs); _loading = false; });
      _scrollToBottom();
      // Mark read
      await api.post('/groups/${widget.group.id}/read');
      _connectWs();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $e')));
    }
  }

  void _connectWs() {
    final token = context.read<ApiClient>().token;
    final url = Uri.parse('${AppConfig.wsBaseUrl}/ws/chat/${widget.group.id}?token=$token');
    _ws = WebSocketChannel.connect(url);
    _ws!.stream.listen((event) {
      try {
        final json = jsonDecode(event as String) as Map<String, dynamic>;
        final msg = Message.fromJson(json);
        if (mounted) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }
      } catch (_) {}
    }, onError: (_) {}, onDone: () {});
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
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if ((text.isEmpty && _picked == null) || _sending) return;
    setState(() => _sending = true);
    try {
      String? imageUrl;
      if (_picked != null) {
        final api = context.read<ApiClient>();
        if (kIsWeb) {
          final bytes = await _picked!.readAsBytes();
          imageUrl = (await api.uploadImageBytes(bytes, _picked!.name))['url'] as String?;
        } else {
          imageUrl = (await api.uploadImage(File(_picked!.path)))['url'] as String?;
        }
      }
      _ws?.sink.add(jsonEncode({
        'content': text,
        if (imageUrl != null) 'image_url': imageUrl,
      }));
      _input.clear();
      setState(() => _picked = null);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $e'), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _ws?.sink.close();
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().user;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [IconButton(icon: const Icon(Icons.info_outline), onPressed: () {})],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final msg = _messages[i];
                    final isMe = me != null && msg.author.id == me.id;
                    final prev = i > 0 ? _messages[i - 1] : null;
                    final showAvatar = !isMe && (prev == null || prev.author.id != msg.author.id);
                    return _MessageBubble(message: msg, isMe: isMe, showAvatar: showAvatar);
                  },
                ),
          ),
          if (_picked != null) _PickedPreview(picked: _picked!, onRemove: () => setState(() => _picked = null)),
          _Composer(
            controller: _input,
            sending: _sending,
            onSend: _send,
            onPickPhoto: _showPickerSheet,
            onChange: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}

class _PickedPreview extends StatelessWidget {
  final XFile picked;
  final VoidCallback onRemove;
  const _PickedPreview({required this.picked, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56, height: 56,
              child: kIsWeb
                ? Image.network(picked.path, fit: BoxFit.cover)
                : Image.file(File(picked.path), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Připravená fotka', style: TextStyle(color: AppTheme.textMuted))),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
            tooltip: 'Odebrat',
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showAvatar;
  const _MessageBubble({required this.message, required this.isMe, required this.showAvatar});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('HH:mm');
    final hasImage = message.imageUrl != null && message.imageUrl!.isNotEmpty;
    final hasText = message.content.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (showAvatar) Avatar(user: message.author, size: 28) else const SizedBox(width: 28),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: hasImage && !hasText
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primary : AppTheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMe ? 14 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 14),
                ),
                border: isMe ? null : Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
                      child: Text(message.author.displayName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                    ),
                  if (hasImage)
                    GestureDetector(
                      onTap: () => _openFullscreen(context, message.imageUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: ApiClient.absoluteUrl(message.imageUrl),
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 200, width: 280,
                            color: AppTheme.surfaceAlt,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 200, width: 280,
                            color: AppTheme.surfaceAlt,
                            child: const Icon(Icons.broken_image_outlined, color: AppTheme.textMuted),
                          ),
                        ),
                      ),
                    ),
                  if (hasText)
                    Padding(
                      padding: hasImage ? const EdgeInsets.fromLTRB(8, 6, 8, 4) : EdgeInsets.zero,
                      child: Text(message.content,
                        style: TextStyle(color: isMe ? Colors.white : AppTheme.text, fontSize: 14)),
                    ),
                  Padding(
                    padding: hasImage ? const EdgeInsets.fromLTRB(8, 0, 8, 4) : EdgeInsets.zero,
                    child: Text(df.format(message.createdAt),
                      style: TextStyle(color: isMe ? Colors.white70 : AppTheme.textMuted, fontSize: 10)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreen(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: Center(
          child: InteractiveViewer(
            child: CachedNetworkImage(imageUrl: ApiClient.absoluteUrl(url)),
          ),
        ),
      ),
    ));
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPickPhoto;
  final VoidCallback onChange;
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onPickPhoto,
    required this.onChange,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: EdgeInsets.fromLTRB(4, 4, 8, MediaQuery.of(context).viewPadding.bottom + 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Přidat fotku',
            onPressed: sending ? null : onPickPhoto,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1, maxLines: 4,
              onChanged: (_) => onChange(),
              decoration: const InputDecoration(
                hintText: 'Napiš zprávu...',
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            onPressed: sending ? null : onSend,
            icon: sending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send, size: 18),
            style: IconButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
