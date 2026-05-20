import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/library/models/song_model.dart';
import '../../features/library/providers/library_provider.dart';
import '../../core/constants/prefs_keys.dart';
import '../../core/utils/media_art_helper.dart';
import '../../services/analytics_service.dart';

/// Repeat mode for the queue.
enum RepeatMode { off, one, all }

/// Central audio engine. Wraps [AudioPlayer] from just_audio.
///
/// Responsibilities:
///   - Play / pause / next / previous
///   - Shuffle and repeat
///   - Progress streaming
///   - Queue management
///   - Background playback via just_audio_background
///   - Listening-time tracking (persisted)
class AudioProvider extends ChangeNotifier {
  dynamic _social;
  void updateSocial(dynamic social) {
    _social = social;
  }
  final AudioPlayer _player = AudioPlayer();
  LibraryProvider? _library;

  // ── Playback state ─────────────────────────────────────────────────────────
  SongItem? _currentSong;
  List<SongItem> _queue = [];   // ordered playback queue for the current session
  int _queueIndex = 0;

  bool _isPlaying   = false;
  bool _isBuffering = false;
  bool _isShuffled  = false;
  RepeatMode _repeatMode = RepeatMode.off;

  Duration _position = Duration.zero;
  Duration _duration  = Duration.zero;

  // ── Listening-time tracking ────────────────────────────────────────────────
  int _sessionStartMs = 0;
  int _totalListeningMs = 0;

  // ── Getters ────────────────────────────────────────────────────────────────
  SongItem?  get currentSong  => _currentSong;
  List<SongItem> get queue    => List.unmodifiable(_queue);
  int        get queueIndex   => _queueIndex;
  bool       get isPlaying    => _isPlaying;
  bool       get isBuffering  => _isBuffering;
  bool       get isShuffled   => _isShuffled;
  RepeatMode get repeatMode   => _repeatMode;
  Duration   get position     => _position;
  Duration   get duration     => _duration;
  int        get totalListeningMs => _totalListeningMs;

  /// 0.0–1.0 progress fraction; safe against zero-duration.
  double get progress =>
      _duration.inMilliseconds > 0
          ? _position.inMilliseconds / _duration.inMilliseconds
          : 0.0;

  bool get hasNext =>
      _repeatMode == RepeatMode.all ||
      _queueIndex < _queue.length - 1;

  bool get hasPrevious =>
      _repeatMode == RepeatMode.all || _queueIndex > 0;

  /// Expose the raw position stream for [StreamBuilder] widgets.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Expose buffered position for the progress bar.
  Stream<Duration?> get bufferedStream => _player.bufferedPositionStream;

