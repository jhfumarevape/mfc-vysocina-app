/// API konfigurace.
///
/// Ostré URL (Cloudflare Tunnel / vlastní doména) se předává při buildu jako
/// `--dart-define=API_BASE_URL=https://...` a `--dart-define=WS_BASE_URL=wss://...`.
/// Defaulty směřují na localhost (dev) a fungují jen pokud běží backend lokálně.
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5002',
  );
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://localhost:5002',
  );

  static const String appName = 'MFC Vysočina';

  /// Preview/dev režim — přeskočí login a pustí tě dovnitř s fake uživatelem.
  /// Pro produkční build předej `--dart-define=PREVIEW_MODE=false`.
  static const bool previewMode = bool.fromEnvironment(
    'PREVIEW_MODE',
    defaultValue: true,
  );
}
