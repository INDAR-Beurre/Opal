# LiquidGlass Music v2.0

A stunning YouTube Music client built with Flutter, featuring a **Liquid Glass** UI aesthetic inspired by CSS liquid glass demos — frosted blur layers, specular highlights, edge glow, and depth shadows.

## What's New in v2

- **InnerTube API** — Direct access to YouTube Music's internal API (same one the web app uses). No third-party backend needed.
- **Piped API fallback** — If InnerTube stream extraction fails, falls back to Piped instances.
- **Google sign-in (cookie-based)** — Sign in with your YouTube Music account to sync your library, playlists, and history. Privacy-first: cookie stored locally only.
- **5-layer Liquid Glass widget system** — Backdrop blur (refraction), tint wash, specular shine, edge highlights, and content. Inspired by DaftPlug, David Lassiter, and Maxuiux CSS demos.
- **4-tab navigation** — Home, Search, Explore (trending/charts), Library.
- **Full now-playing screen** — Giant album art with blurred background, Liquid Glass controls, seek bar, shuffle/repeat, queue viewer.
- **Mini player** — Persistent glassmorphic mini player with progress bar.
- **Auto-queue** — Automatically loads related tracks when near end of queue.
- **Search with filters** — Songs, Artists, Albums, Playlists, Videos filters with autocomplete suggestions.
- **Settings** — Audio quality, content region, account management.
- **Custom app icon** — Liquid glass play button icon at all Android densities.
- **Connectivity fix** — Proper internet permission and cleartext traffic enabled.

## Architecture

```
lib/
├── config/
│   └── backend_config.dart          # InnerTube + Piped API configuration
├── data/
│   └── innertube/
│       ├── innertube_client.dart     # Low-level HTTP client
│       ├── innertube_service.dart    # High-level API service
│       └── innertube_parser.dart     # JSON response parser (~680 lines)
├── domain/
│   ├── models/                      # Track, Playlist, Album, Artist, etc.
│   └── repositories/
│       └── music_repository.dart    # Repository abstraction
├── player/
│   └── playback_controller.dart     # Audio player, queue, shuffle, repeat
├── ui/
│   ├── liquid_glass/                # Reusable Liquid Glass widgets
│   │   ├── liquid_glass_container.dart  # 5-layer glass container
│   │   ├── liquid_glass_card.dart
│   │   ├── liquid_glass_app_bar.dart
│   │   ├── liquid_glass_bottom_bar.dart # 4-tab pill nav
│   │   ├── liquid_glass_button.dart
│   │   └── liquid_glass_bottom_sheet.dart
│   ├── theme/
│   │   └── app_theme.dart           # Dark theme with glass colours
│   ├── widgets/
│   │   ├── track_tile.dart          # Track list item with playing indicator
│   │   └── mini_player.dart         # Persistent mini player
│   └── screens/
│       ├── home/                    # Home page with sections + trending
│       ├── search/                  # Search with autocomplete + filters
│       ├── explore/                 # Trending charts + genre chips
│       ├── library/                 # Queue, liked songs, history
│       ├── now_playing/             # Full-screen player
│       ├── playlist_detail/         # Album/playlist detail
│       ├── artist/                  # Artist page
│       ├── login/                   # Cookie-based Google auth
│       ├── settings/                # Settings + preferences
│       ├── splash_screen.dart       # Animated splash
│       └── app_shell.dart           # Tab shell + mini player
└── main.dart
```

## Build & Run

```bash
flutter pub get
flutter run
```

## InnerTube API

This app communicates directly with YouTube Music's InnerTube API:
- **Base URL**: `https://music.youtube.com/youtubei/v1/`
- **Client**: WEB_REMIX (client ID 67) for browse/search, WEB for player
- **Endpoints**: `search`, `browse` (home/artist/album/playlist), `player`, `next`
- **Auth**: Optional cookie-based (paste from browser DevTools)

## Dependencies

| Package | Purpose |
|---------|---------|
| provider | State management |
| just_audio | Audio playback |
| audio_service | Background playback |
| http | Network requests |
| cached_network_image | Image caching |
| shared_preferences | Local settings storage |
| url_launcher | External links |

## Credits

- UI inspired by CSS liquid glass demos by DaftPlug, David Lassiter, and Maxuiux
- InnerTube API patterns informed by the [Metrolist](https://github.com/MetrolistGroup/Metrolist) project
- Stream URL fallback via [Piped](https://piped.video/) API
