import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/constants/app_constants.dart';
import '../../../features/library/models/song_model.dart';
import '../../../features/library/providers/library_provider.dart';
import '../../../shared/providers/audio_provider.dart';
import '../models/voice_models.dart';

/// Manages the entire AI voice search flow:
///   1. Microphone access via [SpeechToText]
///   2. State machine (idle → listening → processing → success/error)
///   3. Intent parsing (pure Dart keyword matching — no API)
///   4. Action execution (calls [AudioProvider] and [LibraryProvider])
///   5. Command history (last 3 commands, in-memory)
class VoiceProvider extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();

  // ── Dependencies injected via ProxyProvider ───────────────────────────────
  AudioProvider?   _audio;
  LibraryProvider? _library;

  // ── State ─────────────────────────────────────────────────────────────────
  VoiceState      _state          = VoiceState.idle;
  String          _transcript     = '';
  String          _statusMessage  = '';
  ParsedCommand?  _lastCommand;
  List<ParsedCommand> _history    = [];

  // ── Availability ──────────────────────────────────────────────────────────
  bool _isAvailable   = false; // true after successful SpeechToText.initialize()
  bool _isInitialised = false;

  // ── Getters ───────────────────────────────────────────────────────────────
  VoiceState          get state          => _state;
  String              get transcript     => _transcript;
  String              get statusMessage  => _statusMessage;
  ParsedCommand?      get lastCommand    => _lastCommand;
  List<ParsedCommand> get history        => List.unmodifiable(_history);
  bool                get isListening    => _state == VoiceState.listening;
  bool                get isAvailable    => _isAvailable;

  // ── Dependency injection ──────────────────────────────────────────────────

  void updateDependencies(AudioProvider audio, LibraryProvider library) {
    _audio   = audio;
    _library = library;
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Initialises SpeechToText. Call once before first use.
  /// Returns true if the device supports speech recognition.
  Future<bool> initialise() async {
    if (_isInitialised) return _isAvailable;

    _isAvailable = await _speech.initialize(
      onError: (error) {
        debugPrint('[VoiceProvider] speech error: ${error.errorMsg}');
        _setError(_errorMessageFor(error.errorMsg));
      },
      onStatus: (status) {
        debugPrint('[VoiceProvider] speech status: $status');
        // 'done' fires when the mic stops (timeout or silence)
        if (status == 'done' && _state == VoiceState.listening) {
          _processTranscript();
        }
      },
    );

    _isInitialised = true;
    notifyListeners();
    return _isAvailable;
  }

  // ── Start / stop listening ────────────────────────────────────────────────

  /// Starts listening. Returns false if speech is unavailable.
  Future<bool> startListening() async {
    if (!_isInitialised) await initialise();
    if (!_isAvailable)   { _setError('Microphone not available'); return false; }
    if (_state == VoiceState.listening) return true;

    _transcript    = '';
    _statusMessage = 'Listening…';
    _setState(VoiceState.listening);

    await _speech.listen(
      onResult: (result) {
        _transcript = result.recognizedWords;
        notifyListeners();
        // If we get a final result before the timeout, process immediately.
        if (result.finalResult) _processTranscript();
      },
      listenFor:          AppConstants.voiceListenDuration,
      pauseFor:           const Duration(seconds: 3),
      localeId:           'en_US',
      cancelOnError:      true,
      partialResults:     true,
    );

    return true;
  }

  /// Stops listening early (user taps mic again).
  Future<void> stopListening() async {
    if (_state != VoiceState.listening) return;
    await _speech.stop();
    _processTranscript();
  }

  // ── Processing ────────────────────────────────────────────────────────────

  /// Called when the mic stops (timeout, silence, or user taps stop).
  /// Only runs if we were actually listening.
  void _processTranscript() {
    if (_state != VoiceState.listening) return;
    final words = _transcript.trim();
    if (words.isEmpty) {
      _setError("I didn't hear anything. Try again?");
      return;
    }
    _statusMessage = 'Understanding…';
    _setState(VoiceState.processing);
    _parseAndExecute(words);
  }

  /// Core parsing + execution — no state guard.
  /// Called from [_processTranscript] (real mic) and [simulateTranscript] (chips).
  void _parseAndExecute(String words) {
    final command = _parseIntent(words);
    if (command == null) {
      _setError("I couldn't understand that. Try again?");
      return;
    }

    final executed = _executeCommand(command);
    if (!executed) {
      _setError("Couldn't do that right now.");
      return;
    }

    _lastCommand   = command;
    _statusMessage = command.description;
    _addToHistory(command);
    _setState(VoiceState.success);

    // Auto-reset to idle after 3 seconds.
    Future.delayed(const Duration(seconds: 3), () {
      if (_state == VoiceState.success) {
        _setState(VoiceState.idle);
        _transcript    = '';
        _statusMessage = '';
      }
    });
  }

  // ── Intent parser — pure keyword matching ────────────────────────────────

  /// Parses a transcript string into a [ParsedCommand].
  /// Returns null if no intent is matched.
  ParsedCommand? _parseIntent(String transcript) {
    final t = transcript.toLowerCase().trim();

    // ── 1. Control commands — check first so "skip" doesn't match mood ──────
    if (_matchesAny(t, VoiceKeywords.pause)) {
      return ParsedCommand(intent: VoiceIntent.control, transcript: transcript);
    }
    if (_matchesAny(t, VoiceKeywords.next)) {
      return ParsedCommand(intent: VoiceIntent.control, transcript: transcript);
    }
    if (_matchesAny(t, VoiceKeywords.prev)) {
      return ParsedCommand(intent: VoiceIntent.control, transcript: transcript);
    }
    if (_matchesAny(t, VoiceKeywords.resume) && !_matchesAny(t, ['play'])) {
      // "play" alone is ambiguous — handled below
      return ParsedCommand(intent: VoiceIntent.control, transcript: transcript);
    }

    // ── 2. Like ──────────────────────────────────────────────────────────────
    if (_matchesAny(t, VoiceKeywords.like)) {
      return ParsedCommand(intent: VoiceIntent.likeSong, transcript: transcript);
    }

    // ── 3. What's playing ─────────────────────────────────────────────────
    if (_matchesAny(t, VoiceKeywords.whatsPlaying)) {
      return ParsedCommand(
          intent: VoiceIntent.whatsPlaying, transcript: transcript);
    }

    // ── 4. Random ────────────────────────────────────────────────────────────
    if (_matchesAny(t, VoiceKeywords.random)) {
      return ParsedCommand(
          intent: VoiceIntent.playRandom, transcript: transcript);
    }

    // ── 5. Activity ───────────────────────────────────────────────────────────
    for (final entry in VoiceKeywords.activities.entries) {
      final matched = entry.value.where((kw) => t.contains(kw)).toList();
      if (matched.isNotEmpty) {
        return ParsedCommand(
          intent:     VoiceIntent.playByActivity,
          transcript: transcript,
          moodLabel:  entry.key,
          keywords:   matched,
        );
      }
    }

    // ── 6. Mood ────────────────────────────────────────────────────────────
    for (final entry in VoiceKeywords.moods.entries) {
      final matched = entry.value.where((kw) => t.contains(kw)).toList();
      if (matched.isNotEmpty) {
        return ParsedCommand(
          intent:     VoiceIntent.playByMood,
          transcript: transcript,
          moodLabel:  entry.key,
          keywords:   matched,
        );
      }
    }

    // ── 7. "Play" alone — treat as resume / play random if library not empty ─
    if (t.contains('play')) {
      if (_audio?.isPlaying == false && _audio?.currentSong != null) {
        return ParsedCommand(intent: VoiceIntent.control, transcript: transcript);
      }
      return ParsedCommand(intent: VoiceIntent.playRandom, transcript: transcript);
    }

    return null; // No intent matched
  }

  bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }

  // ── Action executor ───────────────────────────────────────────────────────

  /// Executes the action corresponding to [command].
  /// Returns false if the action cannot be performed (e.g. empty library).
  bool _executeCommand(ParsedCommand command) {
    if (_audio == null || _library == null) return false;

    switch (command.intent) {

      // ── Playback controls ────────────────────────────────────────────────
      case VoiceIntent.control:
        return _executeControl(command.transcript.toLowerCase());

      // ── Play by mood ─────────────────────────────────────────────────────
      case VoiceIntent.playByMood:
      case VoiceIntent.playByActivity:
        final mood = command.moodLabel?.toLowerCase() ?? '';
        List<String> keywords = command.keywords.isEmpty 
            ? (mood.isNotEmpty ? [mood] : <String>[])
            : command.keywords;

        // Map abstract moods to simulated genres
        if (mood.contains('happy') || mood.contains('energetic')) {
          keywords.addAll(['Pop', 'Dance', 'Rock']);
        } else if (mood.contains('sad') || mood.contains('blue')) {
          keywords.addAll(['Classical', 'Acoustic', 'Jazz']);
        } else if (mood.contains('relax') || mood.contains('calm') || mood.contains('chill')) {
          keywords.addAll(['Lofi', 'Classical', 'Acoustic']);
        } else if (mood.contains('party') || mood.contains('lit')) {
          keywords.addAll(['Hip Hop', 'Dance', 'Rock']);
        } else if (mood.contains('study') || mood.contains('focus')) {
          keywords.addAll(['Lofi', 'Classical']);
        }

        final matches = _library!.songsMatchingKeywords(keywords);
        final pool    = matches.isNotEmpty ? matches : _library!.allSongs;
        if (pool.isEmpty) return false;

        final song = pool[Random().nextInt(pool.length)];
        _audio!.playSong(song, pool);
        return true;

      // ── Play random ──────────────────────────────────────────────────────
      case VoiceIntent.playRandom:
        final all = _library!.allSongs;
        if (all.isEmpty) return false;
        final song = all[Random().nextInt(all.length)];
        _audio!.playSong(song, all);
        return true;

      // ── What's playing ───────────────────────────────────────────────────
      case VoiceIntent.whatsPlaying:
        // The UI shows the current song info on success state.
        // Return false only if nothing is playing.
        return _audio!.currentSong != null;

      // ── Like current song ────────────────────────────────────────────────
      case VoiceIntent.likeSong:
        final song = _audio!.currentSong;
        if (song == null) return false;
        _library!.toggleLike(song);
        return true;
    }
  }

  bool _executeControl(String transcript) {
    if (_audio == null) return false;

    if (_matchesAny(transcript, VoiceKeywords.pause)) {
      if (_audio!.isPlaying) _audio!.playPause();
      return true;
    }
    if (_matchesAny(transcript, VoiceKeywords.resume) ||
        transcript.contains('play')) {
      if (!_audio!.isPlaying) _audio!.playPause();
      return true;
    }
    if (_matchesAny(transcript, VoiceKeywords.next)) {
      _audio!.skipToNext();
      return true;
    }
    if (_matchesAny(transcript, VoiceKeywords.prev)) {
      _audio!.skipToPrevious();
      return true;
    }
    return false;
  }

  // ── History ───────────────────────────────────────────────────────────────

  void _addToHistory(ParsedCommand command) {
    _history.insert(0, command);
    if (_history.length > AppConstants.commandHistoryMax) {
      _history = _history.sublist(0, AppConstants.commandHistoryMax);
    }
  }

  // ── State helpers ─────────────────────────────────────────────────────────

  void _setState(VoiceState state) {
    _state = state;
    notifyListeners();
  }

  void _setError(String message) {
    _statusMessage = message;
    _state         = VoiceState.error;
    notifyListeners();

    // Auto-reset after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (_state == VoiceState.error) {
        _state         = VoiceState.idle;
        _statusMessage = '';
        _transcript    = '';
        notifyListeners();
      }
    });
  }

  String _errorMessageFor(String errorCode) {
    switch (errorCode) {
      case 'error_no_match':
        return "I couldn't find music matching that. Try a different mood?";
      case 'error_speech_timeout':
        return "I didn't hear anything. Try again?";
      case 'error_permission':
        return 'Please enable microphone access in Settings.';
      default:
        return "Couldn't hear you. Try again?";
    }
  }

  /// Resets back to idle. Called when the user dismisses an error or result.
  void reset() {
    _speech.stop();
    _state         = VoiceState.idle;
    _transcript    = '';
    _statusMessage = '';
    notifyListeners();
  }

  /// Injects a transcript string directly — used by suggestion chips in the UI.
  /// Skips the microphone entirely and goes straight to intent parsing.
  void simulateTranscript(String text) {
    if (text.trim().isEmpty) return;
    _transcript    = text;
    _statusMessage = 'Understanding…';
    _setState(VoiceState.processing);
    // Small delay so the user sees the "Understanding…" state briefly.
    Future.delayed(
      const Duration(milliseconds: 400),
      () => _parseAndExecute(text.trim()),
    );
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}
