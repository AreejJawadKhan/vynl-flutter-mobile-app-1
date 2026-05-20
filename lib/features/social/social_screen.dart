import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import 'providers/social_provider.dart';
import 'models/social_models.dart';
import 'blend_screen.dart';

class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listening Now'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BlendScreen()),
            ),
            tooltip: 'Find your Blend',
          ),
        ],
      ),
      body: social.feed.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
        onRefresh: () async {},
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(
            AppConstants.spaceM, AppConstants.spaceM,
            AppConstants.spaceM,
            AppConstants.miniPlayerCollapsedHeight +
                AppConstants.bottomNavHeight + AppConstants.spaceXL,
          ),
          itemCount: social.feed.length,
          itemBuilder: (_, i) => _NowPlayingCard(entry: social.feed[i]),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.headphones_rounded, size: 80,
              color: AppColors.stone.withOpacity(0.3)),
          const SizedBox(height: AppConstants.spaceM),
          Text('Nobody is listening right now',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppConstants.spaceS),
          Text('Invite friends to see what they\'re playing',
              style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  final NowPlayingEntry entry;
  const _NowPlayingCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final ago = _timeAgo(entry.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceM),
        child: Row(
          children: [
            // User avatar
            _buildAvatar(entry),
            const SizedBox(width: AppConstants.spaceM),

            // Song info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(entry.displayName,
                          style: AppTextStyles.songTitle),
                      const Spacer(),
                      Text(ago, style: AppTextStyles.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(entry.title,
                      style: AppTextStyles.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text('${entry.artist} · ${entry.genre}',
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),

            const SizedBox(width: AppConstants.spaceM),

            // Album art
            _buildAlbumArt(entry),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(NowPlayingEntry entry) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.blushDark,
          backgroundImage: entry.photoUrl.isNotEmpty
              ? CachedNetworkImageProvider(entry.photoUrl)
              : null,
          child: entry.photoUrl.isEmpty
              ? Text(entry.displayName[0].toUpperCase(),
              style: const TextStyle(
                  color: AppColors.darkBerry, fontWeight: FontWeight.bold))
              : null,
        ),
        // Listening pulse
        Positioned(
          bottom: 0, right: 0,
          child: Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: AppColors.sage,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumArt(NowPlayingEntry entry) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusS),
      child: entry.albumArtUrl.isNotEmpty
          ? CachedNetworkImage(
        imageUrl: entry.albumArtUrl,
        width: 56, height: 56,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 56, height: 56,
          color: AppColors.blushDark,
          child: const Icon(Icons.music_note_rounded,
              color: AppColors.stone),
        ),
        errorWidget: (_, __, ___) => _placeholderArt(),
      )
          : _placeholderArt(),
    );
  }

  Widget _placeholderArt() {
    return Container(
      width: 56, height: 56,
      color: AppColors.blushDark,
      child: const Icon(Icons.music_note_rounded, color: AppColors.stone),
    );
  }

  String _timeAgo(int timestamp) {
    final diff = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}