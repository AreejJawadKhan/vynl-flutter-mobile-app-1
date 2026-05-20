import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../shared/providers/audio_provider.dart';
import 'models/voice_models.dart';
import 'providers/voice_provider.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final Animation<double>   _bgAnim;
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VoiceProvider>().initialise();
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceProvider>();
    final audio = context.watch<AudioProvider>();

    // Sync wave animation
    if (voice.isListening && !_waveCtrl.isAnimating) {
      _waveCtrl.repeat();
    } else if (!voice.isListening && _waveCtrl.isAnimating) {
      _waveCtrl.stop();
      _waveCtrl.reset();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI Voice')),
      body: AnimatedBuilder(
        animation: _bgAnim,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(
                  AppColors.blush,
                  AppColors.sageLight.withValues(alpha: 0.4),
                  _bgAnim.value,
                )!,
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
          child: child,
        ),
        child: SafeArea(
          child: Padding(
            // Extra bottom padding for mini-player + nav bar
            padding: EdgeInsets.only(
              bottom: AppConstants.miniPlayerCollapsedHeight +
                  AppConstants.bottomNavHeight +
                  AppConstants.spaceM,
            ),
            child: Column(
              children: [
                // ── Status + transcription ─────────────────────────────
                Expanded(
                  flex: 3,
                  child: _StatusArea(voice: voice, audio: audio),
                ),

                // ── Mic button ────────────────────────────────────────
                _MicButton(voice: voice, waveCtrl: _waveCtrl),

                const SizedBox(height: AppConstants.spaceM),

                // ── Sound wave ────────────────────────────────────────
                SizedBox(
                  height: 48,
                  child: _SoundWave(
                    controller: _waveCtrl,
                    isActive: voice.isListening,
                  ),
                ),

                const SizedBox(height: AppConstants.spaceL),

                // ── Suggestion chips ──────────────────────────────────
                _SuggestionChips(voice: voice),

                const SizedBox(height: AppConstants.spaceL),

                // ── Command history ───────────────────────────────────
                if (voice.history.isNotEmpty)
                  Expanded(
                    child: _CommandHistory(history: voice.history),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Status area ───────────────────────────────────────────────────────────────

class _StatusArea extends StatelessWidget {
  final VoiceProvider voice;
  final AudioProvider audio;
  const _StatusArea({required this.voice, required this.audio});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceXL,
        vertical:   AppConstants.spaceM,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StateIcon(state: voice.state),
          const SizedBox(height: AppConstants.spaceM),

          if (voice.statusMessage.isNotEmpty)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                voice.statusMessage,
                key: ValueKey(voice.statusMessage),
                style: AppTextStyles.headlineSmall.copyWith(
                  color: _colorForState(voice.state),
                ),
                textAlign: TextAlign.center,
              ),
            ),

          if (voice.transcript.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spaceS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceM,
                vertical:   AppConstants.spaceS,
              ),
              decoration: BoxDecoration(
                color: AppColors.darkBerry.withValues(alpha: 0.07),
                borderRadius:
                BorderRadius.circular(AppConstants.radiusM),
              ),
              child: Text(
                '"${voice.transcript}"',
                style: AppTextStyles.bodyMedium
                    .copyWith(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          if (voice.state == VoiceState.success &&
              voice.lastCommand?.intent == VoiceIntent.whatsPlaying &&
              audio.currentSong != null) ...[
            const SizedBox(height: AppConstants.spaceM),
            _NowPlayingCard(audio: audio),
          ],

          // ── Idle hint ──────────────────────────────────────────────
          if (voice.state == VoiceState.idle) ...[
            const SizedBox(height: AppConstants.spaceM),
            Text(
              'Tap the mic and say something like\n"Play happy music" or "Skip"',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.stoneDark),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Color _colorForState(VoiceState state) {
    switch (state) {
      case VoiceState.listening:  return AppColors.sage;
      case VoiceState.success:    return AppColors.darkBerry;
      case VoiceState.error:      return AppColors.roseQuartz;
      default:                    return AppColors.stoneDark;
    }
  }
}

class _StateIcon extends StatelessWidget {
  final VoiceState state;
  const _StateIcon({required this.state});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color    color;

    switch (state) {
      case VoiceState.idle:
        icon  = Icons.mic_none_rounded;
        color = AppColors.stone;
        break;
      case VoiceState.listening:
        icon  = Icons.mic_rounded;
        color = AppColors.sage;
        break;
      case VoiceState.processing:
        icon  = Icons.hourglass_top_rounded;
        color = AppColors.roseQuartz;
        break;
      case VoiceState.success:
        icon  = Icons.check_circle_rounded;
        color = AppColors.sage;
        break;
      case VoiceState.error:
        icon  = Icons.error_outline_rounded;
        color = AppColors.roseQuartz;
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: Icon(icon, key: ValueKey(state), size: 44, color: color),
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  final AudioProvider audio;
  const _NowPlayingCard({required this.audio});

  @override
  Widget build(BuildContext context) {
    final song = audio.currentSong!;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.darkBerry.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(
            color: AppColors.darkBerry.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_note_rounded,
              color: AppColors.darkBerry, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(song.title,
                    style: AppTextStyles.songTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(song.artist,
                    style: AppTextStyles.songArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mic button ────────────────────────────────────────────────────────────────

class _MicButton extends StatelessWidget {
  final VoiceProvider voice;
  final AnimationController waveCtrl;
  const _MicButton({required this.voice, required this.waveCtrl});

  @override
  Widget build(BuildContext context) {
    final isListening  = voice.isListening;
    final isProcessing = voice.state == VoiceState.processing;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        if (isListening) {
          await voice.stopListening();
        } else {
          await voice.startListening();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width:  isListening ? 96 : 80,
        height: isListening ? 96 : 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isListening ? AppColors.darkBerry : AppColors.sage,
          boxShadow: [
            BoxShadow(
              color: (isListening
                  ? AppColors.darkBerry
                  : AppColors.sage)
                  .withValues(alpha: isListening ? 0.45 : 0.30),
              blurRadius:   isListening ? 28 : 16,
              spreadRadius: isListening ? 6  : 2,
            ),
          ],
        ),
        child: isProcessing
            ? const Center(
          child: SizedBox(
            width: 28, height: 28,
            child: CircularProgressIndicator(
              color:       AppColors.white,
              strokeWidth: 2.5,
            ),
          ),
        )
            : Icon(
          isListening
              ? Icons.mic_rounded
              : Icons.mic_none_rounded,
          color: AppColors.white,
          size: isListening ? 44 : 36,
        ),
      ),
    );
  }
}

// ── Sound wave ────────────────────────────────────────────────────────────────

class _SoundWave extends StatelessWidget {
  final AnimationController controller;
  final bool isActive;
  const _SoundWave(
      {required this.controller, required this.isActive});

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(
          7,
              (i) => _Bar(
            height: 4,
            color:  AppColors.stone.withValues(alpha: 0.4),
            margin: const EdgeInsets.symmetric(horizontal: 3),
          ),
        ),
      );
    }

    const barCount = 7;
    const heights  = [18.0, 32.0, 42.0, 48.0, 42.0, 32.0, 18.0];
    final phases   = List.generate(barCount, (i) => i / barCount);

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(barCount, (i) {
            final phase  = phases[i];
            final factor =
                (math.sin((t + phase) * 2 * math.pi) + 1) / 2;
            final h = 6 + heights[i] * factor;
            return _Bar(
              height: h,
              color: Color.lerp(
                AppColors.sage.withValues(alpha: 0.5),
                AppColors.darkBerry,
                factor,
              )!,
              margin:
              const EdgeInsets.symmetric(horizontal: 3),
            );
          }),
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  final double height;
  final Color  color;
  final EdgeInsets margin;
  const _Bar(
      {required this.height,
        required this.color,
        required this.margin});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      margin:   margin,
      width:    5,
      height:   height,
      decoration: BoxDecoration(
        color:        color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// ── Suggestion chips ──────────────────────────────────────────────────────────

class _SuggestionChips extends StatelessWidget {
  final VoiceProvider voice;
  const _SuggestionChips({required this.voice});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spaceM),
        itemCount: VoiceKeywords.suggestions.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: AppConstants.spaceS),
        itemBuilder: (_, i) {
          final suggestion = VoiceKeywords.suggestions[i];
          return ActionChip(
            label: Text(
              suggestion,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.darkBerry),
            ),
            backgroundColor:
            AppColors.darkBerry.withValues(alpha: 0.07),
            side: BorderSide(
              color: AppColors.darkBerry.withValues(alpha: 0.2),
              width: 0.8,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              voice.simulateTranscript(suggestion);
            },
          );
        },
      ),
    );
  }
}

// ── Command history ───────────────────────────────────────────────────────────

class _CommandHistory extends StatelessWidget {
  final List<ParsedCommand> history;
  const _CommandHistory({required this.history});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Recent commands', style: AppTextStyles.label),
          const SizedBox(height: AppConstants.spaceS),
          ...history.map(
                (cmd) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded,
                      size: 14, color: AppColors.stone),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"${cmd.transcript}"',
                      style: AppTextStyles.bodySmall.copyWith(
                          fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cmd.description,
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.sage),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}