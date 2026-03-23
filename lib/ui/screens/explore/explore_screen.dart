import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/models/track.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../player/playback_controller.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../theme/app_theme.dart';
import '../../widgets/track_tile.dart';

/// Explore tab — shows trending / charts from InnerTube.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with AutomaticKeepAliveClientMixin {
  List<Track> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<MusicRepository>();
      final tracks = await repo.getTrending();
      if (mounted) {
        setState(() {
          _tracks = tracks;
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

    return CustomScrollView(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: MediaQuery.of(context).padding.top + 16,
                bottom: 8),
            child: Text('Explore',
                style: Theme.of(context).textTheme.headlineLarge),
          ),
        ),
        // Genre chips
        SliverToBoxAdapter(
          child: SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              children: [
                _GenreChip(
                    label: 'Pop',
                    color: const Color(0xFF7EB8FF),
                    icon: Icons.star_rounded),
                _GenreChip(
                    label: 'Hip-Hop',
                    color: const Color(0xFFFF8A65),
                    icon: Icons.mic_rounded),
                _GenreChip(
                    label: 'Electronic',
                    color: const Color(0xFF9EE4D0),
                    icon: Icons.surround_sound_rounded),
                _GenreChip(
                    label: 'Rock',
                    color: const Color(0xFFFF6B8A),
                    icon: Icons.music_note_rounded),
                _GenreChip(
                    label: 'Classical',
                    color: const Color(0xFFB39DDB),
                    icon: Icons.piano_rounded),
                _GenreChip(
                    label: 'Jazz',
                    color: const Color(0xFFFFD54F),
                    icon: Icons.nightlife_rounded),
              ],
            ),
          ),
        ),
        // Trending header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 8),
            child: Text('Trending',
                style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
        // Content
        if (_loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
                child:
                    CircularProgressIndicator(color: AppTheme.primaryAccent)),
          )
        else if (_error != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded,
                      size: 48, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 12),
                  const Text('Could not load trending',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed: _loadTrending,
                      child: const Text('Retry')),
                ],
              ),
            ),
          )
        else if (_tracks.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.explore_rounded,
                      size: 48, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 12),
                  const Text('No trending content available',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
          )
        else ...[
          // Top 3 featured
          if (_tracks.length >= 3)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _tracks.take(10).length,
                  itemBuilder: (context, i) {
                    final t = _tracks[i];
                    return _FeaturedCard(
                      track: t,
                      rank: i + 1,
                      onTap: () {
                        context
                            .read<PlaybackController>()
                            .setQueue(_tracks, startIndex: i);
                      },
                    );
                  },
                ),
              ),
            ),
          // Full list
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 20, right: 20, top: 24, bottom: 8),
              child: Text('All Trending',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
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
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 160)),
      ],
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _GenreChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: LiquidGlassContainer(
        borderRadius: 16,
        intensity: 0.5,
        tintColor: color.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Track track;
  final int rank;
  final VoidCallback onTap;

  const _FeaturedCard({
    required this.track,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: LiquidGlassCard(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          borderRadius: 16,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              errorWidget: (_, __, ___) =>
                                  Container(color: AppTheme.surfaceElevated),
                            )
                          : Container(color: AppTheme.surfaceElevated),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 3),
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
              // Rank badge
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('#$rank',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
