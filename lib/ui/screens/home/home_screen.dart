import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/models/home_section.dart';
import '../../../domain/models/track.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../player/playback_controller.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../theme/app_theme.dart';
import '../../widgets/track_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  List<HomeSection> _sections = [];
  List<Track> _trending = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<MusicRepository>();
      final results = await Future.wait([
        repo.getHomePage(),
        repo.getTrending(),
      ]);
      if (mounted) {
        setState(() {
          _sections = results[0] as List<HomeSection>;
          _trending = results[1] as List<Track>;
          _loading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryAccent),
      );
    }
    if (_error != null) {
      return _ErrorView(error: _error!, onRetry: _loadContent);
    }
    return RefreshIndicator(
      onRefresh: _loadContent,
      color: AppTheme.primaryAccent,
      backgroundColor: AppTheme.surfaceElevated,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // Greeting header
          SliverToBoxAdapter(child: _buildGreeting()),
          // Trending carousel
          if (_trending.isNotEmpty)
            SliverToBoxAdapter(child: _buildTrendingCarousel()),
          // Home sections
          for (final section in _sections) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.only(left: 20, right: 20, top: 28, bottom: 10),
                child: Text(section.title,
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
            ),
            SliverToBoxAdapter(child: _buildSectionGrid(section)),
          ],
          // Bottom padding for mini-player + nav bar
          const SliverToBoxAdapter(child: SizedBox(height: 160)),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 18) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: MediaQuery.of(context).padding.top + 16,
          bottom: 12),
      child: Text(greeting,
          style: Theme.of(context).textTheme.headlineLarge),
    );
  }

  Widget _buildTrendingCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 12, top: 8),
          child: Text('Trending Now',
              style: Theme.of(context).textTheme.headlineSmall),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _trending.take(15).length,
            itemBuilder: (context, i) {
              final track = _trending[i];
              return _TrendingCard(
                track: track,
                onTap: () {
                  context
                      .read<PlaybackController>()
                      .setQueue(_trending, startIndex: i);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionGrid(HomeSection section) {
    final tracks = section.tracks;
    if (tracks.length <= 4) {
      // Vertical list for small sections
      return Column(
        children: tracks
            .map((t) => TrackTile(
                  track: t,
                  onTap: () {
                    context
                        .read<PlaybackController>()
                        .setQueue(tracks, startIndex: tracks.indexOf(t));
                  },
                  isPlaying:
                      context.watch<PlaybackController>().currentTrack?.id ==
                          t.id,
                ))
            .toList(),
      );
    }
    // Horizontal scroll for bigger sections
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: tracks.length,
        itemBuilder: (context, i) {
          return _TrendingCard(
            track: tracks[i],
            onTap: () {
              context
                  .read<PlaybackController>()
                  .setQueue(tracks, startIndex: i);
            },
          );
        },
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;

  const _TrendingCard({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 155,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: LiquidGlassCard(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album art
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: track.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: track.highResThumbnail,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _artPlaceholder(),
                        )
                      : _artPlaceholder(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Text(track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _artPlaceholder() {
    return Container(
      color: AppTheme.surfaceElevated,
      child: const Center(
          child: Icon(Icons.music_note_rounded,
              color: AppTheme.textTertiary, size: 32)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 56, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('Could not load content',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              error.length > 120 ? '${error.substring(0, 120)}...' : error,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
