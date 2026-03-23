import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/models/search_result.dart';
import '../../../domain/models/track.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../player/playback_controller.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<String> _suggestions = [];
  List<SearchResult> _results = [];
  bool _searching = false;
  String _activeFilter = 'all';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _results = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    try {
      final repo = context.read<MusicRepository>();
      final suggestions = await repo.searchSuggestions(query);
      if (mounted && _searchCtrl.text.isNotEmpty) {
        setState(() => _suggestions = suggestions);
      }
    } catch (_) {}
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    _focusNode.unfocus();
    setState(() {
      _searching = true;
      _suggestions = [];
    });
    try {
      final repo = context.read<MusicRepository>();
      final filter = _activeFilter == 'all' ? null : _activeFilter;
      final results = await repo.search(query, filter: filter);
      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searching = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Search failed: $e'),
          backgroundColor: AppTheme.errorRed,
        ));
      }
    }
  }

  void _onResultTap(SearchResult result) {
    if (result.type == SearchResultType.song ||
        result.type == SearchResultType.video) {
      final track = Track(
        id: result.id,
        title: result.title,
        artist: result.artist ?? result.subtitle,
        thumbnailUrl: result.thumbnailUrl,
        durationSeconds: result.durationSeconds,
      );
      context.read<PlaybackController>().setQueue([track]);
    } else if (result.type == SearchResultType.artist &&
        result.browseId != null) {
      Navigator.of(context).pushNamed('/artist', arguments: result.browseId);
    } else if (result.type == SearchResultType.album &&
        result.browseId != null) {
      Navigator.of(context)
          .pushNamed('/playlist_detail', arguments: result.browseId);
    } else if (result.type == SearchResultType.playlist) {
      Navigator.of(context)
          .pushNamed('/playlist_detail', arguments: result.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 8),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LiquidGlassContainer(
            borderRadius: 20,
            intensity: 0.5,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            enableSpecular: false,
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    color: AppTheme.textSecondary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _focusNode,
                    onChanged: _onQueryChanged,
                    onSubmitted: _performSearch,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Search songs, artists, albums...',
                      hintStyle: TextStyle(
                          color: AppTheme.textTertiary, fontSize: 15),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                if (_searchCtrl.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() {
                        _suggestions = [];
                        _results = [];
                      });
                    },
                    child: const Icon(Icons.close_rounded,
                        color: AppTheme.textSecondary, size: 18),
                  ),
              ],
            ),
          ),
        ),
        // Filter chips
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChip(
                  label: 'All',
                  active: _activeFilter == 'all',
                  onTap: () => _setFilter('all')),
              _FilterChip(
                  label: 'Songs',
                  active: _activeFilter == 'songs',
                  onTap: () => _setFilter('songs')),
              _FilterChip(
                  label: 'Artists',
                  active: _activeFilter == 'artists',
                  onTap: () => _setFilter('artists')),
              _FilterChip(
                  label: 'Albums',
                  active: _activeFilter == 'albums',
                  onTap: () => _setFilter('albums')),
              _FilterChip(
                  label: 'Playlists',
                  active: _activeFilter == 'playlists',
                  onTap: () => _setFilter('playlists')),
              _FilterChip(
                  label: 'Videos',
                  active: _activeFilter == 'videos',
                  onTap: () => _setFilter('videos')),
            ],
          ),
        ),
        // Results / Suggestions
        Expanded(
          child: _searching
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryAccent))
              : _suggestions.isNotEmpty
                  ? _buildSuggestions()
                  : _results.isNotEmpty
                      ? _buildResults()
                      : _buildEmptyState(),
        ),
      ],
    );
  }

  void _setFilter(String filter) {
    setState(() => _activeFilter = filter);
    if (_searchCtrl.text.isNotEmpty) {
      _performSearch(_searchCtrl.text);
    }
  }

  Widget _buildSuggestions() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: _suggestions.length,
      itemBuilder: (context, i) {
        return ListTile(
          leading: const Icon(Icons.search_rounded,
              color: AppTheme.textTertiary, size: 18),
          title: Text(_suggestions[i],
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 14)),
          dense: true,
          onTap: () {
            _searchCtrl.text = _suggestions[i];
            _performSearch(_suggestions[i]);
          },
        );
      },
    );
  }

  Widget _buildResults() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 160),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final r = _results[i];
        return _SearchResultTile(result: r, onTap: () => _onResultTap(r));
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded,
              size: 56, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 14),
          const Text('Search YouTube Music',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active
              ? AppTheme.primaryAccent.withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
          border: Border.all(
            color: active
                ? AppTheme.primaryAccent.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
            width: 0.6,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color: active ? AppTheme.primaryAccent : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _SearchResultTile({required this.result, required this.onTap});

  IconData get _typeIcon {
    switch (result.type) {
      case SearchResultType.song:
        return Icons.music_note_rounded;
      case SearchResultType.artist:
        return Icons.person_rounded;
      case SearchResultType.album:
        return Icons.album_rounded;
      case SearchResultType.playlist:
        return Icons.queue_music_rounded;
      case SearchResultType.video:
        return Icons.play_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCircle = result.type == SearchResultType.artist;
    return ListTile(
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(isCircle ? 24 : 6),
        child: SizedBox(
          width: 48,
          height: 48,
          child: result.thumbnailUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: result.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      _fallback(isCircle),
                )
              : _fallback(isCircle),
        ),
      ),
      title: Text(result.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500)),
      subtitle: Text(result.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 12)),
      trailing: Icon(_typeIcon, size: 16, color: AppTheme.textTertiary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _fallback(bool circle) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(circle ? 24 : 6),
      ),
      child: Icon(_typeIcon, color: AppTheme.textTertiary, size: 22),
    );
  }
}
