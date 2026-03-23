import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../domain/repositories/music_repository.dart';
import '../../../domain/models/track.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/artist.dart';
import '../../../data/innertube/innertube_service.dart' show ArtistPage, ArtistSection;
import '../../../player/playback_controller.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../widgets/track_tile.dart';
import '../../widgets/section_header.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/error_view.dart';
import '../../theme/app_theme.dart';

/// Artist screen with hero image, parallax scrolling, and dynamic sections
/// for songs, albums, and related artists.
class ArtistScreen extends StatefulWidget {
  final String channelId;

  const ArtistScreen({super.key, required this.channelId});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  static const double _heroHeight = 340.0;
  static const double _albumCardWidth = 150.0;
  static const double _albumCardHeight = 210.0;
  static const double _artistCircleSize = 90.0;

  late Future<ArtistPage> _artistFuture;

  @override
  void initState() {
    super.initState();
    _fetchArtist();
  }

  void _fetchArtist() {
    final repo = context.read<MusicRepository>();
    _artistFuture = repo.getArtist(widget.channelId);
  }

  void _retry() {
    setState(_fetchArtist);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
      body: FutureBuilder<ArtistPage>(
        future: _artistFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoading();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _buildError(
              snapshot.error?.toString() ?? 'Could not load artist',
            );
          }
          return _buildContent(snapshot.data!);
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Loading state with shimmer placeholders
  // -------------------------------------------------------------------------

  Widget _buildLoading() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: _heroHeight,
          pinned: true,
          backgroundColor: AppTheme.surfaceBase,
          leading: _backButton(),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: AppTheme.surfaceElevated,
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryAccent),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, __) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: ShimmerTrackTile(),
              ),
              childCount: 8,
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Error state with retry
  // -------------------------------------------------------------------------

  Widget _buildError(String message) {
    return Column(
      children: [
        AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _backButton(),
        ),
        Expanded(
          child: ErrorView(
            message: message,
            onRetry: _retry,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Loaded content
  // -------------------------------------------------------------------------

  Widget _buildContent(ArtistPage page) {
    final artist = page.artist;
    final sections = page.sections;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Hero app bar with parallax artist image
        _buildHeroAppBar(artist),

        // Artist name + subscriber count below the hero
        SliverToBoxAdapter(child: _buildArtistHeader(artist)),

        // Dynamic sections
        for (final section in sections) ..._buildSection(section),

        // Bottom padding so content isn't hidden behind mini-player
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Hero SliverAppBar with parallax
  // -------------------------------------------------------------------------

  SliverAppBar _buildHeroAppBar(Artist artist) {
    final imageUrl = artist.thumbnailUrl;

    return SliverAppBar(
      expandedHeight: _heroHeight,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.surfaceBase,
      leading: _backButton(),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: AppTheme.surfaceElevated),
                errorWidget: (_, __, ___) =>
                    Container(color: AppTheme.surfaceElevated),
              )
            else
              Container(color: AppTheme.surfaceElevated),

            // Gradient overlay for legibility
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x88000000),
                    AppTheme.surfaceBase,
                  ],
                  stops: [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Artist name + subscriber count
  // -------------------------------------------------------------------------

  Widget _buildArtistHeader(Artist artist) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            artist.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          if (artist.subscriberCount != null) ...[
            const SizedBox(height: 6),
            Text(
              '${artist.subscriberCount} subscribers',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Section dispatcher
  // -------------------------------------------------------------------------

  List<Widget> _buildSection(ArtistSection section) {
    if (section.items.isEmpty) return const [];

    final first = section.items.first;

    if (first is Track) {
      return _buildTrackSection(section);
    } else if (first is Album) {
      return _buildAlbumSection(section);
    } else if (first is Artist) {
      return _buildArtistCircleSection(section);
    }

    return const [];
  }

  // -------------------------------------------------------------------------
  // Track section (vertical list)
  // -------------------------------------------------------------------------

  List<Widget> _buildTrackSection(ArtistSection section) {
    final tracks = section.items.whereType<Track>().toList();
    final playback = context.read<PlaybackController>();

    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: section.title,
          onSeeAll: section.browseId != null
              ? () => Navigator.of(context).pushNamed(
                    '/playlist_detail',
                    arguments: section.browseId,
                  )
              : null,
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final track = tracks[index];
            return TrackTile(
              track: track,
              onTap: () => playback.setQueue(tracks, startIndex: index),
            );
          },
          childCount: tracks.length,
        ),
      ),
    ];
  }

  // -------------------------------------------------------------------------
  // Album section (horizontal scroll)
  // -------------------------------------------------------------------------

  List<Widget> _buildAlbumSection(ArtistSection section) {
    final albums = section.items.whereType<Album>().toList();

    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: section.title,
          onSeeAll: section.browseId != null
              ? () => Navigator.of(context).pushNamed(
                    '/playlist_detail',
                    arguments: section.browseId,
                  )
              : null,
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: _albumCardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: albums.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final album = albums[index];
              return _AlbumCard(
                album: album,
                width: _albumCardWidth,
                onTap: () => Navigator.of(context).pushNamed(
                  '/playlist_detail',
                  arguments: album.id,
                ),
              );
            },
          ),
        ),
      ),
    ];
  }

  // -------------------------------------------------------------------------
  // Artist section (horizontal circles)
  // -------------------------------------------------------------------------

  List<Widget> _buildArtistCircleSection(ArtistSection section) {
    final artists = section.items.whereType<Artist>().toList();

    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: section.title,
          onSeeAll: section.browseId != null
              ? () => Navigator.of(context).pushNamed(
                    '/artist',
                    arguments: section.browseId,
                  )
              : null,
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: _artistCircleSize + 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: artists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final artist = artists[index];
              return _ArtistCircle(
                artist: artist,
                size: _artistCircleSize,
                onTap: () => Navigator.of(context).pushNamed(
                  '/artist',
                  arguments: artist.id,
                ),
              );
            },
          ),
        ),
      ),
    ];
  }

  // -------------------------------------------------------------------------
  // Shared back button
  // -------------------------------------------------------------------------

  Widget _backButton() {
    return LiquidGlassIconButton(
      icon: Icons.arrow_back_rounded,
      size: 40,
      iconSize: 20,
      onPressed: () => Navigator.of(context).pop(),
    );
  }
}

// ===========================================================================
// Album card for horizontal scroll
// ===========================================================================

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({
    required this.album,
    required this.width,
    required this.onTap,
  });

  final Album album;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildThumbnail(),
            ),
            const SizedBox(height: 8),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              album.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final url = album.thumbnailUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: width,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: width,
      color: AppTheme.surfaceElevated,
      child: const Icon(
        Icons.album_rounded,
        color: AppTheme.textTertiary,
        size: 36,
      ),
    );
  }
}

// ===========================================================================
// Artist circle for horizontal scroll
// ===========================================================================

class _ArtistCircle extends StatelessWidget {
  const _ArtistCircle({
    required this.artist,
    required this.size,
    required this.onTap,
  });

  final Artist artist;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          children: [
            ClipOval(child: _buildThumbnail()),
            const SizedBox(height: 8),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final url = artist.thumbnailUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceElevated,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person_rounded,
        color: AppTheme.textTertiary,
        size: 32,
      ),
    );
  }
}
