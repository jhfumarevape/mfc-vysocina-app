import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';
import '../widgets/avatar.dart';
import 'admin_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;
    if (user == null) return const SizedBox();

    final isStaff = user.isAdmin || user.isCaptain;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Upravit profil',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Hlavička s avatarem, jménem, rolí, bio
          const SizedBox(height: 24),
          Center(child: Avatar(user: user, size: 100)),
          const SizedBox(height: 16),
          Center(
            child: Text(
              user.displayName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          Center(
            child: Text('@${user.username}', style: const TextStyle(color: AppTheme.textMuted)),
          ),
          if (user.role != 'member')
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _RoleBadge(role: user.role, label: user.roleLabel),
              ),
            ),
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                user.bio!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ),
          ],

          // Statistika "Členem od"
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Členem od ${DateFormat('LLLL yyyy', 'cs').format(user.createdAt)}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Sekce: Účet ────────────────────────────────────────────────
          _section('Účet'),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(user.email),
          ),
          _divider(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Upravit profil'),
            subtitle: const Text('Jméno, bio, avatar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),

          // ── Sekce: Nastavení aplikace ──────────────────────────────────
          const SizedBox(height: 12),
          _section('Nastavení'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifikace'),
            subtitle: const Text('Aktuality, akce, chat, zmínky'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
            ),
          ),
          _divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('O aplikaci'),
            subtitle: const Text('Verze 0.1.0'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAbout(context),
          ),

          // ── Sekce: Administrace (jen admin/kapitán) ────────────────────
          if (isStaff) ...[
            const SizedBox(height: 12),
            _section('Administrace'),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_outlined, color: AppTheme.primary),
              ),
              title: const Text('Administrace týmu'),
              subtitle: const Text('Členové, role, akce, skupiny'),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.primary),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              ),
            ),
          ],

          // ── Sekce: Účet — odhlášení ────────────────────────────────────
          const SizedBox(height: 24),
          _divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.danger),
            title: const Text('Odhlásit se', style: TextStyle(color: AppTheme.danger)),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Opravdu se odhlásit?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušit')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Odhlásit', style: TextStyle(color: AppTheme.danger)),
                    ),
                  ],
                ),
              );
              if (ok == true) await auth.logout();
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static Widget _section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
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

  static Widget _divider() => const Divider(color: AppTheme.border, height: 1, indent: 56);

  static void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'MFC Vysočina',
      applicationVersion: '0.1.0',
      applicationLegalese: '© 2026 MFC Vysočina — týmová aplikace',
      children: const [
        SizedBox(height: 16),
        Text(
          'Komunitní aplikace pro buhurt tým MFC Vysočina. '
          'Aktuality, kalendář akcí, chat, RSVP a víc.',
        ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  final String label;
  const _RoleBadge({required this.role, required this.label});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (role) {
      'admin' => (AppTheme.primary, Icons.shield),
      'captain' => (Colors.purple, Icons.star),
      _ => (AppTheme.textMuted, Icons.person),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
