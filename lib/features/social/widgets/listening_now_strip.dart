import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/social_models.dart';
import '../providers/social_provider.dart';

/// Compact live feed shown above Blend when friends are playing.
class ListeningNowStrip extends StatelessWidget {
  const ListeningNowStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    if (social.feed.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Listening now', style: AppTextStyles.label),
        const SizedBox(height: AppConstants.spaceS),
        ...social.feed.map((e) => _NowPlayingCard(entry: e)),
        const SizedBox(height: AppConstants.spaceL),
      ],
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  final NowPlayingEntry entry;
  const _NowPlayingCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceS),
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.blushDark,
            child: Text(
              entry.displayName.isNotEmpty
                  ? entry.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.darkBerry,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.displayName, style: AppTextStyles.songTitle),
                Text(
                  '${entry.title} · ${entry.artist}',
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (entry.albumArtUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
              child: CachedNetworkImage(
                imageUrl: entry.albumArtUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
        ],
      ),
    );
  }
}
