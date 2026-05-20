import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../features/library/widgets/album_art_widget.dart';
import '../../../../shared/providers/audio_provider.dart';
import 'vinyl_painter.dart';
import 'needle_painter.dart';

// ── Needle angle constants ────────────────────────────────────────────────────
// Resting angle (retracted, not playing)
const double _needleResting = -0.42;
// Playing angle (touching the vinyl)
const double _needlePlaying = -0.10;

/// The vinyl record widget — the visual centrepiece of the Now Playing screen.
///
/// Owns two [AnimationController]s:
///   1. [_spinController]   — continuous rotation at 33⅓ RPM
///   2. [_needleController] — needle pivot between resting and playing positions
///
/// Responds to [AudioProvider] state:
///   - Playing   → spins at constant speed, needle on disc
///   - Paused    → decelerates and stops, needle lifts away
///   - Buffering → slow-pulse glow on disc edge
///   - Error     → gentle shake
///
/// Gesture handling (per spec):
///   - Tap           → toggle play/pause
///   - Double-tap    → like/unlike song
///   - Swipe left    → next track
///   - Swipe right   → previous track
///   - Long-press    → show song details
class VinylWidget extends StatefulWidget {
  final AudioProvider audio;
  final int? albumId;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final String? albumArtUrl;

  const VinylWidget({
    super.key,
    required this.audio,
    required this.albumId,
    this.albumArtUrl,
    required this.onDoubleTap,
    required this.onLongPress,
  });

  @override
  State<VinylWidget> createState() => _VinylWidgetState();
}

