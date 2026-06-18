import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom painter that draws a rounded-rectangle tank with animated water
/// waves filling it to [waterLevel] (0.0 → 1.0).
///
/// [wavePhase] drives the horizontal wave motion (typically an animation
/// value that increments continuously).
class WaterTankPainter extends CustomPainter {
  final double waterLevel; // 0.0 – 1.0
  final double wavePhase; // continuously increasing value for wave animation
  final Color waterColor;
  final Color tankBorderColor;

  WaterTankPainter({
    required this.waterLevel,
    required this.wavePhase,
    required this.waterColor,
    required this.tankBorderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cornerRadius = w * 0.12;

    // ─── Tank outline (rounded rect) ──────────────────────────────────────
    final tankRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(cornerRadius),
    );

    // Clip everything inside the tank shape
    canvas.save();
    canvas.clipRRect(tankRect);

    // Tank background (slightly tinted)
    final bgPaint = Paint()..color = waterColor.withValues(alpha: 0.06);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // ─── Water fill with wave ─────────────────────────────────────────────
    final clampedLevel = waterLevel.clamp(0.0, 1.0);
    final waterTop = h * (1.0 - clampedLevel);
    final waveHeight = h * 0.025; // wave amplitude

    final waterPath = Path();
    waterPath.moveTo(0, waterTop);

    // Draw sine wave across the top of the water
    for (double x = 0; x <= w; x += 1.0) {
      final y = waterTop +
          math.sin((x / w * 2 * math.pi) + wavePhase) * waveHeight +
          math.sin((x / w * 4 * math.pi) + wavePhase * 1.5) *
              waveHeight *
              0.5;
      waterPath.lineTo(x, y);
    }

    // Close the path at the bottom
    waterPath.lineTo(w, h);
    waterPath.lineTo(0, h);
    waterPath.close();

    // Water gradient (darker at bottom, lighter at top)
    final waterPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          waterColor.withValues(alpha: 0.6),
          waterColor.withValues(alpha: 0.9),
        ],
      ).createShader(Rect.fromLTWH(0, waterTop, w, h - waterTop));

    canvas.drawPath(waterPath, waterPaint);

    // Second wave layer (slightly offset for depth effect)
    final wave2Path = Path();
    final wave2Top = waterTop + waveHeight * 0.6;
    wave2Path.moveTo(0, wave2Top);
    for (double x = 0; x <= w; x += 1.0) {
      final y = wave2Top +
          math.sin((x / w * 2.5 * math.pi) + wavePhase * 0.8 + 1.2) *
              waveHeight *
              0.7;
      wave2Path.lineTo(x, y);
    }
    wave2Path.lineTo(w, h);
    wave2Path.lineTo(0, h);
    wave2Path.close();

    final wave2Paint = Paint()
      ..color = waterColor.withValues(alpha: 0.25);
    canvas.drawPath(wave2Path, wave2Paint);

    canvas.restore();

    // ─── Tank border ──────────────────────────────────────────────────────
    final borderPaint = Paint()
      ..color = tankBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(tankRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant WaterTankPainter oldDelegate) {
    return oldDelegate.waterLevel != waterLevel ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.waterColor != waterColor;
  }
}
