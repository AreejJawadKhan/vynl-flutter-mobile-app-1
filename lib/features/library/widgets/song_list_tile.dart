import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/providers/audio_provider.dart';
import '../models/song_model.dart';
import '../providers/playlist_provider.dart';
import 'album_art_widget.dart';

/// A single row in the library list.
///
/// Shows:
///   - Album art thumbnail (50×50)
///   - Song title (bold, truncated)
///   - Artist name (light, truncated)
///   - Duration (right-aligned)
///   - Animated equaliser bars when this song is currently playing
///   - Subtle highlight when active
class SongListTile extends StatelessWidget {
  final SongItem song;
  final List<SongItem> queue; // The list this song belongs to (for context)
  final VoidCallback? onTap;

  const SongListTile({
    super.key,
    required this.song,
    required this.queue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final audio    = context.watch<AudioProvider>();
    final isActive = audio.currentSong?.id == song.id;
    final isPlaying = isActive && audio.isPlaying;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        if (onTap != null) {
          onTap!();
        } else {
          context.read<AudioProvider>().playSong(song, queue);
        }
      },
      borderRadius: BorderRadius.circular(AppConstants.radiusM),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.darkBerry.withOpacity(0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceM,
          vertical: AppConstants.spaceS + 2,
        ),
        child: Row(
          children: [
            // ── Album art ──────────────────────────────────────────────────
            Stack(
              children: [
                AlbumArtWidget(
                  albumId: song.albumId,
                  size: 44,
                ),
                // Playing overlay tint
                if (isActive)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.darkBerry.withOpacity(0.35),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusS),
                      ),
                      child: Center(
                        child: isPlaying
                            ? const _EqualiserBars()
                            : const Icon(
                                Icons.pause_rounded,
                                color: AppColors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 14),

            // ── Song info ──────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: isActive
                        ? AppTextStyles.songTitle
                            .copyWith(color: AppColors.darkBerry)
                        : AppTextStyles.songTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist,
                    style: AppTextStyles.songArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Duration ───────────────────────────────────────────────────
            Text(
              song.formattedDuration,
              style: AppTextStyles.songDuration,
            ),
            const SizedBox(width: 4),

            // ── Menu ───────────────────────────────────────────────────────
            const SizedBox(width: 8),
            _SongListTileMenu(song: song),
          ],
        ),
      ),
    );
  }
}

class _SongListTileMenu extends StatelessWidget {
  final SongItem song;
  const _SongListTileMenu({required this.song});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, provider, _) {
        return PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.stone),
          onSelected: (value) async {
            if (value == 'add_to_playlist') {
              _showPlaylistPicker(context, provider);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'add_to_playlist',
              child: Row(
                children: [
                  Icon(Icons.playlist_add_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Add to playlist'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPlaylistPicker(BuildContext context, PlaylistProvider provider) {
    if (provider.playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No playlists found. Create one first!')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusL)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
              child: Text('Add to playlist', style: AppTextStyles.headlineSmall),
            ),
            const SizedBox(height: AppConstants.spaceS),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: provider.playlists.length,
                itemBuilder: (context, i) {
                  final p = provider.playlists[i];
                  return ListTile(
                    leading: const Icon(Icons.playlist_play_rounded),
                    title: Text(p.name),
                    onTap: () {
                      provider.addSong(p.id, song);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added to ${p.name}')),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated equaliser bars ────────────────────────────────────────────────────

/// Three animated bars that pulse to indicate active playback.
class _EqualiserBars extends StatefulWidget {
  const _EqualiserBars();

  @override
  State<_EqualiserBars> createState() => _EqualiserBarsState();
}

class _EqualiserBarsState extends State<_EqualiserBars>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    // Three bars with staggered durations for organic feel.
    final durations = [350, 500, 280];
    _controllers = durations
        .map((ms) => AnimationController(
              vsync: this,
              duration: Duration(milliseconds: ms),
            )..repeat(reverse: true))
        .toList();

    _animations = _controllers
        .map((c) => Tween<double>(begin: 0.2, end: 1.0).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (_, __) => Container(
            width: 3,
            height: 14 * _animations[i].value,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