class _VinylWidgetState extends State<VinylWidget>
    with TickerProviderStateMixin {

  // ── Spin controller ───────────────────────────────────────────────────────
  late final AnimationController _spinController;

  // ── Needle controller ─────────────────────────────────────────────────────
  late final AnimationController _needleController;
  late final Animation<double> _needleAngle;

  // ── Pulse controller (buffering glow) ─────────────────────────────────────
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  // ── Shake controller (error state) ───────────────────────────────────────
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnim;

  // ── Accumulated rotation offset ───────────────────────────────────────────
  // Stored so the disc doesn't jump back to 0 when paused and resumed.
  double _savedAngle = 0.0;

  // ── Previous playback state — to detect transitions ───────────────────────
  bool _wasPlaying    = false;
  bool _wasBuffering  = false;

  @override
  void initState() {
    super.initState();

    // Spin — one full rotation every ~1800ms (33⅓ RPM).
    // We use repeat() so it loops continuously.
    // Duration matches AppConstants.vinylRotationMs.
    _spinController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: AppConstants.vinylRotationMs),
    );

    // Needle — swings between resting and playing angles.
    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _needleAngle = Tween<double>(
      begin: _needleResting,
      end:   _needlePlaying,
    ).animate(CurvedAnimation(
      parent: _needleController,
      curve:  Curves.easeInOut,
    ));

    // Pulse — slow in-and-out glow for buffering state.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Shake — brief left-right oscillation for error state.
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0,  end:  6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 6.0,  end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end:  4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0,  end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end:  0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));

    // Listen to spin ticks so we can save the angle on pause.
    _spinController.addListener(_onSpinTick);

    // Apply the initial state.
    _syncToAudioState(initial: true);

    // Seed the "was" trackers to the current state so that the first call
    // to didUpdateWidget doesn't fire a redundant sync if state hasn't changed.
    _wasPlaying   = widget.audio.isPlaying;
    _wasBuffering = widget.audio.isBuffering;
  }

  @override
  void didUpdateWidget(VinylWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final isPlaying   = widget.audio.isPlaying;
    final isBuffering = widget.audio.isBuffering;

    // Only act when state actually changes.
    if (isPlaying != _wasPlaying || isBuffering != _wasBuffering) {
      _syncToAudioState(initial: false);
      _wasPlaying   = isPlaying;
      _wasBuffering = isBuffering;
    }
  }

  // ── Sync animations to AudioProvider state ────────────────────────────────

  void _syncToAudioState({required bool initial}) {
    final isPlaying   = widget.audio.isPlaying;
    final isBuffering = widget.audio.isBuffering;

    if (isBuffering) {
      _spinController.stop();
      _needleController.reverse();
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else if (isPlaying) {
      _pulseController.stop();
      _pulseController.reset();

      // Resume spinning from where we left off.
      // We restart from 0 but offset by _savedAngle — the spin controller
      // always starts at 0 and we add _savedAngle in the build method.
      if (initial) {
        // Don't animate needle on first build — just snap.
        _needleController.value = 0.0; // resting
      } else {
        _needleController.forward(); // swing needle onto disc
      }
      _spinController.repeat();

    } else {
      // Paused or stopped.
      _pulseController.stop();
      _pulseController.reset();

      // Save current angle before stopping so disc resumes from same position.
      _savedAngle = _currentSpinAngle;
      _spinController.stop();
      _needleController.reverse(); // lift needle off disc
    }
  }

  void _onSpinTick() {
    // Nothing extra needed — setState is driven by AnimatedBuilder in build().
  }

  // ── Current total spin angle (radians) ────────────────────────────────────
  double get _currentSpinAngle {
    return _savedAngle + (_spinController.value * 2 * math.pi);
  }

  // ── Dispose ───────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _spinController.removeListener(_onSpinTick);
    _spinController.dispose();
    _needleController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ── Gesture handlers ──────────────────────────────────────────────────────

  void _onTap() {
    HapticFeedback.selectionClick();
    widget.audio.playPause();
  }

  void _onDoubleTap() {
    HapticFeedback.lightImpact();
    widget.onDoubleTap();
  }

  void _onLongPress() {
    HapticFeedback.mediumImpact();
    widget.onLongPress();
  }

  void _onSwipeLeft() {
    HapticFeedback.selectionClick();
    widget.audio.skipToNext();
  }

  void _onSwipeRight() {
    HapticFeedback.selectionClick();
    widget.audio.skipToPrevious();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const double vinylSize   = AppConstants.vinylDiameter;      // 280
    const double labelSize   = AppConstants.vinylLabelDiameter; // 200
    // Total canvas — vinyl plus room for the needle arm on the right
    const double canvasWidth  = vinylSize + 60;
    const double canvasHeight = vinylSize + 40;

    return GestureDetector(
      onTap:          _onTap,
      onDoubleTap:    _onDoubleTap,
      onLongPress:    _onLongPress,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -200) _onSwipeLeft();
        if (details.primaryVelocity! >  200) _onSwipeRight();
      },
      child: SizedBox(
        width:  canvasWidth,
        height: canvasHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [

            // ── Needle (behind disc, except pivot which overlaps) ───────────
            Positioned(
              top:  0,
              left: 0,
              child: AnimatedBuilder(
                animation: _needleAngle,
                builder: (_, __) => CustomPaint(
                  size: const Size(canvasWidth, canvasHeight),
                  painter: NeedlePainter(angle: _needleAngle.value),
                ),
              ),
            ),

            // ── Vinyl disc (centred in canvas) ────────────────────────────
            Positioned(
              top:  20,
              left: 0,
              child: _buildDisc(vinylSize, labelSize),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildDisc(double vinylSize, double labelSize) {
    final isBuffering = widget.audio.isBuffering;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _spinController,
        _pulseController,
        _shakeController,
      ]),
      builder: (_, __) {
        final spinAngle   = _currentSpinAngle;
        final shakeOffset = _shakeController.isAnimating
            ? _shakeAnim.value
            : 0.0;
        final pulseOpacity = isBuffering
            ? (0.3 + _pulseAnim.value * 0.5)
            : 0.0;

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: SizedBox(
            width:  vinylSize,
            height: vinylSize,

            child: Stack(
              alignment: Alignment.center,
              children: [

                // ── Drop shadow beneath the disc ───────────────────────────
                Container(
                  width:  vinylSize,
                  height: vinylSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),

                // ── Rotating vinyl body + grooves + glint ──────────────────
                Transform.rotate(
                  angle: spinAngle,
                  child: CustomPaint(
                    size: Size(vinylSize, vinylSize),
                    painter: VinylPainter(glintAngle: spinAngle),
                  ),
                ),

                // ── Album art circle (sits on top of the label area) ───────
                // Rotates with the disc.
                Transform.rotate(
                  angle: spinAngle,
                  child: ClipOval(
                    child: SizedBox(
                      width:  labelSize,
                      height: labelSize,
                      child: AlbumArtWidget(
                        albumId:      widget.albumId,
                        albumArtUrl:  widget.albumArtUrl,
                        size:         labelSize,
                        borderRadius: labelSize / 2,
                      ),
                    ),
                  ),
                ),

                // ── Shimmer overlay on album art (subtle) ──────────────────
                // A thin white arc that sweeps across the label as it spins.
                Transform.rotate(
                  angle: spinAngle,
                  child: CustomPaint(
                    size: Size(labelSize, labelSize),
                    painter: _LabelShimmerPainter(angle: spinAngle),
                  ),
                ),

                // ── Pulse glow ring for buffering state ────────────────────
                if (isBuffering)
                  Container(
                    width:  vinylSize,
                    height: vinylSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.roseQuartz.withOpacity(pulseOpacity),
                        width: 4,
                      ),
                    ),
                  ),

                // ── Buffering spinner ──────────────────────────────────────
                if (isBuffering)
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: AppColors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Label shimmer painter ─────────────────────────────────────────────────────

/// Draws a single thin arc over the album art to simulate a light shimmer.
/// Very subtle — low opacity so it doesn't overpower the artwork.
class _LabelShimmerPainter extends CustomPainter {
  final double angle;
  const _LabelShimmerPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.18);

    // Single arc — about 40 degrees wide
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.65),
      angle + math.pi / 4,
      math.pi / 4.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_LabelShimmerPainter old) => old.angle != angle;
}
