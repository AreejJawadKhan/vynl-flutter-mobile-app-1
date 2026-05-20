import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/constants/app_constants.dart';
import '../../../features/library/providers/library_provider.dart';
import '../../../shared/providers/audio_provider.dart';
import '../../../services/gemini_service.dart';
import '../models/voice_models.dart';

class VoiceProvider extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  final GeminiService _gemini = GeminiService();

  AudioProvider?   _audio;
  LibraryProvider? _library;

  VoiceState          _state         = VoiceState.idle;
  String              _transcript    = '';
  String              _statusMessage = '';
  ParsedCommand?      _lastCommand;
  List<ParsedCommand> _history       = [];

  bool _isAvailable   = false;
  bool _isInitialised = false;

  VoiceState          get state         => _state;
  String              get transcript    => _transcript;
  String              get statusMessage => _statusMessage;
  ParsedCommand?      get lastCommand   => _lastCommand;
  List<ParsedCommand> get history       => List.unmodifiable(_history);
  bool                get isListening   => _state == VoiceState.listening;
  bool                get isAvailable   => _isAvailable;

  void updateDependencies(AudioProvider audio, LibraryProvider library) {
    _audio   = audio;
    _library = library;
  }

  Future<bool> initialise() async {
    if (_isInitialised) return _isAvailable;

    _isAvailable = await _speech.initialize(
      onError: (error) {
        debugPrint('[VoiceProvider] speech error: ${error.errorMsg}');
        _setError(_errorMessageFor(error.errorMsg));
      },
      onStatus: (status) {
        debugPrint('[VoiceProvider] speech status: $status');
        if (status == 'done' && _state == VoiceState.listening) {
          _processTranscript();
        }
      },
    );

    _isInitialised = true;
    notifyListeners();
    return _isAvailable;
  }

  Future<bool> startListening() async {
    if (!_isInitialised) await initialise();
    if (!_isAvailable) {
      _setError('Microphone not available');
      return false;
    }
    if (_state == VoiceState.listening) return true;

    _transcript    = '';
    _statusMessage = 'Listening…';
    _setState(VoiceState.listening);

    await _speech.listen(
      onResult: (result) {
        _transcript = result.recognizedWords;
        notifyListeners();
        if (result.finalResult) _processTranscript();
      },
      listenFor: AppConstants.voiceListenDuration,
      pauseFor:  const Duration(seconds: 3),
      localeId:  'en_US',
      // Fixed: use SpeechListenOptions instead of deprecated params
      listenOptions: SpeechListenOptions(
        cancelOnError:  true,
        partialResults: true,
      ),
    );

    return true;
  }

  Future<void> stopListening() async {
    if (_state != VoiceState.listening) return;
    await _speech.stop();
    _processTranscript();
  }

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

  Future<void> _parseAndExecute(String words) async {
    // 1. Fast local keyword match (offline)
    final localCommand = _parseIntent(words);

    // 2. Gemini for richer understanding
    final genres = _library?.allSongs
        .map((s) => s.genre)
        .toSet()
        .where((g) => g.isNotEmpty && g != 'Unknown')
        .toList() ??
        [];

    GeminiIntent? geminiResult;
    try {
      geminiResult = await _gemini.parseVoiceCommand(words, genres);
    } catch (e) {
      debugPrint('[VoiceProvider] Gemini failed, using local: $e');
    }

    // 3. Pick best result
    ParsedCommand? command;
    if (geminiResult != null && geminiResult.confidence > 0.6) {
      command = _geminiIntentToCommand(geminiResult, words);
    }
    command ??= localCommand;

    if (command == null) {
      _setError("I couldn't understand that. Try again?");
      return;
    }

    final executed = _executeCommand(command);
    if (!executed) {
      _setError("Couldn't find matching songs.");
      return;
    }

    _lastCommand   = command;
    _statusMessage = command.description;
    _addToHistory(command);
    _setState(VoiceState.success);

    Future.delayed(const Duration(seconds: 3), () {
      if (_state == VoiceState.success) {
        _setState(VoiceState.idle);
        _transcript    = '';
        _statusMessage = '';
      }
    });
  }

  ParsedCommand? _geminiIntentToCommand(
      GeminiIntent intent, String transcript) {
    switch (intent.intent) {
      case 'play_genre':
        return ParsedCommand(
          intent:    VoiceIntent.playByMood,
          transcript: transcript,
          moodLabel:  intent.genre,
          keywords:   intent.genre != null ? [intent.genre!] : [],
        );
      case 'play_mood':
        return ParsedCommand(
          intent:    VoiceIntent.playByMood,
          transcript: transcript,
          moodLabel:  intent.mood,
          keywords:   intent.mood != null ? [intent.mood!] : [],
        );
      case 'play_random':
        return ParsedCommand(
            intent: VoiceIntent.playRandom, transcript: transcript);
      case 'control':
        return ParsedCommand(
            intent:     VoiceIntent.control,
            transcript: intent.controlAction ?? transcript);
      case 'whats_playing':
        return ParsedCommand(
            intent: VoiceIntent.whatsPlaying, transcript: transcript);
      case 'like_song':
        return ParsedCommand(
            intent: VoiceIntent.likeSong, transcript: transcript);
      default:
        return null;
    }
  }

  // ── Local keyword parser ──────────────────────────────────────────────────
  ParsedCommand? _parseIntent(String transcript) {
    final t = transcript.toLowerCase().trim();

    // ── 1. Explicit controls FIRST ───────────────────────────────────
    if (_matchesAny(t, VoiceKeywords.pause)) {
      return ParsedCommand(intent: VoiceIntent.control, transcript: transcript);
    }
    if (_matchesAny(t, VoiceKeywords.next)) {
      return ParsedCommand(intent: VoiceIntent.control, transcript: transcript);
    }
    if (_matchesAny(t, VoiceKeywords.prev)) {
      return ParsedCommand(intent: VoiceIntent.control, transcript: transcript);
    }

    // ── 2. Like ──────────────────────────────────────────────────────
    if (_matchesAny(t, VoiceKeywords.like)) {
      return ParsedCommand(intent: VoiceIntent.likeSong, transcript: transcript);
    }

    // ── 3. Random ────────────────────────────────────────────────────
    if (_matchesAny(t, VoiceKeywords.random)) {
      return ParsedCommand(intent: VoiceIntent.playRandom, transcript: transcript);
    }

    // ── 4. Activity (check before mood — more specific) ──────────────
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

    // ── 5. Mood ───────────────────────────────────────────────────────
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

    // ── 6. "Play X music" / "Play X songs" — genre from transcript ───
    // Extract what comes after "play"
    if (t.contains('play')) {
      final afterPlay = t.replaceFirst(RegExp(r'.*?play\s+'), '').trim();
      final cleanedGenre = afterPlay
          .replaceAll(RegExp(r'\b(music|song|songs|some|me|a|the)\b'), '')
          .trim();

      if (cleanedGenre.isNotEmpty && cleanedGenre.length > 2) {
        // Check if it matches a known genre in the library
        final genres = _library?.allSongs
            .map((s) => s.genre.toLowerCase())
            .toSet() ??
            {};
        final matchedGenre = genres.firstWhere(
              (g) => g.contains(cleanedGenre) || cleanedGenre.contains(g),
          orElse: () => '',
        );

        if (matchedGenre.isNotEmpty) {
          return ParsedCommand(
            intent:    VoiceIntent.playByMood,
            transcript: transcript,
            moodLabel:  matchedGenre,
            keywords:   [matchedGenre],
          );
        }

        // Still treat it as a genre search even if not exact match
        return ParsedCommand(
          intent:    VoiceIntent.playByMood,
          transcript: transcript,
          moodLabel:  cleanedGenre,
          keywords:   [cleanedGenre],
        );
      }

      // Plain "play" — resume or random
      if (_audio?.isPlaying == false && _audio?.currentSong != null) {
        return ParsedCommand(intent: VoiceIntent.control, transcript: transcript);
      }
      return ParsedCommand(intent: VoiceIntent.playRandom, transcript: transcript);
    }

    // ── 7. What's playing — LAST, only if no play intent found ───────
    if (_matchesAny(t, ['what song', 'who sings', 'what is this', 'who is this', 'song name'])) {
      return ParsedCommand(intent: VoiceIntent.whatsPlaying, transcript: transcript);
    }

    return null;
  }

  bool _matchesAny(String text, List<String> keywords) =>
      keywords.any((kw) => text.contains(kw));

  // ── Command executor ──────────────────────────────────────────────────────
  bool _executeCommand(ParsedCommand command) {
    if (_audio == null || _library == null) return false;

    switch (command.intent) {
      case VoiceIntent.control:
        return _executeControl(command.transcript.toLowerCase());

      case VoiceIntent.playByMood:
      case VoiceIntent.playByActivity:
        final mood = command.moodLabel?.toLowerCase() ?? '';
        final keywords = List<String>.from(
          command.keywords.isEmpty
              ? (mood.isNotEmpty ? [mood] : <String>[])
              : command.keywords,
        );

        if (mood.contains('happy') || mood.contains('energetic')) {
          keywords.addAll(['Pop', 'Dance', 'Rock']);
        } else if (mood.contains('sad') || mood.contains('blue')) {
          keywords.addAll(['Classical', 'Acoustic', 'Jazz']);
        } else if (mood.contains('relax') ||
            mood.contains('calm') ||
            mood.contains('chill')) {
          keywords.addAll(['Lofi', 'Classical', 'Acoustic']);
        } else if (mood.contains('party') || mood.contains('lit')) {
          keywords.addAll(['Hip Hop', 'Dance', 'Rock']);
        } else if (mood.contains('study') || mood.contains('focus')) {
          keywords.addAll(['Lofi', 'Classical']);
        }

        if (mood.isNotEmpty) keywords.add(mood);

        final matches = _library!.songsMatchingKeywords(keywords);
        final pool = matches.isNotEmpty ? matches : _library!.allSongs;
        if (pool.isEmpty) return false;

        final song = pool[Random().nextInt(pool.length)];
        _audio!.playSong(song, pool);
        return true;

      case VoiceIntent.playRandom:
        final all = _library!.allSongs;
        if (all.isEmpty) return false;
        final song = all[Random().nextInt(all.length)];
        _audio!.playSong(song, all);
        return true;

      case VoiceIntent.whatsPlaying:
        return _audio!.currentSong != null;

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

  void simulateTranscript(String text) {
    if (text.trim().isEmpty) return;
    _transcript    = text;
    _statusMessage = 'Understanding…';
    _setState(VoiceState.processing);
    Future.delayed(
      const Duration(milliseconds: 400),
          () => _parseAndExecute(text.trim()),
    );
  }

  void _addToHistory(ParsedCommand command) {
    _history.insert(0, command);
    if (_history.length > AppConstants.commandHistoryMax) {
      _history = _history.sublist(0, AppConstants.commandHistoryMax);
    }
  }

  void _setState(VoiceState state) {
    _state = state;
    notifyListeners();
  }

  void _setError(String message) {
    _statusMessage = message;
    _state         = VoiceState.error;
    notifyListeners();
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
        return "Couldn't find music matching that. Try a different mood?";
      case 'error_speech_timeout':
        return "I didn't hear anything. Try again?";
      case 'error_permission':
        return 'Please enable microphone access in Settings.';
      default:
        return "Couldn't hear you. Try again?";
    }
  }

  void reset() {
    _speech.stop();
    _state         = VoiceState.idle;
    _transcript    = '';
    _statusMessage = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}