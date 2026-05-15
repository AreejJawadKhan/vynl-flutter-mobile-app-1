import '../../../core/constants/app_colors.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/prefs_keys.dart';
import '../../../core/utils/app_utils.dart';
import '../../../features/library/models/song_model.dart';
import '../../../shared/providers/audio_provider.dart';
import '../models/room_models.dart';

/// In-memory group room simulation engine.
///
/// There is no real network — all state lives in this provider.
/// Simulated participants are injected on join so the demo works
/// without a second device.
///
/// Design so that real networking (WebSocket / Firebase) can slot in
/// later by replacing only the private simulation methods.
class RoomProvider extends ChangeNotifier {
  AudioProvider? _audio;

  // ── Active room ───────────────────────────────────────────────────────────
  Room? _room;
  Room? get room => _room;
  bool get inRoom => _room != null;

  // ── Emoji reactions queue ─────────────────────────────────────────────────
  List<EmojiReaction> _reactions = [];
  List<EmojiReaction> get reactions => List.unmodifiable(_reactions);

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _idleTimer;       // auto-close after 5 min with no participants
  Timer? _simTimer;        // drives simulated participant activity
  Timer? _voteTimer;       // countdown during a vote
  Timer? _reactionTimer;   // (Deprecated: use _reactionTimers)
  final List<Timer> _reactionTimers = [];

  // ── Room history ──────────────────────────────────────────────────────────
  List<String> _history = [];   // last 3 room codes
  List<String> get history => List.unmodifiable(_history);

  // ── Simulated names pool ──────────────────────────────────────────────────
  static const List<String> _simNames = [
    'Alex', 'Jordan', 'Sam', 'Riley', 'Casey',
    'Morgan', 'Taylor', 'Jamie', 'Quinn', 'Drew',
  ];
  static const List<String> _simEmojis = ['🎵', '🔥', '💃', '🎶', '✨', '😍', '🎸'];

  final Random _rng = Random();

  // ── Local user ────────────────────────────────────────────────────────────
  static const String _localUserId   = 'local_user';
  static const String _localUserName = 'You';

  RoomProvider() {
    _loadHistory();
  }

  void updateAudio(AudioProvider audio) {
    _audio = audio;
  }

