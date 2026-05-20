import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'widgets/album_art_widget.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/permission_helper.dart';
import '../../shared/providers/audio_provider.dart';
import '../../shared/widgets/empty_state_widget.dart';
import 'models/song_model.dart';
import 'providers/library_provider.dart';
import 'providers/playlist_provider.dart';
import 'widgets/sort_bottom_sheet.dart';
import 'widgets/song_list_tile.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  bool _searchOpen = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkPermission());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final hasStorage = await PermissionHelper.hasStorage();
    if (!hasStorage && mounted) {
      await PermissionHelper.requestStorage();
      if (mounted) {
        context.read<LibraryProvider>().scanLibrary();
      }
    }
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        context.read<LibraryProvider>().clearSearch();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();

    return Scaffold(
      appBar: _buildAppBar(library),
      body: Column(
        children: [
          // ── Search bar ───────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            child: _searchOpen
                ? _buildSearchBar(library)
                : const SizedBox.shrink(),
          ),

          // ── Enrichment banner ────────────────────────────────────────
          if (library.isEnriching)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceM, vertical: 6),
              color: AppColors.sage.withValues(alpha: 0.12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: AppColors.sage),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      library.activeVisibleEnrich > 0
                          ? 'Fetching art for visible songs…'
                          : 'Updating library metadata…',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.sageDark),
                    ),
                  ),
                ],
              ),
            ),

          // ── Tab bar ──────────────────────────────────────────────────
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.music_note_rounded, size: 18),
                text: 'Songs',
              ),
              Tab(
                icon: Icon(Icons.queue_music_rounded, size: 18),
                text: 'Playlists',
              ),
            ],
          ),

          // ── Tab content ──────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 0: Songs
                _SongsTab(library: library,
                    searchController: _searchController),
                // Tab 1: Playlists
                const _PlaylistsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(LibraryProvider library) {
    return AppBar(
      title: const Text('My Music'),
      actions: [
        // Only show sort on Songs tab
        AnimatedBuilder(
          animation: _tabController,
          builder: (_, __) {
            if (_tabController.index != 0) return const SizedBox.shrink();
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.sort_rounded),
                  onPressed: () => SortBottomSheet.show(context),
                  tooltip: 'Sort',
                ),
                if (library.sortMode != SortMode.titleAZ)
                  Positioned(
                    right: 8, top: 8,
                    child: Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.darkBerry,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        IconButton(
          icon: Icon(
            _searchOpen
                ? Icons.search_off_rounded
                : Icons.search_rounded,
          ),
          onPressed: _toggleSearch,
          tooltip: _searchOpen ? 'Close search' : 'Search',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildSearchBar(LibraryProvider library) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spaceM, 0,
        AppConstants.spaceM, AppConstants.spaceS,
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        style: AppTextStyles.bodyLarge,
        onChanged: library.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'Search songs, artists…',
          prefixIcon:
          const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon:
            const Icon(Icons.clear_rounded, size: 18),
            onPressed: () {
              _searchController.clear();
              library.clearSearch();
            },
          )
              : null,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ── Songs Tab ──────────────────────────────────────────────────────────────

class _SongsTab extends StatelessWidget {
  final LibraryProvider library;
  final TextEditingController searchController;
  const _SongsTab(
      {required this.library, required this.searchController});

  @override
  Widget build(BuildContext context) {
    if (library.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (library.errorMessage != null) {
      return EmptyStateWidget(
        icon: Icons.error_outline_rounded,
        title: 'Could not load library',
        subtitle: library.errorMessage,
        buttonLabel: 'Retry',
        onButtonTap: library.scanLibrary,
      );
    }

    if (library.allSongs.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.library_music_rounded,
        title: 'No songs found',
        subtitle:
        'Make sure audio files are stored on this device.',
        buttonLabel: 'Refresh Library',
        onButtonTap: library.scanLibrary,
      );
    }

    final songs = library.displayedSongs;
    if (songs.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.search_off_rounded,
        title: 'No results',
        subtitle:
        'Try a different song title or artist name.',
      );
    }

    return Column(
      children: [
        // Song count label
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                library.searchQuery.isNotEmpty
                    ? '${songs.length} of ${library.totalCount} songs'
                    : '${library.totalCount} songs',
                style: AppTextStyles.label,
              ),
              Text(
                library.sortMode.label,
                style: AppTextStyles.label
                    .copyWith(color: AppColors.darkBerry),
              ),
            ],
          ),
        ),
        Expanded(child: _SongList(songs: songs)),
      ],
    );
  }
}

