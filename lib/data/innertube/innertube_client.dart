import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../../config/backend_config.dart';

/// Error types for InnerTube API calls.
enum InnerTubeErrorType {
  network,
  auth,
  rateLimited,
  contentUnavailable,
  serverError,
  unknown,
}

class InnerTubeException implements Exception {
  final String message;
  final int? statusCode;
  final InnerTubeErrorType type;

  InnerTubeException(this.message, {this.statusCode, this.type = InnerTubeErrorType.unknown});

  factory InnerTubeException.fromStatusCode(int code, String body) {
    InnerTubeErrorType type;
    if (code == 401 || code == 403) {
      type = InnerTubeErrorType.auth;
    } else if (code == 429) {
      type = InnerTubeErrorType.rateLimited;
    } else if (code >= 500) {
      type = InnerTubeErrorType.serverError;
    } else {
      type = InnerTubeErrorType.unknown;
    }
    return InnerTubeException(
      'InnerTube error $code',
      statusCode: code,
      type: type,
    );
  }

  @override
  String toString() => 'InnerTubeException($type): $message';
}

/// Low-level InnerTube HTTP client with SAPISID auth, retry logic,
/// multi-client support, and visitor data persistence.
class InnerTubeClient {
  final http.Client _http;
  String? _visitorData;
  String? _dataSyncId;
  String? _cookie;
  String? _sapisid;
  String _region;
  String _language;

  InnerTubeClient({
    http.Client? httpClient,
    String region = BackendConfig.defaultRegion,
    String language = BackendConfig.defaultLanguage,
  })  : _http = httpClient ?? http.Client(),
        _region = region,
        _language = language;

  String? get cookie => _cookie;
  String? get visitorData => _visitorData;
  String get region => _region;
  String get language => _language;

  set region(String value) => _region = value;
  set language(String value) => _language = value;

  void setCookie(String? cookie) {
    _cookie = cookie;
    _sapisid = _extractSapisid(cookie);
  }

  void setDataSyncId(String? id) => _dataSyncId = id;
  void setVisitorData(String? vd) => _visitorData = vd;

  bool get isLoggedIn => _cookie != null && _cookie!.isNotEmpty;

  /// Extract SAPISID from cookie string.
  static String? _extractSapisid(String? cookie) {
    if (cookie == null) return null;
    final regex = RegExp(r'SAPISID=([^;]+)');
    final match = regex.firstMatch(cookie);
    return match?.group(1);
  }

  /// Generate SAPISIDHASH authorization header.
  /// Format: SAPISIDHASH {timestamp}_{sha1("{timestamp} {SAPISID} {origin}")}
  String? _generateSapisidHash() {
    if (_sapisid == null) return null;
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final input = '$timestamp $_sapisid ${BackendConfig.origin}';
    final hash = sha1.convert(utf8.encode(input)).toString();
    return 'SAPISIDHASH ${timestamp}_$hash';
  }

  /// Build InnerTube context for a specific client type.
  Map<String, dynamic> _buildContext(InnerTubeClientConfig client, {bool setLogin = false}) {
    final clientMap = <String, dynamic>{
      'clientName': client.clientName,
      'clientVersion': client.clientVersion,
      'gl': _region,
      'hl': _language,
    };
    if (_visitorData != null) clientMap['visitorData'] = _visitorData;
    if (client.osName != null) clientMap['osName'] = client.osName;
    if (client.osVersion != null) clientMap['osVersion'] = client.osVersion;
    if (client.deviceMake != null) clientMap['deviceMake'] = client.deviceMake;
    if (client.deviceModel != null) clientMap['deviceModel'] = client.deviceModel;
    if (client.androidSdkVersion != null) {
      clientMap['androidSdkVersion'] = client.androidSdkVersion;
    }

    final context = <String, dynamic>{'client': clientMap};

    if (client.isEmbedded) {
      context['thirdParty'] = {'embedUrl': 'https://www.youtube.com'};
    }

    if (setLogin && _dataSyncId != null && client.supportsLogin) {
      context['user'] = {'onBehalfOfUser': _dataSyncId};
    }

    return context;
  }

