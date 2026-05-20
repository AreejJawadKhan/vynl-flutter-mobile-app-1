import '../features/library/models/song_model.dart';
import '../features/rooms/models/room_models.dart';

/// Maps Firebase Realtime Database room nodes ↔ app models.
class RoomRtdbCodec {
  RoomRtdbCodec._();

  static Map<String, dynamic> songToMap(SongItem song) => {
        'deviceSongId': song.id,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'genre': song.genre,
        'duration': song.duration,
        'uri': song.uri,
        'albumId': song.albumId,
        'albumArtUrl': song.albumArtUrl ?? '',
      };

  static SongItem songFromMap(Map<dynamic, dynamic> m) {
    final map = Map<String, dynamic>.from(m);
    return SongItem(
      id: (map['deviceSongId'] as num?)?.toInt() ?? 0,
      title: map['title']?.toString() ?? 'Unknown',
      artist: map['artist']?.toString() ?? 'Unknown Artist',
      album: map['album']?.toString() ?? 'Unknown Album',
      genre: map['genre']?.toString() ?? 'Unknown',
      duration: (map['duration'] as num?)?.toInt() ?? 0,
      uri: map['uri']?.toString(),
      albumId: (map['albumId'] as num?)?.toInt(),
      dateAdded: 0,
      albumArtUrl: map['albumArtUrl']?.toString().isNotEmpty == true
          ? map['albumArtUrl'] as String
          : null,
    );
  }

  static RoomParticipant participantFromMap(
    String id,
    Map<dynamic, dynamic> m,
  ) {
    return RoomParticipant(
      id: id,
      username: m['username']?.toString() ?? 'Guest',
      colorIndex: (m['colorIndex'] as num?)?.toInt() ?? 0,
      isActive: m['isActive'] as bool? ?? true,
    );
  }

  static RoomQueueItem queueItemFromMap(
    String id,
    Map<dynamic, dynamic> m,
  ) {
    final songMap = Map<String, dynamic>.from(
      (m['song'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    return RoomQueueItem(
      id: id,
      song: songFromMap(songMap),
      addedById: m['addedById']?.toString() ?? '',
      addedByName: m['addedByName']?.toString() ?? '',
      upvotes: (m['upvotes'] as num?)?.toInt() ?? 0,
      downvotes: (m['downvotes'] as num?)?.toInt() ?? 0,
    );
  }

  static RoomChatMessage messageFromMap(Map<dynamic, dynamic> m) {
    final ts = m['timestamp'];
    return RoomChatMessage(
      participantId: m['participantId']?.toString() ?? '',
      participantName: m['participantName']?.toString() ?? '',
      text: m['text']?.toString() ?? '',
      timestamp: ts is int
          ? DateTime.fromMillisecondsSinceEpoch(ts)
          : DateTime.now(),
    );
  }

  static String statusToString(RoomStatus s) {
    switch (s) {
      case RoomStatus.idle:
        return 'idle';
      case RoomStatus.active:
        return 'active';
      case RoomStatus.voting:
        return 'voting';
      case RoomStatus.empty:
        return 'empty';
    }
  }

  static RoomStatus statusFromString(String? raw) {
    switch (raw) {
      case 'active':
        return RoomStatus.active;
      case 'voting':
        return RoomStatus.voting;
      case 'empty':
        return RoomStatus.empty;
      default:
        return RoomStatus.idle;
    }
  }
}
