import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/backend_config.dart';
import '../../domain/models/track.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/search_result.dart';
import '../../domain/models/home_section.dart';
import 'innertube_client.dart';
import 'innertube_parser.dart';

/// High-level service that wraps InnerTube endpoints and returns
/// parsed domain models. Inspired by Metrolist's YouTube.kt.
class InnerTubeService {
  final InnerTubeClient _client;

  InnerTubeService({InnerTubeClient? client})
      : _client = client ?? InnerTubeClient();

  /// Set cookie for authenticated requests (Google sign-in).
  void setCookie(String? cookie) {
    _client.cookie = cookie;
  }

  // ─────────────────────────────────────────────────────────
  // SEARCH
  // ─────────────────────────────────────────────────────────

  /// Search YouTube Music for songs, artists, albums, playlists.
  Future<List<SearchResult>> search(String query,
      {String? filter}) async {
    final body = <String, dynamic>{
      'query': query,
    };
    if (filter != null) {
      body['params'] = _getSearchParams(filter);
    }

    final data = await _client.post('search', body);
    return InnerTubeParser.parseSearchResults(data);
  }

  /// Get search suggestions / autocomplete.
  Future<List<String>> searchSuggestions(String query) async {
    final data = await _client.post('music/get_search_suggestions', {
      'input': query,
    });
    return InnerTubeParser.parseSearchSuggestions(data);
  }

  // ─────────────────────────────────────────────────────────
  // BROWSE (Home, Artist, Album, Playlist pages)
  // ─────────────────────────────────────────────────────────

  /// Fetch the YouTube Music home page content.
  Future<List<HomeSection>> getHomePage() async {
    final data = await _client.post('browse', {
      'browseId': 'FEmusic_home',
    });
    return InnerTubeParser.parseHomePage(data);
  }

  /// Fetch an artist page by channel ID.
  Future<Artist> getArtist(String channelId) async {
    final data = await _client.post('browse', {
      'browseId': channelId,
    });
    return InnerTubeParser.parseArtistPage(data, channelId);
  }

  /// Fetch an album page.
  Future<Album> getAlbum(String browseId) async {
    final data = await _client.post('browse', {
      'browseId': browseId,
    });
    return InnerTubeParser.parseAlbumPage(data, browseId);
  }

  /// Fetch a playlist.
  Future<Playlist> getPlaylist(String playlistId) async {
    final id = playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
    final data = await _client.post('browse', {
      'browseId': id,
    });
    return InnerTubeParser.parsePlaylistPage(data, playlistId);
  }

  // ─────────────────────────────────────────────────────────
  // PLAYER (stream URLs)
  // ─────────────────────────────────────────────────────────

  /// Get playable stream URLs for a video/song.
  /// Uses the WEB client for better compatibility with stream extraction.
  Future<String?> getStreamUrl(String videoId) async {
    try {
      final data = await _client.post('player', {
        'videoId': videoId,
      }, useWebClient: true);

      return InnerTubeParser.parseBestAudioStream(data);
    } catch (_) {
      // Fallback to Piped API
      return _getStreamUrlFromPiped(videoId);
    }
  }

  /// Piped API fallback for stream URL extraction.
  Future<String?> _getStreamUrlFromPiped(String videoId) async {
    final urls = [
      BackendConfig.pipedBaseUrl,
      ...BackendConfig.pipedFallbacks,
    ];
    for (final baseUrl in urls) {
      try {
        final uri = Uri.parse('$baseUrl/streams/$videoId');
        final response = await http.get(uri).timeout(
              Duration(seconds: BackendConfig.httpTimeoutSeconds),
            );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final audioStreams = data['audioStreams'] as List? ?? [];
          if (audioStreams.isEmpty) continue;
          // Sort by bitrate, pick best
          audioStreams.sort((a, b) =>
              ((b['bitrate'] as int?) ?? 0)
                  .compareTo((a['bitrate'] as int?) ?? 0));
          return audioStreams.first['url'] as String?;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────
  // NEXT (related songs, queue)
  // ─────────────────────────────────────────────────────────

  /// Get related tracks for a given song (for auto-play queue).
  Future<List<Track>> getRelatedTracks(String videoId,
      {String? playlistId}) async {
    final body = <String, dynamic>{
      'videoId': videoId,
      'enablePersistentPlaylistPanel': true,
      'isAudioOnly': true,
    };
    if (playlistId != null) body['playlistId'] = playlistId;

    final data = await _client.post('next', body);
    return InnerTubeParser.parseRelatedTracks(data);
  }

  // ─────────────────────────────────────────────────────────
  // TRENDING
  // ─────────────────────────────────────────────────────────

  /// Fetch trending/charts content.
  Future<List<Track>> getTrending() async {
    final data = await _client.post('browse', {
      'browseId': 'FEmusic_charts',
    });
    return InnerTubeParser.parseTrendingTracks(data);
  }

  /// Get search filter params encoded string.
  String _getSearchParams(String filter) {
    switch (filter) {
      case 'songs':
        return 'EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D';
      case 'videos':
        return 'EgWKAQIQAWoKEAkQChAFEAMQBA%3D%3D';
      case 'albums':
        return 'EgWKAQIYAWoKEAkQChAFEAMQBA%3D%3D';
      case 'artists':
        return 'EgWKAQIgAWoKEAkQChAFEAMQBA%3D%3D';
      case 'playlists':
        return 'EgWKAQIoAWoKEAkQChAFEAMQBA%3D%3D';
      default:
        return '';
    }
  }
}
