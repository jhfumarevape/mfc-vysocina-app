import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Group>? _groups;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().get('/groups');
      setState(() {
        _groups = (res as List).map((j) => Group.fromJson(j as Map<String, dynamic>)).toList();
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final canCreate = auth.hasPermission('groups.create');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: RefreshIndicator(color: AppTheme.primary, onRefresh: _load, child: _build()),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              backgroundColor: AppTheme.primary,
              onPressed: _openCreateDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _build() {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppTheme.danger)));
    }
    if (_groups == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_groups!.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 120),
        Icon(Icons.forum_outlined, size: 64, color: AppTheme.textMuted),
        SizedBox(height: 12),
        Center(child: Text('Žádné chat skupiny', style: TextStyle(color: AppTheme.textMuted))),
      ]);
    }
    return ListView.separated(
      itemCount: _groups!.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
      itemBuilder: (_, i) {
        final g = _groups![i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary,
            child: Text(g.name.isNotEmpty ? g.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: g.lastMessagePreview != null
            ? Text(g.lastMessagePreview!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textMuted))
            : Text('${g.memberCount} členů', style: const TextStyle(color: AppTheme.textMuted)),
          trailing: SizedBox(
            width: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (g.lastMessageAt != null)
                  Text(_formatTime(g.lastMessageAt!), style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(height: 4),
                if (g.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    alignment: Alignment.center,
                    child: Text('${g.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(group: g)));
            _load();
          },
          onLongPress: () => _openGroupMenu(g),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    if (now.difference(dt).inDays < 7) {
      return DateFormat('EEE', 'cs').format(dt);
    }
    return DateFormat('d.M.').format(dt);
  }

  // ─── Group create / edit / delete ───────────────────────────────────

  Future<void> _openGroupMenu(Group g) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit, color: AppTheme.primary),
            title: const Text('Přejmenovat'),
            onTap: () => Navigator.pop(context, 'rename'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
            title: const Text('Smazat skupinu', style: TextStyle(color: AppTheme.danger)),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (action == 'rename') await _openRenameDialog(g);
    if (action == 'delete') await _confirmDelete(g);
  }

  Future<void> _openCreateDialog() async {
    final api = context.read<ApiClient>();
    List<User> allUsers;
    try {
      final res = await api.get('/groups/users');
      allUsers = (res as List).map((j) => User.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _showError('Nelze načíst uživatele: $e');
      return;
    }

    final myId = context.read<AuthService>().user?.id;
    final selected = <int>{};
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Nová chat skupina'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Název skupiny'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Popis (volitelné)'),
                ),
                const SizedBox(height: 16),
                const Text('Členové', style: TextStyle(color: AppTheme.textMuted)),
                ...allUsers.where((u) => u.id != myId).map((u) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(u.fullName ?? u.username),
                  subtitle: Text('@${u.username}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  value: selected.contains(u.id),
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      selected.add(u.id);
                    } else {
                      selected.remove(u.id);
                    }
                  }),
                )),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Zrušit')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Vytvořit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    if (nameCtrl.text.trim().isEmpty) {
      _showError('Vyplň název skupiny');
      return;
    }
    try {
      await api.post('/groups', {
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        'member_ids': selected.toList(),
      });
      _showOk('Skupina vytvořena');
      _load();
    } catch (e) {
      _showError('Chyba: $e');
    }
  }

  Future<void> _openRenameDialog(Group g) async {
    final nameCtrl = TextEditingController(text: g.name);
    final descCtrl = TextEditingController(text: g.description ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Upravit skupinu'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Název'), autofocus: true),
            const SizedBox(height: 8),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Popis')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Zrušit')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Uložit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<ApiClient>().patch('/groups/${g.id}', {
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      });
      _showOk('Skupina upravena');
      _load();
    } catch (e) {
      _showError('Chyba: $e');
    }
  }

  Future<void> _confirmDelete(Group g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Smazat "${g.name}"?'),
        content: const Text('Smaže se celá konverzace včetně všech zpráv. Tato akce je nevratná.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Zrušit')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Smazat', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<ApiClient>().delete('/groups/${g.id}');
      _showOk('Skupina smazána');
      _load();
    } catch (e) {
      _showError('Chyba: $e');
    }
  }

  void _showOk(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.primary));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.danger));
  }
}
