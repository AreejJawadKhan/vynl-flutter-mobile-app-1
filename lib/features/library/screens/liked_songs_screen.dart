import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../../../shared/providers/audio_provider.dart';

class LikedSongsScreen extends StatelessWidget {
  const LikedSongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, child) {
        final songs = library.likedSongs;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Liked Songs'),
          ),
          body: songs.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(
                    bottom: AppConstants.miniPlayerCollapsedHeight +
                        AppConstants.bottomNavHeight +
                        AppConstants.spaceXL,
                  ),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return _LikedSongTile(song: song);
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 80,
            color: AppColors.roseQuartz.withOpacity(0.3),
          ),
          const SizedBox(height: AppConstants.spaceM),
          Text('No liked songs yet', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppConstants.spaceS),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Songs you heart in the library will appear here for quick access.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _LikedSongTile extends StatelessWidget {
  final SongItem song;
  const _LikedSongTile({required this.song});

  @override
  Widget build(BuildContext context) {
    final audio   = context.read<AudioProvider>();
    final library = context.read<LibraryProvider>();
    final isPlaying = audio.currentSong?.id == song.id && audio.isPlaying;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceM,
        vertical: 4,
      ),
      leading: Container(
        width: AppConstants.albumArtListSize,
        height: AppConstants.albumArtListSize,
        decoration: BoxDecoration(
          color: AppColors.stone.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppConstants.radiusS),
        ),
        child: isPlaying
            ? const Center(
                child: Icon(Icons.equalizer_rounded, color: AppColors.roseQuartz),
              )
            : const Icon(Icons.music_note_rounded, color: AppColors.stone),
      ),
      title: Text(
        song.title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: isPlaying ? AppColors.roseQuartz : null,
          fontWeight: isPlaying ? FontWeight.bold : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song.artist,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.stone),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(song.formattedDuration, style: AppTextStyles.bodySmall),
          const SizedBox(width: AppConstants.spaceS),
          IconButton(
            icon: const Icon(Icons.favorite_rounded,
                color: AppColors.roseQuartz, size: 20),
            onPressed: () => library.toggleLike(song),
          ),
        ],
      ),
      onTap: () {
        audio.playSong(song, library.likedSongs);
      },
    );
  }
}
