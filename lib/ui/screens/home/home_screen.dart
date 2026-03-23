import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../domain/models/home_section.dart';
import '../../../domain/models/track.dart';
import '../../../player/playback_controller.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../widgets/section_header.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/error_view.dart';
import '../../theme/app_theme.dart';

/// Home screen displaying personalised sections from InnerTube.
///
/// Shows a time-based greeting, a settings shortcut, and horizontally
/// scrolling card carousels for each [HomeSection]. Supports pull-to-refresh
/// and continuation loading.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  List<HomeSection> _sections = [];
  String? _continuation;
  bool _loading = true;
  String? _error;
  bool _loadingMore = false;

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
      final response = await repo.getHomePage();
      if (mounted) {
        setState(() {
          _sections = response.sections;
          _continuation = response.continuation;
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

  Future<void> _loadMore() async {
    if (_loadingMore || _continuation == null) return;
    setState(() => _loadingMore = true);
    try {
      final repo = context.read<MusicRepository>();
      final moreSections =
          await repo.getHomePageContinuation(_continuation!);
      if (mounted) {
        setState(() {
          _sections.addAll(moreSections);
          // Continuation is consumed; further pages would need their own token.
          _continuation = null;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ── Greeting ──

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  // ── Track interaction ──

  void _onTrackTap(Track track) {
    if (track.isPlayable) {
      context.read<PlaybackController>().playTrack(track);
    } else if (track.browseId != null) {
      Navigator.of(context).pushNamed(
        '/playlist_detail',
        arguments: {'browseId': track.browseId},
      );
    }
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
          _buildHeader(),
          const SizedBox(height: 12),
          const ShimmerCardSection(),
          const SizedBox(height: 24),
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
          _buildHeader(),
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
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
            _loadMore();
          }
          return false;
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: _buildHeader(),
              ),
            ),

            // Sections
            for (final section in _sections) ...[
              SliverToBoxAdapter(
                child: SectionHeader(title: section.title),
              ),
              SliverToBoxAdapter(
                child: _buildHorizontalTrackList(section.tracks),
              ),
            ],

            // Continuation loader
            if (_loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryAccent,
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom spacing for mini-player + nav bar
            const SliverToBoxAdapter(child: SizedBox(height: 160)),
          ],
        ),
      ),
    );
  }

  // ── Header with greeting + settings ──

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _greeting(),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_rounded,
              color: AppTheme.textSecondary,
            ),
            splashRadius: 22,
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
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
            onTap: () => _onTrackTap(track),
          );
        },
      ),
    );
  }
}

/// A single track card rendered as a LiquidGlass surface with thumbnail,
/// title and artist.
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
