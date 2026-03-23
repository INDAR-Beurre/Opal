import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/innertube/innertube_service.dart'
    show MoodCategory, MoodItem;
import '../../../domain/models/home_section.dart';
import '../../../domain/models/track.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../player/playback_controller.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../widgets/section_header.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/error_view.dart';
import '../../theme/app_theme.dart';

/// Explore screen showing moods/genres and charts/trending content.
///
/// Fetches data from [MusicRepository.getMoodsAndGenres] and
/// [MusicRepository.getCharts], displaying mood chips in a [Wrap] and
/// chart sections as horizontal scrolling carousels.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with AutomaticKeepAliveClientMixin {
  List<MoodCategory> _moodCategories = [];
  List<HomeSection> _chartSections = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  // ── Data fetching ──

  Future<void> _loadContent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<MusicRepository>();
      final results = await Future.wait([
        repo.getMoodsAndGenres(),
        repo.getCharts(),
      ]);
      if (mounted) {
        setState(() {
          _moodCategories = results[0] as List<MoodCategory>;
          _chartSections = results[1] as List<HomeSection>;
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

  // ── Track interaction ──

  void _onTrackTap(Track track, List<Track> siblings, int index) {
    if (track.isPlayable) {
      context.read<PlaybackController>().setQueue(siblings, startIndex: index);
    } else if (track.browseId != null) {
      Navigator.of(context).pushNamed(
        '/playlist_detail',
        arguments: {'browseId': track.browseId},
      );
    }
  }

  void _onMoodTap(MoodItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(item.title),
        backgroundColor: AppTheme.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildLoadingState();
    if (_error != null) return _buildErrorState();
    return _buildContent();
  }

  // ── Loading state ──

  Widget _buildLoadingState() {
    return SafeArea(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16),
        children: [
          _buildTitle(),
          const SizedBox(height: 16),
          // Shimmer chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                8,
                (_) => const ShimmerLoading(
                  width: 90,
                  height: 36,
                  borderRadius: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const ShimmerCardSection(),
          const SizedBox(height: 24),
          const ShimmerCardSection(),
        ],
      ),
    );
  }

  // ── Error state ──

  Widget _buildErrorState() {
    return SafeArea(
      child: Column(
        children: [
          _buildTitle(),
          const Spacer(),
          ErrorView(
            message: _error!.length > 120
                ? '${_error!.substring(0, 120)}...'
                : _error!,
            onRetry: _loadContent,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ── Success content ──

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadContent,
      color: AppTheme.primaryAccent,
      backgroundColor: AppTheme.surfaceElevated,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Title
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: _buildTitle(),
            ),
          ),

          // Moods & Genres
          if (_moodCategories.isNotEmpty) ...[
            for (final category in _moodCategories) ...[
              SliverToBoxAdapter(
                child: SectionHeader(title: category.title),
              ),
              SliverToBoxAdapter(
                child: _buildMoodChips(category.items),
              ),
            ],
          ],

          // Charts / Trending sections
          if (_chartSections.isNotEmpty) ...[
            for (final section in _chartSections) ...[
              SliverToBoxAdapter(
                child: SectionHeader(title: section.title),
              ),
              SliverToBoxAdapter(
                child: _buildHorizontalTrackList(section.tracks),
              ),
            ],
          ],

          // Empty state
          if (_moodCategories.isEmpty && _chartSections.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No explore content available',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),

          // Bottom spacing for mini-player + nav bar
          const SliverToBoxAdapter(child: SizedBox(height: 160)),
        ],
      ),
    );
  }

  // ── Title ──

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        'Explore',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
    );
  }

  // ── Mood / Genre chips ──

  Widget _buildMoodChips(List<MoodItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          return LiquidGlassChip(
            label: item.title,
            onTap: () => _onMoodTap(item),
          );
        }).toList(),
      ),
    );
  }

  // ── Horizontal scrolling track list ──

  Widget _buildHorizontalTrackList(List<Track> tracks) {
    if (tracks.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          return _TrackCard(
            track: track,
            onTap: () => _onTrackTap(track, tracks, index),
          );
        },
      ),
    );
  }
}

/// A single track card rendered as a LiquidGlass surface with thumbnail,
/// title and artist. Shared across chart sections.
class _TrackCard extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;

  const _TrackCard({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      onTap: onTap,
      width: 155,
      borderRadius: 16,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
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
                      placeholder: (_, __) => Container(
                        color: AppTheme.surfaceElevated,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => _thumbnailPlaceholder(),
                    )
                  : _thumbnailPlaceholder(),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
            child: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),

          // Artist
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnailPlaceholder() {
    return Container(
      color: AppTheme.surfaceElevated,
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppTheme.textTertiary,
          size: 32,
        ),
      ),
    );
  }
}
