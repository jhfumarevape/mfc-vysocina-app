import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/config.dart';
import 'api_client.dart';

class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool updateAvailable;

  UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.updateAvailable,
  });
}

class UpdateChecker extends ChangeNotifier {
  /// Verze tohohle buildu — předáno workflow přes `--dart-define=APP_VERSION=0.1.0+N`.
  /// Default je hodnota z pubspec.yaml (pro lokální dev build bez flagu).
  static const String currentVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.1.0+1',
  );

  UpdateInfo? _info;
  bool _checking = false;
  double _downloadProgress = 0;
  bool _downloading = false;

  UpdateInfo? get info => _info;
  bool get checking => _checking;
  double get downloadProgress => _downloadProgress;
  bool get downloading => _downloading;
  bool get hasUpdate => _info?.updateAvailable ?? false;

  Future<void> check() async {
    // Web build nelze instalovat APK — kontrola verze pro něj nemá smysl.
    if (kIsWeb) return;
    _checking = true;
    notifyListeners();
    try {
      final res = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/api/version'));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final latest = (data['latest_version'] as String?) ?? '0.0.0';
        final url = (data['download_url'] as String?) ?? '';
        final notes = (data['release_notes'] as String?) ?? '';
        _info = UpdateInfo(
          latestVersion: latest,
          downloadUrl: url,
          releaseNotes: notes,
          updateAvailable: url.isNotEmpty && _isNewer(latest, currentVersion),
        );
      }
    } catch (_) {
      // ignore network errors — banner se prostě nezobrazí
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  static bool _isNewer(String latest, String current) {
    final a = latest.split(RegExp(r'[+.]')).map((s) => int.tryParse(s) ?? 0).toList();
    final b = current.split(RegExp(r'[+.]')).map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < a.length || i < b.length; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av > bv) return true;
      if (av < bv) return false;
    }
    return false;
  }

  Future<File?> downloadApk() async {
    if (_info == null) return null;
    _downloading = true;
    _downloadProgress = 0;
    notifyListeners();

    try {
      // download_url může být absolutní (GitHub Release) nebo relativní (vlastní backend)
      final raw = _info!.downloadUrl;
      final url = raw.startsWith('http') ? raw : (AppConfig.apiBaseUrl + raw);
      final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      final file = File('${dir.path}/mfc-vysocina-${_info!.latestVersion}.apk');

      final req = http.Request('GET', Uri.parse(url));
      final res = await req.send();
      final total = res.contentLength ?? 0;
      var received = 0;

      final sink = file.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          _downloadProgress = received / total;
          notifyListeners();
        }
      }
      await sink.close();

      _downloading = false;
      notifyListeners();
      return file;
    } catch (e) {
      _downloading = false;
      notifyListeners();
      return null;
    }
  }
}
