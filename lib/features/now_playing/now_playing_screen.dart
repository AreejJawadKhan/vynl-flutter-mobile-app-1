import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../features/library/models/song_model.dart';
import '../../features/library/providers/library_provider.dart';
import '../../shared/providers/audio_provider.dart' as ap;
import '../../shared/widgets/app_snack_bar.dart';
import 'widgets/vinyl_widget.dart';

/// Full Now Playing screen — Phase 3.
/// [VinylWidget] (vinyl_widget.dart) is the centrepiece animation.
/// [_AlbumArtSection] is kept below as a documented fallback reference.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audio   = context.watch<ap.AudioProvider>();
    final library = context.watch<LibraryProvider>();
    final song    = audio.currentSong;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(leading: _BackBtn(), title: const Text('Now Playing')),
        body: const Center(child: Text('No song selected')),
      );
    }

    final isLiked = library.isLiked(song);

    return Scaffold(
      appBar: _buildAppBar(context, audio, library, song, isLiked),
      body: SafeArea(
        child: Column(
          children: [
            // ── Vinyl record animation ────────────────────────────────────
            // VinylWidget owns its AnimationControllers. Gestures:
            //   tap → play/pause, double-tap → like, swipe → skip, long-press → details
            Expanded(
              flex: 5,
              child: Center(
                child: VinylWidget(
                  audio:       audio,
                  albumId:     song.albumId,
                  albumArtUrl: song.albumArtUrl, // ← add this
                  onDoubleTap: () async {
                    await library.toggleLike(song);
                    if (context.mounted) {
                      AppSnackBar.show(
                        context,
                        library.isLiked(song)
                            ? '♥ Added to liked'
                            : 'Removed from liked',
                        duration: const Duration(seconds: 1),
                      );
                    }
                  },
                  onLongPress: () => showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppConstants.radiusXL)),
                    ),
                    builder: (_) => _SongDetailsSheet(song: song),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceXL),
              child: _SongInfo(song: song, isLiked: isLiked, library: library),
            ),
            const SizedBox(height: AppConstants.spaceM),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceL),
              child: _SeekSection(audio: audio),
            ),
            const SizedBox(height: AppConstants.spaceS),
            _PrimaryControls(audio: audio),
            const SizedBox(height: AppConstants.spaceM),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceXL),
              child: _SecondaryControls(audio: audio, library: library, song: song),
            ),
            _QueuePreview(audio: audio),
            const SizedBox(height: AppConstants.spaceL),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ap.AudioProvider audio,
    LibraryProvider library,
    SongItem song,
    bool isLiked,
  ) {
    return AppBar(
      leading: _BackBtn(),
      title: const Text('Now Playing'),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusM)),
          onSelected: (value) async {
            switch (value) {
              case 'like':
                await library.toggleLike(song);
                if (context.mounted) {
                  AppSnackBar.show(context,
                      isLiked ? 'Removed from liked songs' : 'Added to liked songs');
                }
                break;
              case 'details':
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppConstants.radiusXL)),
                  ),
                  builder: (_) => _SongDetailsSheet(song: song),
                );
                break;
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'like',
              child: Row(children: [
                Icon(
                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: AppColors.roseQuartz, size: 20,
                ),
                const SizedBox(width: 12),
                Text(isLiked ? 'Unlike' : 'Like'),
              ]),
            ),
            const PopupMenuItem(
              value: 'details',
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 20),
                SizedBox(width: 12),
                Text('Song details'),
              ]),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Back button ───────────────────────────────────────────────────────────────

class _BackBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        onPressed: () => Navigator.of(context).pop(),
      );
}

// ── Album art fallback (Phase 2 reference — NOT used in active UI) ───────────
// VinylWidget is the active implementation. This class is kept as a documented
// reference in case VinylWidget needs to be temporarily disabled for debugging.

// ── Song info ─────────────────────────────────────────────────────────────────

