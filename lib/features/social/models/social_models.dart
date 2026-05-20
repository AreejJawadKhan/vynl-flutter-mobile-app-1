class NowPlayingEntry {
  final String uid;
  final String displayName;
  final String photoUrl;
  final String title;
  final String artist;
  final String albumArtUrl;
  final String genre;
  final int timestamp;

  const NowPlayingEntry({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.title,
    required this.artist,
    required this.albumArtUrl,
    required this.genre,
    required this.timestamp,
  });

  factory NowPlayingEntry.fromMap(String uid, Map<String, dynamic> map) {
    return NowPlayingEntry(
      uid:         uid,
      displayName: map['displayName'] as String? ?? 'Someone',
      photoUrl:    map['photoUrl']    as String? ?? '',
      title:       map['title']       as String? ?? '',
      artist:      map['artist']      as String? ?? '',
      albumArtUrl: map['albumArtUrl'] as String? ?? '',
      genre:       map['genre']       as String? ?? 'Unknown',
      timestamp:   _readTimestamp(map['timestamp']),
    );
  }

  static int _readTimestamp(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  /// Treat missing/zero timestamp as recent (ServerValue may resolve after first read).
  bool get isRecent {
    if (timestamp <= 0) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - timestamp) < 10 * 60 * 1000;
  }
}

class HistoryEntry {
  final String title;
  final String artist;
  final String? genre;
  final int hour;
  final int timestamp;

  const HistoryEntry({
    required this.title,
    required this.artist,
    this.genre,
    required this.hour,
    required this.timestamp,
  });

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      title:     map['title']     as String? ?? '',
      artist:    map['artist']    as String? ?? '',
      genre:     map['genre']     as String?,
      hour:      map['hour']      as int?    ?? 0,
      timestamp: map['timestamp'] as int?    ?? 0,
    );
  }
}

class BlendResult {
  final String user1Uid;
  final String user1Name;
  final String user2Uid;
  final String user2Name;
  final int compatibilityPct;
  final List<String> sharedGenres;
  final List<String> sharedArtists;
  final String label;
  final bool noHistoryYet;

  const BlendResult({
    required this.user1Uid,
    required this.user1Name,
    required this.user2Uid,
    required this.user2Name,
    required this.compatibilityPct,
    required this.sharedGenres,
    required this.sharedArtists,
    required this.label,
    this.noHistoryYet = false,
  });
}