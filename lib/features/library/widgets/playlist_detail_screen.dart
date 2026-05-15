import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../widgets/song_list_tile.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final playlistProv = context.watch<PlaylistProvider>();
    final library = context.watch<LibraryProvider>();
    
    final playlistIndex = playlistProv.playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex == -1) {
      return Scaffold(appBar: AppBar(title: const Text('Playlist not found')));
    }
    
    final playlist = playlistProv.playlists[playlistIndex];

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
      body: playlist.items.isEmpty
          ? const Center(child: Text('No songs in this playlist.'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 150),
              itemCount: playlist.items.length,
              itemBuilder: (context, i) {
                final item = playlist.items[i];
                final song = library.songById(item.songId);
                
                if (song == null) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      title: Text(song.title, style: AppTextStyles.bodyLarge),
                      subtitle: Text(song.artist, style: AppTextStyles.bodySmall),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.stone),
                        onPressed: () => playlistProv.removeSongFromPlaylist(playlistId, song.id),
                      ),
                    ),
                    if (item.note != null && item.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.sage.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppConstants.radiusS),
                            border: Border.all(color: AppColors.sage.withOpacity(0.3)),
                          ),
                          child: Text(
                            'Note: ${item.note}',
                            style: AppTextStyles.bodySmall.copyWith(fontStyle: FontStyle.italic),
                          ),
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
