import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/prefs_keys.dart';
import '../../../core/utils/permission_helper.dart';
import '../../../services/music_enrichment_service.dart';
import '../models/song_model.dart';

class LibraryProvider extends ChangeNotifier {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final MusicEnrichmentService _enrichment = MusicEnrichmentService();

  List<SongItem> _allSongs = [];

  bool     _isLoading   = false;
  bool     _isEnriching = false;
  String?  _errorMessage;
  String   _searchQuery = '';
  SortMode _sortMode    = SortMode.titleAZ;

  Set<String>  _likedIds  = {};
  List<String> _recentIds = [];

  bool     get isLoading    => _isLoading;
  bool     get isEnriching  => _isEnriching;
  String?  get errorMessage => _errorMessage;
  String   get searchQuery  => _searchQuery;
  SortMode get sortMode     => _sortMode;

  List<SongItem> get allSongs => _allSongs;

  List<SongItem> get displayedSongs {
    var list = _allSongs.toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((s) =>
      s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.genre.toLowerCase().contains(q))
          .toList();
    }

    switch (_sortMode) {
      case SortMode.titleAZ:
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortMode.artistAZ:
        list.sort((a, b) =>
            a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case SortMode.recentlyAdded:
        list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
    }

    return list;
  }

  List<SongItem> songsMatchingKeywords(List<String> keywords) {
    if (keywords.isEmpty) return _allSongs.toList();
    return _allSongs.where((s) {
      final hay =
      '${s.title} ${s.artist} ${s.album} ${s.genre}'.toLowerCase();
      return keywords.any((kw) => hay.contains(kw.toLowerCase()));
    }).toList();
  }

  List<SongItem> get likedSongs =>
      _allSongs.where((s) => _likedIds.contains(s.persistId)).toList();

  List<SongItem> get recentlyPlayed {
    final map = {for (final s in _allSongs) s.persistId: s};
    return _recentIds.where(map.containsKey).map((id) => map[id]!).toList();
  }

  int get likedCount => _likedIds.length;
  int get totalCount => _allSongs.length;

  LibraryProvider() {
    _loadPersistedData().then((_) => scanLibrary());
  }

  Future<void> _loadPersistedData() async {
    final prefs = await SharedPreferences.getInstance();
    _likedIds  = Set<String>.from(
        prefs.getStringList(PrefsKeys.likedSongs) ?? []);
    _recentIds = prefs.getStringList(PrefsKeys.recentlyPlayed) ?? [];
  }

  // ── Library scan ────────────────────────────────────────────────────────

