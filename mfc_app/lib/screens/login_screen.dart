import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import 'register_screen.dart';

/// Klíč v SharedPreferences pro pamatování posledního emailu.
const _kLastUsername = 'last_username';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _obscurePass = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLastUsername();
  }

  Future<void> _loadLastUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_kLastUsername);
    if (last != null && last.isNotEmpty && mounted) {
      setState(() => _user.text = last);
    }
  }

  Future<void> _login() async {
    setState(() { _busy = true; _error = null; });
    try {
      final username = _user.text.trim();
      await context.read<AuthService>().login(username, _pass.text);
      // Úspěch — pamatovat email pro příští spuštění
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastUsername, username);
      // Říct OS, že login byl OK → password manager nabídne uložit heslo
      TextInput.finishAutofillContext(shouldSave: true);
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
            // AutofillGroup → Android Credential Manager / Google Password
            // Manager rozpozná pole a nabídne uložit/vyplnit heslo.
            child: AutofillGroup(
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
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Uživatelské jméno nebo email',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    autofillHints: const [AutofillHints.password],
                    obscureText: _obscurePass,
                    decoration: InputDecoration(
                      labelText: 'Heslo',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
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
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: const [
                      Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Po přihlášení zůstaneš v aplikaci 30 dní bez nutnosti opětovného loginu.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
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
      ),
    );
  }
}
