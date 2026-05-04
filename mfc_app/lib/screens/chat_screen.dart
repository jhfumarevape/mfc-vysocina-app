import 'dart:convert';

import 'package:flutter/material.dart';
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

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      _ws?.sink.add(jsonEncode({'content': text}));
      _input.clear();
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
          _Composer(controller: _input, sending: _sending, onSend: _send),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                children: [
                  if (!isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(message.author.displayName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                    ),
                  Text(message.content,
                    style: TextStyle(color: isMe ? Colors.white : AppTheme.text, fontSize: 14)),
                  Text(df.format(message.createdAt),
                    style: TextStyle(color: isMe ? Colors.white70 : AppTheme.textMuted, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _Composer({required this.controller, required this.sending, required this.onSend});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).viewPadding.bottom + 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1, maxLines: 4,
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
            icon: const Icon(Icons.send, size: 18),
            style: IconButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
