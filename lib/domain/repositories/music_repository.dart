import '../../data/innertube/innertube_service.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/search_result.dart';
import '../models/home_section.dart';

/// Repository abstraction over the InnerTube service.
class MusicRepository {
  final InnerTubeService _service;

  MusicRepository({InnerTubeService? service})
      : _service = service ?? InnerTubeService();

  void setCookie(String? cookie) => _service.setCookie(cookie);

  Future<List<SearchResult>> search(String query, {String? filter}) =>
      _service.search(query, filter: filter);

  Future<List<String>> searchSuggestions(String query) =>
      _service.searchSuggestions(query);

  Future<List<HomeSection>> getHomePage() => _service.getHomePage();

  Future<Artist> getArtist(String channelId) => _service.getArtist(channelId);

  Future<Album> getAlbum(String browseId) => _service.getAlbum(browseId);

  Future<Playlist> getPlaylist(String playlistId) =>
      _service.getPlaylist(playlistId);

  Future<String?> getStreamUrl(String videoId) =>
      _service.getStreamUrl(videoId);

  Future<List<Track>> getRelatedTracks(String videoId) =>
      _service.getRelatedTracks(videoId);

  Future<List<Track>> getTrending() => _service.getTrending();

  /// Resolve a track's stream URL.
  Future<Track> resolveStreamUrl(Track track) async {
    if (track.streamUrl != null && track.streamUrl!.isNotEmpty) return track;
    final url = await getStreamUrl(track.id);
    return track.copyWith(streamUrl: url);
  }
}
