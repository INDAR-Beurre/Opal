import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../domain/models/track.dart';
import '../domain/repositories/music_repository.dart';

enum RepeatMode { off, all, one }

/// Central playback controller managing audio, queue, and state.
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

  PlaybackController({required MusicRepository repository})
      : _repository = repository {
    _initListeners();
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
      _currentIndex = 0;
      _playCurrentTrack();
    } else {
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    _queue = List.from(tracks);
    _currentIndex = startIndex.clamp(0, _queue.length - 1);
    _generateShuffleOrder();
    await _playCurrentTrack();
  }

  void addToQueue(Track track) {
    _queue.add(track);
    _generateShuffleOrder();
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (_queue.isEmpty) {
        _currentIndex = -1;
        _audioPlayer.stop();
      } else {
        _currentIndex = _currentIndex.clamp(0, _queue.length - 1);
        _playCurrentTrack();
      }
    }
    _generateShuffleOrder();
    notifyListeners();
  }

  Future<void> _playCurrentTrack() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final track = await _repository.resolveStreamUrl(_queue[_currentIndex]);
      _queue[_currentIndex] = track;

      if (track.streamUrl == null || track.streamUrl!.isEmpty) {
        throw Exception('Could not resolve stream URL');
      }

      await _audioPlayer.setUrl(track.streamUrl!);
      await _audioPlayer.play();
      _isLoading = false;

      // Auto-load related tracks if near end of queue
      if (_currentIndex >= _queue.length - 2) {
        _loadRelatedTracks(track.id);
      }

      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Playback error: ${e.toString()}';
      notifyListeners();
      if (hasNext) {
        Future.delayed(const Duration(seconds: 1), () => next());
      }
    }
  }

  /// Auto-load related tracks to extend the queue.
  Future<void> _loadRelatedTracks(String videoId) async {
    try {
      final related = await _repository.getRelatedTracks(videoId);
      final newTracks =
          related.where((t) => !_queue.any((q) => q.id == t.id)).take(10);
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
    if (_currentIndex > 0) {
      _currentIndex--;
    }
    await _playCurrentTrack();
  }

  Future<void> seek(Duration position) => _audioPlayer.seek(position);

  void setShuffle(bool enabled) {
    _shuffle = enabled;
    _generateShuffleOrder();
    notifyListeners();
  }

  void cycleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.all;
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.off;
        break;
    }
    notifyListeners();
  }

  Future<void> playAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await _playCurrentTrack();
  }

  void _generateShuffleOrder() {
    if (!_shuffle || _queue.isEmpty) {
      _shuffledIndices = null;
      return;
    }
    _shuffledIndices = List.generate(_queue.length, (i) => i)..shuffle(Random());
    if (_currentIndex >= 0) {
      _shuffledIndices!.remove(_currentIndex);
      _shuffledIndices!.insert(0, _currentIndex);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
