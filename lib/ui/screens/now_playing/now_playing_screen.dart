import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../player/playback_controller.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../widgets/track_tile.dart';
import '../../theme/app_theme.dart';

/// Full-screen now-playing view with blurred album art background,
/// Liquid Glass controls, swipe-to-dismiss, and queue sheet.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  static const double _blurSigma = 60.0;
  static const double _overlayOpacity = 0.55;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaybackController>(
      builder: (context, pc, _) {
        final track = pc.currentTrack;
        if (track == null) {
          return const Scaffold(
            backgroundColor: AppTheme.surfaceBase,
            body: Center(
              child: Text(
                'No track playing',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! > 300) {
                Navigator.of(context).pop();
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Blurred album art background
                _BlurredBackground(
                  imageUrl: track.highResThumbnail,
                  blurSigma: _blurSigma,
                  overlayOpacity: _overlayOpacity,
                ),

                // Foreground content
                SafeArea(
                  child: Column(
                    children: [
                      _TopBar(
                        onClose: () => Navigator.of(context).pop(),
                        onQueue: () => _showQueue(context, pc),
                      ),
                      const Spacer(flex: 2),
                      _Artwork(
                        imageUrl: track.highResThumbnail,
                        trackId: track.id,
                      ),
                      const Spacer(flex: 1),
                      _TrackInfo(
                        title: track.title,
                        artist: track.artist,
                      ),
                      const SizedBox(height: 28),
                      _SeekBar(pc: pc),
                      const SizedBox(height: 20),
                      _TransportControls(pc: pc),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQueue(BuildContext context, PlaybackController pc) {
    LiquidGlassBottomSheet.show(
      context: context,
      child: _QueueContent(pc: pc),
    );
  }
}

// ---------------------------------------------------------------------------
// Blurred background with dark overlay
// ---------------------------------------------------------------------------

class _BlurredBackground extends StatelessWidget {
  const _BlurredBackground({
    required this.imageUrl,
    required this.blurSigma,
    required this.overlayOpacity,
  });

  final String imageUrl;
  final double blurSigma;
  final double overlayOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl.isNotEmpty)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  Container(color: AppTheme.surfaceBase),
            ),
          ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(color: Colors.black.withValues(alpha: overlayOpacity)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar: chevron-down close button + "Now Playing" label + queue button
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose, required this.onQueue});

  final VoidCallback onClose;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const Text(
            'Now Playing',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          IconButton(
            onPressed: onQueue,
            icon: const Icon(
              Icons.queue_music_rounded,
              color: Colors.white70,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Large album art with Hero animation and rounded corners
// ---------------------------------------------------------------------------

class _Artwork extends StatelessWidget {
  const _Artwork({required this.imageUrl, required this.trackId});

  final String imageUrl;
  final String trackId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Hero(
        tag: 'album_art_$trackId',
        child: AspectRatio(
          aspectRatio: 1,
          child: LiquidGlassContainer(
            borderRadius: 24,
            intensity: 0.6,
            padding: const EdgeInsets.all(6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.surfaceElevated,
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppTheme.textTertiary,
          size: 64,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Song title + artist
// ---------------------------------------------------------------------------

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({required this.title, required this.artist});

  final String title;
  final String artist;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            artist,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Seek bar with LiquidGlassSlider and time indicators
// ---------------------------------------------------------------------------

class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.pc});

  final PlaybackController pc;

  @override
  Widget build(BuildContext context) {
    final posMs = pc.position.inMilliseconds.toDouble();
    final durMs = pc.duration.inMilliseconds.toDouble();
    final bufMs = pc.bufferedPosition.inMilliseconds.toDouble();
    final safeDur = durMs > 0 ? durMs : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          LiquidGlassSlider(
            value: posMs.clamp(0.0, safeDur),
            max: safeDur,
            buffered: bufMs.clamp(0.0, safeDur),
            onChanged: (v) => pc.seek(Duration(milliseconds: v.toInt())),
            onChangeEnd: (v) => pc.seek(Duration(milliseconds: v.toInt())),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(pc.position),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  _formatDuration(pc.duration),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Transport controls: shuffle, previous, play/pause, next, repeat
// ---------------------------------------------------------------------------

class _TransportControls extends StatelessWidget {
  const _TransportControls({required this.pc});

  final PlaybackController pc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Shuffle
          LiquidGlassIconButton(
            icon: Icons.shuffle_rounded,
            size: 42,
            iconSize: 20,
            iconColor: pc.shuffle
                ? AppTheme.primaryAccent
                : AppTheme.textTertiary,
            onPressed: pc.toggleShuffle,
          ),

          // Previous
          LiquidGlassIconButton(
            icon: Icons.skip_previous_rounded,
            size: 52,
            iconSize: 26,
            onPressed: pc.previous,
          ),

          // Play / Pause (large) — shows loading spinner when buffering
          _PlayPauseButton(pc: pc),

          // Next
          LiquidGlassIconButton(
            icon: Icons.skip_next_rounded,
            size: 52,
            iconSize: 26,
            onPressed: pc.next,
          ),

          // Repeat
          LiquidGlassIconButton(
            icon: _repeatIcon(pc.repeatMode),
            size: 42,
            iconSize: 20,
            iconColor: pc.repeatMode != RepeatMode.off
                ? AppTheme.primaryAccent
                : AppTheme.textTertiary,
            onPressed: pc.cycleRepeatMode,
          ),
        ],
      ),
    );
  }

  IconData _repeatIcon(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
      case RepeatMode.all:
        return Icons.repeat_rounded;
      case RepeatMode.one:
        return Icons.repeat_one_rounded;
    }
  }
}

// ---------------------------------------------------------------------------
// Play/Pause button with loading state
// ---------------------------------------------------------------------------

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.pc});

  final PlaybackController pc;

  @override
  Widget build(BuildContext context) {
    if (pc.isLoading) {
      return LiquidGlassButton(
        isCircle: true,
        size: 72,
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
      );
    }

    return LiquidGlassButton(
      isCircle: true,
      size: 72,
      onTap: pc.togglePlayPause,
      child: Icon(
        pc.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: Colors.white,
        size: 34,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Queue sheet content
// ---------------------------------------------------------------------------

class _QueueContent extends StatelessWidget {
  const _QueueContent({required this.pc});

  final PlaybackController pc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              const Text(
                'Queue',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${pc.queue.length} tracks',
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: pc.queue.isEmpty
              ? const Center(
                  child: Text(
                    'Queue is empty',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                )
              : ListView.builder(
                  itemCount: pc.queue.length,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemBuilder: (context, i) {
                    final track = pc.queue[i];
                    final isCurrentTrack = i == pc.currentIndex;
                    return TrackTile(
                      track: track,
                      isPlaying: isCurrentTrack,
                      trackNumber: i + 1,
                      onTap: () {
                        pc.playAtIndex(i);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
