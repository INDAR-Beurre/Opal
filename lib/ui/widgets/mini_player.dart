import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../player/playback_controller.dart';
import '../theme/app_theme.dart';

/// A compact mini-player bar that appears above the bottom navigation.
/// Features a Liquid Glass frosted look with progress indicator.
class MiniPlayer extends StatelessWidget {
  final VoidCallback onTap;

  const MiniPlayer({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaybackController>(
      builder: (context, pc, _) {
        final track = pc.currentTrack;
        if (track == null) return const SizedBox.shrink();

        final progress = pc.duration.inMilliseconds > 0
            ? pc.position.inMilliseconds / pc.duration.inMilliseconds
            : 0.0;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.10),
                        Colors.white.withOpacity(0.03),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                      width: 0.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 18,
                        spreadRadius: -4,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            // Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 46,
                                height: 46,
                                child: track.thumbnailUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: track.thumbnailUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            _placeholder(),
                                      )
                                    : _placeholder(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Track info
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            // Controls
                            IconButton(
                              onPressed: pc.previous,
                              icon: const Icon(Icons.skip_previous_rounded,
                                  color: Colors.white, size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                            ),
                            IconButton(
                              onPressed: pc.togglePlayPause,
                              icon: Icon(
                                pc.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 40, minHeight: 40),
                            ),
                            IconButton(
                              onPressed: pc.next,
                              icon: const Icon(Icons.skip_next_rounded,
                                  color: Colors.white, size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ),
                      ),
                      // Progress bar
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16)),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 2.5,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.surfaceElevated,
      child: const Icon(Icons.music_note_rounded,
          color: AppTheme.textTertiary, size: 20),
    );
  }
}
