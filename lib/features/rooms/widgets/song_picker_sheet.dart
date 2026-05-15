import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../features/library/models/song_model.dart';
import '../../../features/library/providers/library_provider.dart';
import '../../../features/library/widgets/album_art_widget.dart';

/// Modal bottom sheet that lets a user pick a song from their library
/// to add to the room queue.
///
/// Returns the selected [SongItem] via [Navigator.pop].
class SongPickerSheet extends StatefulWidget {
  const SongPickerSheet({super.key});

  static Future<SongItem?> show(BuildContext context) {
    final library = context.read<LibraryProvider>();
    return showModalBottomSheet<SongItem>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXL),
        ),
      ),
      builder: (_) => ChangeNotifierProvider<LibraryProvider>.value(
        value: library,
        child: const SongPickerSheet(),
      ),
    );
  }

  @override
  State<SongPickerSheet> createState() => _SongPickerSheetState();
}

class _SongPickerSheetState extends State<SongPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final songs   = _query.isEmpty
        ? library.allSongs
        : library.allSongs.where((s) {
            final q = _query.toLowerCase();
            return s.title.toLowerCase().contains(q) ||
                s.artist.toLowerCase().contains(q);
          }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // ── Handle ────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.stone.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceM),
            child: Row(
              children: [
                Text('Add a song', style: AppTextStyles.headlineSmall),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),

          // ── Search ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppConstants.spaceM, 4,
                AppConstants.spaceM, AppConstants.spaceS),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText:   'Search songs…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () =>
                            setState(() { _query = ''; _searchCtrl.clear(); }),
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // ── Songs list ────────────────────────────────────────────────
          Expanded(
            child: songs.isEmpty
                ? Center(
                    child: Text('No songs found',
                        style: AppTextStyles.bodyMedium),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spaceS,
                        vertical: 4),
                    itemCount: songs.length,
                    itemBuilder: (_, i) {
                      final song = songs[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spaceM,
                            vertical: 2),
                        leading: AlbumArtWidget(
                          albumId: song.albumId,
                          size:    44,
                        ),
                        title: Text(
                          song.title,
                          style: AppTextStyles.songTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          song.artist,
                          style: AppTextStyles.songArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: AppColors.sage,
                          size: 24,
                        ),
                        onTap: () => Navigator.pop(context, song),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
