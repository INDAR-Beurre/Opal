import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../domain/models/playlist.dart';
import '../../../player/playback_controller.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../widgets/error_view.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/track_tile.dart';
import '../../theme/app_theme.dart';

/// Library screen — quick-access cards for Liked Songs, History, and Queue,
/// plus user playlists when logged in. Shows a sign-in prompt otherwise.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
  List<Playlist>? _playlists;
  bool _isLoadingPlaylists = false;
  String? _playlistError;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final repo = context.read<MusicRepository>();
    if (!repo.isLoggedIn) return;

    setState(() {
      _isLoadingPlaylists = true;
      _playlistError = null;
    });

    try {
      final playlists = await repo.getLibraryPlaylists();
      if (mounted) {
        setState(() {
          _playlists = playlists;
          _isLoadingPlaylists = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _playlistError = e.toString();
          _isLoadingPlaylists = false;
        });
      }
    }
  }

  // ── Quick-access actions ──

  Future<void> _onLikedSongsTap() async {
    final repo = context.read<MusicRepository>();
    if (!repo.isLoggedIn) {
      _showSignInSnackBar();
      return;
    }

    _showLoadingDialog('Loading liked songs...');

    try {
      await repo.getLikedSongs();
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        Navigator.of(context).pushNamed('/playlist_detail', arguments: 'LM');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load liked songs: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _onHistoryTap() async {
    final repo = context.read<MusicRepository>();
    if (!repo.isLoggedIn) {
      _showSignInSnackBar();
      return;
    }

    _showLoadingDialog('Loading history...');

    try {
      final tracks = await repo.getHistory();
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      final playbackController = context.read<PlaybackController>();
      LiquidGlassBottomSheet.show(
        context: context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Listening History',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (tracks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No listening history yet',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    return TrackTile(
                      track: track,
                      isPlaying:
                          playbackController.currentTrack?.id == track.id,
                      onTap: () {
                        Navigator.of(context).pop();
                        playbackController.setQueue(
                          tracks,
                          startIndex: index,
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load history: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _onQueueTap() {
    final playbackController = context.read<PlaybackController>();
    if (playbackController.queue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Queue is empty — play something first'),
          backgroundColor: AppTheme.surfaceElevated,
        ),
      );
      return;
    }

    LiquidGlassBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Queue',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '${playbackController.queue.length} tracks',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: playbackController.queue.length,
              itemBuilder: (context, index) {
                final track = playbackController.queue[index];
                return TrackTile(
                  track: track,
                  isPlaying: index == playbackController.currentIndex,
                  onTap: () {
                    Navigator.of(context).pop();
                    playbackController.playAtIndex(index);
                  },
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppTheme.textTertiary,
                      size: 16,
                    ),
                    onPressed: () {
                      playbackController.removeFromQueue(index);
                      // Rebuild the sheet if still open
                      if (mounted) setState(() {});
                    },
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSignInSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sign in to access this feature'),
        backgroundColor: AppTheme.surfaceElevated,
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: LiquidGlassContainer(
          borderRadius: 20,
          intensity: 0.7,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryAccent),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final repo = context.read<MusicRepository>();
    final pc = context.watch<PlaybackController>();

    return RefreshIndicator(
      onRefresh: _loadPlaylists,
      color: AppTheme.primaryAccent,
      backgroundColor: AppTheme.surfaceElevated,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // ── Title ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: MediaQuery.of(context).padding.top + 16,
                bottom: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Library',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  LiquidGlassIconButton(
                    icon: Icons.settings_rounded,
                    size: 40,
                    iconSize: 20,
                    iconColor: AppTheme.textSecondary,
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/settings'),
                  ),
                ],
              ),
            ),
          ),

          // ── Quick access cards ──
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickAccessCard(
                      icon: Icons.favorite_rounded,
                      label: 'Liked Songs',
                      color: const Color(0xFFFF6B8A),
                      onTap: _onLikedSongsTap,
                    ),
                  ),
                  Expanded(
                    child: _QuickAccessCard(
                      icon: Icons.history_rounded,
                      label: 'History',
                      color: AppTheme.primaryAccent,
                      onTap: _onHistoryTap,
                    ),
                  ),
                  Expanded(
                    child: _QuickAccessCard(
                      icon: Icons.queue_music_rounded,
                      label: 'Queue',
                      color: AppTheme.secondaryAccent,
                      onTap: _onQueueTap,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── User playlists or sign-in prompt ──
          if (!repo.isLoggedIn)
            SliverToBoxAdapter(child: _buildSignInCard())
          else ...[
            // Section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 28,
                  bottom: 8,
                ),
                child: Text(
                  'Your Playlists',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            // Playlist content
            if (_isLoadingPlaylists)
              SliverToBoxAdapter(child: _buildPlaylistsLoading())
            else if (_playlistError != null)
              SliverToBoxAdapter(
                child: ErrorView(
                  message: _playlistError!.length > 120
                      ? '${_playlistError!.substring(0, 120)}...'
                      : _playlistError!,
                  onRetry: _loadPlaylists,
                ),
              )
            else if (_playlists != null && _playlists!.isNotEmpty)
              _buildPlaylistGrid()
            else if (_playlists != null && _playlists!.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyView(
                  icon: Icons.playlist_add_rounded,
                  message: 'No playlists yet',
                ),
              ),
          ],

          // ── Current queue inline ──
          if (pc.queue.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 28,
                  bottom: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Now Playing Queue',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      '${pc.queue.length} tracks',
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Show at most 5 tracks inline; the rest via the queue sheet.
                  if (index >= 5) return null;
                  final track = pc.queue[index];
                  return TrackTile(
                    track: track,
                    isPlaying: index == pc.currentIndex,
                    onTap: () => pc.playAtIndex(index),
                  );
                },
                childCount: pc.queue.length.clamp(0, 5),
              ),
            ),
            if (pc.queue.length > 5)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: _onQueueTap,
                      child: const Text(
                        'View full queue',
                        style: TextStyle(
                          color: AppTheme.primaryAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],

          // ── Empty state when nothing to show ──
          if (!repo.isLoggedIn &&
              pc.queue.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_music_rounded,
                    size: 56,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Your library is empty',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Start playing music or sign in\nto sync your YouTube Music library',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          // Bottom padding for mini-player + nav bar
          const SliverToBoxAdapter(child: SizedBox(height: 160)),
        ],
      ),
    );
  }

  Widget _buildSignInCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: LiquidGlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(20),
        onTap: () => Navigator.of(context).pushNamed('/login'),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryAccent.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppTheme.primaryAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sign in to access your library',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View playlists, liked songs, and history',
                    style: TextStyle(
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
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistsLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: 4,
        itemBuilder: (_, __) => const ShimmerLoading(
          height: 180,
          borderRadius: 16,
        ),
      ),
    );
  }

  Widget _buildPlaylistGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final playlist = _playlists![index];
            return _PlaylistCard(
              playlist: playlist,
              onTap: () => Navigator.of(context).pushNamed(
                '/playlist_detail',
                arguments: playlist.id,
              ),
            );
          },
          childCount: _playlists!.length,
        ),
      ),
    );
  }
}

// ── Quick-access card ──

class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      onTap: onTap,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Playlist card ──

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;

  const _PlaylistCard({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      onTap: onTap,
      borderRadius: 16,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: _buildThumbnail(),
            ),
          ),
          // Title and subtitle
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Text(
              playlist.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Text(
              playlist.uploaderName ?? '${playlist.trackCount} tracks',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    if (playlist.thumbnailUrl != null && playlist.thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: playlist.thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _thumbnailPlaceholder(),
        errorWidget: (_, __, ___) => _thumbnailPlaceholder(),
      );
    }
    return _thumbnailPlaceholder();
  }

  Widget _thumbnailPlaceholder() {
    return Container(
      color: AppTheme.surfaceElevated,
      child: const Center(
        child: Icon(
          Icons.queue_music_rounded,
          color: AppTheme.textTertiary,
          size: 32,
        ),
      ),
    );
  }
}
