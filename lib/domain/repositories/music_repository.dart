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
  String _audioQuality;

  MusicRepository({InnerTubeService? service, String audioQuality = 'best'})
      : _service = service ?? InnerTubeService(),
        _audioQuality = audioQuality;

  void setCookie(String? cookie) => _service.setCookie(cookie);
  void setRegion(String region) => _service.setRegion(region);
  void setAudioQuality(String quality) => _audioQuality = quality;
  bool get isLoggedIn => _service.isLoggedIn;

  // ─── Search ───
  Future<SearchResponse> search(String query, {String? filter}) =>
      _service.search(query, filter: filter);

  Future<SearchResponse> searchContinuation(String continuation) =>
      _service.searchContinuation(continuation);

  Future<List<String>> searchSuggestions(String query) =>
      _service.searchSuggestions(query);

  // ─── Browse ───
  Future<HomePageResponse> getHomePage() => _service.getHomePage();

  Future<List<HomeSection>> getHomePageContinuation(String continuation) =>
      _service.getHomePageContinuation(continuation);

  Future<ArtistPage> getArtist(String browseId) =>
      _service.getArtist(browseId);

  Future<Album> getAlbum(String browseId) => _service.getAlbum(browseId);

  Future<Playlist> getPlaylist(String playlistId) =>
      _service.getPlaylist(playlistId);

  Future<PlaylistContinuation> getPlaylistContinuation(
          String continuation) =>
      _service.getPlaylistContinuation(continuation);

  Future<List<HomeSection>> getCharts() => _service.getCharts();

  Future<List<MoodCategory>> getMoodsAndGenres() =>
      _service.getMoodsAndGenres();

  Future<List<HomeSection>> getMoodPlaylists(String params) =>
      _service.getMoodPlaylists(params);

  Future<List<HomeSection>> getNewReleases() => _service.getNewReleases();

  // ─── Player ───
  Future<StreamInfo?> getStreamInfo(String videoId) =>
      _service.getStreamInfo(videoId, audioQuality: _audioQuality);

  // ─── Next / Queue ───
  Future<NextResponse> getNext(String videoId, {String? playlistId}) =>
      _service.getNext(videoId, playlistId: playlistId);

  Future<List<Track>> getRelatedTracks(String videoId) async {
    final response = await _service.getNext(videoId);
    return response.queue;
  }

  // ─── Library ───
  Future<void> likeSong(String videoId) => _service.likeSong(videoId);
  Future<void> unlikeSong(String videoId) => _service.unlikeSong(videoId);

  Future<String?> createPlaylist(String title,
          {List<String> videoIds = const []}) =>
      _service.createPlaylist(title, videoIds: videoIds);

  Future<void> deletePlaylist(String playlistId) =>
      _service.deletePlaylist(playlistId);

  Future<void> addToPlaylist(String playlistId, List<String> videoIds) =>
      _service.addToPlaylist(playlistId, videoIds);

  Future<Map<String, dynamic>?> getAccountInfo() =>
      _service.getAccountInfo();

  Future<List<Playlist>> getLibraryPlaylists() =>
      _service.getLibraryPlaylists();

  Future<Playlist> getLikedSongs() => _service.getLikedSongs();

  Future<List<Track>> getHistory() => _service.getHistory();

  /// Resolve a track's stream URL.
  Future<Track> resolveStreamUrl(Track track) async {
    if (track.streamUrl != null && track.streamUrl!.isNotEmpty) return track;
    final info = await getStreamInfo(track.id);
    return track.copyWith(streamUrl: info?.url);
  }

  void dispose() => _service.dispose();
}
