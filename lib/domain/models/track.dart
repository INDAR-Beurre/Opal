/// Represents a single music track / song.
class Track {
  final String id; // YouTube video ID
  final String title;
  final String artist;
  final String? album;
  final int durationSeconds;
  final String thumbnailUrl;
  final String? streamUrl;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.durationSeconds = 0,
    this.thumbnailUrl = '',
    this.streamUrl,
  });

  Duration get duration => Duration(seconds: durationSeconds);

  String get formattedDuration {
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    final s = duration.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// High-quality thumbnail (YouTube provides multiple sizes)
  String get highResThumbnail {
    if (thumbnailUrl.contains('lh3.googleusercontent.com') ||
        thumbnailUrl.contains('yt3.ggpht.com')) {
      // YouTube Music thumbnail — request high res
      return thumbnailUrl.replaceAll(RegExp(r'=w\d+-h\d+'), '=w500-h500');
    }
    return thumbnailUrl;
  }

  Track copyWith({String? streamUrl}) {
    return Track(
      id: id,
      title: title,
      artist: artist,
      album: album,
      durationSeconds: durationSeconds,
      thumbnailUrl: thumbnailUrl,
      streamUrl: streamUrl ?? this.streamUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Track && other.id == id);
  @override
  int get hashCode => id.hashCode;
}
