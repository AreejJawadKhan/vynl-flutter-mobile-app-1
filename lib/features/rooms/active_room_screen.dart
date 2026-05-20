import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../auth/providers/auth_provider.dart' as ap;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import 'models/room_models.dart';
import 'providers/room_provider.dart';
import 'widgets/emoji_reaction_overlay.dart';
import 'widgets/participant_avatar.dart';
import 'widgets/queue_item_tile.dart';
import 'widgets/song_picker_sheet.dart';

/// The live room screen — shown when the user is inside a room.
/// Accessed from RoomsScreen once a room is active.
class ActiveRoomScreen extends StatefulWidget {
  const ActiveRoomScreen({super.key});

  @override
  State<ActiveRoomScreen> createState() => _ActiveRoomScreenState();
}

class _ActiveRoomScreenState extends State<ActiveRoomScreen> {
  final _chatCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();

  static const List<String> _quickEmojis = ['🎵', '🔥', '💃', '✨', '😍', '👌'];

  @override
  void dispose() {
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isPopping = false;

  void _leave() {
    if (_isPopping) return;
    _isPopping = true;
    context.read<RoomProvider>().leaveRoom();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = context.watch<RoomProvider>();
    final room  = rooms.room;

    if (room == null) {
      // Only pop if we've been in the screen for a moment
      // Don't pop immediately — give Firebase time to attach listeners
      if (!_isPopping) {
        _isPopping = true;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && rooms.room == null) {
            Navigator.of(context).pop();
          } else {
            // Firebase loaded — reset the flag
            if (mounted) setState(() => _isPopping = false);
          }
        });
      }
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Joining Room…')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to room…'),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _confirmLeave(context);
        if (leave && context.mounted) {
          _leave();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: _buildAppBar(context, room, rooms),
        body: Stack(
          children: [
            Column(
              children: [
                // ── Participants strip ───────────────────────────────────
                _ParticipantsStrip(participants: room.participants),

                // ── Queue list ───────────────────────────────────────────
                Expanded(
                  child: _QueueList(room: room, rooms: rooms),
                ),

                // ── Chat + emoji bar at bottom ───────────────────────────
                _BottomBar(
                  room:         room,
                  rooms:        rooms,
                  chatCtrl:     _chatCtrl,
                  quickEmojis:  _quickEmojis,
                  onMessageSent: _scrollChatToBottom,
                ),
              ],
            ),

            // ── Floating emoji reactions ─────────────────────────────────
            Positioned.fill(
              child: EmojiReactionOverlay(reactions: rooms.reactions),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, Room room, RoomProvider rooms) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () async {
          final leave = await _confirmLeave(context);
          if (leave && context.mounted) {
            _leave();
          }
        },
      ),
      title: Column(
        children: [
          Text(room.name, style: AppTextStyles.headlineSmall),
          Text(
            '${room.participantCount} listening',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
      actions: [
        // Copyable room code
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: room.code));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Room code copied'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceM,
                vertical:   AppConstants.spaceS),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  room.code,
                  style: AppTextStyles.roomCode.copyWith(
                    fontSize: 15,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.copy_rounded,
                    size: 14, color: AppColors.stone),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave room?'),
        content: const Text('The room will close and all participants will be disconnected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Leave',
                style: TextStyle(color: AppColors.darkBerry)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ── Participants strip ─────────────────────────────────────────────────────────

class _ParticipantsStrip extends StatelessWidget {
  final List<RoomParticipant> participants;
  const _ParticipantsStrip({required this.participants});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          bottom: BorderSide(
            color: AppColors.stone.withOpacity(0.15),
            width: 0.5,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spaceM,
            vertical:   AppConstants.spaceS),
        itemCount: participants.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppConstants.spaceM),
        itemBuilder: (_, i) => ParticipantAvatar(
          participant: participants[i],
          size: 44,
        ),
      ),
    );
  }
}

// ── Queue list ────────────────────────────────────────────────────────────────

class _QueueList extends StatelessWidget {
  final Room room;
  final RoomProvider rooms;
  const _QueueList({required this.room, required this.rooms});

