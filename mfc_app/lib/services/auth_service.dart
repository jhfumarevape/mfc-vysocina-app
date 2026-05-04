import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'api_client.dart';

/// Holds auth state (token + current user). ChangeNotifier so UI rebuilds.
class AuthService extends ChangeNotifier {
  final ApiClient api;
  User? _user;
  Set<String> _permissions = {};
  bool _booting = true;

  AuthService(this.api);

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get booting => _booting;
  Set<String> get permissions => _permissions;
  bool hasPermission(String key) => _permissions.contains(key);

  Future<void> _loadPermissions() async {
    try {
      final res = await api.get('/auth/me/permissions');
      final perms = (res as Map<String, dynamic>)['permissions'] as List;
      _permissions = perms.cast<String>().toSet();
    } catch (_) {
      _permissions = {};
    }
  }

  /// Restore token from disk on app start, validate by hitting /auth/me.
  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      api.setToken(token);
      try {
        final me = await api.get('/auth/me');
        _user = User.fromJson(me as Map<String, dynamic>);
        await _loadPermissions();
      } catch (_) {
        api.setToken(null);
        await prefs.remove('access_token');
      }
    }
    _booting = false;
    notifyListeners();
  }

  Future<void> login(String usernameOrEmail, String password) async {
    final res = await api.post('/auth/login', {
      'username': usernameOrEmail,
      'password': password,
    });
    await _setSession(res as Map<String, dynamic>);
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) async {
    final res = await api.post('/auth/register', {
      'username': username,
      'email': email,
      'password': password,
      if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
    });
    await _setSession(res as Map<String, dynamic>);
  }

  Future<void> _setSession(Map<String, dynamic> tokenResp) async {
    final token = tokenResp['access_token'] as String;
    api.setToken(token);
    _user = User.fromJson(tokenResp['user'] as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    await _loadPermissions();
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    api.setToken(null);
    _user = null;
    _permissions = {};
    notifyListeners();
  }

  Future<void> updateMe({String? fullName, String? bio, String? avatarUrl, String? pushToken}) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (bio != null) body['bio'] = bio;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (pushToken != null) body['push_token'] = pushToken;
    final res = await api.patch('/auth/me', body);
    _user = User.fromJson(res as Map<String, dynamic>);
    notifyListeners();
  }
}
