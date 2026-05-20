import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../../auth/providers/auth_provider.dart' as ap;
import '../../../services/analytics_service.dart';
import '../models/social_models.dart';

class SocialProvider extends ChangeNotifier {
  ap.AuthProvider? _auth;
  String? _activeUid;
  StreamSubscription? _feedSub;

  List<NowPlayingEntry> _feed = [];
  List<NowPlayingEntry> get feed => List.unmodifiable(_feed);

  BlendResult? _blend;
  BlendResult? get blend => _blend;

  bool _loading = false;
  bool get loading => _loading;

  void updateAuth(ap.AuthProvider auth) {
    _auth = auth;
    if (auth.isAuthenticated) {
      _activeUid = auth.uid;
      _startListeningFeed();
    } else {
      _feedSub?.cancel();
      _feed = [];
      final uid = _activeUid;
      _activeUid = null;
      if (uid != null && uid.isNotEmpty) {
        _removeNowPlayingEntry(uid);
      }
      notifyListeners();
    }
  }

  Future<void> _removeNowPlayingEntry(String uid) async {
    try {
      await FirebaseDatabase.instance.ref('nowPlaying/$uid').remove();
    } catch (e) {
      debugPrint('[SocialProvider] clear nowPlaying on sign-out: $e');
    }
  }

  /// Re-subscribes to the now-playing feed (e.g. pull-to-refresh).
  Future<void> refreshFeed() async {
    if (_auth == null || !_auth!.isAuthenticated) return;
    _startListeningFeed();
  }

