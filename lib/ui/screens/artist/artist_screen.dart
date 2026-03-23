import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../liquid_glass/liquid_glass.dart';
import '../../theme/app_theme.dart';

class ArtistScreen extends StatefulWidget {
  final String channelId;
  const ArtistScreen({super.key, required this.channelId});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  Artist? _artist;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<MusicRepository>();
      final artist = await repo.getArtist(widget.channelId);
      if (mounted) setState(() { _artist = artist; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.surfaceBase,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
      );
    }
    if (_error != null || _artist == null) {
      return Scaffold(
        backgroundColor: AppTheme.surfaceBase,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load artist',
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              TextButton(onPressed: _load, child: const Text('Retry')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go back')),
            ],
          ),
        ),
      );
    }

    final artist = _artist!;
    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(artist)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(artist.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  if (artist.subscriberCount != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${artist.subscriberCount} subscribers',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                    ),
                  const SizedBox(height: 20),
                  // Placeholder for songs / albums sections
                  LiquidGlassContainer(
                    borderRadius: 20,
                    intensity: 0.5,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.music_note_rounded,
                            color: AppTheme.textTertiary, size: 32),
                        const SizedBox(height: 10),
                        const Text(
                          'Full artist page coming soon.\nSearch for songs by this artist.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 160)),
        ],
      ),
    );
  }

  Widget _buildHeader(Artist artist) {
    return Stack(
      children: [
        if (artist.thumbnailUrl != null && artist.thumbnailUrl!.isNotEmpty)
          SizedBox(
            height: 280,
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: artist.thumbnailUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  Container(color: AppTheme.surfaceElevated),
            ),
          )
        else
          Container(height: 280, color: AppTheme.surfaceElevated),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.2),
                    AppTheme.surfaceBase,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          child: LiquidGlassIconButton(
            icon: Icons.arrow_back_rounded,
            size: 40,
            iconSize: 20,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}
