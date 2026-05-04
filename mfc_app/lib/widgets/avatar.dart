import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/theme.dart';
import '../models/user.dart';
import '../services/api_client.dart';

class Avatar extends StatelessWidget {
  final User user;
  final double size;

  const Avatar({super.key, required this.user, this.size = 40});

  @override
  Widget build(BuildContext context) {
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: ApiClient.absoluteUrl(user.avatarUrl),
          width: size, height: size, fit: BoxFit.cover,
          placeholder: (_, __) => _initials(),
          errorWidget: (_, __, ___) => _initials(),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() {
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        user.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
