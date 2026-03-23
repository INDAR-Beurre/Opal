import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../domain/models/search_result.dart';
import '../../../domain/models/track.dart';
import '../../../data/innertube/innertube_service.dart' show SearchResponse;
import '../../../player/playback_controller.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../widgets/track_tile.dart';
import '../../widgets/error_view.dart';
import '../../widgets/shimmer_loading.dart';
import '../../theme/app_theme.dart';

/// Full-featured search screen with debounced autocomplete, filter chips,
/// recent searches persistence, and type-aware result rendering.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  static const _recentSearchesKey = 'recent_searches';
  static const _maxRecentSearches = 10;
  static const _debounceDuration = Duration(milliseconds: 300);

  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;

  // ── State ──
  List<String> _suggestions = [];
  List<SearchResult> _results = [];
  String? _continuation;
  List<String> _recentSearches = [];
  bool _isLoading = false;
  String? _error;
  String _selectedFilter = 'All';

  static const _filters = ['All', 'Songs', 'Artists', 'Albums', 'Playlists'];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _searchController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onControllerChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Recent searches persistence ──

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_recentSearchesKey);
      if (mounted && stored != null) {
        setState(() => _recentSearches = stored);
      }
    } catch (_) {
      // Silently fail — recent searches are non-critical.
    }
  }

  Future<void> _addRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _recentSearches.remove(trimmed);
      _recentSearches.insert(0, trimmed);
      if (_recentSearches.length > _maxRecentSearches) {
        _recentSearches = _recentSearches.sublist(0, _maxRecentSearches);
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchesKey, _recentSearches);
    } catch (_) {}
  }

  Future<void> _removeRecentSearch(String query) async {
    setState(() => _recentSearches.remove(query));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchesKey, _recentSearches);
    } catch (_) {}
  }

  Future<void> _clearRecentSearches() async {
    setState(() => _recentSearches.clear());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (_) {}
  }

  // ── Search logic ──

  /// Called on every text change to trigger rebuild (for clear button visibility).
  void _onControllerChanged() {
    setState(() {});
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _results = [];
        _continuation = null;
        _error = null;
      });
      return;
    }

    _debounceTimer = Timer(_debounceDuration, () {
      _fetchSuggestions(query.trim());
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) return;
    try {
      final repo = context.read<MusicRepository>();
      final suggestions = await repo.searchSuggestions(query);
      if (mounted && _searchController.text.trim().isNotEmpty) {
        setState(() => _suggestions = suggestions);
      }
    } catch (_) {
      // Suggestions are best-effort; don't surface errors.
    }
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _focusNode.unfocus();
    _debounceTimer?.cancel();

    setState(() {
      _isLoading = true;
      _suggestions = [];
      _results = [];
      _continuation = null;
      _error = null;
    });

    await _addRecentSearch(trimmed);

    try {
      final repo = context.read<MusicRepository>();
      final filterParam = _selectedFilter == 'All'
          ? null
          : _selectedFilter.toLowerCase();
      final SearchResponse response =
          await repo.search(trimmed, filter: filterParam);

      if (mounted) {
        setState(() {
          _results = response.results;
          _continuation = response.continuation;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onSuggestionTap(String suggestion) {
    _searchController.text = suggestion;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    _performSearch(suggestion);
  }

  void _onFilterSelected(String filter) {
    if (filter == _selectedFilter) return;
    setState(() => _selectedFilter = filter);
    if (_searchController.text.trim().isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  void _onResultTap(SearchResult result) {
    switch (result.type) {
      case SearchResultType.song:
      case SearchResultType.video:
        final track = Track(
          id: result.id,
          title: result.title,
          artist: result.artist ?? result.subtitle,
          thumbnailUrl: result.thumbnailUrl,
          durationSeconds: result.durationSeconds,
        );
        context.read<PlaybackController>().playTrack(track);
      case SearchResultType.artist:
        if (result.browseId != null) {
          Navigator.of(context)
              .pushNamed('/artist', arguments: result.browseId);
        }
      case SearchResultType.album:
        final id = result.browseId ?? result.id;
        Navigator.of(context).pushNamed('/playlist_detail', arguments: id);
      case SearchResultType.playlist:
        Navigator.of(context)
            .pushNamed('/playlist_detail', arguments: result.id);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _debounceTimer?.cancel();
    setState(() {
      _suggestions = [];
      _results = [];
      _continuation = null;
      _error = null;
    });
    _focusNode.requestFocus();
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final query = _searchController.text.trim();

    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 8),
        // Search input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LiquidGlassTextField(
            controller: _searchController,
            focusNode: _focusNode,
            hintText: 'Search songs, artists, albums...',
            prefixIcon: Icons.search_rounded,
            autofocus: false,
            textInputAction: TextInputAction.search,
            onChanged: _onQueryChanged,
            onSubmitted: _performSearch,
            suffix: query.isNotEmpty
                ? GestureDetector(
                    onTap: _clearSearch,
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppTheme.textSecondary,
                      size: 18,
                    ),
                  )
                : null,
          ),
        ),
        // Filter chips
        _buildFilterChips(),
        // Content area
        Expanded(child: _buildContent(query)),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          return LiquidGlassChip(
            label: filter,
            selected: _selectedFilter == filter,
            onTap: () => _onFilterSelected(filter),
          );
        },
      ),
    );
  }

  Widget _buildContent(String query) {
    // Loading state
    if (_isLoading) {
      return _buildLoadingShimmer();
    }

    // Error state
    if (_error != null) {
      return ErrorView(
        message: _error!.length > 150
            ? '${_error!.substring(0, 150)}...'
            : _error!,
        onRetry: () => _performSearch(_searchController.text),
      );
    }

    // Suggestions overlay (takes priority when visible)
    if (_suggestions.isNotEmpty) {
      return _buildSuggestions();
    }

    // Search results
    if (_results.isNotEmpty) {
      return _buildResults();
    }

    // Empty query — show recent searches or empty state
    if (query.isEmpty) {
      if (_recentSearches.isNotEmpty) {
        return _buildRecentSearches();
      }
      return _buildEmptyState();
    }

    // Query entered but no results yet (hasn't submitted)
    return _buildEmptyState();
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: 8,
      itemBuilder: (_, __) => const ShimmerTrackTile(),
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return ListTile(
          leading: const Icon(
            Icons.search_rounded,
            color: AppTheme.textTertiary,
            size: 18,
          ),
          title: Text(
            suggestion,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(
              Icons.north_west_rounded,
              color: AppTheme.textTertiary,
              size: 16,
            ),
            onPressed: () {
              _searchController.text = suggestion;
              _searchController.selection = TextSelection.fromPosition(
                TextPosition(offset: suggestion.length),
              );
              // Don't search yet — let user refine.
            },
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          onTap: () => _onSuggestionTap(suggestion),
        );
      },
    );
  }

  Widget _buildRecentSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent searches',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              GestureDetector(
                onTap: _clearRecentSearches,
                child: const Text(
                  'Clear all',
                  style: TextStyle(
                    color: AppTheme.primaryAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final query = _recentSearches[index];
              return ListTile(
                leading: const Icon(
                  Icons.history_rounded,
                  color: AppTheme.textTertiary,
                  size: 18,
                ),
                title: Text(
                  query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.textTertiary,
                    size: 16,
                  ),
                  onPressed: () => _removeRecentSearch(query),
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                onTap: () {
                  _searchController.text = query;
                  _searchController.selection = TextSelection.fromPosition(
                    TextPosition(offset: query.length),
                  );
                  _performSearch(query);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final playbackController = context.watch<PlaybackController>();
    final currentTrackId = playbackController.currentTrack?.id;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 160),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];

        switch (result.type) {
          case SearchResultType.song:
          case SearchResultType.video:
            return _buildTrackResult(result, currentTrackId);
          case SearchResultType.artist:
            return _buildArtistResult(result);
          case SearchResultType.album:
          case SearchResultType.playlist:
            return _buildCollectionResult(result);
        }
      },
    );
  }

  Widget _buildTrackResult(SearchResult result, String? currentTrackId) {
    final track = Track(
      id: result.id,
      title: result.title,
      artist: result.artist ?? result.subtitle,
      thumbnailUrl: result.thumbnailUrl,
      durationSeconds: result.durationSeconds,
    );
    return TrackTile(
      track: track,
      isPlaying: currentTrackId == result.id,
      onTap: () => _onResultTap(result),
    );
  }

  Widget _buildArtistResult(SearchResult result) {
    return InkWell(
      onTap: () => _onResultTap(result),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Circular thumbnail for artists
            ClipOval(
              child: SizedBox(
                width: 48,
                height: 48,
                child: result.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: result.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _artistPlaceholder(),
                        errorWidget: (_, __, ___) => _artistPlaceholder(),
                      )
                    : _artistPlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    result.subtitle.isNotEmpty ? result.subtitle : 'Artist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionResult(SearchResult result) {
    final isAlbum = result.type == SearchResultType.album;
    final typeIcon =
        isAlbum ? Icons.album_rounded : Icons.queue_music_rounded;

    return InkWell(
      onTap: () => _onResultTap(result),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: result.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: result.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            _collectionPlaceholder(typeIcon),
                        errorWidget: (_, __, ___) =>
                            _collectionPlaceholder(typeIcon),
                      )
                    : _collectionPlaceholder(typeIcon),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(typeIcon, size: 12, color: AppTheme.textTertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          result.subtitle.isNotEmpty
                              ? result.subtitle
                              : (isAlbum ? 'Album' : 'Playlist'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyView(
      icon: Icons.search_rounded,
      message: 'Search for music',
    );
  }

  // ── Placeholder helpers ──

  Widget _artistPlaceholder() {
    return Container(
      color: AppTheme.surfaceElevated,
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          color: AppTheme.textTertiary,
          size: 22,
        ),
      ),
    );
  }

  Widget _collectionPlaceholder(IconData icon) {
    return Container(
      color: AppTheme.surfaceElevated,
      child: Center(
        child: Icon(icon, color: AppTheme.textTertiary, size: 20),
      ),
    );
  }
}
