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

/// High-level InnerTube API service. All public methods return domain models.
/// Inspired by Metrolist's YouTube.kt architecture.
class InnerTubeService {
  final InnerTubeClient _client;

  InnerTubeService({InnerTubeClient? client})
      : _client = client ?? InnerTubeClient();

  InnerTubeClient get innerTubeClient => _client;

  void setCookie(String? cookie) => _client.setCookie(cookie);
  void setRegion(String region) => _client.region = region;
  void setLanguage(String language) => _client.language = language;
  bool get isLoggedIn => _client.isLoggedIn;

  // ─────────────────────────────────────────────────────────
  // SEARCH
  // ─────────────────────────────────────────────────────────

  /// Search YouTube Music. Optional [filter] for type filtering.
  /// Returns results and a continuation token for pagination.
  Future<SearchResponse> search(String query, {String? filter}) async {
    final body = <String, dynamic>{'query': query};
    if (filter != null) body['params'] = _getSearchParams(filter);
    final data = await _client.post('search', body);
    return InnerTubeParser.parseSearchResponse(data);
  }

  /// Load more search results using a continuation token.
  Future<SearchResponse> searchContinuation(String continuation) async {
    final data = await _client.post('search', {'continuation': continuation});
    return InnerTubeParser.parseSearchContinuation(data);
  }

  /// Get search autocomplete suggestions.
  Future<List<String>> searchSuggestions(String query) async {
    final data = await _client.post('music/get_search_suggestions', {
      'input': query,
    });
    return InnerTubeParser.parseSearchSuggestions(data);
  }

  // ─────────────────────────────────────────────────────────
  // BROWSE
  // ─────────────────────────────────────────────────────────

  /// Fetch YouTube Music home page.
  Future<HomePageResponse> getHomePage() async {
    final data = await _client.post('browse', {'browseId': 'FEmusic_home'});
    return InnerTubeParser.parseHomePage(data);
  }

  /// Fetch home page continuation.
  Future<List<HomeSection>> getHomePageContinuation(String continuation) async {
    final data = await _client.post('browse', {'continuation': continuation});
    return InnerTubeParser.parseHomePageContinuation(data);
  }

  /// Fetch an artist page by channel ID / browse ID.
  Future<ArtistPage> getArtist(String browseId) async {
    final data = await _client.post('browse', {'browseId': browseId});
    return InnerTubeParser.parseArtistPage(data, browseId);
  }

  /// Fetch an album page.
  Future<Album> getAlbum(String browseId) async {
    final data = await _client.post('browse', {'browseId': browseId});
    return InnerTubeParser.parseAlbumPage(data, browseId);
  }

  /// Fetch a playlist page.
  Future<Playlist> getPlaylist(String playlistId) async {
    final id = playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
    final data = await _client.post('browse', {'browseId': id});
    return InnerTubeParser.parsePlaylistPage(data, playlistId);
  }

  /// Fetch playlist continuation for pagination.
  Future<PlaylistContinuation> getPlaylistContinuation(
      String continuation) async {
    final data = await _client.post('browse', {'continuation': continuation});
    return InnerTubeParser.parsePlaylistContinuation(data);
  }

  /// Fetch charts/trending.
  Future<List<HomeSection>> getCharts() async {
    final data = await _client.post('browse', {
      'browseId': 'FEmusic_charts',
    });
    return InnerTubeParser.parseCharts(data);
  }

  /// Fetch moods/genres.
  Future<List<MoodCategory>> getMoodsAndGenres() async {
    final data = await _client.post('browse', {
      'browseId': 'FEmusic_moods_and_genres',
    });
    return InnerTubeParser.parseMoodsAndGenres(data);
  }

  /// Fetch mood/genre playlist page.
  Future<List<HomeSection>> getMoodPlaylists(String params) async {
    final data = await _client.post('browse', {
      'browseId': 'FEmusic_moods_and_genres_category',
      'params': params,
    });
    return InnerTubeParser.parseMoodPlaylists(data);
  }

  /// Fetch new releases.
  Future<List<HomeSection>> getNewReleases() async {
    final data = await _client.post('browse', {
      'browseId': 'FEmusic_new_releases',
    });
    return InnerTubeParser.parseNewReleases(data);
  }

  // ─────────────────────────────────────────────────────────
  // PLAYER
  // ─────────────────────────────────────────────────────────

