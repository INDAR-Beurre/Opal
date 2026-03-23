import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../player/playback_controller.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../theme/app_theme.dart';
import '../../widgets/track_tile.dart';

/// Library tab — shows recently played, queue, and favourites.
/// When signed in with Google, shows user's YTM playlists & liked songs.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pc = context.watch<PlaybackController>();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: MediaQuery.of(context).padding.top + 16,
                bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Library',
                    style: Theme.of(context).textTheme.headlineLarge),
                LiquidGlassIconButton(
                  icon: Icons.settings_rounded,
                  size: 40,
                  iconSize: 20,
                  iconColor: AppTheme.textSecondary,
                  onPressed: () => Navigator.of(context).pushNamed('/settings'),
                ),
              ],
            ),
          ),
        ),
        // Quick action cards
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _QuickCard(
                    icon: Icons.favorite_rounded,
                    label: 'Liked Songs',
                    color: const Color(0xFFFF6B8A),
                    onTap: () {
                      // TODO: Fetch liked songs from YTM if signed in
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sign in to see your liked songs'),
                          backgroundColor: AppTheme.surfaceElevated,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickCard(
                    icon: Icons.history_rounded,
                    label: 'History',
                    color: AppTheme.primaryAccent,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sign in to see your history'),
                          backgroundColor: AppTheme.surfaceElevated,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickCard(
                    icon: Icons.download_rounded,
                    label: 'Downloads',
                    color: AppTheme.secondaryAccent,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Download feature coming soon'),
                          backgroundColor: AppTheme.surfaceElevated,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // Current queue section
        if (pc.queue.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 20, right: 20, top: 28, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Current Queue',
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text('${pc.queue.length} tracks',
                      style: const TextStyle(
                          color: AppTheme.textTertiary, fontSize: 12)),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final track = pc.queue[i];
                return TrackTile(
                  track: track,
                  isPlaying: i == pc.currentIndex,
                  onTap: () => pc.playAtIndex(i),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textTertiary, size: 16),
                    onPressed: () => pc.removeFromQueue(i),
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                );
              },
              childCount: pc.queue.length,
            ),
          ),
        ],
        // Empty state
        if (pc.queue.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.library_music_rounded,
                      size: 56, color: Colors.white.withOpacity(0.15)),
                  const SizedBox(height: 14),
                  const Text('Your library is empty',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 15)),
                  const SizedBox(height: 6),
                  const Text(
                      'Start playing music or sign in to sync your YouTube Music library',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textTertiary, fontSize: 12)),
                ],
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 160)),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassContainer(
        borderRadius: 16,
        intensity: 0.5,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        tintColor: color.withOpacity(0.08),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
