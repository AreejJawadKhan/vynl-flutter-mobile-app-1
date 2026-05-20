import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../features/library/providers/library_provider.dart';
import '../../features/library/widgets/album_art_widget.dart';
import '../../features/voice/providers/voice_provider.dart';
import '../../shared/providers/audio_provider.dart';

/// The persistent glassmorphic mini-player shown above the bottom nav.
///
/// Phase 1: Static placeholder shell
/// Phase 2: Wired to AudioProvider — live song data, real controls, seek bar
/// Phase 3: Will be upgraded with the vinyl-aware expanded view
class MiniPlayerStub extends StatefulWidget {
  const MiniPlayerStub({super.key});

  @override
  State<MiniPlayerStub> createState() => _MiniPlayerStubState();
}

class _MiniPlayerStubState extends State<MiniPlayerStub> {
  bool _isExpanded = false;

  void _toggle() => setState(() => _isExpanded = !_isExpanded);

  @override
  Widget build(BuildContext context) {
    final audio   = context.watch<AudioProvider>();
    final isLight = Theme.of(context).brightness == Brightness.light;
    final hasSong = audio.currentSong != null;

    // Don't show the player at all when nothing has been played yet.
    if (!hasSong) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _isExpanded
          ? () => Navigator.pushNamed(context, AppRoutes.nowPlaying)
          : _toggle,
      child: AnimatedContainer(
        duration: AppConstants.miniPlayerAnimDuration,
        curve: Curves.easeInOutCubic,
        height: _isExpanded
            ? AppConstants.miniPlayerExpandedHeight
            : AppConstants.miniPlayerCollapsedHeight,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(AppConstants.miniPlayerBorderRadius),
            topRight:    Radius.circular(AppConstants.miniPlayerBorderRadius),
            bottomLeft:  Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          border: Border.all(color: AppColors.glassBorder, width: 1),
        ),
        clipBehavior: Clip.hardEdge,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppConstants.miniPlayerBlurSigma,
            sigmaY: AppConstants.miniPlayerBlurSigma,
          ),
          child: Container(
            color: isLight ? AppColors.glassBackground : AppColors.glassDark,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _isExpanded
                ? _buildExpanded(audio)
                : _buildCollapsed(audio),
          ),
        ),
      ),
    );
  }

  // ── Collapsed ─────────────────────────────────────────────────────────────
  Widget _buildCollapsed(AudioProvider audio) {
    final song = audio.currentSong!;
    return Row(
      children: [
        AlbumArtWidget(
          albumId:     song.albumId,
          albumArtUrl: song.albumArtUrl,
          size: AppConstants.albumArtMiniSmall,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                style: AppTextStyles.songTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                song.artist,
                style: AppTextStyles.songArtist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _MiniBtn(
          icon: audio.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          size: 32,
          onTap: () => audio.playPause(),
        ),
        _MiniBtn(
          icon: Icons.skip_next_rounded,
          size: 28,
          onTap: () => audio.skipToNext(),
        ),
        GestureDetector(
          onTap: _toggle,
          child: const Icon(
            Icons.keyboard_arrow_up_rounded,
            color: AppColors.stone,
            size: 20,
          ),
        ),
      ],
    );
  }

  // ── Expanded ──────────────────────────────────────────────────────────────
  Widget _buildExpanded(AudioProvider audio) {
    final song    = audio.currentSong!;
    final library = context.read<LibraryProvider>();
    final isLiked = context.watch<LibraryProvider>().isLiked(song);
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
        // Collapse indicator
        GestureDetector(
          onTap: _toggle,
          child: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.stone,
            size: 20,
          ),
        ),

        // Art + song info + mic
        Row(
          children: [
            AlbumArtWidget(
              albumId:     song.albumId,
              albumArtUrl: song.albumArtUrl,
              size: AppConstants.albumArtMiniLarge,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: AppTextStyles.songTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song.artist,
                    style: AppTextStyles.songArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _MiniBtn(
              icon: Icons.mic_rounded,
              size: 22,
              color: AppColors.sage,
              onTap: () async {
                HapticFeedback.lightImpact();
                final voice = context.read<VoiceProvider>();
                if (voice.isListening) {
                  await voice.stopListening();
                } else {
                  await voice.startListening();
                }
              },
            ),
          ],
        ),

        // Progress bar with live seek
        _SeekBar(audio: audio),

        // Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _MiniBtn(
              icon: Icons.skip_previous_rounded,
              size: 28,
              onTap: () => audio.skipToPrevious(),
            ),
            _MiniBtn(
              icon: audio.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              size: 36,
              onTap: () => audio.playPause(),
            ),
            _MiniBtn(
              icon: Icons.skip_next_rounded,
              size: 28,
              onTap: () => audio.skipToNext(),
            ),
            _MiniBtn(
              icon: isLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 22,
              color: isLiked ? AppColors.roseQuartz : AppColors.stone,
              onTap: () {
                HapticFeedback.lightImpact();
                library.toggleLike(song);
              },
            ),
            _MiniBtn(
              icon: Icons.queue_music_rounded,
              size: 22,
              onTap: () {},
            ),
          ],
        ),
      ],
    ));
  }
}

// ── Seek bar ───────────────────────────────────────────────────────────────────

class _SeekBar extends StatelessWidget {
  final AudioProvider audio;
  const _SeekBar({required this.audio});

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            trackHeight: 2.5,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          ),
          child: Slider(
            value: audio.progress.clamp(0.0, 1.0),
            onChanged: (v) => audio.seekToFraction(v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(audio.position), style: AppTextStyles.timestamp),
              Text(_fmt(audio.duration), style: AppTextStyles.timestamp),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Icon button helper ─────────────────────────────────────────────────────────

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final Color? color;

  const _MiniBtn({
    required this.icon,
    required this.size,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: size, color: color ?? AppColors.darkBerry),
      ),
    );
  }
}