class _SongInfo extends StatelessWidget {
  final SongItem song;
  final bool isLiked;
  final LibraryProvider library;
  const _SongInfo({required this.song, required this.isLiked, required this.library});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(song.title, style: AppTextStyles.nowPlayingTitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(song.artist, style: AppTextStyles.nowPlayingArtist,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        GestureDetector(
          onTap: () async {
            HapticFeedback.lightImpact();
            await library.toggleLike(song);
            if (context.mounted) {
              AppSnackBar.show(context,
                  isLiked ? 'Removed from liked' : 'Added to liked',
                  duration: const Duration(seconds: 1));
            }
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(isLiked),
              color: isLiked ? AppColors.roseQuartz : AppColors.stone,
              size: AppConstants.iconL,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Seek bar ──────────────────────────────────────────────────────────────────

class _SeekSection extends StatelessWidget {
  final ap.AudioProvider audio;
  const _SeekSection({required this.audio});

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<Duration>(
          stream: audio.positionStream,
          builder: (_, snapshot) {
            final pos = snapshot.data ?? Duration.zero;
            final dur = audio.duration;
            final fraction = dur.inMilliseconds > 0
                ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                : 0.0;
            return Slider(value: fraction, onChanged: audio.seekToFraction);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StreamBuilder<Duration>(
                stream: audio.positionStream,
                builder: (_, snap) =>
                    Text(_fmt(snap.data ?? Duration.zero),
                        style: AppTextStyles.timestamp),
              ),
              Text(_fmt(audio.duration), style: AppTextStyles.timestamp),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Primary controls ──────────────────────────────────────────────────────────

class _PrimaryControls extends StatelessWidget {
  final ap.AudioProvider audio;
  const _PrimaryControls({required this.audio});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded),
          iconSize: 40,
          color: audio.hasPrevious ? AppColors.darkBerry : AppColors.stone,
          onPressed: audio.hasPrevious
              ? () { HapticFeedback.selectionClick(); audio.skipToPrevious(); }
              : null,
        ),
        GestureDetector(
          onTap: () { HapticFeedback.mediumImpact(); audio.playPause(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.darkBerry,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkBerry.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: audio.isBuffering
                ? const Center(
                    child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                          color: AppColors.white, strokeWidth: 2.5),
                    ),
                  )
                : Icon(
                    audio.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppColors.white, size: 38,
                  ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: 40,
          color: audio.hasNext ? AppColors.darkBerry : AppColors.stone,
          onPressed: audio.hasNext
              ? () { HapticFeedback.selectionClick(); audio.skipToNext(); }
              : null,
        ),
      ],
    );
  }
}

// ── Secondary controls ────────────────────────────────────────────────────────

class _SecondaryControls extends StatelessWidget {
  final ap.AudioProvider audio;
  final LibraryProvider library;
  final SongItem song;
  const _SecondaryControls(
      {required this.audio, required this.library, required this.song});

  IconData _repeatIcon(ap.RepeatMode mode) {
    switch (mode) {
      case ap.RepeatMode.one: return Icons.repeat_one_rounded;
      default:             return Icons.repeat_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shuffleActive = audio.isShuffled;
    final repeatActive  = audio.repeatMode != ap.RepeatMode.off;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SecBtn(
          icon: Icons.shuffle_rounded,
          color: shuffleActive ? AppColors.darkBerry : AppColors.stone,
          isActive: shuffleActive,
          onTap: () { HapticFeedback.selectionClick(); audio.toggleShuffle(); },
        ),
        _SecBtn(
          icon: Icons.queue_music_rounded,
          color: AppColors.stone,
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppConstants.radiusXL)),
            ),
            builder: (_) => _QueueSheet(audio: audio),
          ),
        ),
        _SecBtn(
          icon: _repeatIcon(audio.repeatMode),
          color: repeatActive ? AppColors.darkBerry : AppColors.stone,
          isActive: repeatActive,
          onTap: () { HapticFeedback.selectionClick(); audio.cycleRepeat(); },
        ),
      ],
    );
  }
}

class _SecBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;
  const _SecBtn({required this.icon, required this.color,
      required this.onTap, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: color, size: 26),
            if (isActive)
              Positioned(
                bottom: -3, left: 0, right: 0,
                child: Center(
                  child: Container(
                    width: 5, height: 5,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Queue preview strip ───────────────────────────────────────────────────────

class _QueuePreview extends StatelessWidget {
  final ap.AudioProvider audio;
  const _QueuePreview({required this.audio});

  @override
  Widget build(BuildContext context) {
    final upcoming = audio.queue.skip(audio.queueIndex + 1).take(2).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppConstants.spaceXL, AppConstants.spaceS, AppConstants.spaceXL, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: AppConstants.spaceS),
          Text('Up next', style: AppTextStyles.label),
          const SizedBox(height: AppConstants.spaceXS),
          ...upcoming.map((s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                const Icon(Icons.music_note_rounded,
                    size: 14, color: AppColors.stone),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${s.title} · ${s.artist}',
                      style: AppTextStyles.bodySmall,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ── Queue bottom sheet ────────────────────────────────────────────────────────

class _QueueSheet extends StatelessWidget {
  final ap.AudioProvider audio;
  const _QueueSheet({required this.audio});

  @override
  Widget build(BuildContext context) {
    final queue = audio.queue;
    final idx   = audio.queueIndex;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize:     0.4,
      maxChildSize:     0.9,
      expand: false,
      builder: (_, controller) => Column(
        children: [
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
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Queue', style: AppTextStyles.headlineSmall),
                Text('${queue.length} songs', style: AppTextStyles.label),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: queue.length,
              itemBuilder: (_, i) {
                final s         = queue[i];
                final isCurrent = i == idx;
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: Icon(
                    isCurrent ? Icons.equalizer_rounded : Icons.music_note_rounded,
                    color: isCurrent ? AppColors.darkBerry : AppColors.stone,
                    size: 20,
                  ),
                  title: Text(s.title,
                      style: isCurrent
                          ? AppTextStyles.songTitle.copyWith(color: AppColors.darkBerry)
                          : AppTextStyles.songTitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(s.artist,
                      style: AppTextStyles.songArtist,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: isCurrent
                      ? const Icon(Icons.volume_up_rounded,
                          color: AppColors.darkBerry, size: 18)
                      : null,
                  onTap: () {
                    audio.playSong(s, queue.toList());
                    Navigator.pop(context);
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

// ── Song details sheet ────────────────────────────────────────────────────────

class _SongDetailsSheet extends StatelessWidget {
  final SongItem song;
  const _SongDetailsSheet({required this.song});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.stone.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spaceL),
            Text('Song details', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppConstants.spaceM),
            _DetailRow(label: 'Title',    value: song.title),
            _DetailRow(label: 'Artist',   value: song.artist),
            _DetailRow(label: 'Album',    value: song.album),
            _DetailRow(label: 'Duration', value: song.formattedDuration),
            const SizedBox(height: AppConstants.spaceM),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 76, child: Text(label, style: AppTextStyles.label)),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}
