import '../../domain/models/track.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/search_result.dart';
import '../../domain/models/home_section.dart';

/// Parses InnerTube API JSON responses into domain models.
/// InnerTube responses are deeply nested — this class handles
/// the traversal following patterns from Metrolist's page parsers.
class InnerTubeParser {
  InnerTubeParser._();

  // ─── SEARCH ───

  static List<SearchResult> parseSearchResults(Map<String, dynamic> data) {
    final results = <SearchResult>[];
    try {
      // Navigate: contents > tabbedSearchResultsRenderer > tabs[0] >
      //           tabRenderer > content > sectionListRenderer > contents
      final tabs = _nav(data, [
            'contents',
            'tabbedSearchResultsRenderer',
            'tabs'
          ]) as List? ??
          [];
      if (tabs.isEmpty) return results;

      final sections = _nav(tabs[0], [
            'tabRenderer',
            'content',
            'sectionListRenderer',
            'contents'
          ]) as List? ??
          [];

      for (final section in sections) {
        // musicShelfRenderer contains list items
        final shelf = section['musicShelfRenderer'];
        if (shelf == null) continue;

        final contents = shelf['contents'] as List? ?? [];
        for (final item in contents) {
          final renderer = item['musicResponsiveListItemRenderer'];
          if (renderer == null) continue;

          final result = _parseSearchItem(renderer);
          if (result != null) results.add(result);
        }
      }
    } catch (e) {
      print('Search parse error: $e');
    }
    return results;
  }

