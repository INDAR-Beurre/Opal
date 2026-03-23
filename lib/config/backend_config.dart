/// ============================================================
/// BACKEND CONFIGURATION — v2.0
/// ============================================================
/// Uses YouTube's InnerTube API directly (same API that YouTube Music
/// web app uses). No third-party backend needed.
///
/// Optional: sign in with your Google account cookie to sync
/// your YouTube Music library, history, and playlists.
/// ============================================================

class BackendConfig {
  BackendConfig._();

  // ─── InnerTube API (YouTube Music Web) ───
  static const String innerTubeBaseUrl =
      'https://music.youtube.com/youtubei/v1';

  // WEB_REMIX client (YouTube Music Web)
  static const String clientName = 'WEB_REMIX';
  static const String clientVersion = '1.20260213.01.00';
  static const String clientId = '67';
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0';

  // WEB client (for player/stream URLs)
  static const String webClientName = 'WEB';
  static const String webClientVersion = '2.20260213.00.00';
  static const String webClientId = '1';

  // Origins
  static const String origin = 'https://music.youtube.com';
  static const String referer = 'https://music.youtube.com/';

  // ─── Piped API fallback (for stream URL extraction if InnerTube fails) ───
  static const String pipedBaseUrl = 'https://pipedapi.kavin.rocks';
  static const List<String> pipedFallbacks = [
    'https://pipedapi.adminforge.de',
    'https://api.piped.projectsegfau.lt',
  ];

  // ─── App settings ───
  static const String defaultRegion = 'US';
  static const String defaultLanguage = 'en';
  static const String audioQuality = 'best'; // best, medium, low
  static const int maxSearchResults = 30;
  static const int httpTimeoutSeconds = 15;
}
