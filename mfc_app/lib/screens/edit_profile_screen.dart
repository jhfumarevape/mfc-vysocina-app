import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/avatar.dart';

/// Editace profilu — jméno, bio, avatar.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _bio;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().user;
    _fullName = TextEditingController(text: user?.fullName ?? '');
    _bio = TextEditingController(text: user?.bio ?? '');
  }

  @override
  void dispose() {
    _fullName.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<AuthService>().updateMe(
        fullName: _fullName.text.trim(),
        bio: _bio.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil uložen ✓'), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadAvatar({required ImageSource source}) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _saving = true);

      final api = context.read<ApiClient>();
      final Map<String, dynamic> resp;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        resp = await api.uploadImageBytes(bytes, picked.name);
      } else {
        resp = await api.uploadImage(File(picked.path));
      }
      final avatarUrl = resp['url'] as String?;
      if (avatarUrl == null) throw Exception('Server nevrátil URL');

      await context.read<AuthService>().updateMe(avatarUrl: avatarUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar nahrán ✓'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showAvatarSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
                title: const Text('Vyfotit'),
                onTap: () { Navigator.pop(context); _pickAndUploadAvatar(source: ImageSource.camera); },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
              title: const Text('Z galerie'),
              onTap: () { Navigator.pop(context); _pickAndUploadAvatar(source: ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppTheme.textMuted),
              title: const Text('Zrušit', style: TextStyle(color: AppTheme.textMuted)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    if (user == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upravit profil'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
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
            const SizedBox(height: 8),
            Center(
              child: Stack(
                children: [
                  Avatar(user: user, size: 100),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: AppTheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _saving ? null : _showAvatarSheet,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '@${user.username}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _fullName,
              decoration: const InputDecoration(
                labelText: 'Celé jméno',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Zadej jméno' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bio,
              decoration: const InputDecoration(
                labelText: 'Bio',
                prefixIcon: Icon(Icons.notes_outlined),
                hintText: 'Pár slov o sobě (volitelné)',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              maxLength: 200,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppTheme.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Email a uživatelské jméno měnit nelze. Pokud potřebuješ, kontaktuj admina.',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
