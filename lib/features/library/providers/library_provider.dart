import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/prefs_keys.dart';
import '../../../core/utils/permission_helper.dart';
import '../models/song_model.dart';

/// Manages the full music library:
///   - Device scan via on_audio_query
///   - Sort and search filtering
///   - Liked songs list (persisted)
///   - Recently played list (persisted)
class LibraryProvider extends ChangeNotifier {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  // ── Raw data ───────────────────────────────────────────────────────────────
  List<SongItem> _allSongs = [];

  // ── UI state ───────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  SortMode _sortMode = SortMode.titleAZ;

  // ── Persisted sets ─────────────────────────────────────────────────────────
  Set<String> _likedIds = {};
  List<String> _recentIds = []; // ordered newest-first

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isLoading     => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  SortMode get sortMode  => _sortMode;

  List<SongItem> get allSongs => _allSongs;

  /// The list shown in the UI — filtered by search, sorted by sortMode.
  List<SongItem> get displayedSongs {
    var list = _allSongs.toList();

    // Apply search filter.
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) =>
          s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q)).toList();
    }

    // Apply sort.
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

  /// Songs matching a mood keyword set — used by voice search (Phase 5).
  List<SongItem> songsMatchingKeywords(List<String> keywords) {
    if (keywords.isEmpty) return _allSongs.toList();
    return _allSongs.where((s) {
      final hay = '${s.title} ${s.artist} ${s.album} ${s.genre}'.toLowerCase();
      return keywords.any((kw) => hay.contains(kw.toLowerCase()));
    }).toList();
  }

  bool isLiked(SongItem song) => _likedIds.contains(song.persistId);

  List<SongItem> get likedSongs =>
      _allSongs.where((s) => _likedIds.contains(s.persistId)).toList();

  List<SongItem> get recentlyPlayed {
    final map = {for (final s in _allSongs) s.persistId: s};
    return _recentIds
        .where(map.containsKey)
        .map((id) => map[id]!)
        .toList();
  }

  int get likedCount  => _likedIds.length;
  int get totalCount  => _allSongs.length;

  // ── Initialisation ─────────────────────────────────────────────────────────
  LibraryProvider() {
    _loadPersistedData().then((_) => scanLibrary());
  }

  Future<void> _loadPersistedData() async {
    final prefs = await SharedPreferences.getInstance();
    _likedIds   = Set<String>.from(prefs.getStringList(PrefsKeys.likedSongs) ?? []);
    _recentIds  = prefs.getStringList(PrefsKeys.recentlyPlayed) ?? [];
  }

  // ── Library scan ───────────────────────────────────────────────────────────

  /// Scans device storage for all audio files.
  /// Safe to call multiple times (e.g. on Refresh button tap).
  Future<void> scanLibrary() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Request permission natively before querying to prevent on_audio_query crash
      final hasPerm = await PermissionHelper.hasStorage();
      if (!hasPerm) {
        final granted = await PermissionHelper.requestStorage();
        if (!granted) {
          _errorMessage = 'Permission denied. Please enable in settings.';
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      final rawSongs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      _allSongs = rawSongs
          .where((s) =>
              s.duration != null &&
              s.duration! > 10000 && // skip clips shorter than 10s
              s.uri != null)
          .map((s) {
            final item = SongItem.fromAudioQuery(s);
            // If genre is missing, try to guess or assign random
            if (item.genre == 'Unknown' || item.genre.isEmpty || item.genre == '<unknown>') {
              return _enrichWithGenre(item);
            }
            return item;
          })
          .toList();

    } catch (e) {
      _errorMessage = 'Could not load music library. '
          'Please check storage permissions.';
      debugPrint('[LibraryProvider] scan error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Search ─────────────────────────────────────────────────────────────────
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

  // ── Sort ───────────────────────────────────────────────────────────────────
  void setSortMode(SortMode mode) {
    if (_sortMode == mode) return;
    _sortMode = mode;
    notifyListeners();
  }

  // ── Liked songs ────────────────────────────────────────────────────────────
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
    await prefs.setStringList(PrefsKeys.likedSongs, _likedIds.toList());
  }

  // ── Recently played ────────────────────────────────────────────────────────
  Future<void> recordPlayed(SongItem song) async {
    _recentIds.remove(song.persistId);
    _recentIds.insert(0, song.persistId);
    if (_recentIds.length > 20) {
      _recentIds = _recentIds.sublist(0, 20);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(PrefsKeys.recentlyPlayed, _recentIds);
  }

  // ── Lookup by ID ───────────────────────────────────────────────────────────
  SongItem? songById(int id) {
    try {
      return _allSongs.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns the next song after [current] in [queue], wrapping if needed.
  SongItem? nextSong(SongItem current, List<SongItem> queue) {
    if (queue.isEmpty) return null;
    final idx = queue.indexOf(current);
    if (idx < 0 || idx >= queue.length - 1) return queue.first;
    return queue[idx + 1];
  }

  /// Returns the previous song before [current] in [queue].
  SongItem? previousSong(SongItem current, List<SongItem> queue) {
    if (queue.isEmpty) return null;
    final idx = queue.indexOf(current);
    if (idx <= 0) return queue.last;
    return queue[idx - 1];
  }

  // ── Genre Simulation ───────────────────────────────────────────────────────

  SongItem _enrichWithGenre(SongItem item) {
    final guessed = _guessGenre(item.artist, item.title);
    return SongItem(
      id:        item.id,
      title:     item.title,
      artist:    item.artist,
      album:     item.album,
      genre:     guessed,
      duration:  item.duration,
      dateAdded: item.dateAdded,
      uri:       item.uri,
      albumId:   item.albumId,
    );
  }

  String _guessGenre(String artist, String title) {
    final a = artist.toLowerCase();
    final t = title.toLowerCase();

    // 1. Famous artist mapping
    if (a.contains('swift')) return 'Pop';
    if (a.contains('weeknd')) return 'Pop';
    if (a.contains('drake') || a.contains('post malone')) return 'Hip Hop';
    if (a.contains('imagine dragons') || a.contains('coldplay')) return 'Rock';
    if (a.contains('lofi') || a.contains('chill')) return 'Lofi';
    if (a.contains('beethoven') || a.contains('mozart') || a.contains('bach')) return 'Classical';
    
    // 2. Title keywords
    if (t.contains('lofi') || t.contains('chill') || t.contains('study')) return 'Lofi';
    if (t.contains('remix') || t.contains('dance') || t.contains('club')) return 'Dance';
    if (t.contains('acoustic') || t.contains('piano')) return 'Acoustic';

    // 3. Random fallback from curated list
    const genres = ['Pop', 'Rock', 'Hip Hop', 'Jazz', 'Classical', 'Lofi', 'Dance', 'R&B'];
    // Use the song ID as a seed so it's consistent for the same song
    final random = (item_id) => genres[item_id % genres.length];
    
    // Using a simple hash of the artist name to keep it consistent
    int hash = 0;
    for (int i = 0; i < a.length; i++) {
      hash = (hash << 5) - hash + a.codeUnitAt(i);
    }
    return genres[hash.abs() % genres.length];
  }
}
