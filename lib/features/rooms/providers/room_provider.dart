import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/prefs_keys.dart';
import '../../../core/utils/app_utils.dart';
import '../../../features/auth/providers/auth_provider.dart' as ap;
import '../../../features/library/models/song_model.dart';
import '../../../services/room_rtdb_codec.dart';
import '../../../shared/providers/audio_provider.dart';
import '../models/room_models.dart';

/// Real-time group rooms backed by Firebase Realtime Database.
class RoomProvider extends ChangeNotifier {
  AudioProvider? _audio;
  ap.AuthProvider? _auth;

  Room? _room;
  Room? get room => _room;
  bool get inRoom => _room != null;

  String? _joinError;
  String? get joinError => _joinError;

  List<EmojiReaction> _reactions = [];
  List<EmojiReaction> get reactions => List.unmodifiable(_reactions);

  Timer? _idleTimer;
  Timer? _voteTimer;
  final List<Timer> _reactionTimers = [];
  final List<StreamSubscription<DatabaseEvent>> _roomSubs = [];

  List<String> _history = [];
  List<String> get history => List.unmodifiable(_history);

  final Random _rng = Random();
  String? _lastPlayedQueueHeadId;
  bool _voteActionInProgress = false;

  RoomProvider() {
    _loadHistory();
  }

  String? get _uid => _auth?.uid;
  bool get _isAuthed => _auth?.isAuthenticated ?? false;

  void updateAudio(AudioProvider audio) => _audio = audio;

  void updateAuth(ap.AuthProvider auth) {
    _auth = auth;
    if (!auth.isAuthenticated && inRoom) {
      leaveRoom();
    }
  }

  DatabaseReference get _roomRef =>
      FirebaseDatabase.instance.ref('rooms/${_room!.code}');

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

