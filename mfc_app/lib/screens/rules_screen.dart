import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../models/rule.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/profile_app_bar_action.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  List<Rule>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().get('/rules');
      setState(() {
        _items = (res as List).map((j) => Rule.fromJson(j as Map<String, dynamic>)).toList();
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _add() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _NewRuleScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _delete(Rule r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Smazat pravidlo?'),
        content: Text('„${r.title}" bude trvale smazáno.'),
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
        await context.read<ApiClient>().delete('/rules/${r.id}');
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
        title: const Text('Pravidla'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          const ProfileAppBarAction(),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              backgroundColor: AppTheme.primary,
              onPressed: _add,
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
        const Icon(Icons.gavel_outlined, size: 72, color: AppTheme.textMuted),
        const SizedBox(height: 12),
        const Center(child: Text('Žádná pravidla zatím', style: TextStyle(color: AppTheme.textMuted))),
        const SizedBox(height: 8),
        if (canEdit)
          Center(
            child: TextButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add, color: AppTheme.primary),
              label: const Text('Přidat první pravidlo', style: TextStyle(color: AppTheme.primary)),
            ),
          ),
      ]);
    }

    final grouped = <String, List<Rule>>{};
    for (final r in _items!) {
      final cat = r.category ?? 'Obecná';
      grouped.putIfAbsent(cat, () => []).add(r);
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
          ...grouped[cat]!.map((r) => _RuleListTile(
                rule: r,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _RuleDetailScreen(rule: r, canEdit: canEdit, onDelete: () => _delete(r)),
                )),
              )),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

class _RuleListTile extends StatelessWidget {
  final Rule rule;
  final VoidCallback onTap;
  const _RuleListTile({required this.rule, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.menu_book_outlined, color: AppTheme.primary),
        ),
        title: Text(rule.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: rule.documentUrl != null
            ? Row(children: const [
                Icon(Icons.attach_file, size: 12, color: AppTheme.textMuted),
                SizedBox(width: 4),
                Text('PDF příloha', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ])
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _RuleDetailScreen extends StatelessWidget {
  final Rule rule;
  final bool canEdit;
  final VoidCallback onDelete;
  const _RuleDetailScreen({required this.rule, required this.canEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(rule.category ?? 'Pravidlo'),
        actions: [
          if (rule.documentUrl != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Otevřít přílohu',
              onPressed: () async {
                final uri = Uri.parse(rule.documentUrl!);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          if (canEdit)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') {
                  Navigator.of(context).pop();
                  onDelete();
                }
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
      body: Markdown(
        data: '# ${rule.title}\n\n${rule.content}',
        padding: const EdgeInsets.all(16),
        styleSheet: MarkdownStyleSheet(
          h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.text),
          h2: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppTheme.text),
          h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.text),
          p: const TextStyle(fontSize: 15, height: 1.5, color: AppTheme.text),
          listBullet: const TextStyle(fontSize: 15, color: AppTheme.text),
          a: const TextStyle(color: AppTheme.primary, decoration: TextDecoration.underline),
          code: const TextStyle(backgroundColor: AppTheme.surfaceAlt, fontFamily: 'monospace'),
          codeblockDecoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
          ),
          blockquoteDecoration: BoxDecoration(
            color: AppTheme.surface,
            border: const Border(left: BorderSide(color: AppTheme.primary, width: 4)),
          ),
        ),
        onTapLink: (_, href, __) async {
          if (href != null) await launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
        },
      ),
    );
  }
}

// ─── New rule screen ───────────────────────────────────────────────────

class _NewRuleScreen extends StatefulWidget {
  const _NewRuleScreen();
  @override
  State<_NewRuleScreen> createState() => _NewRuleScreenState();
}

class _NewRuleScreenState extends State<_NewRuleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _category = TextEditingController();
  final _documentUrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _category.dispose();
    _documentUrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<ApiClient>().post('/rules', {
        'title': _title.text.trim(),
        'content': _content.text.trim(),
        'category': _category.text.trim().isEmpty ? null : _category.text.trim(),
        'document_url': _documentUrl.text.trim().isEmpty ? null : _documentUrl.text.trim(),
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
        title: const Text('Nové pravidlo'),
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
                labelText: 'Název pravidla',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Vyplň název' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(
                labelText: 'Kategorie',
                prefixIcon: Icon(Icons.category_outlined),
                hintText: 'např. 5v5, duely, vybavení, bezpečnost',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _content,
              decoration: const InputDecoration(
                labelText: 'Obsah (podporuje Markdown)',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
                hintText: '## Nadpis\n\nText pravidla...\n\n- bod 1\n- bod 2',
              ),
              maxLines: 12,
              minLines: 8,
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Vyplň obsah' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _documentUrl,
              decoration: const InputDecoration(
                labelText: 'Odkaz na PDF / web (volitelný)',
                prefixIcon: Icon(Icons.attach_file),
                hintText: 'https://...',
              ),
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
                    'Tip: Markdown podporuje **tučné**, *kurzívu*, # nadpisy, - seznamy, [odkazy](url) a víc.',
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
