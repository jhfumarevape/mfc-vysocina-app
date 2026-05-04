import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _fullName = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AuthService>().register(
        username: _username.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        fullName: _fullName.text.trim(),
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Chyba: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrace')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _fullName,
                  decoration: const InputDecoration(labelText: 'Jméno a příjmení'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vyplň jméno' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'Uživatelské jméno (přezdívka)'),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Min 3 znaky' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Neplatný email' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Heslo'),
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6) ? 'Min 6 znaků' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password2,
                  decoration: const InputDecoration(labelText: 'Heslo znovu'),
                  obscureText: true,
                  validator: (v) => (v != _password.text) ? 'Hesla se neshodují' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: const TextStyle(color: AppTheme.danger)),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _busy ? null : _register,
                  child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Vytvořit účet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
