import '../../domain/models/track.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/search_result.dart';
import '../../domain/models/home_section.dart';
import 'innertube_service.dart';

/// Parses InnerTube JSON responses into domain models.
/// Handles all response shapes following Metrolist's parsing patterns.
class InnerTubeParser {
  InnerTubeParser._();

  // ═══════════════════════════════════════════════════════════
  // SEARCH
  // ═══════════════════════════════════════════════════════════

  static SearchResponse parseSearchResponse(Map<String, dynamic> data) {
    final results = <SearchResult>[];
    String? continuation;
    try {
      final tabs = _nav(data,
              ['contents', 'tabbedSearchResultsRenderer', 'tabs']) as List? ??
          [];
      if (tabs.isEmpty) return const SearchResponse();

      final sections = _nav(tabs[0], [
            'tabRenderer',
            'content',
            'sectionListRenderer',
            'contents'
          ]) as List? ??
          [];

      for (final section in sections) {
        // Top result card
        final card = section['musicCardShelfRenderer'];
        if (card != null) {
          final result = _parseCardShelfResult(card);
          if (result != null) results.add(result);
          // Also parse items inside the card's shelf
          final cardContents = card['contents'] as List? ?? [];
          for (final item in cardContents) {
            final r = item['musicResponsiveListItemRenderer'];
            if (r != null) {
              final parsed = _parseSearchItem(r);
              if (parsed != null) results.add(parsed);
            }
          }
          continue;
        }

        // Regular shelf
        final shelf = section['musicShelfRenderer'];
        if (shelf == null) continue;

        final contents = shelf['contents'] as List? ?? [];
        for (final item in contents) {
          final renderer = item['musicResponsiveListItemRenderer'];
          if (renderer == null) continue;
          final result = _parseSearchItem(renderer);
          if (result != null) results.add(result);
        }

        // Get continuation from shelf
        continuation ??= _getContinuation(shelf['continuations']);
      }
    } catch (_) {}
    return SearchResponse(results: results, continuation: continuation);
  }

  static SearchResponse parseSearchContinuation(Map<String, dynamic> data) {
    final results = <SearchResult>[];
    String? continuation;
    try {
      final contents = _nav(data,
              ['continuationContents', 'musicShelfContinuation', 'contents'])
          as List? ?? [];
      for (final item in contents) {
        final renderer = item['musicResponsiveListItemRenderer'];
        if (renderer == null) continue;
        final result = _parseSearchItem(renderer);
        if (result != null) results.add(result);
      }
      continuation = _getContinuation(_nav(data,
          ['continuationContents', 'musicShelfContinuation', 'continuations']));
    } catch (_) {}
    return SearchResponse(results: results, continuation: continuation);
  }

  static SearchResult? _parseCardShelfResult(Map<String, dynamic> card) {
    try {
      final title =
          _getRunsText(card['title']?['runs']) ?? '';
      if (title.isEmpty) return null;

      final subtitle = _getRunsText(card['subtitle']?['runs']) ?? '';
      final thumbnail = _getThumbnailUrl(card['thumbnail']);

      // Determine type from navigation
      final navEndpoint = card['title']?['runs']?[0]?['navigationEndpoint'];
      String? videoId;
      String? browseId;
      SearchResultType type = SearchResultType.song;

      if (navEndpoint != null) {
        videoId = navEndpoint['watchEndpoint']?['videoId'];
        browseId = navEndpoint['browseEndpoint']?['browseId'];
        final pageType = _getPageType(navEndpoint);
        type = _pageTypeToSearchType(pageType);
      }

      return SearchResult(
        id: videoId ?? browseId ?? '',
        title: title,
        artist: _extractArtistFromSubtitle(subtitle),
        subtitle: subtitle,
        thumbnailUrl: thumbnail ?? '',
        type: type,
        browseId: browseId,
      );
    } catch (_) {
      return null;
    }
  }

