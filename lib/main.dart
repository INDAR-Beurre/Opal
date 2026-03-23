import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'domain/repositories/music_repository.dart';
import 'player/playback_controller.dart';
import 'ui/screens/settings/settings_provider.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/app_shell.dart';
import 'ui/screens/now_playing/now_playing_screen.dart';
import 'ui/screens/playlist_detail/playlist_detail_screen.dart';
import 'ui/screens/artist/artist_screen.dart';
import 'ui/screens/login/login_screen.dart';
import 'ui/screens/settings/settings_screen.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Init settings
  final settings = SettingsProvider();
  await settings.init();

  // Create repository and apply saved settings
  final repo = MusicRepository();
  if (settings.cookie != null) {
    repo.setCookie(settings.cookie);
  }
  repo.setRegion(settings.region);
  repo.setAudioQuality(settings.audioQuality);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        Provider<MusicRepository>.value(value: repo),
        ChangeNotifierProvider(
          create: (_) => PlaybackController(repository: repo),
        ),
      ],
      child: const OpalApp(),
    ),
  );
}

class OpalApp extends StatelessWidget {
  const OpalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Opal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
                builder: (_) => const SplashScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => const AppShell());
          case '/now_playing':
            return PageRouteBuilder(
              pageBuilder: (_, __, ___) => const NowPlayingScreen(),
              transitionsBuilder: (_, anim, __, child) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                    parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 350),
            );
          case '/playlist_detail':
            final browseId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => PlaylistDetailScreen(browseId: browseId),
            );
          case '/artist':
            final channelId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => ArtistScreen(channelId: channelId),
            );
          case '/login':
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
          case '/settings':
            return MaterialPageRoute(
              builder: (_) => const SettingsScreen(),
            );
          default:
            return MaterialPageRoute(builder: (_) => const AppShell());
        }
      },
    );
  }
}
