import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  @override
  void initState() {
    super.initState();
    // Load playlists when the screen is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showCreatePlaylistDialog(context),
            tooltip: 'Create Playlist',
          ),
        ],
      ),
      body: Consumer<PlaylistProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.playlists.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppConstants.spaceM),
            itemCount: provider.playlists.length,
            itemBuilder: (context, index) {
              final playlist = provider.playlists[index];
              return _PlaylistCard(playlist: playlist);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_music_rounded, 
            size: 80, 
            color: AppColors.primary.withOpacity(0.3)
          ),
          const SizedBox(height: AppConstants.spaceM),
          Text('No playlists yet', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppConstants.spaceS),
          Text('Create your first playlist to get started', 
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone)
          ),
          const SizedBox(height: AppConstants.spaceL),
          ElevatedButton.icon(
            onPressed: () => _showCreatePlaylistDialog(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Playlist'),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<PlaylistProvider>().createPlaylist(name);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;

  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusM)),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceM,
          vertical: AppConstants.spaceS,
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(AppConstants.radiusS),
          ),
          child: const Icon(Icons.playlist_play_rounded, color: AppColors.primary),
        ),
        title: Text(playlist.name, style: AppTextStyles.headlineSmall),
        subtitle: Text('${playlist.songIds.length} songs', 
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.stone)
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              _showDeleteConfirm(context);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete Playlist', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaylistDetailScreen(playlist: playlist),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist?'),
        content: Text('Are you sure you want to delete "${playlist.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<PlaylistProvider>().deletePlaylist(playlist.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class PlaylistDetailScreen extends StatelessWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Selector<PlaylistProvider, List<SongItem>>(
      selector: (context, provider) {
        // Find the current version of the playlist in the provider
        final p = provider.playlists.firstWhere((p) => p.id == playlist.id, orElse: () => playlist);
        return provider.songsForPlaylist(p);
      },
      builder: (context, songs, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(playlist.name),
          ),
          body: songs.isEmpty
              ? _buildEmptyDetailState()
              : ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return ListTile(
                      leading: Container(
                        width: AppConstants.albumArtListSize,
                        height: AppConstants.albumArtListSize,
                        decoration: BoxDecoration(
                          color: AppColors.stone.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppConstants.radiusS),
                        ),
                        child: const Icon(Icons.music_note_rounded),
                      ),
                      title: Text(song.title, style: AppTextStyles.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(song.artist, style: AppTextStyles.bodySmall.copyWith(color: AppColors.stone), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(song.formattedDuration, style: AppTextStyles.bodySmall),
                          const SizedBox(width: AppConstants.spaceS),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'remove') {
                                context.read<PlaylistProvider>().removeSong(playlist.id, song.persistId);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text('Remove from Playlist'),
                              ),
                            ],
                            icon: const Icon(Icons.more_vert_rounded),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyDetailState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off_rounded, 
            size: 60, 
            color: AppColors.primary.withOpacity(0.2)
          ),
          const SizedBox(height: AppConstants.spaceM),
          Text('No songs in this playlist', style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppConstants.spaceS),
          Text('Add songs from your library', 
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.stone)
          ),
        ],
      ),
    );
  }
}
