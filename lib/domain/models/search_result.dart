enum SearchResultType { song, artist, album, playlist, video }

class SearchResult {
  final String id;
  final String title;
  final String? artist;
  final String subtitle;
  final String thumbnailUrl;
  final int durationSeconds;
  final SearchResultType type;
  final String? browseId;

  const SearchResult({
    required this.id,
    required this.title,
    this.artist,
    this.subtitle = '',
    this.thumbnailUrl = '',
    this.durationSeconds = 0,
    this.type = SearchResultType.song,
    this.browseId,
  });
}