  Future<String> _allocateRoomCode() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final code = AppUtils.generateRoomCode();
      final snap =
          await FirebaseDatabase.instance.ref('rooms/$code').get();
      if (!snap.exists) return code;
    }
    throw StateError('Could not allocate a unique room code');
  }

  // ── RTDB listeners ────────────────────────────────────────────────────────

  void _attachRoomListeners(String code) {
    _cancelRoomSubs();
    final base = FirebaseDatabase.instance.ref('rooms/$code');

    _roomSubs.add(base.onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        if (inRoom) leaveRoom();
        return;
      }
      _mergeRoomMeta(event.snapshot.value as Map<dynamic, dynamic>);
    }));

    _roomSubs.add(base.child('participants').onValue.listen((event) {
      _mergeParticipants(event.snapshot);
      notifyListeners();
    }));

    _roomSubs.add(base.child('queue').onValue.listen((event) {
      _mergeQueue(event.snapshot);
      _maybeSyncPlayback();
      notifyListeners();
    }));

    _roomSubs.add(base.child('messages').onValue.listen((event) {
      _mergeMessages(event.snapshot);
      notifyListeners();
    }));

    _roomSubs.add(base.child('voters').onValue.listen((event) {
      _mergeVoters(event.snapshot);
      notifyListeners();
    }));
  }

  void _cancelRoomSubs() {
    for (final s in _roomSubs) {
      s.cancel();
    }
    _roomSubs.clear();
  }

  void _mergeRoomMeta(Map<dynamic, dynamic> data) {
    if (_room == null) return;
    _room!.status =
        RoomRtdbCodec.statusFromString(data['status']?.toString());
    final voteType = data['activeVoteType']?.toString();
    _room!.activeVoteType = voteType == 'skip'
        ? VoteType.skip
        : voteType == 'replay'
            ? VoteType.replay
            : null;
    _room!.voteCountdown = (data['voteCountdown'] as num?)?.toInt();
    notifyListeners();
  }

  void _mergeParticipants(DataSnapshot snap) {
    if (_room == null) return;
    if (!snap.exists || snap.value == null) {
      _room!.participants = [];
      return;
    }
    final map = snap.value as Map<dynamic, dynamic>;
    _room!.participants = map.entries.map((e) {
      return RoomRtdbCodec.participantFromMap(
        e.key.toString(),
        Map<dynamic, dynamic>.from(e.value as Map),
      );
    }).toList()
      ..sort((a, b) => a.username.compareTo(b.username));
  }

  void _mergeQueue(DataSnapshot snap) {
    if (_room == null) return;
    if (!snap.exists || snap.value == null) {
      _room!.queue = [];
      return;
    }
    final map = snap.value as Map<dynamic, dynamic>;
    final items = map.entries.map((e) {
      final m = Map<dynamic, dynamic>.from(e.value as Map);
      return MapEntry(
        (m['order'] as num?)?.toInt() ?? 0,
        RoomRtdbCodec.queueItemFromMap(e.key.toString(), m),
      );
    }).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    _room!.queue = items.map((e) => e.value).toList();
  }

  void _mergeMessages(DataSnapshot snap) {
    if (_room == null) return;
    if (!snap.exists || snap.value == null) {
      _room!.messages = [];
      return;
    }
    final map = snap.value as Map<dynamic, dynamic>;
    final msgs = map.values
        .map((v) => RoomRtdbCodec.messageFromMap(
              Map<dynamic, dynamic>.from(v as Map),
            ))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (msgs.length > 50) {
      msgs.removeRange(0, msgs.length - 50);
    }
    _room!.messages = msgs;
  }

  void _mergeVoters(DataSnapshot snap) {
    if (_room == null) return;
    if (!snap.exists || snap.value == null) {
      _room!.voterIds = {};
      return;
    }
    final map = snap.value as Map<dynamic, dynamic>;
    _room!.voterIds = map.keys.map((k) => k.toString()).toSet();
    _checkVoteThreshold();
    notifyListeners();
  }

  void _maybeSyncPlayback() {
    if (_room == null || _room!.queue.isEmpty) return;
    final head = _room!.queue.first;
    if (_lastPlayedQueueHeadId == head.id) return;
    _lastPlayedQueueHeadId = head.id;
    if (head.song.uri == null || head.song.uri!.isEmpty) return;

    _room!.status = RoomStatus.active;
    _audio?.playSong(
      head.song,
      _room!.queue.map((q) => q.song).toList(),
    );
    _cancelIdleTimer();
  }

  // ── Create / join / leave ─────────────────────────────────────────────────

  Future<Room> createRoom({
    String? name,
    required RoomSettings settings,
  }) async {
    if (!_isAuthed || _uid == null) {
      throw StateError('Sign in to create a room');
    }

    if (inRoom) await leaveRoom();

    final code = await _allocateRoomCode();
    final roomName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : "${_auth!.displayName}'s Room";

    final colorIndex =
        _uid!.hashCode.abs() % AppColors.participantColors.length;

    final ref = FirebaseDatabase.instance.ref('rooms/$code');

    // Single atomic write — room + host participant together
    // This ensures participant exists before any read rule check
    await ref.set({
      'code':     code,
      'name':     roomName,
      'hostId':   _uid,
      'status':   'idle',
      'settings': {
        'everyoneCanAdd': settings.everyoneCanAdd,
        'majoritySkip':   settings.majoritySkip,
      },
      'activeVoteType': null,
      'voteCountdown':  null,
      'createdAt':      ServerValue.timestamp,
      'participants': {
        _uid!: {
          'username':   _auth!.displayName,
          'colorIndex': colorIndex,
          'isActive':   true,
          'joinedAt':   ServerValue.timestamp,
        }
      },
    });

    // Set disconnect handler after atomic write succeeds
    await ref.child('participants/$_uid').onDisconnect().remove();

    _room = Room(
      code:     code,
      name:     roomName,
      hostId:   _uid!,
      settings: settings,
      participants: [
        RoomParticipant(
          id:         _uid!,
          username:   _auth!.displayName,
          colorIndex: colorIndex,
          isActive:   true,
        ),
      ],
    );

    _lastPlayedQueueHeadId = null;
    _attachRoomListeners(code);
    await _saveHistory(code);
    await _incrementRoomsCreated();
    _startIdleTimer();
    notifyListeners();
    return _room!;
  }

  Future<bool> joinRoom(String code) async {
    _joinError = null;
    if (!_isAuthed || _uid == null) {
      _joinError = 'Sign in to join a room';
      notifyListeners();
      return false;
    }

    final trimmed = code.trim().toUpperCase();
    if (trimmed.length != AppConstants.roomCodeLength) {
      _joinError = 'Enter a 6-character code';
      notifyListeners();
      return false;
    }

    if (_room?.code == trimmed) {
      if (_roomSubs.isEmpty) _attachRoomListeners(trimmed);
      return true;
    }

    if (inRoom) await leaveRoom();

    final ref = FirebaseDatabase.instance.ref('rooms/$trimmed');
    final snap = await ref.get();
    if (!snap.exists || snap.value == null) {
      _joinError = 'Room not found. Check the code.';
      notifyListeners();
      return false;
    }

    final data = snap.value as Map<dynamic, dynamic>;
    final participants = data['participants'];
    if (participants is Map && participants.length >= AppConstants.roomMaxParticipants) {
      _joinError = 'Room is full';
      notifyListeners();
      return false;
    }

    final colorIndex =
        _uid!.hashCode.abs() % AppColors.participantColors.length;

    await ref.child('participants/$_uid').set({
      'username': _auth!.displayName,
      'colorIndex': colorIndex,
      'isActive': true,
      'joinedAt': ServerValue.timestamp,
    });
    await ref.child('participants/$_uid').onDisconnect().remove();

    await ref.child('messages').push().set({
      'participantId': _uid,
      'participantName': _auth!.displayName,
      'text': '${_auth!.displayName} joined the room',
      'timestamp': ServerValue.timestamp,
    });

    final settings = data['settings'];
    _room = Room(
      code: trimmed,
      name: data['name']?.toString() ?? 'Room $trimmed',
      hostId: data['hostId']?.toString() ?? '',
      settings: settings is Map
          ? RoomSettings(
              everyoneCanAdd: settings['everyoneCanAdd'] as bool? ?? true,
              majoritySkip: settings['majoritySkip'] as bool? ?? true,
            )
          : const RoomSettings(),
      status: RoomRtdbCodec.statusFromString(data['status']?.toString()),
    );

    _lastPlayedQueueHeadId = null;
    _attachRoomListeners(trimmed);
    await _saveHistory(trimmed);
    _startIdleTimer();
    notifyListeners();
    return true;
  }

  Future<void> leaveRoom() async {
    _cancelAllTimers();
    _cancelRoomSubs();

    if (_room != null && _uid != null) {
      final code = _room!.code;
      final ref = FirebaseDatabase.instance.ref('rooms/$code');
      await ref.child('participants/$_uid').remove();

      final snap = await ref.child('participants').get();
      final empty = !snap.exists ||
          snap.value == null ||
          (snap.value as Map).isEmpty;
      if (empty) {
        await ref.remove();
      }
    }

    _audio?.stop();
    _reactions = [];
    _room = null;
    _lastPlayedQueueHeadId = null;
    notifyListeners();
  }

  bool isHost(String userId) =>
      _room != null && _room!.hostId == userId;

  // ── Queue ─────────────────────────────────────────────────────────────────

  Future<bool> addSong(SongItem song) async {
    if (_room == null || _uid == null) return false;
    if (!_room!.settings.everyoneCanAdd && !isHost(_uid!)) {
      return false;
    }

    final order = _room!.queue.length;
    final itemId = _roomRef.child('queue').push().key!;
    await _roomRef.child('queue/$itemId').set({
      'order': order,
      'song': RoomRtdbCodec.songToMap(song),
      'addedById': _uid,
      'addedByName': _auth?.displayName ?? 'Guest',
      'upvotes': 0,
      'downvotes': 0,
    });

    if (_room!.status == RoomStatus.idle) {
      await _roomRef.update({'status': 'active'});
    }

    _cancelIdleTimer();
    notifyListeners();
    return true;
  }

  Future<void> removeQueueItem(String itemId) async {
    if (_room == null || _uid == null || !isHost(_uid!)) return;
    await _roomRef.child('queue/$itemId').remove();
    notifyListeners();
  }

  // ── Voting ────────────────────────────────────────────────────────────────

  Future<void> castVote(VoteType type) async {
    if (_room == null || _uid == null) return;
    if (_room!.activeVoteType != null && _room!.activeVoteType != type) {
      return;
    }

    if (_room!.activeVoteType == null) {
      await _roomRef.update({
        'activeVoteType': type == VoteType.skip ? 'skip' : 'replay',
        'status': 'voting',
        'voteCountdown': 30,
      });
      await _roomRef.child('voters').remove();
      _startVoteTimer();
    }

    _room!.voterIds.add(_uid!);
    await _roomRef.child('voters/$_uid').set(true);
    _checkVoteThreshold();
    notifyListeners();
  }

  void _checkVoteThreshold() {
    if (_room == null || _voteActionInProgress) return;
    if (_room!.activeVoteType == null) return;
    final count = _room!.participantCount;
    if (count == 0) return;

    final ratio = _room!.voterIds.length / count;
    final voteType = _room!.activeVoteType;

    if (voteType == VoteType.skip &&
        ratio >= AppConstants.skipVoteThreshold) {
      _executeSkip();
    } else if (voteType == VoteType.replay &&
        ratio >= AppConstants.replayVoteThreshold) {
      _executeReplay();
    }
  }

  Future<void> _executeSkip() async {
    if (_room == null || _voteActionInProgress) return;
    _voteActionInProgress = true;
    try {
      await _clearVote();
      if (_room!.queue.isNotEmpty) {
        final firstId = _room!.queue.first.id;
        _room!.queue.removeAt(0);
        _lastPlayedQueueHeadId = null;
        await _roomRef.child('queue/$firstId').remove();
      }
      if (_room!.queue.isEmpty) {
        await _roomRef.update({'status': 'idle'});
        _startIdleTimer();
      } else {
        await _roomRef.update({'status': 'active'});
        _maybeSyncPlayback();
      }
    } finally {
      _voteActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> _executeReplay() async {
    if (_room == null || _voteActionInProgress) return;
    _voteActionInProgress = true;
    try {
      await _clearVote();
      await _roomRef.update({'status': 'active'});
      _maybeSyncPlayback();
    } finally {
      _voteActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> _clearVote() async {
    _voteTimer?.cancel();
    _voteTimer = null;
    await _roomRef.update({
      'activeVoteType': null,
      'voteCountdown': null,
      'status': _room!.queue.isEmpty ? 'idle' : 'active',
    });
    await _roomRef.child('voters').remove();
  }

  void _startVoteTimer() {
    _voteTimer?.cancel();
    _voteTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_room == null) {
        t.cancel();
        return;
      }
      final next = (_room!.voteCountdown ?? 30) - 1;
      if (next <= 0) {
        t.cancel();
        await _clearVote();
      } else {
        await _roomRef.update({'voteCountdown': next});
      }
    });
  }

  // ── Chat & reactions ──────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    if (_room == null || _uid == null || text.trim().isEmpty) return;
    await _roomRef.child('messages').push().set({
      'participantId': _uid,
      'participantName': _auth?.displayName ?? 'Guest',
      'text': text.trim(),
      'timestamp': ServerValue.timestamp,
    });
  }

  void sendReaction(String emoji) {
    if (_room == null) return;
    final reaction = EmojiReaction(
      id: '${emoji}_${DateTime.now().millisecondsSinceEpoch}',
      emoji: emoji,
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
    _voteTimer?.cancel();
    for (final t in _reactionTimers) {
      t.cancel();
    }
    _reactionTimers.clear();
    _idleTimer = null;
    _voteTimer = null;
  }

  @override
  void dispose() {
    _cancelAllTimers();
    _cancelRoomSubs();
    final code = _room?.code;
    final uid = _uid;
    if (code != null && uid != null) {
      FirebaseDatabase.instance
          .ref('rooms/$code/participants/$uid')
          .remove();
    }
    _room = null;
    super.dispose();
  }
}
