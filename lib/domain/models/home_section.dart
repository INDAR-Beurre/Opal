import 'track.dart';

/// A section on the home screen (e.g., "Quick picks", "Listen again").
class HomeSection {
  final String title;
  final List<Track> tracks;

  const HomeSection({
    required this.title,
    required this.tracks,
  });
}
