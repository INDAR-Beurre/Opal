import 'track.dart';

class Playlist {
  final String id;
  final String title;
  final String? uploaderName;
  final String? thumbnailUrl;
  final int trackCount;
  final List<Track> tracks;

  const Playlist({
    required this.id,
    required this.title,
    this.uploaderName,
    this.thumbnailUrl,
    this.trackCount = 0,
    this.tracks = const [],
  });
}
