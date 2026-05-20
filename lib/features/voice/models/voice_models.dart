/// All data models and keyword maps for the AI voice search feature.
///
/// The "AI" here is keyword matching — no external API, no ML model.
/// We take the speech transcript and compare it against these keyword lists.

// ── Voice state ───────────────────────────────────────────────────────────────

/// The current state of the voice input system.
enum VoiceState {
  idle,        // Mic is off, nothing happening
  listening,   // Actively recording — user is speaking
  processing,  // Transcript received, parsing intent
  success,     // Command understood and executed
  error,       // Something went wrong (no match, no mic, etc.)
}

// ── Intent ────────────────────────────────────────────────────────────────────

/// The 6 supported command intents from the spec.
enum VoiceIntent {
  playByMood,    // "Play happy music", "I'm feeling energetic"
  playByActivity,// "Workout music", "Songs for studying"
  playRandom,    // "Surprise me", "Play something random"
  control,       // "Pause", "Skip", "Next song"
  whatsPlaying,  // "What song is this?", "Who sings this?"
  likeSong,      // "Like this song", "Add to favorites"
}

// ── Parsed command ────────────────────────────────────────────────────────────

/// The result of parsing a voice transcript.
class ParsedCommand {
  final VoiceIntent intent;
  final String      transcript;   // Raw words the user said
  final String?     moodLabel;    // e.g. "happy", "calm" (for mood/activity intents)
  final List<String> keywords;    // Keywords that triggered this intent

  const ParsedCommand({
    required this.intent,
    required this.transcript,
    this.moodLabel,
    this.keywords = const [],
  });

  /// Human-readable summary shown in the UI after a command executes.
  String get description {
    switch (intent) {
      case VoiceIntent.playByMood:
        return 'Playing ${moodLabel ?? 'matching'} music';
      case VoiceIntent.playByActivity:
        return 'Playing music for ${moodLabel ?? 'that'}';
      case VoiceIntent.playRandom:
        return 'Playing a random song';
      case VoiceIntent.control:
        return _controlDescription();
      case VoiceIntent.whatsPlaying:
        return 'Showing current song';
      case VoiceIntent.likeSong:
        return 'Song liked ♥';
    }
  }

  String _controlDescription() {
    final t = transcript.toLowerCase();
    if (t.contains('pause') || t.contains('stop'))   return 'Paused';
    if (t.contains('play')  || t.contains('resume')) return 'Playing';
    if (t.contains('next')  || t.contains('skip'))   return 'Skipped to next';
    if (t.contains('prev')  || t.contains('back'))   return 'Went to previous';
    return 'Command executed';
  }
}

// ── Keyword maps ──────────────────────────────────────────────────────────────
// These are the exact keyword lists from the spec.

/// Maps a mood/activity label to the list of trigger words for it.
/// If ANY word from the transcript matches ANY keyword in a list,
/// that mood is selected.
class VoiceKeywords {
  VoiceKeywords._();

  // ── Mood keywords (spec-defined) ──────────────────────────────────────────
  static const Map<String, List<String>> moods = {
    'happy':     ['happy', 'joy', 'uplifting', 'cheerful', 'dance', 'fun', 'excited'],
    'sad':       ['sad', 'emotional', 'melancholy', 'cry', 'crying', 'heartbreak', 'down'],
    'energetic': ['workout', 'energy', 'pump', 'power', 'intense', 'hype', 'run', 'gym'],
    'calm':      ['relax', 'peace', 'chill', 'calm', 'meditation', 'sleep', 'quiet', 'soft'],
    'focus':     ['study', 'focus', 'concentrate', 'work', 'productive', 'coding'],
  };

  // ── Activity keywords (separate from mood per spec, same mechanic) ────────
  static const Map<String, List<String>> activities = {
    'workout':   ['workout', 'exercise', 'gym', 'run', 'running', 'training', 'sport'],
    'studying':  ['study', 'studying', 'homework', 'concentrate', 'focus', 'work'],
    'relaxing':  ['relax', 'relaxing', 'wind down', 'chill', 'rest', 'sleep'],
    'party':     ['party', 'dance', 'dancing', 'club', 'hype', 'celebration'],
    'commute':   ['commute', 'drive', 'driving', 'travel', 'walk', 'walking'],
  };

  // ── Random play triggers ──────────────────────────────────────────────────
  static const List<String> random = [
    'surprise', 'random', 'anything', 'whatever', 'shuffle',
    'pick something', 'choose for me', 'just play',
  ];

  // ── Control triggers ──────────────────────────────────────────────────────
  static const List<String> pause  = ['pause', 'stop', 'halt', 'quiet'];
  static const List<String> resume = ['play', 'resume', 'continue', 'start'];
  static const List<String> next   = ['next', 'skip', 'forward', 'skip this'];
  static const List<String> prev   = ['previous', 'back', 'before', 'last song', 'go back'];

  // ── What's playing triggers ───────────────────────────────────────────────
  static const List<String> whatsPlaying = [
    'what song is this',
    'who sings this',
    'what is this song',
    'who is this',
    'song name',
    'what song',
    'identify song',
  ];

  // ── Like triggers ─────────────────────────────────────────────────────────
  static const List<String> like = [
    'like', 'love', 'favorite', 'favourite', 'heart',
    'add to favorites', 'save this', 'save song',
  ];

  // ── Suggested commands shown in the UI ───────────────────────────────────
  static const List<String> suggestions = [
    'Play happy music',
    'Surprise me',
    'Play workout songs',
    'What song is this?',
    'Skip',
    'Like this song',
  ];
}
