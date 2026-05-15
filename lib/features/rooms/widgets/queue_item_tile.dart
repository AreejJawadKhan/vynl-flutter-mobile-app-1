import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../features/library/widgets/album_art_widget.dart';
import '../models/room_models.dart';

/// One item in the room queue list.
///
/// Shows song art, title, artist, who added it, thumbs-up count,
/// and — if [isFirst] — the active vote progress bar.
class QueueItemTile extends StatelessWidget {
  final RoomQueueItem item;
  final bool isFirst;          // true = this is the currently-playing item
  final bool isHost;
  final bool votingActive;
  final double voteProgress;   // 0.0–1.0 for the vote bar
  final VoidCallback? onRemove;
  final VoidCallback? onVoteSkip;
  final VoidCallback? onVoteReplay;

  const QueueItemTile({
    super.key,
    required this.item,
    required this.isFirst,
    required this.isHost,
    required this.votingActive,
    required this.voteProgress,
    this.onRemove,
    this.onVoteSkip,
    this.onVoteReplay,
  });

  @override
  Widget build(BuildContext context) {
    final song = item.song;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: isFirst
            ? AppColors.darkBerry.withOpacity(0.08)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: isFirst
            ? Border.all(
                color: AppColors.darkBerry.withOpacity(0.25), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ── Album art ───────────────────────────────────────────────
              AlbumArtWidget(
                albumId: song.albumId,
                size:    46,
              ),
              const SizedBox(width: 12),

              // ── Song info + adder ────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isFirst) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.darkBerry,
                              borderRadius:
                                  BorderRadius.circular(AppConstants.radiusS),
                            ),
                            child: Text('NOW PLAYING',
                                style: AppTextStyles.label.copyWith(
                                    color: AppColors.white,
                                    fontSize: 9,
                                    letterSpacing: 0.8)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            song.title,
                            style: AppTextStyles.songTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist,
                      style: AppTextStyles.songArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 11, color: AppColors.stone),
                        const SizedBox(width: 3),
                        Text('Added by ${item.addedByName}',
                            style: AppTextStyles.bodySmall
                                .copyWith(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Vote + upvote counts ────────────────────────────────────
              Column(
                children: [
                  _VoteButton(
                    icon:  Icons.thumb_up_alt_outlined,
                    count: item.upvotes,
                    color: AppColors.sage,
                    onTap: onVoteReplay,
                  ),
                  const SizedBox(height: 6),
                  _VoteButton(
                    icon:  Icons.thumb_down_alt_outlined,
                    count: item.downvotes,
                    color: AppColors.roseQuartz,
                    onTap: onVoteSkip,
                  ),
                ],
              ),

              // ── Host remove button ───────────────────────────────────────
              if (isHost && !isFirst) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onRemove?.call();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: AppColors.stone),
                  ),
                ),
              ],
            ],
          ),

          // ── Vote progress bar (only on current item during vote) ──────
          if (isFirst && votingActive) ...[
            const SizedBox(height: 10),
            _VoteProgressBar(progress: voteProgress),
          ],
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const _VoteButton({
    required this.icon,
    required this.count,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(AppConstants.radiusS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            if (count > 0) ...[
              const SizedBox(width: 3),
              Text('$count',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: color, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}

class _VoteProgressBar extends StatelessWidget {
  final double progress; // 0.0–1.0

  const _VoteProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Skip vote in progress',
                style: AppTextStyles.label
                    .copyWith(color: AppColors.roseQuartz)),
            Text('${(progress * 100).round()}%',
                style: AppTextStyles.label
                    .copyWith(color: AppColors.roseQuartz)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:           progress,
            backgroundColor: AppColors.blushDark.withOpacity(0.4),
            valueColor:      const AlwaysStoppedAnimation(AppColors.roseQuartz),
            minHeight:       6,
          ),
        ),
      ],
    );
  }
}
