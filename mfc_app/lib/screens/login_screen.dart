import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AuthService>().login(_user.text.trim(), _pass.text);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Chyba sítě: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.shield, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 16),
                const Text('MFC Vysočina',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                const Text('Týmová aplikace',
                  style: TextStyle(color: AppTheme.textMuted)),
                const SizedBox(height: 36),
                TextField(
                  controller: _user,
                  decoration: const InputDecoration(
                    labelText: 'Uživatelské jméno nebo email',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  decoration: const InputDecoration(
                    labelText: 'Heslo',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  onSubmitted: (_) => _login(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.danger.withOpacity(.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.danger))),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _login,
                    child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Přihlásit se'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
                  },
                  child: const Text('Nemáš účet? Zaregistruj se',
                    style: TextStyle(color: AppTheme.primary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
