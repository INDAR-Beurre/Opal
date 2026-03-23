import 'track.dart';

class Album {
  final String id; // Browse ID
  final String title;
  final String? artist;
  final String? thumbnailUrl;
  final List<Track> tracks;
  final String? year;
  final String? playlistId;

  const Album({
    required this.id,
    required this.title,
    this.artist,
    this.thumbnailUrl,
    this.tracks = const [],
    this.year,
    this.playlistId,
  });

  String get subtitle {
    final parts = <String>[];
    if (artist != null && artist!.isNotEmpty) parts.add(artist!);
    if (year != null) parts.add(year!);
    return parts.join(' \u2022 ');
  }

  Duration get totalDuration =>
      Duration(seconds: tracks.fold(0, (sum, t) => sum + t.durationSeconds));
}
