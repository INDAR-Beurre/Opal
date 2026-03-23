import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../player/playback_controller.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../theme/app_theme.dart';

/// Full-screen now-playing view with giant album art,
/// Liquid Glass controls, and swipe-to-dismiss.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaybackController>(
      builder: (context, pc, _) {
        final track = pc.currentTrack;
        if (track == null) {
          return const Scaffold(
            backgroundColor: AppTheme.surfaceBase,
            body: Center(
                child: Text('No track playing',
                    style: TextStyle(color: AppTheme.textSecondary))),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Background: blurred album art
              if (track.thumbnailUrl.isNotEmpty)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: track.highResThumbnail,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Container(color: AppTheme.surfaceBase),
                  ),
                ),
              // Dark overlay + blur
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Container(
                    color: Colors.black.withOpacity(0.55),
                  ),
                ),
              ),

              // Content
              SafeArea(
                child: Column(
                  children: [
                    // Top bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                color: Colors.white, size: 30),
                          ),
                          const Text('Now Playing',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          IconButton(
                            onPressed: () =>
                                _showQueue(context, pc),
                            icon: const Icon(Icons.queue_music_rounded,
                                color: Colors.white70, size: 24),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 2),
                    // Album art
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: LiquidGlassContainer(
                          borderRadius: 24,
                          intensity: 0.6,
                          padding: const EdgeInsets.all(6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: track.thumbnailUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: track.highResThumbnail,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _artPlaceholder(),
                                  )
                                : _artPlaceholder(),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(flex: 1),
                    // Track info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Text(
                            track.title,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            track.artist,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Seek bar
                    _SeekBar(pc: pc),
                    const SizedBox(height: 20),
                    // Controls
                    _Controls(pc: pc),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _artPlaceholder() {
    return Container(
      color: AppTheme.surfaceElevated,
      child: const Center(
          child: Icon(Icons.music_note_rounded,
              color: AppTheme.textTertiary, size: 64)),
    );
  }

  void _showQueue(BuildContext context, PlaybackController pc) {
    LiquidGlassBottomSheet.show(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text('Queue',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: pc.queue.length,
              itemBuilder: (context, i) {
                final t = pc.queue[i];
                final playing = i == pc.currentIndex;
                return ListTile(
                  onTap: () {
                    pc.playAtIndex(i);
                    Navigator.of(context).pop();
                  },
                  leading: Text('${i + 1}',
                      style: TextStyle(
                          color: playing
                              ? AppTheme.primaryAccent
                              : AppTheme.textTertiary,
                          fontSize: 13)),
                  title: Text(t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: playing
                              ? AppTheme.primaryAccent
                              : AppTheme.textPrimary,
                          fontSize: 14)),
                  subtitle: Text(t.artist,
                      maxLines: 1,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                  dense: true,
                  trailing: playing
                      ? const Icon(Icons.equalizer_rounded,
                          color: AppTheme.primaryAccent, size: 18)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  final PlaybackController pc;
  const _SeekBar({required this.pc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: AppTheme.primaryAccent,
              inactiveTrackColor: Colors.white.withOpacity(0.12),
              thumbColor: AppTheme.primaryAccent,
              overlayColor: AppTheme.primaryAccent.withOpacity(0.15),
            ),
            child: Slider(
              value: pc.duration.inMilliseconds > 0
                  ? pc.position.inMilliseconds
                      .toDouble()
                      .clamp(0, pc.duration.inMilliseconds.toDouble())
                  : 0,
              max: pc.duration.inMilliseconds > 0
                  ? pc.duration.inMilliseconds.toDouble()
                  : 1,
              onChanged: (v) => pc.seek(Duration(milliseconds: v.toInt())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(pc.position),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
                Text(_formatDuration(pc.duration),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _Controls extends StatelessWidget {
  final PlaybackController pc;
  const _Controls({required this.pc});

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
                : Colors.white.withOpacity(0.5),
            onPressed: () => pc.setShuffle(!pc.shuffle),
          ),
          // Previous
          LiquidGlassIconButton(
            icon: Icons.skip_previous_rounded,
            size: 52,
            iconSize: 26,
            onPressed: pc.previous,
          ),
          // Play / Pause (large)
          LiquidGlassButton(
            size: 72,
            onPressed: pc.togglePlayPause,
            child: Icon(
              pc.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          // Next
          LiquidGlassIconButton(
            icon: Icons.skip_next_rounded,
            size: 52,
            iconSize: 26,
            onPressed: pc.next,
          ),
          // Repeat
          LiquidGlassIconButton(
            icon: _repeatIcon,
            size: 42,
            iconSize: 20,
            iconColor: pc.repeatMode != RepeatMode.off
                ? AppTheme.primaryAccent
                : Colors.white.withOpacity(0.5),
            onPressed: pc.cycleRepeatMode,
          ),
        ],
      ),
    );
  }

  IconData get _repeatIcon {
    switch (pc.repeatMode) {
      case RepeatMode.off:
        return Icons.repeat_rounded;
      case RepeatMode.all:
        return Icons.repeat_rounded;
      case RepeatMode.one:
        return Icons.repeat_one_rounded;
    }
  }
}