  void _startListeningFeed() {
    _feedSub?.cancel();
    final ref = FirebaseDatabase.instance.ref('nowPlaying');
    _feedSub = ref.onValue.listen(
          (event) {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          _feed = [];
          notifyListeners();
          return;
        }
        final map = event.snapshot.value as Map<dynamic, dynamic>;
        _feed = map.entries
            .where((e) => e.key != _auth?.uid)
            .map((e) {
          try {
            return NowPlayingEntry.fromMap(
              e.key as String,
              Map<String, dynamic>.from(e.value as Map),
            );
          } catch (_) {
            return null;
          }
        })
            .whereType<NowPlayingEntry>()
            .where((e) => e.isRecent)
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[SocialProvider] Feed error: $e');
      },
    );
  }

  Future<void> broadcastNowPlaying({
    required String title,
    required String artist,
    required String? albumArtUrl,
    required String? genre,
  }) async {
    if (_auth == null || !_auth!.isAuthenticated) return;
    try {
      final ref = FirebaseDatabase.instance
          .ref('nowPlaying/${_auth!.uid}');
      await ref.set({
        'uid':         _auth!.uid,
        'displayName': _auth!.displayName,
        'photoUrl':    _auth!.photoUrl ?? '',
        'title':       title,
        'artist':      artist,
        'albumArtUrl': albumArtUrl ?? '',
        'genre':       genre ?? 'Unknown',
        'timestamp':   ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('[SocialProvider] broadcastNowPlaying error: $e');
    }
  }

  Future<void> clearNowPlaying() async {
    if (_auth == null || !_auth!.isAuthenticated) return;
    try {
      await FirebaseDatabase.instance
          .ref('nowPlaying/${_auth!.uid}')
          .remove();
    } catch (e) {
      debugPrint('[SocialProvider] clearNowPlaying error: $e');
    }
  }

  Future<void> recordListeningHistory({
    required String title,
    required String artist,
    required String? genre,
  }) async {
    if (_auth == null || !_auth!.isAuthenticated) return;
    try {
      final ref = FirebaseDatabase.instance
          .ref('users/${_auth!.uid}/listeningHistory')
          .push();
      await ref.set({
        'title':     title,
        'artist':    artist,
        'genre':     genre ?? 'Unknown',
        'hour':      DateTime.now().hour,
        'timestamp': ServerValue.timestamp,
      });
      // History cap enforced by Cloud Function `trimListeningHistory`
    } catch (e) {
      debugPrint('[SocialProvider] recordHistory error: $e');
    }
  }

  Future<BlendResult?> calculateBlend(String otherUid) async {
    if (_auth == null || !_auth!.isAuthenticated) return null;

    _loading = true;
    notifyListeners();

    try {
      // Fetch both users' history and the other user's profile
      final myUid = _auth!.uid;

      final results = await Future.wait([
        FirebaseDatabase.instance
            .ref('users/$myUid/listeningHistory')
            .limitToLast(100)
            .get(),
        FirebaseDatabase.instance
            .ref('users/$otherUid/listeningHistory')
            .limitToLast(100)
            .get(),
        FirebaseDatabase.instance
            .ref('users/$otherUid')
            .get(),
      ]);

      final mySnap      = results[0];
      final theirSnap   = results[1];
      final profileSnap = results[2];

      final myHistory    = _parseHistory(mySnap);
      final theirHistory = _parseHistory(theirSnap);

      // Get the other user's display name
      String theirName = 'Friend';
      if (profileSnap.exists && profileSnap.value != null) {
        final profile =
        profileSnap.value as Map<dynamic, dynamic>;
        theirName =
            profile['displayName'] as String? ?? 'Friend';
      }

      _blend = _computeBlend(
        myUid:        myUid,
        myName:       _auth!.displayName,
        theirUid:     otherUid,
        theirName:    theirName,
        myHistory:    myHistory,
        theirHistory: theirHistory,
      );

      await AnalyticsService.logBlendCalculated(
        compatibilityPct: _blend!.compatibilityPct,
        noHistoryYet: _blend!.noHistoryYet,
      );

      return _blend;
    } catch (e) {
      debugPrint('[SocialProvider] Blend error: $e');
      rethrow; // let UI show the error
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<HistoryEntry> _parseHistory(DataSnapshot snap) {
    if (!snap.exists || snap.value == null) return [];
    try {
      final map = snap.value as Map<dynamic, dynamic>;
      return map.values
          .map((v) {
        try {
          return HistoryEntry.fromMap(
              Map<String, dynamic>.from(v as Map));
        } catch (_) {
          return null;
        }
      })
          .whereType<HistoryEntry>()
          .toList();
    } catch (e) {
      debugPrint('[SocialProvider] parseHistory error: $e');
      return [];
    }
  }

  BlendResult _computeBlend({
    required String myUid,
    required String myName,
    required String theirUid,
    required String theirName,
    required List<HistoryEntry> myHistory,
    required List<HistoryEntry> theirHistory,
  }) {
    // No history yet on either side — placeholder until both users play songs
    if (myHistory.isEmpty && theirHistory.isEmpty) {
      return BlendResult(
        user1Uid:         myUid,
        user1Name:        myName,
        user2Uid:         theirUid,
        user2Name:        theirName,
        compatibilityPct: 0,
        sharedGenres:     [],
        sharedArtists:    [],
        label:            'Play songs to unlock your blend 🎵',
        noHistoryYet:     true,
      );
    }

    // Genre frequency maps (0.0–1.0)
    final myGenres    = _genreFrequency(myHistory);
    final theirGenres = _genreFrequency(theirHistory);
    final allGenres   = {...myGenres.keys, ...theirGenres.keys};

    double genreScore = 0;
    final sharedGenres = <String>[];
    for (final g in allGenres) {
      final a = myGenres[g]    ?? 0.0;
      final b = theirGenres[g] ?? 0.0;
      if (a > 0 && b > 0) {
        genreScore += (a < b ? a : b);
        sharedGenres.add(g);
      }
    }

    // Artist overlap
    final myArtists    = _artistFrequency(myHistory);
    final theirArtists = _artistFrequency(theirHistory);
    final sharedArtists = myArtists.keys
        .where((a) => theirArtists.containsKey(a))
        .take(5)
        .toList();
    final artistScore = myArtists.isEmpty
        ? 0.0
        : (sharedArtists.length / myArtists.length).clamp(0.0, 1.0);

    // Time-of-day overlap
    final timeScore = _timeOverlap(myHistory, theirHistory);

    // Weighted score
    double total;
    if (myHistory.isEmpty || theirHistory.isEmpty) {
      total = 0.25; // one side has no history
    } else {
      total = (genreScore * 0.5 +
          artistScore * 0.3 +
          timeScore   * 0.2)
          .clamp(0.0, 1.0);
    }

    final pct = (total * 100).round();

    return BlendResult(
      user1Uid:         myUid,
      user1Name:        myName,
      user2Uid:         theirUid,
      user2Name:        theirName,
      compatibilityPct: pct,
      sharedGenres:     sharedGenres.take(3).toList(),
      sharedArtists:    sharedArtists,
      label:            _blendLabel(pct),
      noHistoryYet:     false,
    );
  }

  Map<String, double> _genreFrequency(List<HistoryEntry> history) {
    final counts = <String, int>{};
    for (final e in history) {
      final g = e.genre ?? 'Unknown';
      if (g != 'Unknown') {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) return {};
    return counts.map((k, v) => MapEntry(k, v / total));
  }

  Map<String, int> _artistFrequency(List<HistoryEntry> history) {
    final counts = <String, int>{};
    for (final e in history) {
      if (e.artist.isNotEmpty) {
        counts[e.artist] = (counts[e.artist] ?? 0) + 1;
      }
    }
    return counts;
  }

  double _timeOverlap(
      List<HistoryEntry> a, List<HistoryEntry> b) {
    final aBuckets = _hourBuckets(a);
    final bBuckets = _hourBuckets(b);
    double overlap = 0;
    for (int h = 0; h < 24; h++) {
      overlap +=
      aBuckets[h] < bBuckets[h] ? aBuckets[h] : bBuckets[h];
    }
    return overlap.clamp(0.0, 1.0);
  }

  List<double> _hourBuckets(List<HistoryEntry> history) {
    final buckets = List<double>.filled(24, 0);
    for (final e in history) {
      if (e.hour >= 0 && e.hour < 24) buckets[e.hour]++;
    }
    final total = buckets.reduce((a, b) => a + b);
    if (total == 0) return buckets;
    return buckets.map((b) => b / total).toList();
  }

  String _blendLabel(int pct) {
    if (pct >= 85) return 'Musical Soulmates 🎵';
    if (pct >= 70) return 'Vibe Twins ✨';
    if (pct >= 55) return 'Solid Overlap 🎶';
    if (pct >= 40) return 'Different Worlds 🌍';
    return 'Polar Opposites 🎭';
  }

  @override
  void dispose() {
    _feedSub?.cancel();
    super.dispose();
  }
}