  /// Build HTTP headers for a request.
  Map<String, String> _buildHeaders(
    InnerTubeClientConfig client, {
    bool setLogin = false,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': client.userAgent,
      'X-Goog-Api-Format-Version': '1',
      'X-YouTube-Client-Name': client.clientId,
      'X-YouTube-Client-Version': client.clientVersion,
      'X-Origin': BackendConfig.origin,
      'Referer': BackendConfig.referer,
      'Accept': 'application/json',
      'Accept-Language': 'en-US,en;q=0.9',
    };

    if (_visitorData != null) {
      headers['X-Goog-Visitor-Id'] = _visitorData!;
    }

    if (setLogin && _cookie != null && client.supportsLogin) {
      headers['Cookie'] = _cookie!;
      final authHash = _generateSapisidHash();
      if (authHash != null) {
        headers['Authorization'] = authHash;
      }
    }

    return headers;
  }

  /// Execute a POST request with retry logic and exponential backoff.
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    InnerTubeClientConfig? client,
    bool setLogin = false,
    Map<String, String>? extraQueryParams,
  }) async {
    final clientConfig = client ?? BackendConfig.webRemix;
    final needsLogin = setLogin && isLoggedIn;

    final fullBody = <String, dynamic>{
      'context': _buildContext(clientConfig, setLogin: needsLogin),
      ...body,
    };

    var uri = Uri.parse('${BackendConfig.innerTubeBaseUrl}/$endpoint');
    final queryParams = <String, String>{
      'prettyPrint': 'false',
      if (extraQueryParams != null) ...extraQueryParams,
    };
    uri = uri.replace(queryParameters: queryParams);

    final headers = _buildHeaders(clientConfig, setLogin: needsLogin);
    final encodedBody = json.encode(fullBody);

    // Retry with exponential backoff
    for (var attempt = 0; attempt <= BackendConfig.maxRetries; attempt++) {
      try {
        final response = await _http
            .post(uri, headers: headers, body: encodedBody)
            .timeout(const Duration(seconds: BackendConfig.httpTimeoutSeconds));

        if (response.statusCode != 200) {
          throw InnerTubeException.fromStatusCode(
              response.statusCode, response.body);
        }

        final data = json.decode(response.body) as Map<String, dynamic>;

        // Extract and persist visitor data from response
        final vd = data['responseContext']?['visitorData'] as String?;
        if (vd != null) _visitorData = vd;

        return data;
      } on InnerTubeException {
        rethrow; // Don't retry API errors
      } on TimeoutException {
        if (attempt == BackendConfig.maxRetries) {
          throw InnerTubeException('Request timed out after ${BackendConfig.maxRetries} retries',
              type: InnerTubeErrorType.network);
        }
      } on SocketException {
        if (attempt == BackendConfig.maxRetries) {
          throw InnerTubeException('Network error after ${BackendConfig.maxRetries} retries',
              type: InnerTubeErrorType.network);
        }
      } on http.ClientException {
        if (attempt == BackendConfig.maxRetries) {
          throw InnerTubeException('Network error after ${BackendConfig.maxRetries} retries',
              type: InnerTubeErrorType.network);
        }
      } catch (e) {
        if (attempt == BackendConfig.maxRetries) {
          throw InnerTubeException('Unexpected error: $e',
              type: InnerTubeErrorType.unknown);
        }
      }

      // Wait before retrying
      if (attempt < BackendConfig.maxRetries) {
        await Future.delayed(
            Duration(milliseconds: BackendConfig.retryDelaysMs[attempt]));
      }
    }

    throw InnerTubeException('Max retries exceeded',
        type: InnerTubeErrorType.network);
  }

  void dispose() {
    _http.close();
  }
}