  // ── Initialisation ─────────────────────────────────────────────────────────
  AudioProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadListeningTime();
    await _configureAudioSession();
    _subscribeToPlayerEvents();
  }

  void updateLibrary(LibraryProvider library) {
    _library = library;
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Respond to audio focus changes (calls, other apps).
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        // Another app is taking focus — pause our playback.
        if (_isPlaying) _player.pause();
      } else {
        // Focus returned. Only auto-resume after a clean pause interruption
        // (e.g. a phone call ended). Do NOT resume after duck — the system
        // will have already restored volume, and re-playing is unexpected UX.
        if (event.type == AudioInterruptionType.pause) {
          _player.play();
        }
      }
    });
  }

  void _subscribeToPlayerEvents() {
    // Playing state changes.
    _player.playingStream.listen((playing) {
      _isPlaying = playing;
      if (playing) {
        _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
      } else if (_sessionStartMs > 0) {
        _totalListeningMs +=
            DateTime.now().millisecondsSinceEpoch - _sessionStartMs;
        _sessionStartMs = 0;
        _saveListeningTime();
      }
      notifyListeners();
    });

    // Buffering state.
    _player.processingStateStream.listen((state) {
      _isBuffering = state == ProcessingState.loading ||
                     state == ProcessingState.buffering;
      notifyListeners();

      // Auto-advance when track completes.
      if (state == ProcessingState.completed) {
        _onTrackComplete();
      }
    });

    // Position tick.
    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    // Duration changes when a new source loads.
    _player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });

    // Handle player errors gracefully.
    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) {
        debugPrint('[AudioProvider] Playback error: $e');
        _isBuffering = false;
        notifyListeners();
        // Auto-skip to next on file error.
        skipToNext();
      },
    );
  }

  // ── Playback controls ──────────────────────────────────────────────────────

  /// Begins playback of [song], rebuilding the queue from [songList].
  /// [songList] is the list the user tapped from (displayed / liked / etc.).
  Future<void> playSong(SongItem song, List<SongItem> songList) async {
    _queue = songList.toList();
    _queueIndex = _queue.indexOf(song);
    if (_queueIndex < 0) {
      _queue.insert(0, song);
      _queueIndex = 0;
    }

    if (_isShuffled) _shuffleQueue(keepCurrent: true);

    await _loadAndPlay(song);
    _library?.recordPlayed(song);
  }

  Future<void> _loadAndPlay(SongItem song) async {
    _currentSong = song;
    _position = Duration.zero;
    _duration  = Duration.zero;
    notifyListeners();

    try {
      final artUri = await MediaArtHelper.uriForSong(song);
      final source = AudioSource.uri(
        Uri.parse(song.uri!),
        tag: MediaItem(
          id:      song.persistId,
          title:   song.title,
          artist:  song.artist,
          album:   song.album,
          duration: Duration(milliseconds: song.duration),
          artUri: artUri,
        ),
      );
      await _player.setAudioSource(source);
      await _player.play();

      // Broadcast to Firebase social feed
      _social?.broadcastNowPlaying(
        title: song.title,
        artist: song.artist,
        albumArtUrl: song.albumArtUrl,
        genre: song.genre,
      );

      // Record in listening history
      _social?.recordListeningHistory(
        title: song.title,
        artist: song.artist,
        genre: song.genre,
      );

      await AnalyticsService.logSongPlayed(
        title: song.title,
        artist: song.artist,
        genre: song.genre,
        hasAlbumArt: song.albumArtUrl != null && song.albumArtUrl!.isNotEmpty,
      );
    } catch (e) {
      debugPrint('[AudioProvider] load error for ${song.title}: $e');
      if (hasNext) await skipToNext();
    }
  }

  Future<void> playPause() async {
    if (_currentSong == null) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _currentSong = null;
    _queue = [];
    _queueIndex = 0;
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    switch (_repeatMode) {
      case RepeatMode.one:
        await _player.seek(Duration.zero);
        await _player.play();
        break;
      case RepeatMode.all:
        _queueIndex = (_queueIndex + 1) % _queue.length;
        await _loadAndPlay(_queue[_queueIndex]);
        break;
      case RepeatMode.off:
        if (_queueIndex < _queue.length - 1) {
          _queueIndex++;
          await _loadAndPlay(_queue[_queueIndex]);
        } else {
          // End of queue — stop cleanly.
          await _player.stop();
          _isPlaying = false;
          notifyListeners();
        }
        break;
    }
    if (_currentSong != null) _library?.recordPlayed(_currentSong!);
  }

  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    // If we're more than 3 seconds in, restart the current track.
    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    switch (_repeatMode) {
      case RepeatMode.all:
        _queueIndex =
            (_queueIndex - 1 + _queue.length) % _queue.length;
        break;
      case RepeatMode.off:
      case RepeatMode.one:
        if (_queueIndex > 0) _queueIndex--;
        break;
    }
    await _loadAndPlay(_queue[_queueIndex]);
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> seekToFraction(double fraction) async {
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * fraction).round(),
    );
    await seekTo(target);
  }

  void _onTrackComplete() {
    if (_repeatMode == RepeatMode.one) {
      _player.seek(Duration.zero);
      _player.play();
    } else {
      skipToNext();
    }
  }

  // ── Shuffle ────────────────────────────────────────────────────────────────
  void toggleShuffle() {
    _isShuffled = !_isShuffled;
    if (_isShuffled && _queue.isNotEmpty) {
      _shuffleQueue(keepCurrent: true);
    }
    notifyListeners();
  }

  void _shuffleQueue({required bool keepCurrent}) {
    if (_queue.isEmpty) return;
    final current = keepCurrent && _currentSong != null
        ? _currentSong
        : null;

    final rng = Random();
    for (var i = _queue.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = _queue[i];
      _queue[i] = _queue[j];
      _queue[j] = tmp;
    }

    if (current != null) {
      // Ensure current song stays at head.
      _queue.remove(current);
      _queue.insert(0, current);
      _queueIndex = 0;
    }
  }

  // ── Repeat ────────────────────────────────────────────────────────────────
  void cycleRepeat() {
    switch (_repeatMode) {
      case RepeatMode.off: _repeatMode = RepeatMode.all;  break;
      case RepeatMode.all: _repeatMode = RepeatMode.one;  break;
      case RepeatMode.one: _repeatMode = RepeatMode.off;  break;
    }
    notifyListeners();
  }

  // ── Queue mutation (for Rooms, Phase 4) ────────────────────────────────────
  void addToQueue(SongItem song) {
    if (!_queue.contains(song)) {
      _queue.add(song);
      notifyListeners();
    }
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    if (index == _queueIndex) return; // can't remove currently playing
    if (index < _queueIndex) _queueIndex--;
    _queue.removeAt(index);
    notifyListeners();
  }

  // ── Listening-time persistence ────────────────────────────────────────────
  Future<void> _loadListeningTime() async {
    final prefs = await SharedPreferences.getInstance();
    _totalListeningMs = prefs.getInt(PrefsKeys.listeningTime) ?? 0;
  }

  Future<void> _saveListeningTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PrefsKeys.listeningTime, _totalListeningMs);
  }

  // ── Dispose ───────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