  static SearchResult? _parseSearchItem(Map<String, dynamic> renderer) {
    try {
      final flexColumns = renderer['flexColumns'] as List? ?? [];
      if (flexColumns.isEmpty) return null;

      final title = _getFlexColumnText(flexColumns, 0);
      if (title == null || title.isEmpty) return null;

      // Get subtitle runs (second flex column)
      final subtitleRuns = _getFlexColumnRuns(flexColumns, 1);
      final subtitle = subtitleRuns.map((r) => r['text'] ?? '').join('');

      // Split subtitle by " • " separator
      final segments = _splitRunsBySeparator(subtitleRuns);

      // Determine type and ID
      String? videoId;
      String? browseId;
      SearchResultType type = SearchResultType.song;

      // Check overlay for videoId (play button)
      final overlay = renderer['overlay']?['musicItemThumbnailOverlayRenderer']
          ?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint'];
      if (overlay != null) {
        videoId = overlay['watchEndpoint']?['videoId'];
      }

      // Check main navigation endpoint
      final mainNav = renderer['navigationEndpoint'];
      if (mainNav != null) {
        browseId = mainNav['browseEndpoint']?['browseId'];
        final pageType = _getPageType(mainNav);
        type = _pageTypeToSearchType(pageType);
      }

      // If no video ID from overlay, check flexColumn runs
      if (videoId == null && type == SearchResultType.song) {
        videoId = _getVideoIdFromRuns(flexColumns);
      }

      // Detect video vs song from subtitle
      if (type == SearchResultType.song && segments.isNotEmpty) {
        final typeLabel =
            segments[0].isNotEmpty ? segments[0][0]['text']?.toString() ?? '' : '';
        if (typeLabel == 'Video') type = SearchResultType.video;
      }

      final id = videoId ?? browseId ?? '';
      if (id.isEmpty) return null;

      final thumbnail = _getThumbnailFromRenderer(renderer);

      // Parse artist: first segment after type indicator (or first segment)
      String artistName = '';
      if (segments.isNotEmpty) {
        final artistSegment = segments[0];
        artistName = artistSegment
            .where((r) => (r['text'] ?? '') != ' \u2022 ')
            .map((r) => r['text'] ?? '')
            .join('');
      }

      // Parse duration from fixed columns or last subtitle segment
      int duration = 0;
      final fixedColumns = renderer['fixedColumns'] as List? ?? [];
      if (fixedColumns.isNotEmpty) {
        final durationText = _getFixedColumnText(fixedColumns, 0);
        duration = _parseDurationString(durationText);
      } else if (subtitle.isNotEmpty) {
        duration = _parseDuration(subtitle);
      }

      return SearchResult(
        id: id,
        title: title,
        artist: artistName,
        subtitle: subtitle,
        thumbnailUrl: thumbnail ?? '',
        durationSeconds: duration,
        type: type,
        browseId: browseId,
      );
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SEARCH SUGGESTIONS
  // ═══════════════════════════════════════════════════════════

  static List<String> parseSearchSuggestions(Map<String, dynamic> data) {
    final suggestions = <String>[];
    try {
      final contents = data['contents'] as List? ?? [];
      for (final section in contents) {
        final renderer =
            section['searchSuggestionsSectionRenderer']?['contents'] as List? ??
                [];
        for (final item in renderer) {
          final runs =
              item['searchSuggestionRenderer']?['suggestion']?['runs'] as List?;
          if (runs != null) {
            final s = runs.map((r) => r['text'] ?? '').join('');
            if (s.isNotEmpty) suggestions.add(s);
          }
        }
      }
    } catch (_) {}
    return suggestions;
  }

  // ═══════════════════════════════════════════════════════════
  // HOME PAGE
  // ═══════════════════════════════════════════════════════════

  static HomePageResponse parseHomePage(Map<String, dynamic> data) {
    final sections = <HomeSection>[];
    String? continuation;
    try {
      final sectionList = _nav(data, [
            'contents',
            'singleColumnBrowseResultsRenderer',
            'tabs',
            0,
            'tabRenderer',
            'content',
            'sectionListRenderer'
          ]) as Map? ??
          {};

      final contents = sectionList['contents'] as List? ?? [];
      continuation = _getContinuation(sectionList['continuations']);

      for (final section in contents) {
        final parsed = _parseHomeSection(section);
        if (parsed != null) sections.add(parsed);
      }
    } catch (_) {}
    return HomePageResponse(sections: sections, continuation: continuation);
  }

  static List<HomeSection> parseHomePageContinuation(Map<String, dynamic> data) {
    final sections = <HomeSection>[];
    try {
      final contents = _nav(data, [
            'continuationContents',
            'sectionListContinuation',
            'contents'
          ]) as List? ??
          [];
      for (final section in contents) {
        final parsed = _parseHomeSection(section);
        if (parsed != null) sections.add(parsed);
      }
    } catch (_) {}
    return sections;
  }

  static HomeSection? _parseHomeSection(Map<String, dynamic> section) {
    try {
      final shelf = section['musicCarouselShelfRenderer'];
      if (shelf == null) return null;

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
        // musicTwoRowItemRenderer (grid items: songs, albums, playlists)
        final twoRow = item['musicTwoRowItemRenderer'];
        if (twoRow != null) {
          final track = _parseTwoRowItem(twoRow);
          if (track != null) tracks.add(track);
          continue;
        }

        // musicResponsiveListItemRenderer (list items: Quick Picks)
        final responsive = item['musicResponsiveListItemRenderer'];
        if (responsive != null) {
          final track = _parseResponsiveListItem(responsive);
          if (track != null) tracks.add(track);
        }
      }

      if (tracks.isNotEmpty && headerTitle.isNotEmpty) {
        return HomeSection(title: headerTitle, tracks: tracks);
      }
    } catch (_) {}
    return null;
  }

  /// Parse a musicTwoRowItemRenderer (grid-style item).
  static Track? _parseTwoRowItem(Map<String, dynamic> renderer) {
    try {
      final title =
          renderer['title']?['runs']?[0]?['text'] as String? ?? '';
      if (title.isEmpty) return null;

      final subtitle = _getRunsText(renderer['subtitle']?['runs']) ?? '';

      // Get video ID or browse ID from navigation
      String? videoId;
      String? browseId;
      final navEndpoint = renderer['navigationEndpoint'];
      if (navEndpoint != null) {
        videoId = navEndpoint['watchEndpoint']?['videoId'];
        browseId = navEndpoint['browseEndpoint']?['browseId'];
      }

      // Also check overlay for play button
      if (videoId == null) {
        videoId = renderer['overlay']?['musicItemThumbnailOverlayRenderer']
            ?['content']?['musicPlayButtonRenderer']
            ?['playNavigationEndpoint']?['watchEndpoint']?['videoId'];
      }

      final id = videoId ?? browseId ?? '';
      if (id.isEmpty) return null;

      final thumbnail = _getThumbnailFromRenderer(renderer);
      final artist = _extractArtistFromSubtitle(subtitle);
      final isPlayable = videoId != null;

      return Track(
        id: id,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnail ?? '',
        durationSeconds: 0,
        browseId: browseId,
        isPlayable: isPlayable,
      );
    } catch (_) {
      return null;
    }
  }

  /// Parse a musicResponsiveListItemRenderer (list-style item).
  static Track? _parseResponsiveListItem(Map<String, dynamic> renderer) {
    try {
      final flexColumns = renderer['flexColumns'] as List? ?? [];
      if (flexColumns.isEmpty) return null;

      final title = _getFlexColumnText(flexColumns, 0);
      if (title == null || title.isEmpty) return null;

      final subtitle = _getFlexColumnText(flexColumns, 1) ?? '';

      // Video ID
      String? videoId;
      final overlay = renderer['overlay']?['musicItemThumbnailOverlayRenderer']
          ?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint'];
      if (overlay != null) {
        videoId = overlay['watchEndpoint']?['videoId'];
      }
      videoId ??= renderer['playlistItemData']?['videoId'];
      videoId ??= _getVideoIdFromRuns(flexColumns);

      // Browse ID
      String? browseId;
      final mainNav = renderer['navigationEndpoint'];
      if (mainNav != null) {
        browseId = mainNav['browseEndpoint']?['browseId'];
      }

      final id = videoId ?? browseId ?? '';
      if (id.isEmpty) return null;

      final thumbnail = _getThumbnailFromRenderer(renderer) ??
          _getThumbnail(renderer);

      // Parse artist and duration from subtitle
      final parts = subtitle.split(' \u2022 ');
      final artist = parts.isNotEmpty ? parts[0].trim() : '';

      int duration = 0;
      final fixedColumns = renderer['fixedColumns'] as List? ?? [];
      if (fixedColumns.isNotEmpty) {
        duration = _parseDurationString(_getFixedColumnText(fixedColumns, 0));
      } else {
        duration = _parseDuration(subtitle);
      }

      return Track(
        id: id,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnail ?? '',
        durationSeconds: duration,
        browseId: browseId,
        isPlayable: videoId != null,
      );
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ARTIST PAGE
  // ═══════════════════════════════════════════════════════════

  static ArtistPage parseArtistPage(
      Map<String, dynamic> data, String browseId) {
    try {
      // Parse header — multiple possible renderer types
      final header = data['header']?['musicImmersiveHeaderRenderer'] ??
          data['header']?['musicVisualHeaderRenderer'] ??
          data['header']?['musicHeaderRenderer'] ??
          {};

      final name =
          header['title']?['runs']?[0]?['text'] as String? ?? 'Unknown Artist';
      final thumbList = header['thumbnail']?['musicThumbnailRenderer']
              ?['thumbnail']?['thumbnails'] as List? ??
          [];
      final thumbnail =
          thumbList.isNotEmpty ? thumbList.last['url'] as String? ?? '' : '';

      final subscriberCount = header['subscriptionButton']
              ?['subscribeButtonRenderer']?['subscriberCountText']?['runs']
          ?[0]?['text'] as String?;

      // Parse sections
      final sections = <ArtistSection>[];
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
        final parsed = _parseArtistSection(section);
        if (parsed != null) sections.add(parsed);
      }

      return ArtistPage(
        artist: Artist(
          id: browseId,
          name: name,
          thumbnailUrl: thumbnail,
          subscriberCount: subscriberCount,
        ),
        sections: sections,
      );
    } catch (_) {
      return ArtistPage(
          artist: Artist(id: browseId, name: 'Unknown Artist'));
    }
  }

  static ArtistSection? _parseArtistSection(Map<String, dynamic> section) {
    try {
      // musicShelfRenderer: song list
      final shelf = section['musicShelfRenderer'];
      if (shelf != null) {
        final title = _nav(shelf, ['title', 'runs', 0, 'text']) as String? ?? '';
        final browseId = _nav(shelf, [
          'bottomEndpoint',
          'browseEndpoint',
          'browseId'
        ]) as String?;
        final contents = shelf['contents'] as List? ?? [];
        final items = <Track>[];
        for (final item in contents) {
          final renderer = item['musicResponsiveListItemRenderer'];
          if (renderer == null) continue;
          final track = _parseResponsiveListItem(renderer);
          if (track != null) items.add(track);
        }
        if (items.isEmpty) return null;
        return ArtistSection(title: title, browseId: browseId, items: items);
      }

      // musicCarouselShelfRenderer: albums, singles, playlists, related artists
      final carousel = section['musicCarouselShelfRenderer'];
      if (carousel != null) {
        final title = _nav(carousel, [
              'header',
              'musicCarouselShelfBasicHeaderRenderer',
              'title',
              'runs',
              0,
              'text'
            ]) as String? ??
            '';
        final browseId = _nav(carousel, [
          'header',
          'musicCarouselShelfBasicHeaderRenderer',
          'title',
          'runs',
          0,
          'navigationEndpoint',
          'browseEndpoint',
          'browseId'
        ]) as String?;

        final contents = carousel['contents'] as List? ?? [];
        final items = <dynamic>[];

        for (final item in contents) {
          final twoRow = item['musicTwoRowItemRenderer'];
          if (twoRow != null) {
            // Determine if it's an album, artist, or playlist
            final navEndpoint = twoRow['navigationEndpoint'];
            final pageType = _getPageType(navEndpoint);

            if (pageType == 'MUSIC_PAGE_TYPE_ARTIST' || pageType == 'MUSIC_PAGE_TYPE_USER_CHANNEL') {
              final artistName =
                  twoRow['title']?['runs']?[0]?['text'] as String? ?? '';
              final artistId =
                  navEndpoint?['browseEndpoint']?['browseId'] as String? ?? '';
              final thumb = _getThumbnailFromRenderer(twoRow);
              items.add(Artist(
                  id: artistId, name: artistName, thumbnailUrl: thumb));
            } else if (pageType == 'MUSIC_PAGE_TYPE_ALBUM') {
              final albumTitle =
                  twoRow['title']?['runs']?[0]?['text'] as String? ?? '';
              final albumBrowseId =
                  navEndpoint?['browseEndpoint']?['browseId'] as String? ?? '';
              final subtitle = _getRunsText(twoRow['subtitle']?['runs']) ?? '';
              final thumb = _getThumbnailFromRenderer(twoRow);
              final playlistId = twoRow['overlay']
                  ?['musicItemThumbnailOverlayRenderer']?['content']
                  ?['musicPlayButtonRenderer']?['playNavigationEndpoint']
                  ?['watchEndpoint']?['playlistId'];
              items.add(Album(
                id: albumBrowseId,
                title: albumTitle,
                artist: subtitle,
                thumbnailUrl: thumb,
                playlistId: playlistId,
              ));
            } else {
              // Treat as playable track or playlist
              final track = _parseTwoRowItem(twoRow);
              if (track != null) items.add(track);
            }
            continue;
          }

          final responsive = item['musicResponsiveListItemRenderer'];
          if (responsive != null) {
            final track = _parseResponsiveListItem(responsive);
            if (track != null) items.add(track);
          }
        }

        if (items.isEmpty) return null;
        return ArtistSection(title: title, browseId: browseId, items: items);
      }
    } catch (_) {}
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // ALBUM PAGE
  // ═══════════════════════════════════════════════════════════

  static Album parseAlbumPage(Map<String, dynamic> data, String browseId) {
    try {
      // Try new responsive header first, then detail header
      final respHeader = _nav(data, [
            'contents',
            'twoColumnBrowseResultsRenderer',
            'tabs',
            0,
            'tabRenderer',
            'content',
            'sectionListRenderer',
            'contents',
            0,
            'musicResponsiveHeaderRenderer'
          ]) ??
          data['header']?['musicDetailHeaderRenderer'] ??
          data['header']?['musicImmersiveHeaderRenderer'] ??
          {};

      final title =
          respHeader['title']?['runs']?[0]?['text'] as String? ?? 'Album';

      // Artist from strapline or subtitle
      final artistRuns =
          respHeader['straplineTextOne']?['runs'] as List? ??
              respHeader['subtitle']?['runs'] as List? ??
              [];
      final artist = artistRuns.map((r) => r['text'] ?? '').join('');

      // Year from subtitle
      final subtitleRuns = respHeader['subtitle']?['runs'] as List? ?? [];
      final year = _extractYear(subtitleRuns);

      // Thumbnail
      final thumbList = respHeader['thumbnail']
                  ?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']
              as List? ??
          respHeader['thumbnail']?['croppedSquareThumbnailRenderer']
              ?['thumbnail']?['thumbnails'] as List? ??
          [];
      final thumbnail =
          thumbList.isNotEmpty ? thumbList.last['url'] as String? ?? '' : '';

      // Try to get playlistId from microformat
      String? playlistId = data['microformat']?['microformatDataRenderer']
          ?['urlCanonical']
          ?.toString()
          .split('=')
          .last;

      // Parse tracks — try two-column first, then single-column
      List tracks = _nav(data, [
            'contents',
            'twoColumnBrowseResultsRenderer',
            'secondaryContents',
            'sectionListRenderer',
            'contents',
            0,
            'musicShelfRenderer',
            'contents'
          ]) as List? ??
          _nav(data, [
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

      final parsedTracks = <Track>[];
      int trackNum = 1;
      for (final item in tracks) {
        final renderer = item['musicResponsiveListItemRenderer'];
        if (renderer == null) continue;

        final flexColumns = renderer['flexColumns'] as List? ?? [];
        final trackTitle = _getFlexColumnText(flexColumns, 0);
        if (trackTitle == null || trackTitle.isEmpty) continue;

        // Track artist (from flex column or fallback to album artist)
        String trackArtist = '';
        final trackArtistRuns = _getFlexColumnRuns(flexColumns, 1);
        if (trackArtistRuns.isNotEmpty) {
          trackArtist = trackArtistRuns.map((r) => r['text'] ?? '').join('');
        }
        if (trackArtist.isEmpty) trackArtist = artist;

        // Video ID
        String? videoId;
        final overlay = renderer['overlay']
            ?['musicItemThumbnailOverlayRenderer']?['content']
            ?['musicPlayButtonRenderer']?['playNavigationEndpoint'];
        if (overlay != null) {
          videoId = overlay['watchEndpoint']?['videoId'];
        }
        videoId ??= renderer['playlistItemData']?['videoId'];

        if (videoId == null) continue;

        // Duration from fixed columns
        int duration = 0;
        final fixedColumns = renderer['fixedColumns'] as List? ?? [];
        if (fixedColumns.isNotEmpty) {
          duration = _parseDurationString(_getFixedColumnText(fixedColumns, 0));
        }

        // Check explicit badge
        final isExplicit = _hasExplicitBadge(renderer);

        parsedTracks.add(Track(
          id: videoId,
          title: trackTitle,
          artist: trackArtist,
          album: title,
          thumbnailUrl: thumbnail,
          durationSeconds: duration,
          trackNumber: trackNum,
          isExplicit: isExplicit,
        ));
        trackNum++;
      }

      return Album(
        id: browseId,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnail,
        tracks: parsedTracks,
        year: year,
        playlistId: playlistId,
      );
    } catch (_) {
      return Album(id: browseId, title: 'Album', tracks: []);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PLAYLIST PAGE
  // ═══════════════════════════════════════════════════════════

  static Playlist parsePlaylistPage(
      Map<String, dynamic> data, String playlistId) {
    try {
      // Header — try responsive header, editable header, then detail header
      final respHeader = _nav(data, [
            'contents',
            'twoColumnBrowseResultsRenderer',
            'tabs',
            0,
            'tabRenderer',
            'content',
            'sectionListRenderer',
            'contents',
            0,
            'musicResponsiveHeaderRenderer'
          ]) ??
          data['header']?['musicEditablePlaylistDetailHeaderRenderer']
              ?['header']?['musicDetailHeaderRenderer'] ??
          data['header']?['musicDetailHeaderRenderer'] ??
          {};

      final title =
          respHeader['title']?['runs']?[0]?['text'] as String? ?? 'Playlist';

      // Author from strapline or subtitle
      final straplineRuns =
          respHeader['straplineTextOne']?['runs'] as List? ?? [];
      final author = straplineRuns.isNotEmpty
          ? straplineRuns.map((r) => r['text'] ?? '').join('')
          : null;

      // Thumbnail
      final thumbList = respHeader['thumbnail']
                  ?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']
              as List? ??
          respHeader['thumbnail']?['croppedSquareThumbnailRenderer']
              ?['thumbnail']?['thumbnails'] as List? ??
          [];
      final thumbnail =
          thumbList.isNotEmpty ? thumbList.last['url'] as String? ?? '' : '';

      // Description
      final description = respHeader['description']
              ?['musicDescriptionShelfRenderer']?['description']?['runs']
          ?.map((r) => r['text'] ?? '')
          ?.join('') as String?;

      // Track count from subtitle
      final subtitleRuns = respHeader['subtitle']?['runs'] as List? ?? [];
      final subtitleText = subtitleRuns.map((r) => r['text'] ?? '').join('');

      // Parse tracks — try two-column, then single-column
      final trackContents = _nav(data, [
            'contents',
            'twoColumnBrowseResultsRenderer',
            'secondaryContents',
            'sectionListRenderer',
            'contents',
            0,
            'musicPlaylistShelfRenderer',
            'contents'
          ]) as List? ??
          _nav(data, [
            'contents',
            'singleColumnBrowseResultsRenderer',
            'tabs',
            0,
            'tabRenderer',
            'content',
            'sectionListRenderer',
            'contents',
            0,
            'musicPlaylistShelfRenderer',
            'contents'
          ]) as List? ??
          _nav(data, [
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
      String? continuation;

      for (final item in trackContents) {
        final renderer = item['musicResponsiveListItemRenderer'];
        if (renderer == null) continue;

        final track = _parsePlaylistTrack(renderer, thumbnail);
        if (track != null) tracks.add(track);
      }

      // Get continuation token
      continuation = _getContinuation(
        _nav(data, [
          'contents',
          'twoColumnBrowseResultsRenderer',
          'secondaryContents',
          'sectionListRenderer',
          'contents',
          0,
          'musicPlaylistShelfRenderer',
          'continuations'
        ]) ??
        _nav(data, [
          'contents',
          'singleColumnBrowseResultsRenderer',
          'tabs',
          0,
          'tabRenderer',
          'content',
          'sectionListRenderer',
          'contents',
          0,
          'musicPlaylistShelfRenderer',
          'continuations'
        ]),
      );

      return Playlist(
        id: playlistId,
        title: title,
        uploaderName: author,
        thumbnailUrl: thumbnail,
        tracks: tracks,
        trackCount: tracks.length,
        continuation: continuation,
        description: description,
      );
    } catch (_) {
      return Playlist(id: playlistId, title: 'Playlist', tracks: []);
    }
  }

  static PlaylistContinuation parsePlaylistContinuation(
      Map<String, dynamic> data) {
    final tracks = <Track>[];
    String? continuation;
    try {
      // Three possible shapes for continuation responses
      final shelfContents = _nav(data, [
            'continuationContents',
            'musicPlaylistShelfContinuation',
            'contents'
          ]) as List? ??
          [];
      final appendedContents = (data['onResponseReceivedActions'] as List?)
              ?.firstOrNull
              ?['appendContinuationItemsAction']?['continuationItems']
          as List? ??
          [];

      final allContents = [...shelfContents, ...appendedContents];

      for (final item in allContents) {
        final renderer = item['musicResponsiveListItemRenderer'];
        if (renderer == null) continue;
        final track = _parsePlaylistTrack(renderer, null);
        if (track != null) tracks.add(track);
      }

      continuation = _getContinuation(
        _nav(data, [
              'continuationContents',
              'musicPlaylistShelfContinuation',
              'continuations'
            ]) ??
            _getContinuationFromItems(appendedContents),
      );
    } catch (_) {}
    return PlaylistContinuation(tracks: tracks, continuation: continuation);
  }

  static Track? _parsePlaylistTrack(
      Map<String, dynamic> renderer, String? fallbackThumbnail) {
    try {
      final flexColumns = renderer['flexColumns'] as List? ?? [];
      if (flexColumns.isEmpty) return null;

      final title = _getFlexColumnText(flexColumns, 0);
      if (title == null || title.isEmpty) return null;

      final subtitle = _getFlexColumnText(flexColumns, 1) ?? '';
      final parts = subtitle.split(' \u2022 ');
      final artist = parts.isNotEmpty ? parts[0].trim() : '';
      final albumName = parts.length > 1 ? parts[1].trim() : null;

      // Video ID
      String? videoId;
      final overlay = renderer['overlay']
          ?['musicItemThumbnailOverlayRenderer']?['content']
          ?['musicPlayButtonRenderer']?['playNavigationEndpoint'];
      if (overlay != null) {
        videoId = overlay['watchEndpoint']?['videoId'];
      }
      videoId ??= renderer['playlistItemData']?['videoId'];

      if (videoId == null) return null;

      // SetVideoId (needed for playlist editing)
      final setVideoId =
          renderer['playlistItemData']?['playlistSetVideoId'] as String?;

      final thumbnail =
          _getThumbnailFromRenderer(renderer) ??
          _getThumbnail(renderer) ??
          fallbackThumbnail;

      // Duration
      int duration = 0;
      final fixedColumns = renderer['fixedColumns'] as List? ?? [];
      if (fixedColumns.isNotEmpty) {
        duration = _parseDurationString(_getFixedColumnText(fixedColumns, 0));
      } else {
        duration = _parseDuration(subtitle);
      }

      final isExplicit = _hasExplicitBadge(renderer);

      return Track(
        id: videoId,
        title: title,
        artist: artist,
        album: albumName,
        thumbnailUrl: thumbnail ?? '',
        durationSeconds: duration,
        setVideoId: setVideoId,
        isExplicit: isExplicit,
      );
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // CHARTS / TRENDING
  // ═══════════════════════════════════════════════════════════

  static List<HomeSection> parseCharts(Map<String, dynamic> data) {
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
        final parsed = _parseHomeSection(section);
        if (parsed != null) sections.add(parsed);
      }
    } catch (_) {}
    return sections;
  }

  // ═══════════════════════════════════════════════════════════
  // MOODS & GENRES
  // ═══════════════════════════════════════════════════════════

  static List<MoodCategory> parseMoodsAndGenres(Map<String, dynamic> data) {
    final categories = <MoodCategory>[];
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
        final grid = section['gridRenderer'];
        if (grid == null) continue;

        final title = _nav(grid, ['header', 'gridHeaderRenderer', 'title', 'runs', 0, 'text'])
            as String? ?? '';

        final items = <MoodItem>[];
        for (final item in (grid['items'] as List? ?? [])) {
          final chip = item['musicNavigationButtonRenderer'];
          if (chip == null) continue;

          final chipTitle =
              chip['buttonText']?['runs']?[0]?['text'] as String? ?? '';
          final params = chip['clickCommand']?['browseEndpoint']?['params']
              as String? ?? '';
          if (chipTitle.isNotEmpty && params.isNotEmpty) {
            items.add(MoodItem(title: chipTitle, params: params));
          }
        }

        if (items.isNotEmpty) {
          categories.add(MoodCategory(title: title, items: items));
        }
      }
    } catch (_) {}
    return categories;
  }

  static List<HomeSection> parseMoodPlaylists(Map<String, dynamic> data) {
    return parseCharts(data); // Same structure
  }

  static List<HomeSection> parseNewReleases(Map<String, dynamic> data) {
    return parseCharts(data); // Same structure
  }

  // ═══════════════════════════════════════════════════════════
  // PLAYER (Stream URLs)
  // ═══════════════════════════════════════════════════════════

  static StreamInfo? parseBestAudioStream(Map<String, dynamic> data,
      {String quality = 'best'}) {
    try {
      final formats =
          data['streamingData']?['adaptiveFormats'] as List? ?? [];
      final audioFormats = formats
          .where(
              (f) => (f['mimeType'] as String? ?? '').startsWith('audio/'))
          .toList();

      if (audioFormats.isEmpty) return null;

      // Sort by bitrate descending
      audioFormats.sort((a, b) =>
          ((b['bitrate'] as int?) ?? 0)
              .compareTo((a['bitrate'] as int?) ?? 0));

      Map<String, dynamic> chosen;
      if (quality == 'low') {
        chosen = audioFormats.last;
      } else if (quality == 'medium') {
        chosen = audioFormats[audioFormats.length ~/ 2];
      } else {
        chosen = audioFormats.first;
      }

      final url = chosen['url'] as String?;
      if (url == null) return null;

      return StreamInfo(
        url: url,
        mimeType: chosen['mimeType'] as String? ?? 'audio/mp4',
        bitrate: chosen['bitrate'] as int? ?? 0,
        source: 'innertube',
      );
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // NEXT (Queue, Lyrics, Related)
  // ═══════════════════════════════════════════════════════════

  static NextResponse parseNextResponse(Map<String, dynamic> data) {
    final tracks = <Track>[];
    String? lyricsId;
    String? relatedId;
    String? continuation;

    try {
      final tabs = _nav(data, [
            'contents',
            'singleColumnMusicWatchNextResultsRenderer',
            'tabbedRenderer',
            'watchNextTabbedResultsRenderer',
            'tabs'
          ]) as List? ??
          [];

      for (int i = 0; i < tabs.length; i++) {
        final tab = tabs[i];

        if (i == 0) {
          // Queue tab
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
            final track = _parseQueueItem(renderer);
            if (track != null) tracks.add(track);
          }

          // Queue continuation
          continuation = _nav(tab, [
                'tabRenderer',
                'content',
                'musicQueueRenderer',
                'content',
                'playlistPanelRenderer',
                'continuations',
                0,
                'nextContinuationData',
                'continuation'
              ]) as String?;
        } else if (i == 1) {
          // Lyrics tab
          lyricsId = _nav(tab, [
            'tabRenderer',
            'endpoint',
            'browseEndpoint',
            'browseId'
          ]) as String?;
        } else if (i == 2) {
          // Related tab
          relatedId = _nav(tab, [
            'tabRenderer',
            'endpoint',
            'browseEndpoint',
            'browseId'
          ]) as String?;
        }
      }
    } catch (_) {}

    return NextResponse(
      queue: tracks,
      lyricsId: lyricsId,
      relatedId: relatedId,
      continuation: continuation,
    );
  }

  static Track? _parseQueueItem(Map<String, dynamic> renderer) {
    try {
      final title =
          renderer['title']?['runs']?[0]?['text'] as String? ?? '';
      final videoId =
          renderer['navigationEndpoint']?['watchEndpoint']?['videoId'];
      if (videoId == null || title.isEmpty) return null;

      final artistRuns = renderer['longBylineText']?['runs'] as List? ??
          renderer['shortBylineText']?['runs'] as List? ??
          [];
      final artist = artistRuns.map((r) => r['text'] ?? '').join('');

      final thumbList =
          renderer['thumbnail']?['thumbnails'] as List? ?? [];
      final thumbnail = thumbList.isNotEmpty
          ? thumbList.last['url'] as String? ?? ''
          : '';

      final lengthText = renderer['lengthText']?['runs']?[0]?['text'];
      final duration = _parseDurationString(lengthText);

      return Track(
        id: videoId,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnail,
        durationSeconds: duration,
      );
    } catch (_) {
      return null;
    }
  }

  static List<Track> parseQueueItems(Map<String, dynamic> data) {
    final tracks = <Track>[];
    try {
      final items = _nav(data, [
            'queueDatas'
          ]) as List? ??
          [];
      for (final item in items) {
        final renderer = item['content']?['playlistPanelVideoRenderer'];
        if (renderer == null) continue;
        final track = _parseQueueItem(renderer);
        if (track != null) tracks.add(track);
      }
    } catch (_) {}
    return tracks;
  }

  // ═══════════════════════════════════════════════════════════
  // LIBRARY
  // ═══════════════════════════════════════════════════════════

  static Map<String, dynamic>? parseAccountInfo(Map<String, dynamic> data) {
    try {
      final header = data['actions']?[0]?['openPopupAction']?['popup']
          ?['multiPageMenuRenderer']?['header']
          ?['activeAccountHeaderRenderer'];
      if (header == null) return null;

      return {
        'name': header['accountName']?['runs']?[0]?['text'],
        'email': header['email']?['runs']?[0]?['text'],
        'channelHandle': header['channelHandle']?['runs']?[0]?['text'],
        'thumbnailUrl': (header['accountPhoto']?['thumbnails'] as List?)
            ?.lastOrNull?['url'],
      };
    } catch (_) {
      return null;
    }
  }

  static List<Playlist> parseLibraryPlaylists(Map<String, dynamic> data) {
    final playlists = <Playlist>[];
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
        final grid = section['gridRenderer']?['items'] as List? ?? [];
        for (final item in grid) {
          final renderer = item['musicTwoRowItemRenderer'];
          if (renderer == null) continue;

          final title =
              renderer['title']?['runs']?[0]?['text'] as String? ?? '';
          final playlistId = renderer['navigationEndpoint']
              ?['browseEndpoint']?['browseId'] as String?;
          if (playlistId == null) continue;

          final subtitle = _getRunsText(renderer['subtitle']?['runs']) ?? '';
          final thumb = _getThumbnailFromRenderer(renderer);

          playlists.add(Playlist(
            id: playlistId.replaceFirst('VL', ''),
            title: title,
            uploaderName: subtitle,
            thumbnailUrl: thumb,
          ));
        }
      }
    } catch (_) {}
    return playlists;
  }

  static List<Track> parseHistoryPage(Map<String, dynamic> data) {
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
        final shelf = section['musicShelfRenderer'];
        if (shelf == null) continue;
        for (final item in (shelf['contents'] as List? ?? [])) {
          final renderer = item['musicResponsiveListItemRenderer'];
          if (renderer == null) continue;
          final track = _parseResponsiveListItem(renderer);
          if (track != null) tracks.add(track);
        }
      }
    } catch (_) {}
    return tracks;
  }

  // ═══════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════

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

  /// Extract text from a flexColumns entry.
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

  /// Extract raw runs from a flex column.
  static List<Map<String, dynamic>> _getFlexColumnRuns(
      List flexColumns, int index) {
    if (index >= flexColumns.length) return [];
    try {
      final runs = flexColumns[index]
          ['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
      if (runs == null) return [];
      return (runs as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Extract text from fixed columns.
  static String? _getFixedColumnText(List fixedColumns, int index) {
    if (index >= fixedColumns.length) return null;
    try {
      final runs = fixedColumns[index]
          ['musicResponsiveListItemFixedColumnRenderer']?['text']?['runs'];
      if (runs == null) return null;
      return (runs as List).map((r) => r['text'] ?? '').join('');
    } catch (_) {
      return null;
    }
  }

  /// Split runs by separator (" • ").
  static List<List<Map<String, dynamic>>> _splitRunsBySeparator(
      List<Map<String, dynamic>> runs) {
    final segments = <List<Map<String, dynamic>>>[];
    var current = <Map<String, dynamic>>[];
    for (final run in runs) {
      final text = run['text'] as String? ?? '';
      if (text == ' \u2022 ' || text == ' · ') {
        if (current.isNotEmpty) segments.add(current);
        current = <Map<String, dynamic>>[];
      } else {
        current.add(run);
      }
    }
    if (current.isNotEmpty) segments.add(current);
    return segments;
  }

  /// Get continuation token from continuations array.
  static String? _getContinuation(dynamic continuations) {
    if (continuations == null) return null;
    try {
      if (continuations is List && continuations.isNotEmpty) {
        return continuations[0]['nextContinuationData']?['continuation']
            as String? ??
            continuations[0]['nextRadioContinuationData']?['continuation']
            as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Get continuation from inline items (appendContinuationItemsAction pattern).
  static dynamic _getContinuationFromItems(List items) {
    for (final item in items) {
      final cont = item['continuationItemRenderer']?['continuationEndpoint']
          ?['continuationCommand']?['token'];
      if (cont != null) return [{'nextContinuationData': {'continuation': cont}}];
    }
    return null;
  }

  /// Extract video ID from flex column runs.
  static String? _getVideoIdFromRuns(List flexColumns) {
    try {
      for (final col in flexColumns) {
        final runs = col['musicResponsiveListItemFlexColumnRenderer']
            ?['text']?['runs'] as List?;
        if (runs == null) continue;
        for (final run in runs) {
          final videoId =
              run['navigationEndpoint']?['watchEndpoint']?['videoId'];
          if (videoId != null) return videoId;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Get page type from a navigation endpoint.
  static String? _getPageType(Map<String, dynamic>? endpoint) {
    if (endpoint == null) return null;
    return endpoint['browseEndpoint']
            ?['browseEndpointContextSupportedConfigs']
        ?['browseEndpointContextMusicConfig']?['pageType'] as String?;
  }

  /// Convert page type to search result type.
  static SearchResultType _pageTypeToSearchType(String? pageType) {
    switch (pageType) {
      case 'MUSIC_PAGE_TYPE_ARTIST':
      case 'MUSIC_PAGE_TYPE_USER_CHANNEL':
        return SearchResultType.artist;
      case 'MUSIC_PAGE_TYPE_ALBUM':
        return SearchResultType.album;
      case 'MUSIC_PAGE_TYPE_PLAYLIST':
        return SearchResultType.playlist;
      default:
        return SearchResultType.song;
    }
  }

  /// Extract thumbnail URL from music thumbnail renderer.
  static String? _getThumbnail(Map<String, dynamic> renderer) {
    try {
      final thumbList = renderer['thumbnail']
          ?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List?;
      if (thumbList != null && thumbList.isNotEmpty) {
        return thumbList.last['url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  static String? _getThumbnailFromRenderer(Map<String, dynamic> renderer) {
    try {
      final thumbList = renderer['thumbnailRenderer']
          ?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List?;
      if (thumbList != null && thumbList.isNotEmpty) {
        return thumbList.last['url'] as String?;
      }
      return _getThumbnail(renderer);
    } catch (_) {
      return _getThumbnail(renderer);
    }
  }

  /// Get thumbnail URL from a generic thumbnail object.
  static String? _getThumbnailUrl(Map<String, dynamic>? thumbObj) {
    if (thumbObj == null) return null;
    try {
      final thumbList = thumbObj['musicThumbnailRenderer']?['thumbnail']
          ?['thumbnails'] as List?;
      if (thumbList != null && thumbList.isNotEmpty) {
        return thumbList.last['url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Join runs text.
  static String? _getRunsText(List? runs) {
    if (runs == null || runs.isEmpty) return null;
    return runs.map((r) => r['text'] ?? '').join('');
  }

  /// Extract artist name from a subtitle string ("Artist • Album • Duration").
  static String _extractArtistFromSubtitle(String subtitle) {
    final parts = subtitle.split(' \u2022 ');
    return parts.isNotEmpty ? parts[0].trim() : '';
  }

  /// Extract year from subtitle runs.
  static String? _extractYear(List runs) {
    for (final run in runs) {
      final text = run['text']?.toString() ?? '';
      final match = RegExp(r'\b(19|20)\d{2}\b').firstMatch(text);
      if (match != null) return match.group(0);
    }
    return null;
  }

  /// Check for explicit badge.
  static bool _hasExplicitBadge(Map<String, dynamic> renderer) {
    try {
      final badges = renderer['badges'] as List? ?? [];
      for (final badge in badges) {
        final iconType = badge['musicInlineBadgeRenderer']?['icon']?['iconType']
            as String? ?? '';
        if (iconType == 'MUSIC_EXPLICIT_BADGE') return true;
      }
      // Also check subtitleBadges
      final subBadges = renderer['subtitleBadges'] as List? ?? [];
      for (final badge in subBadges) {
        final iconType =
            badge['musicInlineBadgeRenderer']?['icon']?['iconType']
                as String? ?? '';
        if (iconType == 'MUSIC_EXPLICIT_BADGE') return true;
      }
    } catch (_) {}
    return false;
  }

  /// Parse duration from a string containing a time pattern.
  static int _parseDuration(String? text) {
    if (text == null) return 0;
    final match = RegExp(r'(\d+):(\d{2})(?::(\d{2}))?').firstMatch(text);
    if (match == null) return 0;
    return _parseDurationString(match.group(0));
  }

  /// Parse "3:45" or "1:03:45" to seconds.
  static int _parseDurationString(String? text) {
    if (text == null) return 0;
    final parts = text.split(':').map((p) => int.tryParse(p) ?? 0).toList();
    if (parts.length == 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
    if (parts.length == 2) return parts[0] * 60 + parts[1];
    return 0;
  }
}