  static SearchResult? _parseSearchItem(Map<String, dynamic> renderer) {
    try {
      final flexColumns = renderer['flexColumns'] as List? ?? [];
      if (flexColumns.isEmpty) return null;

      // Title from first flex column
      final title = _getFlexColumnText(flexColumns, 0);
      if (title == null || title.isEmpty) return null;

      // Subtitle info from second flex column (artist, album, duration)
      final subtitle = _getFlexColumnText(flexColumns, 1);

      // Determine type and extract ID
      final navEndpoint =
          renderer['overlay']?['musicItemThumbnailOverlayRenderer']
              ?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint'];

      String? videoId;
      String? browseId;
      SearchResultType type = SearchResultType.song;

      if (navEndpoint != null) {
        videoId = navEndpoint['watchEndpoint']?['videoId'];
      }

      // Check navigation browse endpoint for artists/albums
      final mainNav = renderer['navigationEndpoint'];
      if (mainNav != null) {
        browseId = mainNav['browseEndpoint']?['browseId'];
        final pageType = mainNav['browseEndpoint']
            ?['browseEndpointContextSupportedConfigs']
            ?['browseEndpointContextMusicConfig']?['pageType'];
        if (pageType == 'MUSIC_PAGE_TYPE_ARTIST') {
          type = SearchResultType.artist;
        } else if (pageType == 'MUSIC_PAGE_TYPE_ALBUM') {
          type = SearchResultType.album;
        } else if (pageType == 'MUSIC_PAGE_TYPE_PLAYLIST') {
          type = SearchResultType.playlist;
        }
      }

      // If no videoId from overlay, try flexColumn runs
      if (videoId == null && type == SearchResultType.song) {
        videoId = _getVideoIdFromRuns(flexColumns);
      }

      final id = videoId ?? browseId ?? '';
      if (id.isEmpty) return null;

      // Thumbnail
      final thumbnail = _getThumbnail(renderer);

      // Duration
      final duration = _parseDuration(subtitle);

      // Artist name (from subtitle, typically "Artist • Album • Duration")
      final parts = subtitle?.split(' \u2022 ') ?? subtitle?.split(' · ') ?? [];
      final artistName =
          parts.isNotEmpty ? parts[0].trim() : '';

      return SearchResult(
        id: id,
        title: title,
        artist: artistName,
        subtitle: subtitle ?? '',
        thumbnailUrl: thumbnail ?? '',
        durationSeconds: duration,
        type: type,
        browseId: browseId,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── SEARCH SUGGESTIONS ───

  static List<String> parseSearchSuggestions(Map<String, dynamic> data) {
    final suggestions = <String>[];
    try {
      final contents = data['contents'] as List? ?? [];
      for (final section in contents) {
        final renderer =
            section['searchSuggestionsSectionRenderer']?['contents'] as List? ??
                [];
        for (final item in renderer) {
          final text = item['searchSuggestionRenderer']?['suggestion']
              ?['runs'] as List?;
          if (text != null) {
            final s = text.map((r) => r['text'] ?? '').join('');
            if (s.isNotEmpty) suggestions.add(s);
          }
        }
      }
    } catch (_) {}
    return suggestions;
  }

  // ─── HOME PAGE ───

  static List<HomeSection> parseHomePage(Map<String, dynamic> data) {
    final sections = <HomeSection>[];
    try {
      final contents = _nav(data, [
            'contents',
            'singleColumnBrowseResultsRenderer',
            'tabs',
            0,
            'tabRenderer',
            'content',
            'sectionListRenderer',
            'contents'
          ]) as List? ??
          [];

      for (final section in contents) {
        final shelf = section['musicCarouselShelfRenderer'];
        if (shelf == null) continue;

        final headerTitle = _nav(shelf, [
              'header',
              'musicCarouselShelfBasicHeaderRenderer',
              'title',
              'runs',
              0,
              'text'
            ]) as String? ??
            '';

        final items = shelf['contents'] as List? ?? [];
        final tracks = <Track>[];

        for (final item in items) {
          final renderer = item['musicTwoRowItemRenderer'] ??
              item['musicResponsiveListItemRenderer'];
          if (renderer == null) continue;

          final track = _parseHomeSectionItem(renderer);
          if (track != null) tracks.add(track);
        }

        if (tracks.isNotEmpty && headerTitle.isNotEmpty) {
          sections.add(HomeSection(
            title: headerTitle,
            tracks: tracks,
          ));
        }
      }
    } catch (e) {
      print('Home parse error: $e');
    }
    return sections;
  }

  static Track? _parseHomeSectionItem(Map<String, dynamic> renderer) {
    try {
      // musicTwoRowItemRenderer (grid items)
      final title = renderer['title']?['runs']?[0]?['text'] as String? ??
          _getFlexColumnText(renderer['flexColumns'] as List? ?? [], 0);
      if (title == null || title.isEmpty) return null;

      final subtitle =
          renderer['subtitle']?['runs']?.map((r) => r['text'])?.join('') ??
              _getFlexColumnText(
                  renderer['flexColumns'] as List? ?? [], 1) ??
              '';

      // Video ID from navigation
      String? videoId;
      final watchEndpoint =
          renderer['navigationEndpoint']?['watchEndpoint'];
      if (watchEndpoint != null) {
        videoId = watchEndpoint['videoId'];
      }

      // Browse endpoint (for playlists, albums)
      final browseEndpoint =
          renderer['navigationEndpoint']?['browseEndpoint'];
      if (videoId == null && browseEndpoint != null) {
        videoId = browseEndpoint['browseId'] ?? '';
      }

      if (videoId == null || videoId.isEmpty) return null;

      final thumbnail = _getThumbnailFromRenderer(renderer);

      // Parse artist from subtitle
      final parts =
          (subtitle as String).split(' \u2022 ');
      final artist = parts.isNotEmpty ? parts[0].trim() : '';

      return Track(
        id: videoId,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnail ?? '',
        durationSeconds: 0,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── ARTIST PAGE ───

  static Artist parseArtistPage(
      Map<String, dynamic> data, String channelId) {
    try {
      final header = data['header']?['musicImmersiveHeaderRenderer'] ??
          data['header']?['musicVisualHeaderRenderer'] ?? {};

      final name =
          header['title']?['runs']?[0]?['text'] as String? ?? 'Unknown Artist';
      final thumbList =
          header['thumbnail']?['musicThumbnailRenderer']?['thumbnail']
              ?['thumbnails'] as List? ?? [];
      final thumbnail = thumbList.isNotEmpty
          ? thumbList.last['url'] as String? ?? ''
          : '';

      final subscriberCount = header['subscriptionButton']
              ?['subscribeButtonRenderer']?['subscriberCountText']?['runs']
          ?[0]?['text'] as String?;

      return Artist(
        id: channelId,
        name: name,
        thumbnailUrl: thumbnail,
        subscriberCount: subscriberCount,
      );
    } catch (_) {
      return Artist(id: channelId, name: 'Unknown Artist');
    }
  }

  // ─── ALBUM PAGE ───

  static Album parseAlbumPage(
      Map<String, dynamic> data, String browseId) {
    try {
      final header =
          data['header']?['musicImmersiveHeaderRenderer'] ?? {};
      final respHeader =
          data['header']?['musicDetailHeaderRenderer'] ?? header;

      final title =
          respHeader['title']?['runs']?[0]?['text'] as String? ?? 'Album';
      final subtitle = (respHeader['subtitle']?['runs'] as List? ?? [])
          .map((r) => r['text'])
          .join('');
      final thumbList = respHeader['thumbnail']
              ?['croppedSquareThumbnailRenderer']?['thumbnail']
              ?['thumbnails'] as List? ??
          [];
      final thumbnail = thumbList.isNotEmpty
          ? thumbList.last['url'] as String? ?? ''
          : '';

      // Parse tracks from shelf
      final contents = _nav(data, [
            'contents',
            'singleColumnBrowseResultsRenderer',
            'tabs',
            0,
            'tabRenderer',
            'content',
            'sectionListRenderer',
            'contents',
            0,
            'musicShelfRenderer',
            'contents'
          ]) as List? ??
          [];

      final tracks = <Track>[];
      for (final item in contents) {
        final renderer = item['musicResponsiveListItemRenderer'];
        if (renderer == null) continue;
        final flexColumns = renderer['flexColumns'] as List? ?? [];
        final trackTitle = _getFlexColumnText(flexColumns, 0);
        if (trackTitle == null) continue;

        final trackArtist = _getFlexColumnText(flexColumns, 1) ?? '';
        String? videoId;
        final overlay = renderer['overlay']
            ?['musicItemThumbnailOverlayRenderer']?['content']
            ?['musicPlayButtonRenderer']?['playNavigationEndpoint'];
        if (overlay != null) {
          videoId = overlay['watchEndpoint']?['videoId'];
        }

        if (videoId != null) {
          tracks.add(Track(
            id: videoId,
            title: trackTitle,
            artist: trackArtist,
            thumbnailUrl: thumbnail,
            durationSeconds: _parseDuration(
                _getFlexColumnText(flexColumns, 2)),
          ));
        }
      }

      return Album(
        id: browseId,
        title: title,
        artist: subtitle,
        thumbnailUrl: thumbnail,
        tracks: tracks,
      );
    } catch (_) {
      return Album(id: browseId, title: 'Album', tracks: []);
    }
  }

  // ─── PLAYLIST PAGE ───

  static Playlist parsePlaylistPage(
      Map<String, dynamic> data, String playlistId) {
    try {
      final header =
          data['header']?['musicDetailHeaderRenderer'] ??
              data['header']?['musicEditablePlaylistDetailHeaderRenderer']
                  ?['header']?['musicDetailHeaderRenderer'] ??
              {};

      final title =
          header['title']?['runs']?[0]?['text'] as String? ?? 'Playlist';
      final thumbList = header['thumbnail']
              ?['croppedSquareThumbnailRenderer']?['thumbnail']
              ?['thumbnails'] as List? ??
          [];
      final thumbnail = thumbList.isNotEmpty
          ? thumbList.last['url'] as String? ?? ''
          : '';

      final contents = _nav(data, [
            'contents',
            'singleColumnBrowseResultsRenderer',
            'tabs',
            0,
            'tabRenderer',
            'content',
            'sectionListRenderer',
            'contents',
            0,
            'musicShelfRenderer',
            'contents'
          ]) as List? ??
          [];

      final tracks = <Track>[];
      for (final item in contents) {
        final renderer = item['musicResponsiveListItemRenderer'];
        if (renderer == null) continue;

        final flexColumns = renderer['flexColumns'] as List? ?? [];
        final trackTitle = _getFlexColumnText(flexColumns, 0);
        if (trackTitle == null) continue;

        final trackSubtitle = _getFlexColumnText(flexColumns, 1) ?? '';
        final parts = trackSubtitle.split(' \u2022 ');
        final artist = parts.isNotEmpty ? parts[0].trim() : '';

        String? videoId;
        final overlay = renderer['overlay']
            ?['musicItemThumbnailOverlayRenderer']?['content']
            ?['musicPlayButtonRenderer']?['playNavigationEndpoint'];
        if (overlay != null) {
          videoId = overlay['watchEndpoint']?['videoId'];
        }

        final trackThumb = _getThumbnail(renderer);

        if (videoId != null) {
          tracks.add(Track(
            id: videoId,
            title: trackTitle,
            artist: artist,
            thumbnailUrl: trackThumb ?? thumbnail,
            durationSeconds:
                _parseDuration(_getFlexColumnText(flexColumns, 2)),
          ));
        }
      }

      return Playlist(
        id: playlistId,
        title: title,
        thumbnailUrl: thumbnail,
        tracks: tracks,
        trackCount: tracks.length,
      );
    } catch (_) {
      return Playlist(id: playlistId, title: 'Playlist', tracks: []);
    }
  }

  // ─── PLAYER (Stream URLs) ───

  static String? parseBestAudioStream(Map<String, dynamic> data) {
    try {
      final formats =
          data['streamingData']?['adaptiveFormats'] as List? ?? [];
      final audioFormats = formats
          .where((f) =>
              (f['mimeType'] as String? ?? '').startsWith('audio/'))
          .toList();

      if (audioFormats.isEmpty) return null;

      // Sort by bitrate descending
      audioFormats.sort((a, b) =>
          ((b['bitrate'] as int?) ?? 0)
              .compareTo((a['bitrate'] as int?) ?? 0));

      return audioFormats.first['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ─── RELATED TRACKS ───

  static List<Track> parseRelatedTracks(Map<String, dynamic> data) {
    final tracks = <Track>[];
    try {
      final tabs = _nav(data, [
            'contents',
            'singleColumnMusicWatchNextResultsRenderer',
            'tabbedRenderer',
            'watchNextTabbedResultsRenderer',
            'tabs'
          ]) as List? ??
          [];

      for (final tab in tabs) {
        final contents = _nav(tab, [
              'tabRenderer',
              'content',
              'musicQueueRenderer',
              'content',
              'playlistPanelRenderer',
              'contents'
            ]) as List? ??
            [];

        for (final item in contents) {
          final renderer = item['playlistPanelVideoRenderer'];
          if (renderer == null) continue;

          final title =
              renderer['title']?['runs']?[0]?['text'] as String? ?? '';
          final videoId =
              renderer['navigationEndpoint']?['watchEndpoint']?['videoId'];
          if (videoId == null || title.isEmpty) continue;

          final longByline = (renderer['longBylineText']?['runs'] as List? ?? [])
              .map((r) => r['text'])
              .join('');
          final thumbList =
              renderer['thumbnail']?['thumbnails'] as List? ?? [];
          final thumbnail = thumbList.isNotEmpty
              ? thumbList.last['url'] as String? ?? ''
              : '';

          final lengthText = renderer['lengthText']?['runs']?[0]?['text'];

          tracks.add(Track(
            id: videoId,
            title: title,
            artist: longByline,
            thumbnailUrl: thumbnail,
            durationSeconds: _parseDurationString(lengthText),
          ));
        }
      }
    } catch (_) {}
    return tracks;
  }

  // ─── TRENDING ───

  static List<Track> parseTrendingTracks(Map<String, dynamic> data) {
    final tracks = <Track>[];
    try {
      final contents = _nav(data, [
            'contents',
            'singleColumnBrowseResultsRenderer',
            'tabs',
            0,
            'tabRenderer',
            'content',
            'sectionListRenderer',
            'contents'
          ]) as List? ??
          [];

      for (final section in contents) {
        final shelf = section['musicCarouselShelfRenderer'] ??
            section['musicShelfRenderer'];
        if (shelf == null) continue;

        final items = shelf['contents'] as List? ?? [];
        for (final item in items) {
          final renderer = item['musicTwoRowItemRenderer'] ??
              item['musicResponsiveListItemRenderer'];
          if (renderer == null) continue;

          final track = _parseHomeSectionItem(renderer);
          if (track != null) tracks.add(track);
        }
        if (tracks.length >= 20) break;
      }
    } catch (_) {}
    return tracks;
  }

  // ─── UTILITY METHODS ───

  /// Navigate a nested map/list structure using a path of keys/indices.
  static dynamic _nav(dynamic data, List<dynamic> path) {
    dynamic current = data;
    for (final key in path) {
      if (current == null) return null;
      if (key is int) {
        if (current is List && key < current.length) {
          current = current[key];
        } else {
          return null;
        }
      } else if (key is String) {
        if (current is Map) {
          current = current[key];
        } else {
          return null;
        }
      }
    }
    return current;
  }

  /// Extract text from a flexColumns entry at a given index.
  static String? _getFlexColumnText(List flexColumns, int index) {
    if (index >= flexColumns.length) return null;
    try {
      final runs = flexColumns[index]
          ['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
      if (runs == null) return null;
      return (runs as List).map((r) => r['text'] ?? '').join('');
    } catch (_) {
      return null;
    }
  }

  /// Extract video ID from flex column navigation endpoints.
  static String? _getVideoIdFromRuns(List flexColumns) {
    try {
      for (final col in flexColumns) {
        final runs = col['musicResponsiveListItemFlexColumnRenderer']
            ?['text']?['runs'] as List?;
        if (runs == null) continue;
        for (final run in runs) {
          final videoId = run['navigationEndpoint']
              ?['watchEndpoint']?['videoId'];
          if (videoId != null) return videoId;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Extract thumbnail URL from a renderer.
  static String? _getThumbnail(Map<String, dynamic> renderer) {
    try {
      final thumbList = renderer['thumbnail']
              ?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']
          as List?;
      if (thumbList != null && thumbList.isNotEmpty) {
        return thumbList.last['url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  static String? _getThumbnailFromRenderer(Map<String, dynamic> renderer) {
    try {
      final thumbList = renderer['thumbnailRenderer']
              ?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']
          as List?;
      if (thumbList != null && thumbList.isNotEmpty) {
        return thumbList.last['url'] as String?;
      }
      // Fallback to direct thumbnail
      return _getThumbnail(renderer);
    } catch (_) {
      return _getThumbnail(renderer);
    }
  }

  /// Parse duration from a subtitle string like "3:45" or "Artist • 3:45".
  static int _parseDuration(String? text) {
    if (text == null) return 0;
    // Look for time pattern in the text
    final timeRegex = RegExp(r'(\d+):(\d{2})(?::(\d{2}))?');
    final match = timeRegex.firstMatch(text);
    if (match == null) return 0;
    return _parseDurationString(match.group(0));
  }

  /// Parse "3:45" or "1:03:45" to seconds.
  static int _parseDurationString(String? text) {
    if (text == null) return 0;
    final parts = text.split(':').map((p) => int.tryParse(p) ?? 0).toList();
    if (parts.length == 3) {
      return parts[0] * 3600 + parts[1] * 60 + parts[2];
    } else if (parts.length == 2) {
      return parts[0] * 60 + parts[1];
    }
    return 0;
  }
}
