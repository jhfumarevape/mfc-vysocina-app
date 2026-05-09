import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../models/tactic.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/profile_app_bar_action.dart';

class TacticsScreen extends StatefulWidget {
  const TacticsScreen({super.key});

  @override
  State<TacticsScreen> createState() => _TacticsScreenState();
}

class _TacticsScreenState extends State<TacticsScreen> {
  List<Tactic>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().get('/tactics');
      setState(() {
        _items = (res as List).map((j) => Tactic.fromJson(j as Map<String, dynamic>)).toList();
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _addTactic() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _NewTacticScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _openVideo(Tactic t) async {
    final uri = Uri.parse(t.videoUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nelze otevřít: ${t.videoUrl}')),
        );
      }
    }
  }

  Future<void> _delete(Tactic t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Smazat taktiku?'),
        content: Text('„${t.title}" bude trvale smazána.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušit')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Smazat', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await context.read<ApiClient>().delete('/tactics/${t.id}');
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final canEdit = auth.user?.isAdmin == true || auth.user?.isCaptain == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taktiky'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          const ProfileAppBarAction(),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              backgroundColor: AppTheme.primary,
              onPressed: _addTactic,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: RefreshIndicator(color: AppTheme.primary, onRefresh: _load, child: _buildBody(canEdit)),
    );
  }

  Widget _buildBody(bool canEdit) {
    if (_error != null) return _ErrorView(message: _error!, onRetry: _load);
    if (_items == null) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_items!.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 80),
        const Icon(Icons.play_circle_outline, size: 72, color: AppTheme.textMuted),
        const SizedBox(height: 12),
        const Center(child: Text('Žádné taktiky zatím', style: TextStyle(color: AppTheme.textMuted))),
        const SizedBox(height: 8),
        if (canEdit)
          Center(
            child: TextButton.icon(
              onPressed: _addTactic,
              icon: const Icon(Icons.add, color: AppTheme.primary),
              label: const Text('Přidat první taktiku', style: TextStyle(color: AppTheme.primary)),
            ),
          ),
      ]);
    }

    // Group by category
    final grouped = <String, List<Tactic>>{};
    for (final t in _items!) {
      final cat = t.category ?? 'Ostatní';
      grouped.putIfAbsent(cat, () => []).add(t);
    }
    final categories = grouped.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final cat in categories) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              cat.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...grouped[cat]!.map((t) => _TacticCard(
                tactic: t,
                onTap: () => _openVideo(t),
                onDelete: canEdit ? () => _delete(t) : null,
              )),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

class _TacticCard extends StatelessWidget {
  final Tactic tactic;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _TacticCard({required this.tactic, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final thumb = tactic.effectiveThumbnail;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with play overlay
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumb != null)
                    CachedNetworkImage(
                      imageUrl: thumb,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppTheme.surfaceAlt),
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.surfaceAlt,
                        child: const Icon(Icons.broken_image_outlined, size: 48, color: AppTheme.textMuted),
                      ),
                    )
                  else
                    Container(
                      color: AppTheme.surfaceAlt,
                      child: const Center(child: Icon(Icons.movie_creation_outlined, size: 48, color: AppTheme.textMuted)),
                    ),
                  // Dark gradient bottom
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                        ),
                      ),
                    ),
                  ),
                  // Play button
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tactic.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        if (tactic.description != null && tactic.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            tactic.description!,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onDelete != null)
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'delete') onDelete!();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Smazat', style: TextStyle(color: AppTheme.danger)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── New tactic screen ─────────────────────────────────────────────────

class _NewTacticScreen extends StatefulWidget {
  const _NewTacticScreen();
  @override
  State<_NewTacticScreen> createState() => _NewTacticScreenState();
}

class _NewTacticScreenState extends State<_NewTacticScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _videoUrl = TextEditingController();
  final _category = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _videoUrl.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<ApiClient>().post('/tactics', {
        'title': _title.text.trim(),
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'video_url': _videoUrl.text.trim(),
        'category': _category.text.trim().isEmpty ? null : _category.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: AppTheme.danger),
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nová taktika'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                : const Text('Uložit', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Název taktiky',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Vyplň název' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _videoUrl,
              decoration: const InputDecoration(
                labelText: 'YouTube URL (nebo přímý odkaz)',
                prefixIcon: Icon(Icons.link),
                hintText: 'https://www.youtube.com/watch?v=...',
              ),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Zadej odkaz na video' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(
                labelText: 'Kategorie (volitelná)',
                prefixIcon: Icon(Icons.category_outlined),
                hintText: 'např. 5v5, duely, obrana...',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Popis',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: const [
                Icon(Icons.lightbulb_outline, size: 18, color: AppTheme.textMuted),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: Pokud zadáš YouTube odkaz, automaticky se vytvoří náhled videa. Vlastní thumbnail můžeš vyplnit později.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                  ),
                ),
              ]),
            ),
          ],
        ),
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
    return ListView(children: [
      const SizedBox(height: 80),
      const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
      const SizedBox(height: 12),
      Center(child: Text(message, style: const TextStyle(color: AppTheme.textMuted))),
      const SizedBox(height: 16),
      Center(child: OutlinedButton(onPressed: onRetry, child: const Text('Zkusit znovu'))),
    ]);
  }
}
