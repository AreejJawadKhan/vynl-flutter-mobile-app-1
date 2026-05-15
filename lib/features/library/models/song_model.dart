import 'package:on_audio_query/on_audio_query.dart';

/// Immutable representation of a single audio track.
///
/// Wraps [SongModel] from on_audio_query with typed accessors
/// and helpers used throughout the app.
class SongItem {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final int duration; // milliseconds
  final String? uri;  // file:// URI for playback
  final int? albumId; // used to load album art via on_audio_query
  final int dateAdded; // Unix timestamp seconds

  const SongItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.duration,
    required this.dateAdded,
    this.uri,
    this.albumId,
  });

  /// Build a [SongItem] from on_audio_query's raw [SongModel].
  factory SongItem.fromAudioQuery(SongModel raw) {
    return SongItem(
      id:        raw.id,
      title:     _cleanTitle(raw.title),
      artist:    raw.artist ?? 'Unknown Artist',
      album:     raw.album  ?? 'Unknown Album',
      genre:     raw.genre  ?? 'Unknown',
      duration:  raw.duration ?? 0,
      uri:       raw.uri,
      albumId:   raw.albumId,
      dateAdded: raw.dateAdded ?? 0,
    );
  }

  /// Duration formatted as m:ss (e.g. "3:42").
  String get formattedDuration {
    final d = Duration(milliseconds: duration);
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// The unique string ID used in SharedPreferences liked/recent lists.
  String get persistId => id.toString();

  // ── Equality ──────────────────────────────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SongItem && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SongItem(id: $id, title: $title, artist: $artist)';

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Strips common file-extension suffixes from raw titles like "track.mp3".
  static String _cleanTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'\.(mp3|flac|aac|ogg|m4a|wav|wma)$',
            caseSensitive: false), '')
        .trim();
  }
}

/// How the library list is currently sorted.
enum SortMode {
  titleAZ,
  artistAZ,
  recentlyAdded,
}

extension SortModeLabel on SortMode {
  String get label {
    switch (this) {
      case SortMode.titleAZ:      return 'Title A–Z';
      case SortMode.artistAZ:     return 'Artist A–Z';
      case SortMode.recentlyAdded: return 'Recently added';
    }
  }
}