  // ── History ───────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _history = prefs.getStringList(PrefsKeys.roomHistory) ?? [];
  }

  Future<void> _saveHistory(String code) async {
    _history.remove(code);
    _history.insert(0, code);
    if (_history.length > AppConstants.roomHistoryMax) {
      _history = _history.sublist(0, AppConstants.roomHistoryMax);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(PrefsKeys.roomHistory, _history);
    notifyListeners();
  }

  Future<void> _incrementRoomsCreated() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(PrefsKeys.roomsCreated) ?? 0;
    await prefs.setInt(PrefsKeys.roomsCreated, count + 1);
  }

  // ── Room creation ─────────────────────────────────────────────────────────

  /// Creates a new room and returns it.
  /// Immediately adds the local user as host participant.
  Future<Room> createRoom({
    String? name,
    required RoomSettings settings,
  }) async {
    final code     = AppUtils.generateRoomCode();
    final roomName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : "$_localUserName's Room";

    final localParticipant = RoomParticipant(
      id:         _localUserId,
      username:   _localUserName,
      colorIndex: 0,
      isActive:   true,
    );

    _room = Room(
      code:         code,
      name:         roomName,
      hostId:       _localUserId,
      settings:     settings,
      participants: [localParticipant],
      status:       RoomStatus.idle,
    );

    await _saveHistory(code);
    await _incrementRoomsCreated();

    // Start simulated participants joining after a short delay.
    _startSimulation();
    _startIdleTimer();

    notifyListeners();
    return _room!;
  }

  // ── Room joining ──────────────────────────────────────────────────────────

  /// Joins an existing room by code.
  /// In simulation, creates a new room with the given code so joining works.
  Future<bool> joinRoom(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.length != AppConstants.roomCodeLength) return false;

    final localParticipant = RoomParticipant(
      id:         _localUserId,
      username:   _localUserName,
      colorIndex: 0,
      isActive:   true,
    );

    _room = Room(
      code:         trimmed,
      name:         'Room $trimmed',
      hostId:       _localUserId,
      settings:     const RoomSettings(),
      participants: [localParticipant],
      status:       RoomStatus.idle,
    );

    await _saveHistory(trimmed);
    _startSimulation();
    _startIdleTimer();

    notifyListeners();
    return true;
  }

  // ── Leave / close room ────────────────────────────────────────────────────

  void leaveRoom() {
    _cancelAllTimers();
    _audio?.stop();
    _reactions = [];
    _room      = null;
    notifyListeners();
  }

  // ── Queue management ──────────────────────────────────────────────────────

  /// Adds a song to the queue. Returns false if permissions deny it.
  bool addSong(SongItem song) {
    if (_room == null) return false;
    if (!_room!.settings.everyoneCanAdd && !_room!.isHost) return false;

    final item = RoomQueueItem(
      id:          '${song.id}_${DateTime.now().millisecondsSinceEpoch}',
      song:        song,
      addedById:   _localUserId,
      addedByName: _localUserName,
    );

    _room!.queue.add(item);

    // If idle, start playing immediately.
    if (_room!.status == RoomStatus.idle) {
      _room!.status = RoomStatus.active;
      _audio?.playSong(song, _room!.queue.map((q) => q.song).toList());
    }

    _cancelIdleTimer();
    notifyListeners();
    return true;
  }

  /// Host removes any queue item by its id.
  void removeQueueItem(String itemId) {
    if (_room == null) return;
    _room!.queue.removeWhere((q) => q.id == itemId);
    notifyListeners();
  }

  // ── Voting ────────────────────────────────────────────────────────────────

  /// Cast a vote. [type] is skip or replay.
  /// Auto-executes if threshold is reached.
  void castVote(VoteType type) {
    if (_room == null) return;
    if (_room!.activeVoteType != null && _room!.activeVoteType != type) return;

    // Start a new vote if none is active.
    if (_room!.activeVoteType == null) {
      _room!.activeVoteType = type;
      _room!.voterIds       = {};
      _room!.status         = RoomStatus.voting;
      _startVoteTimer();
    }

    _room!.voterIds.add(_localUserId);
    _checkVoteThreshold();
    notifyListeners();
  }

  void _checkVoteThreshold() {
    if (_room == null) return;
    final participantCount = _room!.participantCount;
    if (participantCount == 0) return;

    final ratio = _room!.voterIds.length / participantCount;
    final voteType = _room!.activeVoteType;

    final skipThreshold   = AppConstants.skipVoteThreshold;
    final replayThreshold = AppConstants.replayVoteThreshold;

    if (voteType == VoteType.skip   && ratio >= skipThreshold)   _executeSkip();
    if (voteType == VoteType.replay && ratio >= replayThreshold) _executeReplay();
  }

  void _executeSkip() {
    if (_room == null) return;
    _clearVote();
    if (_room!.queue.isNotEmpty) {
      _room!.queue.removeAt(0);
    }
    if (_room!.queue.isNotEmpty) {
      final next = _room!.queue.first.song;
      _audio?.playSong(next, _room!.queue.map((q) => q.song).toList());
      _room!.status = RoomStatus.active;
    } else {
      _room!.status = RoomStatus.idle;
      _startIdleTimer();
    }
    notifyListeners();
  }

  void _executeReplay() {
    if (_room == null) return;
    _clearVote();
    if (_room!.queue.isNotEmpty) {
      _audio?.playSong(
          _room!.queue.first.song,
          _room!.queue.map((q) => q.song).toList());
    }
    _room!.status = RoomStatus.active;
    notifyListeners();
  }

  void _clearVote() {
    _voteTimer?.cancel();
    _voteTimer = null;
    _room?.activeVoteType = null;
    _room?.voterIds       = {};
    _room?.voteCountdown  = null;
    if (_room?.status == RoomStatus.voting) {
      _room?.status = RoomStatus.active;
    }
  }

  void _startVoteTimer() {
    _voteTimer?.cancel();
    _room!.voteCountdown = 30;
    _voteTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_room == null) { t.cancel(); return; }
      _room!.voteCountdown = (_room!.voteCountdown ?? 1) - 1;
      if (_room!.voteCountdown! <= 0) {
        _clearVote();
      }
      notifyListeners();
    });
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  void sendMessage(String text) {
    if (_room == null || text.trim().isEmpty) return;
    _room!.messages.add(RoomChatMessage(
      participantId:   _localUserId,
      participantName: _localUserName,
      text:            text.trim(),
      timestamp:       DateTime.now(),
    ));
    // Keep last 50 messages only.
    if (_room!.messages.length > 50) {
      _room!.messages.removeAt(0);
    }
    notifyListeners();
  }

  // ── Emoji reactions ───────────────────────────────────────────────────────

  void sendReaction(String emoji) {
    if (_room == null) return;
    final reaction = EmojiReaction(
      id:        '${emoji}_${DateTime.now().millisecondsSinceEpoch}',
      emoji:     emoji,
      xFraction: 0.1 + _rng.nextDouble() * 0.8,
    );
    _reactions.add(reaction);
    notifyListeners();
    final timer = Timer(const Duration(milliseconds: 2500), () {
      _reactions.removeWhere((r) => r.id == reaction.id);
      notifyListeners();
    });
    _reactionTimers.add(timer);
  }

  // ── Simulation ────────────────────────────────────────────────────────────
  // Drives realistic-feeling activity without a real backend.

  void _startSimulation() {
    _simTimer?.cancel();
    // First simulated participant joins after 1.5 seconds.
    Timer(const Duration(milliseconds: 1500), _addSimulatedParticipant);
    // Second one joins 3 seconds after that.
    Timer(const Duration(milliseconds: 4500), _addSimulatedParticipant);
    // Periodic activity after that — emoji and chat messages.
    _simTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _simulateActivity();
    });
  }

  void _addSimulatedParticipant() {
    if (_room == null) return;
    if (_room!.participants.length >= AppConstants.roomMaxParticipants) return;

    final usedNames = _room!.participants.map((p) => p.username).toSet();
    final available = _simNames.where((n) => !usedNames.contains(n)).toList();
    if (available.isEmpty) return;

    final name  = available[_rng.nextInt(available.length)];
    final color = _room!.participants.length %
        AppColors.participantColors.length;

    final participant = RoomParticipant(
      id:         'sim_${DateTime.now().millisecondsSinceEpoch}',
      username:   name,
      colorIndex: color.toInt(),
      isActive:   true,
    );

    _room!.participants.add(participant);
    _room!.messages.add(RoomChatMessage(
      participantId:   participant.id,
      participantName: participant.username,
      text:            '${participant.username} joined the room',
      timestamp:       DateTime.now(),
    ));

    _cancelIdleTimer();
    notifyListeners();
  }

  void _simulateActivity() {
    if (_room == null) return;
    final simParticipants = _room!.participants
        .where((p) => p.id != _localUserId)
        .toList();
    if (simParticipants.isEmpty) return;

    final roll = _rng.nextInt(100);

    if (roll < 35) {
      // Send a random emoji reaction from a random simulated participant.
      final emoji = _simEmojis[_rng.nextInt(_simEmojis.length)];
      sendReaction(emoji);
    } else if (roll < 55) {
      // Simulated participant sends a short chat message.
      final participant = simParticipants[_rng.nextInt(simParticipants.length)];
      const messages = [
        '🎵 love this track!',
        'banger 🔥',
        'who added this?',
        'great pick 👌',
        'this is a vibe',
        'next song next song',
      ];
      _room!.messages.add(RoomChatMessage(
        participantId:   participant.id,
        participantName: participant.username,
        text:            messages[_rng.nextInt(messages.length)],
        timestamp:       DateTime.now(),
      ));
      if (_room!.messages.length > 50) _room!.messages.removeAt(0);
      notifyListeners();
    } else if (roll < 65) {
      // Toggle a participant's active status.
      final participant = simParticipants[_rng.nextInt(simParticipants.length)];
      final idx = _room!.participants
          .indexWhere((p) => p.id == participant.id);
      if (idx >= 0) {
        _room!.participants[idx] =
            participant.copyWith(isActive: !participant.isActive);
        notifyListeners();
      }
    }
  }

  // ── Timers ────────────────────────────────────────────────────────────────

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(AppConstants.roomIdleTimeout, () {
      if (_room != null && _room!.status == RoomStatus.idle) {
        leaveRoom();
      }
    });
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void _cancelAllTimers() {
    _idleTimer?.cancel();
    _simTimer?.cancel();
    _voteTimer?.cancel();
    _reactionTimer?.cancel();
    
    for (final t in _reactionTimers) {
      t.cancel();
    }
    _reactionTimers.clear();

    _idleTimer      = null;
    _simTimer       = null;
    _voteTimer      = null;
    _reactionTimer  = null;
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _cancelAllTimers();
    super.dispose();
  }
}
