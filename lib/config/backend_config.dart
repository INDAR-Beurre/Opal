/// Opal backend configuration — InnerTube API + Piped fallback.
class BackendConfig {
  BackendConfig._();

  // ─── InnerTube API ───
  static const String innerTubeBaseUrl =
      'https://music.youtube.com/youtubei/v1';
  static const String origin = 'https://music.youtube.com';
  static const String referer = 'https://music.youtube.com/';

  // ─── Client configurations ───
  static const webRemix = InnerTubeClientConfig(
    clientName: 'WEB_REMIX',
    clientVersion: '1.20260213.01.00',
    clientId: '67',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0',
    supportsLogin: true,
    supportsSignatureTimestamp: true,
  );

  static const web = InnerTubeClientConfig(
    clientName: 'WEB',
    clientVersion: '2.20260213.00.00',
    clientId: '1',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0',
    supportsLogin: false,
    supportsSignatureTimestamp: false,
  );

  static const tvhtml5Embedded = InnerTubeClientConfig(
    clientName: 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
    clientVersion: '2.0',
    clientId: '85',
    userAgent:
        'Mozilla/5.0 (PlayStation 4 5.55) AppleWebKit/601.2 (KHTML, like Gecko)',
    supportsLogin: true,
    supportsSignatureTimestamp: true,
    isEmbedded: true,
  );

  static const androidVr = InnerTubeClientConfig(
    clientName: 'ANDROID_VR',
    clientVersion: '1.61.48',
    clientId: '28',
    userAgent:
        'com.google.android.apps.youtube.vr.oculus/1.61.48 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/97.0.4692.99)',
    supportsLogin: false,
    supportsSignatureTimestamp: false,
    osName: 'Android',
    osVersion: '12',
    deviceMake: 'Meta',
    deviceModel: 'Quest 3',
    androidSdkVersion: '32',
  );

  static const ios = InnerTubeClientConfig(
    clientName: 'IOS',
    clientVersion: '21.03.1',
    clientId: '5',
    userAgent:
        'com.google.ios.youtube/21.03.1 (iPhone16,2; U; CPU iOS 18_2 like Mac OS X)',
    supportsLogin: false,
    supportsSignatureTimestamp: false,
  );

  /// Player fallback chain: try these clients in order
  static const List<InnerTubeClientConfig> playerFallbackChain = [
    webRemix,
    tvhtml5Embedded,
    androidVr,
    ios,
  ];

  // ─── Piped API fallback ───
  static const String pipedBaseUrl = 'https://pipedapi.kavin.rocks';
  static const List<String> pipedFallbacks = [
    'https://pipedapi.adminforge.de',
    'https://api.piped.projectsegfau.lt',
  ];

  // ─── Defaults ───
  static const String defaultRegion = 'US';
  static const String defaultLanguage = 'en';
  static const int httpTimeoutSeconds = 15;
  static const int maxRetries = 3;
  static const List<int> retryDelaysMs = [500, 1000, 2000];
}

class InnerTubeClientConfig {
  final String clientName;
  final String clientVersion;
  final String clientId;
  final String userAgent;
  final bool supportsLogin;
  final bool supportsSignatureTimestamp;
  final bool isEmbedded;
  final String? osName;
  final String? osVersion;
  final String? deviceMake;
  final String? deviceModel;
  final String? androidSdkVersion;

  const InnerTubeClientConfig({
    required this.clientName,
    required this.clientVersion,
    required this.clientId,
    required this.userAgent,
    required this.supportsLogin,
    required this.supportsSignatureTimestamp,
    this.isEmbedded = false,
    this.osName,
    this.osVersion,
    this.deviceMake,
    this.deviceModel,
    this.androidSdkVersion,
  });
}
