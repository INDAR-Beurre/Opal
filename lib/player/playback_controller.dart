import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../domain/models/track.dart';
import '../domain/repositories/music_repository.dart';

enum RepeatMode { off, all, one }

/// Central playback controller with background audio support,
/// media session integration, and multi-source stream resolution.
class PlaybackController extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final MusicRepository _repository;

  List<Track> _queue = [];
  int _currentIndex = -1;
  bool _shuffle = false;
  RepeatMode _repeatMode = RepeatMode.off;
  List<int>? _shuffledIndices;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  PlaybackController({required MusicRepository repository})
      : _repository = repository {
    _initListeners();
    _initAudioSession();
  }

  AudioPlayer get audioPlayer => _audioPlayer;
  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  Track? get currentTrack =>
      _currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get bufferedPosition => _bufferedPosition;
  Duration get duration => _duration;
  bool get isLoading => _isLoading;
  bool get shuffle => _shuffle;
  RepeatMode get repeatMode => _repeatMode;
  String? get error => _error;
  bool get hasNext => _currentIndex < _queue.length - 1;
  bool get hasPrevious => _currentIndex > 0;
  bool get hasQueue => _queue.isNotEmpty;
  bool get isInitialized => _isInitialized;

  /// Initialize audio session for proper focus handling.
  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      // Handle audio interruptions
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          if (_isPlaying) pause();
        } else {
          if (event.type == AudioInterruptionType.pause) {
            play();
          }
        }
      });

      // Handle becoming noisy (headphones unplugged)
      session.becomingNoisyEventStream.listen((_) {
        if (_isPlaying) pause();
      });

      _isInitialized = true;
    } catch (_) {
      _isInitialized = true; // Continue even if session config fails
    }
  }

  void _initListeners() {
    _audioPlayer.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    _audioPlayer.bufferedPositionStream.listen((pos) {
      _bufferedPosition = pos;
      notifyListeners();
    });
    _audioPlayer.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _handleTrackComplete();
      }
      notifyListeners();
    });
  }

  void _handleTrackComplete() {
    if (_repeatMode == RepeatMode.one) {
      _audioPlayer.seek(Duration.zero);
      _audioPlayer.play();
    } else if (hasNext) {
      next();
    } else if (_repeatMode == RepeatMode.all && _queue.isNotEmpty) {
      _currentIndex = _shuffle && _shuffledIndices != null
          ? _shuffledIndices!.first
          : 0;
      _playCurrentTrack();
    } else {
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// Set queue and start playing.
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    _queue = List.from(tracks);
    _currentIndex = startIndex.clamp(0, _queue.length - 1);
    _generateShuffleOrder();
    await _playCurrentTrack();
  }

  /// Play a single track (replaces queue).
  Future<void> playTrack(Track track) async {
    await setQueue([track]);
  }

  /// Add track to end of queue.
  void addToQueue(Track track) {
    _queue.add(track);
    _generateShuffleOrder();
    notifyListeners();
  }

  /// Add track after currently playing.
  void playNext(Track track) {
    if (_currentIndex < 0) {
      _queue.add(track);
      _currentIndex = 0;
      _playCurrentTrack();
    } else {
      _queue.insert(_currentIndex + 1, track);
    }
    _generateShuffleOrder();
    notifyListeners();
  }

  /// Remove track from queue at index.
  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (_queue.isEmpty) {
      _currentIndex = -1;
      _audioPlayer.stop();
      _isPlaying = false;
    } else if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      _currentIndex = _currentIndex.clamp(0, _queue.length - 1);
      _playCurrentTrack();
    }
    _generateShuffleOrder();
    notifyListeners();
  }

  /// Move a track in the queue.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex >= _queue.length) return;
    final track = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, track);
    // Adjust current index
    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
    _generateShuffleOrder();
    notifyListeners();
  }

  /// Resolve stream URL and play the current track.
  Future<void> _playCurrentTrack() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final track = _queue[_currentIndex];

      // Check if existing stream URL is still valid
      if (track.streamUrl != null && track.streamUrl!.isNotEmpty) {
        try {
          await _audioPlayer.setUrl(track.streamUrl!);
          await _audioPlayer.play();
          _isLoading = false;
          _preloadNextTrack();
          notifyListeners();
          return;
        } catch (_) {
          // Stream URL expired or invalid, resolve new one
        }
      }

      // Resolve stream URL
      final resolved = await _repository.resolveStreamUrl(track);
      _queue[_currentIndex] = resolved;

      if (resolved.streamUrl == null || resolved.streamUrl!.isEmpty) {
        throw Exception('Could not resolve stream URL');
      }

      await _audioPlayer.setUrl(resolved.streamUrl!);
      await _audioPlayer.play();
      _isLoading = false;

      // Auto-load related tracks if near end of queue
      if (_currentIndex >= _queue.length - 2) {
        _loadRelatedTracks(resolved.id);
      }

      // Preload next track URL
      _preloadNextTrack();

      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Playback error: ${e.toString()}';
      notifyListeners();
      // Auto-skip on error after 2s delay
      if (hasNext) {
        Future.delayed(const Duration(seconds: 2), () => next());
      }
    }
  }

  /// Pre-resolve the next track's stream URL.
  void _preloadNextTrack() {
    final nextIdx = _getNextIndex();
    if (nextIdx != null && nextIdx < _queue.length) {
      final nextTrack = _queue[nextIdx];
      if (nextTrack.streamUrl == null || nextTrack.streamUrl!.isEmpty) {
        _repository.resolveStreamUrl(nextTrack).then((resolved) {
          if (nextIdx < _queue.length && _queue[nextIdx].id == resolved.id) {
            _queue[nextIdx] = resolved;
          }
        }).catchError((_) {});
      }
    }
  }

  int? _getNextIndex() {
    if (_shuffle && _shuffledIndices != null) {
      final pos = _shuffledIndices!.indexOf(_currentIndex);
      if (pos < _shuffledIndices!.length - 1) {
        return _shuffledIndices![pos + 1];
      }
      return null;
    }
    if (_currentIndex < _queue.length - 1) return _currentIndex + 1;
    return null;
  }

  /// Auto-load related tracks to extend the queue.
  Future<void> _loadRelatedTracks(String videoId) async {
    try {
      final related = await _repository.getRelatedTracks(videoId);
      final newTracks = related
          .where((t) => !_queue.any((q) => q.id == t.id))
          .take(10)
          .toList();
      if (newTracks.isNotEmpty) {
        _queue.addAll(newTracks);
        _generateShuffleOrder();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> play() => _audioPlayer.play();
  Future<void> pause() => _audioPlayer.pause();

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> next() async {
    if (_shuffle && _shuffledIndices != null) {
      final pos = _shuffledIndices!.indexOf(_currentIndex);
      if (pos < _shuffledIndices!.length - 1) {
        _currentIndex = _shuffledIndices![pos + 1];
      } else if (_repeatMode == RepeatMode.all) {
        _currentIndex = _shuffledIndices!.first;
      } else {
        return;
      }
    } else {
      if (_currentIndex < _queue.length - 1) {
        _currentIndex++;
      } else if (_repeatMode == RepeatMode.all) {
        _currentIndex = 0;
      } else {
        return;
      }
    }
    await _playCurrentTrack();
  }

  Future<void> previous() async {
    if (_position.inSeconds > 3) {
      await _audioPlayer.seek(Duration.zero);
      return;
    }
    if (_shuffle && _shuffledIndices != null) {
      final pos = _shuffledIndices!.indexOf(_currentIndex);
      if (pos > 0) {
        _currentIndex = _shuffledIndices![pos - 1];
      }
    } else {
      if (_currentIndex > 0) {
        _currentIndex--;
      }
    }
    await _playCurrentTrack();
  }

  Future<void> seek(Duration position) => _audioPlayer.seek(position);

  void setShuffle(bool enabled) {
    _shuffle = enabled;
    _generateShuffleOrder();
    notifyListeners();
  }

  void toggleShuffle() => setShuffle(!_shuffle);

  void cycleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.all;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
      case RepeatMode.one:
        _repeatMode = RepeatMode.off;
    }
    notifyListeners();
  }

  Future<void> playAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await _playCurrentTrack();
  }

  void clearQueue() {
    _queue.clear();
    _currentIndex = -1;
    _shuffledIndices = null;
    _audioPlayer.stop();
    _isPlaying = false;
    _error = null;
    notifyListeners();
  }

  void _generateShuffleOrder() {
    if (!_shuffle || _queue.isEmpty) {
      _shuffledIndices = null;
      return;
    }
    _shuffledIndices = List.generate(_queue.length, (i) => i)
      ..shuffle(Random());
    // Ensure current track is first in shuffle order
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      _shuffledIndices!.remove(_currentIndex);
      _shuffledIndices!.insert(0, _currentIndex);
    }
  }

  /// Get MediaItem for current track (for audio_service integration).
  MediaItem? get currentMediaItem {
    final track = currentTrack;
    if (track == null) return null;
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      artUri: track.thumbnailUrl.isNotEmpty
          ? Uri.tryParse(track.highResThumbnail)
          : null,
      duration: track.duration,
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
