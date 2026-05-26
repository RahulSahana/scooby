import 'dart:math';
import 'package:flutter/material.dart';

class BatteryArc extends StatelessWidget {
  final double percentage; // 0.0 to 1.0
  final int range;

  const BatteryArc({
    super.key,
    required this.percentage,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
    final String rangeStr = range.toString();
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(200, 100),
              painter: ArcPainter(percentage: percentage),
            ),
            Positioned(
              bottom: 10,
              child: Column(
                children: [
                  Text(
                    rangeStr,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _getBatteryColor(percentage),
                    ),
                  ),
                  Text(
                    'km range',
                    style: TextStyle(
                      fontSize: 14,
                      color: _getBatteryColor(percentage),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${(percentage * 100).toInt()}% Battery',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: _getBatteryColor(percentage),
          ),
        ),
      ],
    );
  }
}

class ArcPainter extends CustomPainter {
  final double percentage;

  ArcPainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 15.0;
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height - strokeWidth / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background Arc
    final bgPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, pi, pi, false, bgPaint);

    // Foreground (Battery) Arc
    final batteryPaint = Paint()
      ..color = _getBatteryColor(percentage)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, pi, pi * percentage, false, batteryPaint);

    // Glow/Mist Effect
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _getBatteryColor(percentage).withAlpha((0.4 * 255).toInt()),
          _getBatteryColor(percentage).withAlpha((0.1 * 255).toInt()),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 30))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    // Create a path for the active arc area to constrain the glow
    final Path glowPath = Path()
      ..addArc(rect.inflate(30), pi, pi * percentage);

    // Optional: Use saveLayer for better blending if needed,
    // but a simple drawPath with transparency usually works well.
    canvas.drawPath(glowPath, glowPaint);
  }

  @override
  bool shouldRepaint(covariant ArcPainter oldDelegate) =>
      oldDelegate.percentage != percentage;
}

Color _getBatteryColor(double p) {
  if (p > 0.5) {
    return Colors.green;
  } else if (p > 0.2) {
    return Colors.orangeAccent;
  }
  return Colors.red;
}
