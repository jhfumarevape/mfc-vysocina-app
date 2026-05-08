import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';

/// Nastavení notifikací — toggly per kategorie. Ukládá se do SharedPreferences.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // Klíče v SharedPreferences
  static const _kMaster = 'notif_master';
  static const _kFeed = 'notif_feed';
  static const _kEvents = 'notif_events';
  static const _kRsvpReminder = 'notif_rsvp_reminder';
  static const _kChat = 'notif_chat';
  static const _kMentions = 'notif_mentions';
  static const _kAdminAnnounce = 'notif_admin_announce';

  bool _master = true;
  bool _feed = true;
  bool _events = true;
  bool _rsvpReminder = true;
  bool _chat = true;
  bool _mentions = true;
  bool _adminAnnounce = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _master = prefs.getBool(_kMaster) ?? true;
      _feed = prefs.getBool(_kFeed) ?? true;
      _events = prefs.getBool(_kEvents) ?? true;
      _rsvpReminder = prefs.getBool(_kRsvpReminder) ?? true;
      _chat = prefs.getBool(_kChat) ?? true;
      _mentions = prefs.getBool(_kMentions) ?? true;
      _adminAnnounce = prefs.getBool(_kAdminAnnounce) ?? true;
      _loading = false;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final disabled = !_master;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifikace')),
      body: ListView(
        children: [
          // Master switch
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: AppTheme.primary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Všechny notifikace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(
                        _master ? 'Zapnuté — dostáváš push notifikace' : 'Vypnuté — žádné push notifikace',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _master,
                  activeColor: AppTheme.primary,
                  onChanged: (v) {
                    setState(() => _master = v);
                    _save(_kMaster, v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _section('Obsah'),
          _SwitchTile(
            icon: Icons.dashboard_outlined,
            title: 'Nové aktuality',
            subtitle: 'Když někdo zveřejní nový post v hlavním feedu',
            value: _feed,
            disabled: disabled,
            onChanged: (v) {
              setState(() => _feed = v);
              _save(_kFeed, v);
            },
          ),
          _divider(),
          _SwitchTile(
            icon: Icons.event_outlined,
            title: 'Nové akce',
            subtitle: 'Trénink, turnaj, sraz — nová akce v kalendáři',
            value: _events,
            disabled: disabled,
            onChanged: (v) {
              setState(() => _events = v);
              _save(_kEvents, v);
            },
          ),
          _divider(),
          _SwitchTile(
            icon: Icons.alarm_outlined,
            title: 'Připomenutí RSVP',
            subtitle: 'Pokud do 48 h před akcí ještě nejsi rozhodnutý',
            value: _rsvpReminder,
            disabled: disabled,
            onChanged: (v) {
              setState(() => _rsvpReminder = v);
              _save(_kRsvpReminder, v);
            },
          ),
          const SizedBox(height: 24),
          _section('Komunikace'),
          _SwitchTile(
            icon: Icons.chat_bubble_outline,
            title: 'Zprávy v chatu',
            subtitle: 'Nové zprávy v týmových skupinách',
            value: _chat,
            disabled: disabled,
            onChanged: (v) {
              setState(() => _chat = v);
              _save(_kChat, v);
            },
          ),
          _divider(),
          _SwitchTile(
            icon: Icons.alternate_email,
            title: 'Zmínky (@username)',
            subtitle: 'Když tě někdo přímo zmíní',
            value: _mentions,
            disabled: disabled,
            onChanged: (v) {
              setState(() => _mentions = v);
              _save(_kMentions, v);
            },
          ),
          const SizedBox(height: 24),
          _section('Tým'),
          _SwitchTile(
            icon: Icons.campaign_outlined,
            title: 'Důležitá oznámení',
            subtitle: 'Zprávy od admina/kapitána (doporučeno nechat)',
            value: _adminAnnounce,
            disabled: disabled,
            onChanged: (v) {
              setState(() => _adminAnnounce = v);
              _save(_kAdminAnnounce, v);
            },
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Změny se ukládají automaticky. Push notifikace fungují jen na mobilu, ne ve webovém prohlížeči.',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _divider() => const Divider(height: 1, color: AppTheme.border, indent: 60);
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool disabled;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.disabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: ListTile(
        leading: Icon(icon, color: value && !disabled ? AppTheme.primary : AppTheme.textMuted),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        trailing: Switch(
          value: value,
          activeColor: AppTheme.primary,
          onChanged: disabled ? null : onChanged,
        ),
      ),
    );
  }
}
