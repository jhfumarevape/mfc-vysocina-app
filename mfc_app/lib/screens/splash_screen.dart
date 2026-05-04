import 'package:flutter/material.dart';

import '../core/theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84, height: 84,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: AppTheme.primary.withOpacity(.4), blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              child: const Icon(Icons.shield, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('MFC Vysočina', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