  @override
  Widget build(BuildContext context) {
    if (room.queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.queue_music_rounded,
                size: 56, color: AppColors.stone),
            const SizedBox(height: AppConstants.spaceM),
            Text('Queue is empty', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppConstants.spaceS),
            Text('Add songs to start listening together',
                style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spaceM,
        AppConstants.spaceS,
        AppConstants.spaceM,
        // Extra padding for bottom bar + mini-player + nav
        AppConstants.miniPlayerCollapsedHeight +
            AppConstants.bottomNavHeight +
            100,
      ),
      itemCount: room.queue.length,
      itemBuilder: (_, i) {
        final item       = room.queue[i];
        final isFirst    = i == 0;
        final voteActive = room.activeVoteType != null && isFirst;
        final progress   = room.participants.isEmpty
            ? 0.0
            : room.voterIds.length / room.participants.length;

        final uid = context.read<ap.AuthProvider>().uid;
        return QueueItemTile(
          key:          ValueKey(item.id),
          item:         item,
          isFirst:      isFirst,
          isHost:       room.isHostFor(uid),
          votingActive: voteActive,
          voteProgress: progress.clamp(0.0, 1.0),
          onRemove:     () => rooms.removeQueueItem(item.id),
          onVoteSkip:   () {
            HapticFeedback.selectionClick();
            rooms.castVote(VoteType.skip);
          },
          onVoteReplay: () {
            HapticFeedback.selectionClick();
            rooms.castVote(VoteType.replay);
          },
        );
      },
    );
  }
}

// ── Bottom bar (chat + add song + emoji) ──────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final Room room;
  final RoomProvider rooms;
  final TextEditingController chatCtrl;
  final List<String> quickEmojis;
  final VoidCallback onMessageSent;

  const _BottomBar({
    required this.room,
    required this.rooms,
    required this.chatCtrl,
    required this.quickEmojis,
    required this.onMessageSent,
  });

  @override
  Widget build(BuildContext context) {
    // Mini-player and nav bar height padding
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    const extraPad = AppConstants.miniPlayerCollapsedHeight +
        AppConstants.bottomNavHeight +
        AppConstants.spaceS;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : extraPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Quick emoji strip ──────────────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
              children: quickEmojis.map((e) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    rooms.sendReaction(e);
                  },
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.blushDark.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),

          const SizedBox(height: 6),

          // ── Chat input + add song button ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceM),
            child: Row(
              children: [
                // Add song button
                _AddSongButton(room: room, rooms: rooms),
                const SizedBox(width: 8),

                // Chat text field
                Expanded(
                  child: TextField(
                    controller: chatCtrl,
                    textInputAction: TextInputAction.send,
                    maxLines: 1,
                    onSubmitted: (text) {
                      if (text.trim().isEmpty) return;
                      rooms.sendMessage(text);
                      chatCtrl.clear();
                      onMessageSent();
                    },
                    decoration: InputDecoration(
                      hintText: 'Say something…',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spaceM,
                          vertical:   10),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send_rounded,
                            size: 20, color: AppColors.darkBerry),
                        onPressed: () {
                          if (chatCtrl.text.trim().isEmpty) return;
                          rooms.sendMessage(chatCtrl.text);
                          chatCtrl.clear();
                          onMessageSent();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSongButton extends StatelessWidget {
  final Room room;
  final RoomProvider rooms;
  const _AddSongButton({required this.room, required this.rooms});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<ap.AuthProvider>().uid;
    final canAdd = room.settings.everyoneCanAdd || room.isHostFor(uid);
    return GestureDetector(
      onTap: canAdd
          ? () async {
              final song = await SongPickerSheet.show(context);
              if (song != null) {
                rooms.addSong(song);
              }
            }
          : null,
      child: Container(
        width:  44,
        height: 44,
        decoration: BoxDecoration(
          color: canAdd ? AppColors.sage : AppColors.stone.withOpacity(0.3),
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
        ),
        child: const Icon(Icons.add_rounded,
            color: AppColors.white, size: 24),
      ),
    );
  }
}
