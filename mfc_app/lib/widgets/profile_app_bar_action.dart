import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/profile_screen.dart';
import '../services/auth_service.dart';
import 'avatar.dart';

/// AppBar akce — kliknutelný avatar v rohu, který otevře Profile.
/// Pouzij jako item v `actions` u AppBaru hlavnich obrazovek.
class ProfileAppBarAction extends StatelessWidget {
  const ProfileAppBarAction({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    if (user == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        tooltip: 'Profil',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        icon: Avatar(user: user, size: 32),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
      ),
    );
  }
}
