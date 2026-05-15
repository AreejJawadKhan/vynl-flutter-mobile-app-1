import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Paints the vinyl disc: dark body, concentric groove rings, center cutout.
///
/// The album art image is drawn separately on top (as a widget) so that
/// on_audio_query's QueryArtworkWidget can handle the actual image loading.
/// This painter only draws the vinyl body and grooves.
///
/// [glintAngle] is the current rotation in radians — used to rotate the
/// subtle light reflection around the disc as it spins.
class VinylPainter extends CustomPainter {
  final double glintAngle;

  const VinylPainter({required this.glintAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // ── 1. Vinyl body — dark near-black disc ─────────────────────────────────
    final bodyPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bodyPaint);

    // ── 2. Outer edge highlight — very subtle lighter ring ────────────────────
    final edgePaint = Paint()
      ..color = const Color(0xFF2E2E2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 1.5, edgePaint);

    // ── 3. Groove rings — concentric circles from outer to inner ──────────────
    // Vinyl grooves sit between the outer edge and the label area.
    // Label radius is vinylLabelDiameter/2 = 100px.
    // We draw grooves from ~90% of outer radius down to ~40% (just outside label).
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    const grooveCount = 18;
    const grooveStart = 0.42; // fraction of radius where grooves begin (inner)
    const grooveEnd   = 0.92; // fraction of radius where grooves end (outer)
    final grooveSpan  = grooveEnd - grooveStart;

    for (int i = 0; i < grooveCount; i++) {
      final fraction = grooveStart + (i / (grooveCount - 1)) * grooveSpan;
      final r = radius * fraction;

      // Alternate between slightly lighter and darker for a subtle banding
      final alpha = (i % 2 == 0) ? 55 : 35;
      groovePaint.color = Color.fromARGB(alpha, 255, 255, 255);
      canvas.drawCircle(center, r, groovePaint);
    }

    // ── 4. Glint — a small arc of light that rotates with the disc ────────────
    // This simulates a light reflection sweeping around as the vinyl spins.
    final glintPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.12);

    final glintRect = Rect.fromCircle(center: center, radius: radius * 0.72);
    // Arc spans about 30 degrees
    canvas.drawArc(glintRect, glintAngle, math.pi / 6, false, glintPaint);

    // ── 5. Label area — dark circle in center (album art sits on top of this) ─
    // This gives the label a slightly different colour from the grooves,
    // matching a real vinyl record's paper label look.
    const labelRadius = 100.0; // = vinylLabelDiameter / 2

    final labelPaint = Paint()
      ..color = const Color(0xFF2A1218) // dark berry-tinted dark
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, labelRadius, labelPaint);

    // Label edge ring — matches the blush palette
    final labelEdgePaint = Paint()
      ..color = AppColors.blushDark.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, labelRadius, labelEdgePaint);

    // ── 6. Center spindle hole ────────────────────────────────────────────────
    final spindlePaint = Paint()
      ..color = const Color(0xFF0D0408)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5, spindlePaint);
  }

  @override
  bool shouldRepaint(VinylPainter oldDelegate) {
    return oldDelegate.glintAngle != glintAngle;
  }
}
