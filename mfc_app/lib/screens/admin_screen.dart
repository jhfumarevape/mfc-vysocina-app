import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/avatar.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textMuted,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Přehled'),
              Tab(icon: Icon(Icons.people_outline), text: 'Uživatelé'),
              Tab(icon: Icon(Icons.event_note_outlined), text: 'Eventy'),
              Tab(icon: Icon(Icons.forum_outlined), text: 'Skupiny'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _StatsTab(),
            _UsersTab(),
            _EventsTab(),
            _GroupsTab(),
          ],
        ),
      ),
    );
  }
}

// ─── Stats tab ─────────────────────────────────────────────────────────

class _StatsTab extends StatefulWidget {
  const _StatsTab();
  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  Map<String, dynamic>? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().get('/admin/stats');
      setState(() => _stats = res as Map<String, dynamic>);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _ErrorView(message: _error!, onRetry: _load);
    if (_stats == null) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _StatTile(label: 'Celkem členů', value: '${_stats!['total_users']}', icon: Icons.people, color: AppTheme.primary),
              _StatTile(label: 'Online teď', value: '${_stats!['online_users']}', icon: Icons.circle, color: AppTheme.success),
              _StatTile(label: 'Aktivní 7 dní', value: '${_stats!['active_users_7d']}', icon: Icons.schedule, color: AppTheme.warning),
              _StatTile(label: 'Příspěvky', value: '${_stats!['total_posts']}', icon: Icons.forum, color: Colors.blue),
              _StatTile(label: 'Akce', value: '${_stats!['total_events']}', icon: Icons.event, color: Colors.purple),
              _StatTile(label: 'Zprávy', value: '${_stats!['total_messages']}', icon: Icons.chat, color: Colors.teal),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const Spacer(),
          ]),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Users tab ─────────────────────────────────────────────────────────

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<User>? _users;
  bool _onlineOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await context.read<ApiClient>().get('/admin/users', query: _onlineOnly ? {'online_only': 'true'} : null);
    setState(() => _users = (res as List).map((j) => User.fromJson(j as Map<String, dynamic>)).toList());
  }

  Future<void> _changeRole(User u, String newRole) async {
    await context.read<ApiClient>().patch('/admin/users/${u.id}', {'role': newRole});
    _load();
  }

  Future<void> _toggleBan(User u) async {
    await context.read<ApiClient>().patch('/admin/users/${u.id}', {'is_banned': !u.isBanned});
    _load();
  }

  Future<void> _delete(User u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Smazat uživatele?'),
        content: Text('Smazat trvale uživatele "${u.displayName}"? Smaže i jeho posty, zprávy, RSVP.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušit')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Smazat', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok == true) {
      await context.read<ApiClient>().delete('/admin/users/${u.id}');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_users == null) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              FilterChip(
                label: const Text('Pouze online'),
                selected: _onlineOnly,
                onSelected: (v) { setState(() => _onlineOnly = v); _load(); },
                selectedColor: AppTheme.primary.withValues(alpha: .3),
              ),
              const Spacer(),
              Text('${_users!.length} uživatelů', style: const TextStyle(color: AppTheme.textMuted)),
            ]),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _users!.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
              itemBuilder: (_, i) => _UserTile(
                user: _users![i],
                onRoleChange: (r) => _changeRole(_users![i], r),
                onBan: () => _toggleBan(_users![i]),
                onDelete: () => _delete(_users![i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final User user;
  final void Function(String) onRoleChange;
  final VoidCallback onBan;
  final VoidCallback onDelete;
  const _UserTile({required this.user, required this.onRoleChange, required this.onBan, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().user;
    final isMe = me?.id == user.id;
    return ListTile(
      leading: Stack(children: [
        Avatar(user: user, size: 44),
        if (user.isOnline)
          Positioned(
            right: 0, bottom: 0,
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: AppTheme.success,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.background, width: 2),
              ),
            ),
          ),
      ]),
      title: Row(children: [
        Expanded(child: Text(user.displayName, style: TextStyle(fontWeight: FontWeight.w600, decoration: user.isBanned ? TextDecoration.lineThrough : null))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: user.isAdmin ? AppTheme.primary.withValues(alpha: .2) : (user.isCaptain ? Colors.purple.withValues(alpha: .2) : AppTheme.surfaceAlt),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(user.roleLabel, style: TextStyle(color: user.isAdmin ? AppTheme.primary : (user.isCaptain ? Colors.purple : AppTheme.textMuted), fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ]),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('@${user.username} · ${user.email}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        if (user.lastSeen != null)
          Text('Poslední aktivita: ${_relative(user.lastSeen!)}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ]),
      trailing: isMe ? null : PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'admin' || v == 'captain' || v == 'member') onRoleChange(v);
          else if (v == 'ban') onBan();
          else if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          if (!user.isAdmin) const PopupMenuItem(value: 'admin', child: Text('Povýšit na admina')),
          if (!user.isCaptain) const PopupMenuItem(value: 'captain', child: Text('Povýšit na kapitána')),
          if (user.role != 'member') const PopupMenuItem(value: 'member', child: Text('Demote na člena')),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'ban', child: Text(user.isBanned ? 'Odbanovat' : 'Zablokovat')),
          const PopupMenuItem(value: 'delete', child: Text('Smazat trvale', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
  }

  static String _relative(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'právě teď';
    if (diff.inMinutes < 60) return 'před ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'před ${diff.inHours} h';
    if (diff.inDays < 7) return 'před ${diff.inDays} dny';
    return DateFormat('d.M.y').format(dt.toLocal());
  }
}

// ─── Events tab ────────────────────────────────────────────────────────

class _EventsTab extends StatefulWidget {
  const _EventsTab();
  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
  List<dynamic>? _events;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await context.read<ApiClient>().get('/admin/events');
    setState(() => _events = res as List);
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Smazat akci?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušit')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Smazat', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok == true) {
      await context.read<ApiClient>().delete('/admin/events/$id');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_events == null) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _events!.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
        itemBuilder: (_, i) {
          final e = _events![i] as Map<String, dynamic>;
          return ListTile(
            title: Text(e['title']),
            subtitle: Text('${e['event_type']} · ${e['location'] ?? '—'} · RSVP: ${e['rsvp_count']}'),
            trailing: IconButton(icon: const Icon(Icons.delete, color: AppTheme.danger), onPressed: () => _delete(e['id'])),
          );
        },
      ),
    );
  }
}

// ─── Groups tab ────────────────────────────────────────────────────────

class _GroupsTab extends StatefulWidget {
  const _GroupsTab();
  @override
  State<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<_GroupsTab> {
  List<dynamic>? _groups;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await context.read<ApiClient>().get('/admin/groups');
    setState(() => _groups = res as List);
  }

  @override
  Widget build(BuildContext context) {
    if (_groups == null) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _groups!.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
        itemBuilder: (_, i) {
          final g = _groups![i] as Map<String, dynamic>;
          return ListTile(
            title: Row(children: [
              Expanded(child: Text(g['name'])),
              if (g['is_default'] == true) const Icon(Icons.star, size: 14, color: AppTheme.warning),
            ]),
            subtitle: Text('${g['member_count']} členů · ${g['message_count']} zpráv'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'default') {
                  await context.read<ApiClient>().post('/admin/groups/${g['id']}/toggle-default');
                  _load();
                } else if (v == 'delete') {
                  await context.read<ApiClient>().delete('/admin/groups/${g['id']}');
                  _load();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'default', child: Text(g['is_default'] == true ? 'Odebrat ze defaultních' : 'Nastavit jako defaultní')),
                if (g['is_default'] != true) const PopupMenuItem(value: 'delete', child: Text('Smazat', style: TextStyle(color: AppTheme.danger))),
              ],
            ),
          );
        },
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
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
      Text(message),
      OutlinedButton(onPressed: onRetry, child: const Text('Zkusit znovu')),
    ]));
  }
}
