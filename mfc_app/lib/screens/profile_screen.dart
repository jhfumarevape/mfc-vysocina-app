import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';
import '../widgets/avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;
    if (user == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(child: Avatar(user: user, size: 100)),
          const SizedBox(height: 16),
          Center(child: Text(user.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
          Center(child: Text('@${user.username}', style: const TextStyle(color: AppTheme.textMuted))),
          if (user.role != 'member')
            Center(child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(.2), borderRadius: BorderRadius.circular(6)),
                child: Text(user.role.toUpperCase(), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 11)),
              ),
            )),
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(user.bio!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMuted)),
            ),
          ],
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(user.email),
          ),
          const Divider(color: AppTheme.border, height: 1),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Upravit profil'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(color: AppTheme.border, height: 1),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifikace'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(color: AppTheme.border, height: 1),
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
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Odhlásit', style: TextStyle(color: AppTheme.danger))),
                  ],
                ),
              );
              if (ok == true) await auth.logout();
            },
          ),
        ],
      ),
    );
  }
}
