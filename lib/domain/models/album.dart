import 'track.dart';

class Album {
  final String id;
  final String title;
  final String? artist;
  final String? thumbnailUrl;
  final List<Track> tracks;

  const Album({
    required this.id,
    required this.title,
    this.artist,
    this.thumbnailUrl,
    this.tracks = const [],
  });
}
