import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Paints the tone-arm needle.
///
/// The needle pivots around a fixed point at the top-right of the vinyl area.
/// [angle] controls the rotation:
///   - Resting (not playing): needle is angled away from disc (~-0.35 rad)
///   - Playing: needle rests on disc (~0.0 rad, pointing inward)
///
/// Animation between states is handled by the parent [VinylWidget] using
/// an [AnimationController] and [CurvedAnimation].
class NeedlePainter extends CustomPainter {
  /// Rotation angle of the needle in radians.
  /// 0.0 = playing position (touching disc).
  /// Negative = retracted away from disc.
  final double angle;

  const NeedlePainter({required this.angle});

  // Pivot point is at top-right, just outside the vinyl circle.
  // These are fractions of the total canvas size.
  static const double _pivotXFraction = 0.85;
  static const double _pivotYFraction = 0.05;

  // Arm length as fraction of canvas width
  static const double _armLengthFraction = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final pivotX  = size.width  * _pivotXFraction;
    final pivotY  = size.height * _pivotYFraction;
    final pivot   = Offset(pivotX, pivotY);
    final armLen  = size.width  * _armLengthFraction;

    canvas.save();
    canvas.translate(pivotX, pivotY);
    canvas.rotate(angle);

    // ── Pivot circle ──────────────────────────────────────────────────────────
    final pivotBodyPaint = Paint()
      ..color = const Color(0xFF3A3A3A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 9, pivotBodyPaint);

    final pivotRingPaint = Paint()
      ..color = AppColors.stone.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset.zero, 9, pivotRingPaint);

    // ── Arm body — straight line from pivot to cartridge ─────────────────────
    // The arm points downward-left toward the vinyl center when playing.
    // We draw it as a thick rounded line.
    final armPaint = Paint()
      ..color = const Color(0xFF4A4A4A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final armEnd = Offset(0, armLen); // arm extends downward before rotation
    canvas.drawLine(Offset.zero, armEnd, armPaint);

    // Arm highlight — thin lighter stripe along the arm
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-1, 8), Offset(-1, armLen - 10), highlightPaint);

    // ── Cartridge (headshell) at the tip ──────────────────────────────────────
    final cartridgePaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.fill;

    // Small rectangular cartridge at arm tip
    final cartridgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, armLen + 8),
        width:  10,
        height: 16,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(cartridgeRect, cartridgePaint);

    // Stylus — tiny needle tip
    final stylusPaint = Paint()
      ..color = AppColors.blushDark
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(0, armLen + 16), 3, stylusPaint);

    canvas.restore();

    // Draw a subtle shadow under the pivot to give it depth
    // (drawn after restore so it's in the original coordinate space)
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(pivotX, pivotY + 2), 10, shadowPaint);
  }

  @override
  bool shouldRepaint(NeedlePainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}
