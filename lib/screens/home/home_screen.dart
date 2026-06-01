import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/battery_provider.dart';
import '../../widgets/battery_arc.dart';
import '../../widgets/connection_badge.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Color _getTemperatureColor(double temp) {
    if (temp >= 45.0) return Colors.red;         // Overheating
    if (temp >= 35.0) return Colors.green;      // Getting warm
    if (temp <= 15.0) return Colors.blue;        // Cold
    return Colors.green;                         // Optimal
  }

  Color _getBatteryColor(num soc) {
    if (soc >= 55) {
      return Colors.green;
    } else if (soc >= 30) {
      return Colors.orangeAccent;
    }
    return Colors.red;
  }


  @override
  Widget build(BuildContext context) {
    final batteryProvider = Provider.of<BatteryProvider>(context);
    final battery = batteryProvider.batteryData;

    // FORCE LIGHT THEME FOR THIS SCREEN
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        cardColor: Colors.white,
      ),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: Colors.grey[50],
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // 1. THE SCOOTER MEDIA LAYER
                    Center(
                      child: battery.current <= -0.6 ? _MotionScooterDisplay(imagePath: 'lib/assets/scooty.png', height: 250) : Image.asset('lib/assets/scooty.png', height: 250),
                    ),

                    // ===================================================
                    // BATTERY ARC
                    // ===================================================
                    BatteryArc(
                      percentage: battery.soc,
                      range: battery.range.toInt(),
                    ),

                    const SizedBox(height: 20),

                    // ===================================================
                    // CONNECTION STATUS
                    // ===================================================
                    const ConnectionBadge(),

                    const SizedBox(height: 20),

                    // ===================================================
                    // VITAL STATS (Unbreakable Layout)
                    // ===================================================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          // ROW 1: Voltage & Current
                          Row(
                            children: [
                              Expanded(
                                child: _LightInfoCard(
                                  title: 'VOLTAGE',
                                  value: '${battery.voltage.toStringAsFixed(1)} V',
                                  icon: Icons.bolt,
                                  iconColor: Colors.amber,
                                  cornerImageAsset: 'lib/assets/voltage.png',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _LightInfoCard(
                                  title: 'CURRENT',
                                  value: '${battery.current.toStringAsFixed(1)} A',
                                  icon: Icons.electric_meter,
                                  iconColor: Colors.blueAccent,
                                  cornerImageAsset: 'lib/assets/current_vector.png',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ROW 2: Temperature & Battery
                          Row(
                            children: [
                              Expanded(
                                child: _LightInfoCard(
                                  title: 'TEMPERATURE',
                                  value: '${battery.temperature.toStringAsFixed(1)} °C',
                                  icon: Icons.thermostat,
                                  iconColor: _getTemperatureColor(battery.temperature),
                                  imageColor: _getTemperatureColor(battery.temperature),
                                  cornerImageAsset: 'lib/assets/temperature.png',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _LightInfoCard(
                                  title: 'BATTERY',
                                  value: '${battery.soc} %',
                                  icon: Icons.battery_full,
                                  iconColor: _getBatteryColor(battery.soc),
                                  imageColor: _getBatteryColor(battery.soc),
                                  cornerImageAsset: 'lib/assets/battery.png',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===================================================
                    // CELL VOLTAGES
                    // ===================================================
                    if (battery.cellVoltages.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Cell Voltages",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: List.generate(
                                battery.cellVoltages.length,
                                (index) {
                                  final cellVoltage = battery.cellVoltages[index];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "C${index + 1}: ${cellVoltage.toStringAsFixed(3)}V",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// =======================================================
// LIGHT THEME INFO CARD (Bulletproof Version)
// =======================================================
class _LightInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final Color? imageColor;
  final String? cornerImageAsset;

  const _LightInfoCard({
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.imageColor,
    this.cornerImageAsset,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? Colors.black54;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            if (cornerImageAsset != null)
              Positioned(
                right: -8,
                bottom: -10,
                child: Opacity(
                  opacity: 1,
                  child: Image.asset(
                    cornerImageAsset!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                    color: imageColor,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: effectiveIconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: effectiveIconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // CRITICAL FIX: Shrinks text instead of wrapping to two lines
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // CRITICAL FIX: Keeps giant numbers safely inside the box
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// RUSHING WIND / MOTION DISPLAY
// =======================================================
class _MotionScooterDisplay extends StatefulWidget {
  final String imagePath;
  final double height;

  const _MotionScooterDisplay({
    required this.imagePath,
    this.height = 250,
  });

  @override
  State<_MotionScooterDisplay> createState() => _MotionScooterDisplayState();
}

class _MotionScooterDisplayState extends State<_MotionScooterDisplay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 1 second loop: Fast enough to feel like speed, smooth enough not to stutter
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(); // Loops infinitely
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. THE MOVING WIND LINES (Background)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _SpeedWindPainter(_controller.value),
                );
              },
            ),
          ),

          // 2. THE STATIC SCOOTER (Foreground)
          Image.asset(
            widget.imagePath,
            height: widget.height,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}

// =======================================================
// THE CUSTOM PAINTER (Calculates the moving lines)
// =======================================================
class _SpeedWindPainter extends CustomPainter {
  final double animationValue;

  _SpeedWindPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3) // Soft grey wind
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // We draw 6 distinct "wind lines" at different heights, speeds, and lengths
    // Y-Offset (0.0 to 1.0) | Length | Speed Multiplier | Start X Offset
    _drawWindLine(canvas, size, paint, y: 0.15, length: 60, speed: 1.2, startX: 0.2);
    _drawWindLine(canvas, size, paint, y: 0.35, length: 100, speed: 1.5, startX: 0.7);
    _drawWindLine(canvas, size, paint, y: 0.50, length: 40, speed: 0.8, startX: 0.4);
    _drawWindLine(canvas, size, paint, y: 0.65, length: 80, speed: 1.3, startX: 0.1);
    _drawWindLine(canvas, size, paint, y: 0.85, length: 50, speed: 1.1, startX: 0.8);
    _drawWindLine(canvas, size, paint, y: 0.95, length: 120, speed: 1.6, startX: 0.5);
  }

  void _drawWindLine(Canvas canvas, Size size, Paint paint, {
    required double y, required double length, required double speed, required double startX,
  }) {
    // Calculates the X position moving right to left
    double normalizedX = (startX - (animationValue * speed)) % 1.0;
    if (normalizedX < 0) normalizedX += 1.0; // Wraps around the screen perfectly

    double xPos = normalizedX * size.width;
    double yPos = y * size.height;

    // Draws the line
    canvas.drawLine(Offset(xPos, yPos), Offset(xPos + length, yPos), paint);

    // Smooth looping logic: If the line is cut off by the right edge, draw the rest on the left
    if (xPos + length > size.width) {
      double remainingLength = (xPos + length) - size.width;
      canvas.drawLine(Offset(0, yPos), Offset(remainingLength, yPos), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedWindPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue; // Only repaint when animation moves
  }
}