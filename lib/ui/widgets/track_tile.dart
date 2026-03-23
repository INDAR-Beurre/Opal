import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/models/track.dart';
import '../theme/app_theme.dart';

/// A single track row used in lists, search results, playlists, etc.
class TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isPlaying;
  final bool showThumbnail;
  final Widget? trailing;

  const TrackTile({
    super.key,
    required this.track,
    this.onTap,
    this.onLongPress,
    this.isPlaying = false,
    this.showThumbnail = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (showThumbnail) ...[
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: track.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: track.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppTheme.surfaceElevated,
                            child: const Icon(Icons.music_note_rounded,
                                color: AppTheme.textTertiary, size: 24),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.surfaceElevated,
                            child: const Icon(Icons.music_note_rounded,
                                color: AppTheme.textTertiary, size: 24),
                          ),
                        )
                      : Container(
                          color: AppTheme.surfaceElevated,
                          child: const Icon(Icons.music_note_rounded,
                              color: AppTheme.textTertiary, size: 24),
                        ),
                ),
              ),
              const SizedBox(width: 14),
            ],
            // Title + artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaying
                          ? AppTheme.primaryAccent
                          : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight:
                          isPlaying ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Duration
            if (track.durationSeconds > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  track.formattedDuration,
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 12),
                ),
              ),
            // Trailing widget (e.g. more button)
            if (trailing != null) trailing!,
            // Now-playing indicator
            if (isPlaying)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: _PlayingBars(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Simple animated equaliser bars for now-playing indicator.
class _PlayingBars extends StatefulWidget {
  const _PlayingBars();

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(3, (i) {
            final height =
                6.0 + 8.0 * ((_ctrl.value + i * 0.3) % 1.0);
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.only(left: 1),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}
