import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/models/playlist.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/track.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../player/playback_controller.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../theme/app_theme.dart';
import '../../widgets/track_tile.dart';

/// Shows details for a playlist or album.
class PlaylistDetailScreen extends StatefulWidget {
  final String browseId;

  const PlaylistDetailScreen({super.key, required this.browseId});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  String _title = '';
  String _subtitle = '';
  String _thumbnail = '';
  List<Track> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<MusicRepository>();
      // Try as album first, then playlist
      if (widget.browseId.startsWith('MPREb_') ||
          widget.browseId.startsWith('OLAK')) {
        final album = await repo.getAlbum(widget.browseId);
        _applyAlbum(album);
      } else {
        final playlist = await repo.getPlaylist(widget.browseId);
        _applyPlaylist(playlist);
      }
    } catch (_) {
      // Fallback: try the other type
      try {
        final repo = context.read<MusicRepository>();
        try {
          final playlist = await repo.getPlaylist(widget.browseId);
          _applyPlaylist(playlist);
        } catch (_) {
          final album = await repo.getAlbum(widget.browseId);
          _applyAlbum(album);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _loading = false;
          });
        }
      }
    }
  }

  void _applyPlaylist(Playlist p) {
    if (!mounted) return;
    setState(() {
      _title = p.title;
      _subtitle = p.uploaderName ?? '${p.trackCount} tracks';
      _thumbnail = p.thumbnailUrl ?? '';
      _tracks = p.tracks;
      _loading = false;
    });
  }

  void _applyAlbum(Album a) {
    if (!mounted) return;
    setState(() {
      _title = a.title;
      _subtitle = a.artist ?? '';
      _thumbnail = a.thumbnailUrl ?? '';
      _tracks = a.tracks;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Failed to load',
                          style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      TextButton(
                          onPressed: _load,
                          child: const Text('Retry')),
                    ],
                  ),
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Hero header
                    SliverToBoxAdapter(child: _buildHeader()),
                    // Track list
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final track = _tracks[i];
                          return TrackTile(
                            track: track,
                            onTap: () {
                              context
                                  .read<PlaybackController>()
                                  .setQueue(_tracks, startIndex: i);
                            },
                            isPlaying: context
                                    .watch<PlaybackController>()
                                    .currentTrack
                                    ?.id ==
                                track.id,
                          );
                        },
                        childCount: _tracks.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 160)),
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        // Background blur
        if (_thumbnail.isNotEmpty)
          SizedBox(
            height: 320,
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: _thumbnail,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  Container(color: AppTheme.surfaceElevated),
            ),
          ),
        Container(
          height: 320,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                AppTheme.surfaceBase,
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.transparent),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: LiquidGlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      size: 40,
                      iconSize: 20,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Album art
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: _thumbnail.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: _thumbnail,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: AppTheme.surfaceElevated,
                            child: const Icon(Icons.album_rounded,
                                size: 48, color: AppTheme.textTertiary),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(_title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(_subtitle,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                // Play all / Shuffle
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ActionButton(
                      icon: Icons.play_arrow_rounded,
                      label: 'Play All',
                      onTap: () {
                        if (_tracks.isNotEmpty) {
                          context
                              .read<PlaybackController>()
                              .setQueue(_tracks);
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    _ActionButton(
                      icon: Icons.shuffle_rounded,
                      label: 'Shuffle',
                      onTap: () {
                        if (_tracks.isNotEmpty) {
                          final pc = context.read<PlaybackController>();
                          pc.setShuffle(true);
                          pc.setQueue(_tracks);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassContainer(
        borderRadius: 20,
        intensity: 0.6,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