class _SongList extends StatefulWidget {
  final List<SongItem> songs;
  const _SongList({required this.songs});

  @override
  State<_SongList> createState() => _SongListState();
}

class _SongListState extends State<_SongList> {
  void _scheduleEnrich(BuildContext context, SongItem song) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LibraryProvider>().enrichSongIfNeeded(song);
    });
  }

  void _onScrollEnd(ScrollMetrics metrics) {
    const rowHeight = 72.0;
    final start = (metrics.pixels / rowHeight).floor();
    final visible =
        (metrics.viewportDimension / rowHeight).ceil() + 2;
    final end = start + visible;
    context.read<LibraryProvider>().enrichVisibleRange(
          start,
          end,
          widget.songs,
        );
  }

  @override
  Widget build(BuildContext context) {
    const bottomPad = AppConstants.miniPlayerCollapsedHeight +
        AppConstants.bottomNavHeight +
        AppConstants.spaceM;

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification) {
          _onScrollEnd(n.metrics);
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: AppConstants.spaceXS,
          bottom: bottomPad,
          left: AppConstants.spaceS,
          right: AppConstants.spaceS,
        ),
        itemCount: widget.songs.length,
        itemBuilder: (context, i) {
          final song = widget.songs[i];
          _scheduleEnrich(context, song);
          return SongListTile(
            key: ValueKey(song.id),
            song: song,
            queue: widget.songs,
            onTap: () {
              context.read<AudioProvider>().playSong(song, widget.songs);
              Navigator.pushNamed(context, AppRoutes.nowPlaying);
            },
          );
        },
      ),
    );
  }
}

// ── Playlists Tab ──────────────────────────────────────────────────────────

class _PlaylistsTab extends StatelessWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context) {
    return const _PlaylistsInlineView();
  }
}

class _PlaylistsInlineView extends StatefulWidget {
  const _PlaylistsInlineView();

  @override
  State<_PlaylistsInlineView> createState() =>
      _PlaylistsInlineViewState();
}

class _PlaylistsInlineViewState
    extends State<_PlaylistsInlineView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistProvider>().load();
    });
  }

  void _showCreateDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration:
          const InputDecoration(hintText: 'Playlist name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                context
                    .read<PlaylistProvider>()
                    .createPlaylist(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlaylistProvider>();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Create playlist button
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spaceM,
            AppConstants.spaceM,
            AppConstants.spaceM,
            AppConstants.spaceS,
          ),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Playlist'),
            ),
          ),
        ),

        if (provider.playlists.isEmpty)
          const Expanded(
            child: EmptyStateWidget(
              icon: Icons.queue_music_rounded,
              title: 'No playlists yet',
              subtitle: 'Create a playlist to organise your songs',
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(
                bottom: AppConstants.miniPlayerCollapsedHeight +
                    AppConstants.bottomNavHeight +
                    AppConstants.spaceXL,
              ),
              itemCount: provider.playlists.length,
              itemBuilder: (context, i) {
                final playlist = provider.playlists[i];
                final songs =
                provider.songsForPlaylist(playlist);
                return _PlaylistTile(
                  playlist: playlist,
                  songCount: songs.length,
                  onTap: () => _openPlaylist(context, playlist.id),
                  onDelete: () => _confirmDelete(
                      context, provider, playlist.id, playlist.name),
                );
              },
            ),
          ),
      ],
    );
  }

  void _openPlaylist(BuildContext context, String playlistId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _PlaylistDetailInline(playlistId: playlistId),
      ),
    );
  }

  void _confirmDelete(BuildContext context,
      PlaylistProvider provider, String id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Playlist?'),
        content:
        Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deletePlaylist(id);
              Navigator.pop(context);
            },
            child: Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final dynamic playlist;
  final int songCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PlaylistTile({
    required this.playlist,
    required this.songCount,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: AppColors.darkBerry.withValues(alpha: 0.1),
          borderRadius:
          BorderRadius.circular(AppConstants.radiusS),
        ),
        child: const Icon(Icons.playlist_play_rounded,
            color: AppColors.darkBerry),
      ),
      title: Text(playlist.name,
          style: AppTextStyles.songTitle),
      subtitle: Text('$songCount songs',
          style: AppTextStyles.bodySmall),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded,
            color: AppColors.stone, size: 20),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}

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