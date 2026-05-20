import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/playlist_provider.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final playlistProv = context.watch<PlaylistProvider>();

    final playlistIndex =
    playlistProv.playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex == -1) {
      return Scaffold(
          appBar: AppBar(title: const Text('Playlist not found')));
    }

    final playlist = playlistProv.playlists[playlistIndex];
    final songs    = playlistProv.songsForPlaylist(playlist);

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share playlist',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing coming soon!')),
              );
            },
          ),
        ],
      ),
      body: songs.isEmpty
          ? const Center(child: Text('No songs in this playlist.'))
          : ListView.builder(
        padding: const EdgeInsets.only(bottom: 150),
        itemCount: songs.length,
        itemBuilder: (context, i) {
          final song = songs[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text(song.title,
                    style: AppTextStyles.bodyLarge),
                subtitle: Text(song.artist,
                    style: AppTextStyles.bodySmall),
                trailing: IconButton(
                  icon: const Icon(
                      Icons.remove_circle_outline,
                      color: AppColors.stone),
                  onPressed: () => playlistProv.removeSong(
                      playlistId, song.persistId),
                ),
              ),
              const Divider(height: 1),
            ],
          );
        },
      ),
    );
  }
}