import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/permission_helper.dart';
import '../../shared/providers/audio_provider.dart';
import '../../shared/widgets/empty_state_widget.dart';
import 'models/song_model.dart';
import 'providers/library_provider.dart';
import 'widgets/sort_bottom_sheet.dart';
import 'widgets/song_list_tile.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermission());
  }

  @override
  void dispose() {
    _searchController.dispose();
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
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            child: _searchOpen
                ? _buildSearchBar(library)
                : const SizedBox.shrink(),
          ),
          if (!library.isLoading && library.allSongs.isNotEmpty)
            _buildCountLabel(library),
          Expanded(child: _buildBody(library)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(LibraryProvider library) {
    return AppBar(
      title: const Text('My Music'),
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.sort_rounded),
              onPressed: () => SortBottomSheet.show(context),
              tooltip: 'Sort',
            ),
            if (library.sortMode != SortMode.titleAZ)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.darkBerry,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          icon: Icon(
            _searchOpen ? Icons.search_off_rounded : Icons.search_rounded,
          ),
          onPressed: _toggleSearch,
          tooltip: _searchOpen ? 'Close search' : 'Search',
        ),
        IconButton(
          icon: const Icon(Icons.queue_music_rounded),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.playlists),
          tooltip: 'Playlists',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildSearchBar(LibraryProvider library) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spaceM, 0, AppConstants.spaceM, AppConstants.spaceS,
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        style: AppTextStyles.bodyLarge,
        onChanged: library.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'Search songs, artists…',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    library.clearSearch();
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCountLabel(LibraryProvider library) {
    final displayed = library.displayedSongs.length;
    final total     = library.totalCount;
    final label     = _searchOpen && library.searchQuery.isNotEmpty
        ? '$displayed of $total songs'
        : '$total songs';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.label),
          Text(
            library.sortMode.label,
            style: AppTextStyles.label.copyWith(color: AppColors.darkBerry),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(LibraryProvider library) {
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
        subtitle: 'Make sure audio files are stored on this device.',
        buttonLabel: 'Refresh Library',
        onButtonTap: library.scanLibrary,
      );
    }

    final List<SongItem> songs = library.displayedSongs;
    if (songs.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.search_off_rounded,
        title: 'No results',
        subtitle: 'Try a different song title or artist name.',
      );
    }

    return _SongList(songs: songs);
  }
}

class _SongList extends StatelessWidget {
  final List<SongItem> songs;
  const _SongList({required this.songs});

  @override
  Widget build(BuildContext context) {
    const bottomPad = AppConstants.miniPlayerCollapsedHeight +
        AppConstants.bottomNavHeight +
        AppConstants.spaceM;

    return ListView.builder(
      padding: const EdgeInsets.only(
        top: AppConstants.spaceXS,
        bottom: bottomPad,
        left: AppConstants.spaceS,
        right: AppConstants.spaceS,
      ),
      itemCount: songs.length,
      itemBuilder: (context, i) {
        final SongItem song = songs[i];
        return SongListTile(
          key: ValueKey(song.id),
          song: song,
          queue: songs,
          onTap: () {
            context.read<AudioProvider>().playSong(song, songs);
            Navigator.pushNamed(context, AppRoutes.nowPlaying);
          },
        );
      },
    );
  }
}
