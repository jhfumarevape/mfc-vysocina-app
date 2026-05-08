/// API configuration. In production this becomes the public Cloudflare URL.
class AppConfig {
  // Cloudflare Tunnel — works from anywhere (mobile data, any WiFi).
  static const String apiBaseUrl = 'https://lafayette-plaintiff-underlying-band.trycloudflare.com';
  static const String wsBaseUrl  = 'wss://lafayette-plaintiff-underlying-band.trycloudflare.com';

  static const String appName = 'MFC Vysočina';

  /// Preview/dev režim — přeskočí login a pustí tě dovnitř s fake uživatelem.
  /// !!! Před releasem na false !!!
  static const bool previewMode = true;
}
