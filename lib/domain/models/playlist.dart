import 'track.dart';

class Playlist {
  final String id;
  final String title;
  final String? uploaderName;
  final String? thumbnailUrl;
  final int trackCount;
  final List<Track> tracks;
  final String? continuation;
  final String? description;

  const Playlist({
    required this.id,
    required this.title,
    this.uploaderName,
    this.thumbnailUrl,
    this.trackCount = 0,
    this.tracks = const [],
    this.continuation,
    this.description,
  });

  Duration get totalDuration =>
      Duration(seconds: tracks.fold(0, (sum, t) => sum + t.durationSeconds));
}
