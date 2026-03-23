import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/backend_config.dart';

/// Low-level InnerTube HTTP client.
/// Sends POST requests to YouTube Music's internal API endpoints.
/// This is the same API that the YouTube Music web app uses.
class InnerTubeClient {
  final http.Client _http;
  String? _visitorData;
  String? cookie; // Set this for logged-in requests

  InnerTubeClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// Build the context object that YouTube expects in every request.
  Map<String, dynamic> _buildContext({bool useWebClient = false}) {
    return {
      'client': {
        'clientName': useWebClient
            ? BackendConfig.webClientName
            : BackendConfig.clientName,
        'clientVersion': useWebClient
            ? BackendConfig.webClientVersion
            : BackendConfig.clientVersion,
        'gl': BackendConfig.defaultRegion,
        'hl': BackendConfig.defaultLanguage,
        if (_visitorData != null) 'visitorData': _visitorData,
      },
    };
  }

  /// Common headers for InnerTube requests.
  Map<String, String> _buildHeaders({bool useWebClient = false}) {
    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': BackendConfig.userAgent,
      'X-Goog-Api-Format-Version': '1',
      'X-YouTube-Client-Name': useWebClient
          ? BackendConfig.webClientId
          : BackendConfig.clientId,
      'X-YouTube-Client-Version': useWebClient
          ? BackendConfig.webClientVersion
          : BackendConfig.clientVersion,
      'X-Origin': BackendConfig.origin,
      'Referer': BackendConfig.referer,
      'Accept': 'application/json',
      'Accept-Language': 'en-US,en;q=0.9',
    };
    if (cookie != null && cookie!.isNotEmpty) {
      headers['Cookie'] = cookie!;
    }
    if (_visitorData != null) {
      headers['X-Goog-Visitor-Id'] = _visitorData!;
    }
    return headers;
  }

  /// Execute a POST request to an InnerTube endpoint.
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool useWebClient = false,
    Map<String, String>? queryParams,
  }) async {
    final fullBody = {
      'context': _buildContext(useWebClient: useWebClient),
      ...body,
    };

    var uri = Uri.parse('${BackendConfig.innerTubeBaseUrl}/$endpoint');
    if (queryParams != null) {
      uri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        ...queryParams,
      });
    }
    // Always add prettyPrint=false for smaller payloads
    uri = uri.replace(queryParameters: {
      ...uri.queryParameters,
      'prettyPrint': 'false',
    });

    final response = await _http
        .post(
          uri,
          headers: _buildHeaders(useWebClient: useWebClient),
          body: json.encode(fullBody),
        )
        .timeout(Duration(seconds: BackendConfig.httpTimeoutSeconds));

    if (response.statusCode != 200) {
      throw InnerTubeException(
        'InnerTube error ${response.statusCode}: ${response.reasonPhrase}',
        response.statusCode,
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;

    // Extract visitor data from response if present
    final vd = _extractVisitorData(data);
    if (vd != null) _visitorData = vd;

    return data;
  }

  String? _extractVisitorData(Map<String, dynamic> data) {
    try {
      return data['responseContext']?['visitorData'] as String?;
    } catch (_) {
      return null;
    }
  }
}

class InnerTubeException implements Exception {
  final String message;
  final int statusCode;
  InnerTubeException(this.message, this.statusCode);
  @override
  String toString() => message;
}
