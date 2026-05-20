import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../features/library/models/song_model.dart';

// ── Room state ────────────────────────────────────────────────────────────────

/// The lifecycle state of a room.
enum RoomStatus {
  idle,    // Room exists, no song playing
  active,  // Song is playing
  voting,  // A skip or replay vote is in progress
  empty,   // No participants — will auto-close after 5 minutes
}

// ── Participant ───────────────────────────────────────────────────────────────

/// A single participant in a room.
class RoomParticipant {
  final String id;       // unique per session
  final String username;
  final int colorIndex;  // index into AppColors.participantColors
  bool isActive;         // true = currently listening, false = away

  RoomParticipant({
    required this.id,
    required this.username,
    required this.colorIndex,
    this.isActive = true,
  });

  Color get color => AppColors.participantColors[
      colorIndex % AppColors.participantColors.length];

  /// First letter of username, uppercased — shown in the avatar circle.
  String get initial => username.isEmpty ? '?' : username[0].toUpperCase();

  RoomParticipant copyWith({bool? isActive}) {
    return RoomParticipant(
      id:         id,
      username:   username,
      colorIndex: colorIndex,
      isActive:   isActive ?? this.isActive,
    );
  }
}

// ── Queue item ────────────────────────────────────────────────────────────────

/// One entry in the room's song queue.
class RoomQueueItem {
  final String id;           // unique per queue entry
  final SongItem song;
  final String addedById;    // participant ID who added it
  final String addedByName;
  int upvotes;
  int downvotes;             // skip votes

  RoomQueueItem({
    required this.id,
    required this.song,
    required this.addedById,
    required this.addedByName,
    this.upvotes   = 0,
    this.downvotes = 0,
  });
}

// ── Chat message ──────────────────────────────────────────────────────────────

/// A single chat message shown in the mini-chat bubble.
class RoomChatMessage {
  final String participantId;
  final String participantName;
  final String text;
  final DateTime timestamp;

  const RoomChatMessage({
    required this.participantId,
    required this.participantName,
    required this.text,
    required this.timestamp,
  });
}

// ── Emoji reaction ────────────────────────────────────────────────────────────

/// A floating emoji reaction triggered by a participant.
/// [id] is used as a widget key so Flutter can track the animation.
class EmojiReaction {
  final String id;
  final String emoji;
  final double xFraction; // 0.0–1.0 horizontal position on screen

  const EmojiReaction({
    required this.id,
    required this.emoji,
    required this.xFraction,
  });
}

// ── Vote type ─────────────────────────────────────────────────────────────────

enum VoteType { skip, replay }

// ── Room settings ─────────────────────────────────────────────────────────────

/// Configurable room settings set at creation time.
class RoomSettings {
  final bool everyoneCanAdd;       // false = host only
  final bool majoritySkip;         // false = host-only skip

  const RoomSettings({
    this.everyoneCanAdd = true,
    this.majoritySkip   = true,
  });

  RoomSettings copyWith({bool? everyoneCanAdd, bool? majoritySkip}) {
    return RoomSettings(
      everyoneCanAdd: everyoneCanAdd ?? this.everyoneCanAdd,
      majoritySkip:   majoritySkip   ?? this.majoritySkip,
    );
  }
}

// ── Room ──────────────────────────────────────────────────────────────────────

/// The full state of a room. Managed entirely by [RoomProvider].
class Room {
  final String code;            // 6-char alphanumeric
  final String name;
  final String hostId;
  final RoomSettings settings;

  List<RoomParticipant> participants;
  List<RoomQueueItem>   queue;
  List<RoomChatMessage> messages;
  RoomStatus            status;

  // Current vote state (only one active at a time)
  VoteType?             activeVoteType;
  Set<String>           voterIds;       // participant IDs who have voted
  int?                  voteCountdown;  // seconds remaining (null = no vote)

  RoomQueueItem? get currentItem =>
      queue.isNotEmpty ? queue.first : null;

  Room({
    required this.code,
    required this.name,
    required this.hostId,
    required this.settings,
    List<RoomParticipant>? participants,
    List<RoomQueueItem>?   queue,
    List<RoomChatMessage>? messages,
    this.status       = RoomStatus.idle,
    this.activeVoteType,
    Set<String>?      voterIds,
    this.voteCountdown,
  })  : participants = participants ?? [],
        queue        = queue        ?? [],
        messages     = messages     ?? [],
        voterIds     = voterIds     ?? {};

  bool isHostFor(String userId) => hostId == userId;

  int get participantCount => participants.length;
}
