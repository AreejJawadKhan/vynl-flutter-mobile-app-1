import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/providers/audio_provider.dart';
import '../providers/playlist_provider.dart';
import '../models/song_model.dart';
import '../widgets/album_art_widget.dart';

class _PlaylistDetailInline extends StatelessWidget {
  final String playlistId;
  const _PlaylistDetailInline({required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlaylistProvider>();
    final audio    = context.watch<AudioProvider>();

    final idx = provider.playlists
        .indexWhere((p) => p.id == playlistId);
    if (idx == -1) {
      return Scaffold(
          appBar: AppBar(title: const Text('Playlist')));
    }

    final playlist = provider.playlists[idx];
    final songs    = provider.songsForPlaylist(playlist);

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          if (songs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.shuffle_rounded),
              tooltip: 'Shuffle play',
              onPressed: () {
                final shuffled = List<SongItem>.from(songs)
                  ..shuffle();
                audio.playSong(shuffled.first, shuffled);
                Navigator.pushNamed(
                    context, AppRoutes.nowPlaying);
              },
            ),
        ],
      ),
      body: songs.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off_rounded,
                size: 64, color: AppColors.stone),
            SizedBox(height: AppConstants.spaceM),
            Text('No songs in this playlist'),
          ],
        ),
      )
          : Column(
        children: [
          // Play all button
          Padding(
            padding: const EdgeInsets.all(AppConstants.spaceM),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  audio.playSong(songs.first, songs);
                  Navigator.pushNamed(
                      context, AppRoutes.nowPlaying);
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Play All (${songs.length} songs)'),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(
                bottom: AppConstants.miniPlayerCollapsedHeight +
                    AppConstants.bottomNavHeight +
                    AppConstants.spaceL,
              ),
              itemCount: songs.length,
              itemBuilder: (context, i) {
                final song    = songs[i];
                final isPlaying = audio.currentSong?.id == song.id &&
                    audio.isPlaying;

                return ListTile(
                  leading: Stack(
                    children: [
                      AlbumArtWidget(
                        albumId:     song.albumId,
                        albumArtUrl: song.albumArtUrl,
                        size: 48,
                      ),
                      if (isPlaying)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.darkBerry
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusS),
                            ),
                            child: const Icon(
                                Icons.equalizer_rounded,
                                color: AppColors.white,
                                size: 20),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    song.title,
                    style: isPlaying
                        ? AppTextStyles.songTitle.copyWith(
                        color: AppColors.darkBerry)
                        : AppTextStyles.songTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${song.artist} · ${song.genre}',
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(song.formattedDuration,
                          style: AppTextStyles.bodySmall),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                            Icons.remove_circle_outline,
                            color: AppColors.stone,
                            size: 18),
                        onPressed: () => provider.removeSong(
                            playlistId, song.persistId),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Play from this song, using the full playlist as queue
                    audio.playSong(song, songs);
                    Navigator.pushNamed(
                        context, AppRoutes.nowPlaying);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}