  /// Get stream URL for a video using multi-client fallback chain.
  /// Tries: WEB_REMIX → TVHTML5_SIMPLY_EMBEDDED → ANDROID_VR → iOS → Piped
  Future<StreamInfo?> getStreamInfo(String videoId,
      {String audioQuality = 'best'}) async {
    // Try each client in the fallback chain
    for (final clientConfig in BackendConfig.playerFallbackChain) {
      try {
        final body = <String, dynamic>{
          'videoId': videoId,
          if (clientConfig.isEmbedded)
            'playbackContext': {
              'contentPlaybackContext': {'signatureTimestamp': 0}
            },
        };

        final data = await _client.post(
          'player',
          body,
          client: clientConfig,
          setLogin: clientConfig.supportsLogin && _client.isLoggedIn,
        );

        final status = data['playabilityStatus']?['status'] as String?;
        if (status != 'OK') continue;

        final streamInfo =
            InnerTubeParser.parseBestAudioStream(data, quality: audioQuality);
        if (streamInfo != null) return streamInfo;
      } catch (_) {
        continue;
      }
    }

    // Fallback to Piped API
    return _getStreamFromPiped(videoId, audioQuality);
  }

  /// Piped API fallback for stream URL extraction.
  Future<StreamInfo?> _getStreamFromPiped(
      String videoId, String quality) async {
    final urls = [BackendConfig.pipedBaseUrl, ...BackendConfig.pipedFallbacks];
    for (final baseUrl in urls) {
      try {
        final uri = Uri.parse('$baseUrl/streams/$videoId');
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: BackendConfig.httpTimeoutSeconds));
        if (response.statusCode != 200) continue;

        final data = json.decode(response.body);
        final audioStreams = data['audioStreams'] as List? ?? [];
        if (audioStreams.isEmpty) continue;

        // Filter to audio-only streams
        final validStreams = audioStreams
            .where((s) => s['url'] != null && s['mimeType'] != null)
            .toList();
        if (validStreams.isEmpty) continue;

        // Sort by bitrate
        validStreams.sort((a, b) =>
            ((b['bitrate'] as int?) ?? 0)
                .compareTo((a['bitrate'] as int?) ?? 0));

        Map<String, dynamic> chosen;
        if (quality == 'low') {
          chosen = validStreams.last;
        } else if (quality == 'medium') {
          chosen = validStreams[validStreams.length ~/ 2];
        } else {
          chosen = validStreams.first;
        }

        return StreamInfo(
          url: chosen['url'] as String,
          mimeType: chosen['mimeType'] as String? ?? 'audio/mp4',
          bitrate: chosen['bitrate'] as int? ?? 0,
          source: 'piped',
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────
  // NEXT (Queue, Related, Lyrics)
  // ─────────────────────────────────────────────────────────

  /// Get related tracks / up-next queue for a song.
  Future<NextResponse> getNext(String videoId,
      {String? playlistId, String? continuation}) async {
    final body = <String, dynamic>{
      'videoId': videoId,
      'enablePersistentPlaylistPanel': true,
      'isAudioOnly': true,
      if (playlistId != null) 'playlistId': playlistId,
      if (continuation != null) 'continuation': continuation,
    };
    final data = await _client.post('next', body);
    return InnerTubeParser.parseNextResponse(data);
  }

  /// Get queue tracks.
  Future<List<Track>> getQueue(List<String> videoIds,
      {String? playlistId}) async {
    final data = await _client.post('music/get_queue', {
      'videoIds': videoIds,
      if (playlistId != null) 'playlistId': playlistId,
    });
    return InnerTubeParser.parseQueueItems(data);
  }

  // ─────────────────────────────────────────────────────────
  // LIBRARY (requires login)
  // ─────────────────────────────────────────────────────────

  /// Like a song.
  Future<void> likeSong(String videoId) async {
    await _client.post('like/like', {'target': {'videoId': videoId}},
        setLogin: true);
  }

  /// Unlike a song.
  Future<void> unlikeSong(String videoId) async {
    await _client.post('like/removelike', {'target': {'videoId': videoId}},
        setLogin: true);
  }

  /// Create a new playlist.
  Future<String?> createPlaylist(String title,
      {List<String> videoIds = const []}) async {
    final data = await _client.post(
        'playlist/create',
        {
          'title': title,
          'privacyStatus': 'PRIVATE',
          if (videoIds.isNotEmpty) 'videoIds': videoIds,
        },
        setLogin: true);
    return data['playlistId'] as String?;
  }

  /// Delete a playlist.
  Future<void> deletePlaylist(String playlistId) async {
    await _client.post(
        'playlist/delete', {'playlistId': playlistId},
        setLogin: true);
  }

  /// Add songs to a playlist.
  Future<void> addToPlaylist(String playlistId, List<String> videoIds) async {
    final actions = videoIds
        .map((id) => {'action': 'ACTION_ADD_VIDEO', 'addedVideoId': id})
        .toList();
    await _client.post(
        'browse/edit_playlist',
        {'playlistId': playlistId, 'actions': actions},
        setLogin: true);
  }

  /// Remove songs from a playlist.
  Future<void> removeFromPlaylist(
      String playlistId, List<String> setVideoIds) async {
    final actions = setVideoIds
        .map((id) => {
              'action': 'ACTION_REMOVE_VIDEO',
              'setVideoId': id,
            })
        .toList();
    await _client.post(
        'browse/edit_playlist',
        {'playlistId': playlistId, 'actions': actions},
        setLogin: true);
  }

  /// Get account info.
  Future<Map<String, dynamic>?> getAccountInfo() async {
    if (!isLoggedIn) return null;
    try {
      final data =
          await _client.post('account/account_menu', {}, setLogin: true);
      return InnerTubeParser.parseAccountInfo(data);
    } catch (_) {
      return null;
    }
  }

  /// Fetch user library playlists.
  Future<List<Playlist>> getLibraryPlaylists() async {
    if (!isLoggedIn) return [];
    try {
      final data = await _client.post(
          'browse', {'browseId': 'FEmusic_liked_playlists'},
          setLogin: true);
      return InnerTubeParser.parseLibraryPlaylists(data);
    } catch (_) {
      return [];
    }
  }

  /// Fetch liked songs playlist.
  Future<Playlist> getLikedSongs() async {
    return getPlaylist('LM');
  }

  /// Fetch listening history.
  Future<List<Track>> getHistory() async {
    if (!isLoggedIn) return [];
    try {
      final data = await _client.post(
          'browse', {'browseId': 'FEmusic_history'},
          setLogin: true);
      return InnerTubeParser.parseHistoryPage(data);
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────
  // SEARCH FILTER PARAMS
  // ─────────────────────────────────────────────────────────

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
        return 'EgeKAQQoADgBagwQDhAKEAMQBRAJEAQ%3D';
      default:
        return '';
    }
  }

  void dispose() => _client.dispose();
}

/// Response wrapper for search with continuation support.
class SearchResponse {
  final List<SearchResult> results;
  final String? continuation;

  const SearchResponse({this.results = const [], this.continuation});
}

/// Response wrapper for next endpoint.
class NextResponse {
  final List<Track> queue;
  final String? lyricsId;
  final String? relatedId;
  final String? continuation;

  const NextResponse({
    this.queue = const [],
    this.lyricsId,
    this.relatedId,
    this.continuation,
  });
}

/// Stream info for a resolved audio URL.
class StreamInfo {
  final String url;
  final String mimeType;
  final int bitrate;
  final String source; // 'innertube', 'piped', etc.
  final DateTime resolvedAt;

  StreamInfo({
    required this.url,
    this.mimeType = 'audio/mp4',
    this.bitrate = 0,
    this.source = 'innertube',
  }) : resolvedAt = DateTime.now();

  /// Stream URLs expire after ~6 hours.
  bool get isExpired =>
      DateTime.now().difference(resolvedAt).inHours >= 5;
}

/// Home page response with continuation.
class HomePageResponse {
  final List<HomeSection> sections;
  final String? continuation;

  const HomePageResponse({this.sections = const [], this.continuation});
}

/// Playlist continuation result.
class PlaylistContinuation {
  final List<Track> tracks;
  final String? continuation;

  const PlaylistContinuation({this.tracks = const [], this.continuation});
}

/// Mood/genre category.
class MoodCategory {
  final String title;
  final List<MoodItem> items;

  const MoodCategory({required this.title, this.items = const []});
}

/// Individual mood/genre item.
class MoodItem {
  final String title;
  final String params;

  const MoodItem({required this.title, required this.params});
}

/// Artist page model with sections.
class ArtistPage {
  final Artist artist;
  final List<ArtistSection> sections;

  const ArtistPage({required this.artist, this.sections = const []});
}

/// A section on an artist page (top songs, albums, singles, etc.).
class ArtistSection {
  final String title;
  final String? browseId;
  final List<dynamic> items; // Track, Album, or Artist objects

  const ArtistSection({required this.title, this.browseId, this.items = const []});
}