  Future<void> scanLibrary() async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final hasPerm = await PermissionHelper.hasStorage();
      if (!hasPerm) {
        final granted = await PermissionHelper.requestStorage();
        if (!granted) {
          _errorMessage =
          'Permission denied. Please enable in settings.';
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      final rawSongs = await _audioQuery.querySongs(
        sortType:   SongSortType.TITLE,
        orderType:  OrderType.ASC_OR_SMALLER,
        uriType:    UriType.EXTERNAL,
        ignoreCase: true,
      );

      _allSongs = rawSongs
          .where((s) =>
      s.duration != null &&
          s.duration! > 10000 &&
          s.uri != null)
          .map((s) => SongItem.fromAudioQuery(s))
          .toList();

      _isLoading = false;
      notifyListeners();

      // Enrich in background — don't block UI
      _enrichSongsInBackground();
    } catch (e) {
      _errorMessage =
      'Could not load music library. Check storage permissions.';
      debugPrint('[LibraryProvider] scan error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Enrichment ──────────────────────────────────────────────────────────

  Future<void> _enrichSongsInBackground() async {
    if (_allSongs.isEmpty) return;
    _isEnriching = true;
    notifyListeners();

    // 1. Load from Firebase first (shared across all devices/logins)
    final cache = await _loadEnrichmentFromFirebase();

    // 2. Apply cached values immediately so UI shows art right away
    bool anyCached = false;
    for (int i = 0; i < _allSongs.length; i++) {
      final song   = _allSongs[i];
      final key    = _metaKey(song.artist, song.title);
      final cached = cache[key];
      if (cached != null) {
        final artUrl = cached['albumArtUrl'];
        final genre  = cached['genre'];
        _allSongs[i] = song.copyWithEnrichment(
          genre: (genre != null && genre.isNotEmpty &&
              genre != 'Unknown')
              ? genre
              : null,
          albumArtUrl:
          (artUrl != null && artUrl.isNotEmpty) ? artUrl : null,
        );
        anyCached = true;
      }
    }
    if (anyCached) notifyListeners();

    // 3. Only call Last.fm for songs not in cache
    final needsEnrichment = _allSongs.where((s) {
      final key = _metaKey(s.artist, s.title);
      return !cache.containsKey(key);
    }).toList();

    debugPrint(
        '[Library] ${needsEnrichment.length} songs need Last.fm enrichment');

    if (needsEnrichment.isNotEmpty) {
      const batchSize = 5;
      for (int i = 0; i < needsEnrichment.length; i += batchSize) {
        final end =
        (i + batchSize).clamp(0, needsEnrichment.length);
        final batch = needsEnrichment.sublist(i, end);

        await Future.wait(batch.map(_enrichSong));

        if (end < needsEnrichment.length) {
          await Future.delayed(const Duration(milliseconds: 250));
        }
        notifyListeners();
      }

      // 4. Save newly fetched data to Firebase + local
      await _saveEnrichmentToFirebase();
      await _saveLocalCache();
    }

    _isEnriching = false;
    notifyListeners();
    debugPrint('[Library] Enrichment complete.');
  }

  Future<void> _enrichSong(SongItem song) async {
    try {
      final info =
      await _enrichment.getTrackInfo(song.artist, song.title);
      final idx  = _allSongs.indexOf(song);
      if (idx < 0) return;

      if (info == null) {
        // Use local genre guess as fallback
        final guessed = _guessGenre(song.artist, song.title);
        _allSongs[idx] = song.copyWithEnrichment(genre: guessed);
        return;
      }

      _allSongs[idx] = song.copyWithEnrichment(
        genre: info.genre ?? _guessGenre(song.artist, song.title),
        albumArtUrl: info.albumArtUrl,
      );
    } catch (e) {
      debugPrint(
          '[LibraryProvider] Enrich error for ${song.title}: $e');
    }
  }

  // ── Firebase enrichment cache ──────────────────────────────────────

  /// Consistent key for a song — same across all users/devices
  String _metaKey(String artist, String title) {
    final raw =
        '${artist.toLowerCase().trim()}::${title.toLowerCase().trim()}';
    int hash = 0;
    for (final c in raw.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return 'song_$hash';
  }

  Future<Map<String, Map<String, String>>>
  _loadEnrichmentFromFirebase() async {
    // Always load local cache first as offline fallback
    final localCache = await _loadLocalCache();

    // Check if user is logged in
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('[Library] Not logged in — using local cache only');
      return localCache;
    }

    try {
      final snapshot =
      await FirebaseDatabase.instance.ref('songMeta').get();

      if (!snapshot.exists || snapshot.value == null) {
        return localCache;
      }

      final data   = snapshot.value as Map<dynamic, dynamic>;
      final result = <String, Map<String, String>>{};

      data.forEach((key, value) {
        if (value is Map) {
          result[key.toString()] = {
            'genre':
            value['genre']?.toString() ?? 'Unknown',
            'albumArtUrl':
            value['albumArtUrl']?.toString() ?? '',
            'artist': value['artist']?.toString() ?? '',
            'title':  value['title']?.toString() ?? '',
          };
        }
      });

      // Merge: local cache fills any gaps
      localCache.forEach((k, v) {
        if (!result.containsKey(k)) result[k] = v;
      });

      debugPrint(
          '[Library] Loaded ${result.length} entries from Firebase songMeta');
      return result;
    } catch (e) {
      debugPrint(
          '[Library] Firebase songMeta load error: $e — using local cache');
      return localCache;
    }
  }

  Future<void> _saveEnrichmentToFirebase() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final updates = <String, dynamic>{};

      for (final song in _allSongs) {
        // Only save songs that have real enrichment
        if (song.albumArtUrl != null ||
            (song.genre != 'Unknown' && song.genre.isNotEmpty)) {
          final key = _metaKey(song.artist, song.title);
          updates['$key/genre']       = song.genre;
          updates['$key/albumArtUrl'] = song.albumArtUrl ?? '';
          updates['$key/artist']      = song.artist;
          updates['$key/title']       = song.title;
        }
      }

      if (updates.isNotEmpty) {
        await FirebaseDatabase.instance
            .ref('songMeta')
            .update(updates);
        debugPrint(
            '[Library] Saved ${updates.length ~/ 4} songs to Firebase songMeta');
      }
    } catch (e) {
      debugPrint('[Library] Firebase save error: $e');
    }
  }

  // ── Local SharedPreferences cache (offline fallback) ───────────────

  Future<Map<String, Map<String, String>>> _loadLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('song_enrichment_v2');
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
            (k, v) => MapEntry(k, Map<String, String>.from(v as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveLocalCache() async {
    final prefs    = await SharedPreferences.getInstance();
    final cacheMap = <String, Map<String, String>>{};
    for (final song in _allSongs) {
      if (song.albumArtUrl != null ||
          (song.genre != 'Unknown' && song.genre.isNotEmpty)) {
        final key = _metaKey(song.artist, song.title);
        cacheMap[key] = {
          'genre':       song.genre,
          'albumArtUrl': song.albumArtUrl ?? '',
        };
      }
    }
    await prefs.setString(
        'song_enrichment_v2', jsonEncode(cacheMap));
  }

  // ── Search / Sort ───────────────────────────────────────────────────

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) return;
    _searchQuery = '';
    notifyListeners();
  }

  void setSortMode(SortMode mode) {
    if (_sortMode == mode) return;
    _sortMode = mode;
    notifyListeners();
  }

  // ── Liked songs ─────────────────────────────────────────────────────

  bool isLiked(SongItem song) => _likedIds.contains(song.persistId);

  Future<void> toggleLike(SongItem song) async {
    if (_likedIds.contains(song.persistId)) {
      _likedIds.remove(song.persistId);
    } else {
      _likedIds.add(song.persistId);
    }
    notifyListeners();
    await _persistLiked();
  }

  Future<void> _persistLiked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        PrefsKeys.likedSongs, _likedIds.toList());
  }

  // ── Recently played ─────────────────────────────────────────────────

  Future<void> recordPlayed(SongItem song) async {
    _recentIds.remove(song.persistId);
    _recentIds.insert(0, song.persistId);
    if (_recentIds.length > 20) {
      _recentIds = _recentIds.sublist(0, 20);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        PrefsKeys.recentlyPlayed, _recentIds);
  }

  // ── Lookup ──────────────────────────────────────────────────────────

  SongItem? songById(int id) {
    try {
      return _allSongs.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  SongItem? nextSong(SongItem current, List<SongItem> queue) {
    if (queue.isEmpty) return null;
    final idx = queue.indexOf(current);
    if (idx < 0 || idx >= queue.length - 1) return queue.first;
    return queue[idx + 1];
  }

  SongItem? previousSong(SongItem current, List<SongItem> queue) {
    if (queue.isEmpty) return null;
    final idx = queue.indexOf(current);
    if (idx <= 0) return queue.last;
    return queue[idx - 1];
  }

  // ── Genre fallback guess ────────────────────────────────────────────

  String _guessGenre(String artist, String title) {
    final a = artist.toLowerCase();
    final t = title.toLowerCase();

    if (a.contains('swift')) {
      return 'Pop';
    }
    if (a.contains('weeknd')) {
      return 'Pop';
    }
    if (a.contains('drake') || a.contains('post malone')) {
      return 'Hip Hop';
    }
    if (a.contains('imagine dragons') || a.contains('coldplay')) {
      return 'Rock';
    }
    if (a.contains('lofi') || a.contains('chill')) {
      return 'Lofi';
    }
    if (a.contains('beethoven') || a.contains('mozart') || a.contains('bach')) {
      return 'Classical';
    }

    if (t.contains('lofi') || t.contains('chill') || t.contains('study')) {
      return 'Lofi';
    }
    if (t.contains('remix') || t.contains('dance') || t.contains('club')) {
      return 'Dance';
    }
    if (t.contains('acoustic') || t.contains('piano')) {
      return 'Acoustic';
    }

    const genres = [
      'Pop', 'Rock', 'Hip Hop', 'Jazz',
      'Classical', 'Lofi', 'Dance', 'R&B'
    ];
    int hash = 0;
    for (int i = 0; i < a.length; i++) {
      hash = (hash << 5) - hash + a.codeUnitAt(i);
    }
    return genres[hash.abs() % genres.length];
  }
}
