import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A circular pH dial, 0–14, with colored zones (acidic / neutral / alkaline)
/// and a needle pointing at the current reading.
class PhGauge extends StatelessWidget {
  final double pH;
  final double size;

  const PhGauge({super.key, required this.pH, this.size = 180});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PhGaugePainter(pH: pH.clamp(0, 14)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(pH.toStringAsFixed(1), style: AppText.reading),
              const SizedBox(height: 2),
              const Text('pH', style: AppText.label),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhGaugePainter extends CustomPainter {
  final double pH;
  _PhGaugePainter({required this.pH});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;

    const startAngle = 135 * math.pi / 180;
    const sweepAngle = 270 * math.pi / 180;

    final trackPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    final zones = [
      (0.0, 6.0, AppColors.phLow),
      (6.0, 8.0, AppColors.phMid),
      (8.0, 14.0, AppColors.phHigh),
    ];

    for (final (from, to, color) in zones) {
      final zonePaint = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.butt;

      final zoneStart = startAngle + (from / 14) * sweepAngle;
      final zoneSweep = ((to - from) / 14) * sweepAngle;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        zoneStart,
        zoneSweep,
        false,
        zonePaint,
      );
    }

    final needleAngle = startAngle + (pH / 14) * sweepAngle;
    final needleLength = radius - 18;
    final needleEnd = Offset(
      center.dx + needleLength * math.cos(needleAngle),
      center.dy + needleLength * math.sin(needleAngle),
    );

    final needlePaint = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, needleEnd, needlePaint);

    final hubPaint = Paint()..color = AppColors.textPrimary;
    canvas.drawCircle(center, 5, hubPaint);
  }

  @override
  bool shouldRepaint(covariant _PhGaugePainter oldDelegate) {
    return oldDelegate.pH != pH;
  }
}
