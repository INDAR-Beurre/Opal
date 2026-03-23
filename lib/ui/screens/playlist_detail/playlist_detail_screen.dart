import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../domain/models/track.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/playlist.dart';
import '../../../player/playback_controller.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../widgets/track_tile.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/error_view.dart';
import '../../theme/app_theme.dart';

/// Playlist/Album detail screen.
///
/// Determines content type from [browseId]:
/// - Starts with "MPR" or "OLAK" -> album (via [MusicRepository.getAlbum])
/// - Otherwise -> playlist (via [MusicRepository.getPlaylist])
class PlaylistDetailScreen extends StatefulWidget {
  final String browseId;

  const PlaylistDetailScreen({super.key, required this.browseId});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late final bool _isAlbum;

  String _title = '';
  String _subtitle = '';
  String _thumbnailUrl = '';
  List<Track> _tracks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isAlbum = widget.browseId.startsWith('MPR') ||
        widget.browseId.startsWith('OLAK');
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = context.read<MusicRepository>();

      if (_isAlbum) {
        final album = await repo.getAlbum(widget.browseId);
        if (!mounted) return;
        setState(() {
          _title = album.title;
          _subtitle = album.artist ?? '';
          _thumbnailUrl = album.thumbnailUrl ?? '';
          _tracks = album.tracks;
          _isLoading = false;
        });
      } else {
        final playlist = await repo.getPlaylist(widget.browseId);
        if (!mounted) return;
        setState(() {
          _title = playlist.title;
          _subtitle = playlist.uploaderName ?? '${playlist.trackCount} tracks';
          _thumbnailUrl = playlist.thumbnailUrl ?? '';
          _tracks = playlist.tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatTotalDuration() {
    final totalSeconds =
        _tracks.fold<int>(0, (sum, track) => sum + track.durationSeconds);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours hr $minutes min';
    }
    return '$minutes min';
  }

  void _playAll() {
    if (_tracks.isEmpty) return;
    context.read<PlaybackController>().setQueue(_tracks, startIndex: 0);
  }

  void _shuffleAll() {
    if (_tracks.isEmpty) return;
    final controller = context.read<PlaybackController>();
    controller.setShuffle(true);
    controller.setQueue(_tracks, startIndex: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.surfaceBase,
        body: _buildShimmerState(),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.surfaceBase,
        body: SafeArea(
          child: Column(
            children: [
              _buildBackButton(),
              Expanded(
                child: ErrorView(
                  message: _error!,
                  onRetry: _loadData,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildActionButtons()),
          _buildTrackList(),
          const SliverToBoxAdapter(child: SizedBox(height: 160)),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LiquidGlassIconButton(
          icon: Icons.arrow_back_rounded,
          size: 40,
          iconSize: 20,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Widget _buildShimmerState() {
    return SafeArea(
      child: Column(
        children: [
          // Header shimmer
          const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                ShimmerLoading(width: 160, height: 160, borderRadius: 16),
                SizedBox(height: 16),
                ShimmerLoading(width: 200, height: 22, borderRadius: 6),
                SizedBox(height: 8),
                ShimmerLoading(width: 140, height: 14, borderRadius: 4),
                SizedBox(height: 8),
                ShimmerLoading(width: 100, height: 12, borderRadius: 4),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShimmerLoading(width: 120, height: 44, borderRadius: 16),
                    SizedBox(width: 12),
                    ShimmerLoading(width: 120, height: 44, borderRadius: 16),
                  ],
                ),
              ],
            ),
          ),
          // Track list shimmer
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: 8,
              itemBuilder: (_, __) => const ShimmerTrackTile(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        // Background image
        if (_thumbnailUrl.isNotEmpty)
          SizedBox(
            height: 340,
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: _thumbnailUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  Container(color: AppTheme.surfaceElevated),
            ),
          ),
        // Gradient overlay
        Container(
          height: 340,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.3),
                AppTheme.surfaceBase,
              ],
            ),
          ),
        ),
        // Blur layer
        Positioned.fill(
          child: SizedBox(
            height: 340,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        // Content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: LiquidGlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    size: 40,
                    iconSize: 20,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(height: 16),
                // Album art
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: _thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: _thumbnailUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _buildArtPlaceholder(),
                          )
                        : _buildArtPlaceholder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                // Subtitle (artist / author)
                Text(
                  _subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                // Track count + total duration
                Text(
                  '${_tracks.length} tracks  \u2022  ${_formatTotalDuration()}',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArtPlaceholder() {
    return Container(
      color: AppTheme.surfaceElevated,
      child: const Icon(
        Icons.album_rounded,
        size: 48,
        color: AppTheme.textTertiary,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: LiquidGlassButton(
              onTap: _playAll,
              borderRadius: 20,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Play All',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LiquidGlassButton(
              onTap: _shuffleAll,
              borderRadius: 20,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shuffle_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Shuffle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackList() {
    return Consumer<PlaybackController>(
      builder: (context, playbackController, _) {
        final currentTrackId = playbackController.currentTrack?.id;

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final track = _tracks[index];
              final isPlaying = currentTrackId == track.id;

              return TrackTile(
                track: track,
                isPlaying: isPlaying,
                trackNumber: _isAlbum ? index + 1 : null,
                showThumbnail: !_isAlbum,
                onTap: () {
                  context
                      .read<PlaybackController>()
                      .setQueue(_tracks, startIndex: index);
                },
              );
            },
            childCount: _tracks.length,
          ),
        );
      },
    );
  }
}
