import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../player/playback_controller.dart';
import '../liquid_glass/liquid_glass.dart';
import '../widgets/mini_player.dart';
import 'home/home_screen.dart';
import 'search/search_screen.dart';
import 'explore/explore_screen.dart';
import 'library/library_screen.dart';
import 'now_playing/now_playing_screen.dart';

/// The main app shell with 4 tabs and the persistent mini-player.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentTab = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    ExploreScreen(),
    LibraryScreen(),
  ];

  void _onTabTap(int i) {
    setState(() => _currentTab = i);
  }

  void _openNowPlaying() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const NowPlayingScreen(),
        transitionsBuilder: (_, anim, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTrack =
        context.watch<PlaybackController>().currentTrack != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: IndexedStack(
        index: _currentTab,
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasTrack)
            MiniPlayer(onTap: _openNowPlaying),
          LiquidGlassBottomBar(
            currentIndex: _currentTab,
            onTap: _onTabTap,
          ),
        ],
      ),
    );
  }
}
