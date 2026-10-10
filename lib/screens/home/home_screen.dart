import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/battery_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/battery_arc.dart';
import '../../widgets/connection_badge.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Color _getTemperatureColor(double temp, ColorScheme colors) {
    if (temp >= 45) return colors.error;      // Critical
    if (temp >= 35) return Colors.orange;   // Warm
    if (temp <= 15) return colors.secondary;  // Cold
    return colors.primary;                    // Normal
  }

  Color _getBatteryColor(num soc, ColorScheme colors) {
    if (soc >= 55) return colors.primary;
    if (soc >= 30) return colors.tertiary;
    return colors.error;
  }

  Color _getSohColor(num soh,ColorScheme colors) {
    if (soh >= 90) return colors.primary;           // Excellent / Optimal
    if (soh >= 80) return colors.tertiary;          // Fair / Degrading
    return colors.error;                            // Poor / Replace soon
  }


  @override
  Widget build(BuildContext context) {
    final batteryProvider = Provider.of<BatteryProvider>(context);
    final battery = batteryProvider.batteryData;
    final theme = Theme.of(context).extension<AppColors>()!;
    final colors = Theme.of(context).colorScheme;

    String powerLabel;

    if (battery.current > 0) {
      powerLabel = 'Charging Power';
    } else if (battery.current < 0) {
      powerLabel = 'Power Draw';
    } else {
      powerLabel = 'Power';
    }



    return Scaffold(
      backgroundColor: theme.background,
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                child: Column(
                  //crossAxisAlignment: CrossAxisAlignment.stretch,
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

                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BATTERY VITALS',
                            style: TextStyle(
                              color: Color(0xFF9B9B9B),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Data Row 0
                          Row(
                            children: [
                              Expanded(
                                child: _LightInfoCard(
                                  title: 'VOLTAGE',
                                  value: '${battery.voltage.toStringAsFixed(1)} V',
                                  icon: Icons.bolt,
                                  iconColor: theme.warningAmber,
                                  cornerImageAsset: 'lib/assets/voltage.png',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _LightInfoCard(
                                  title: 'BATTERY',
                                  value: '${battery.soc} %',
                                  icon: Icons.battery_full,
                                  iconColor: _getBatteryColor(battery.soc, colors),
                                  imageColor: _getBatteryColor(battery.soc, colors),
                                  cornerImageAsset: 'lib/assets/battery.png',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Data Row 0
                          Row(
                            children: [

                              Expanded(
                                child: _LightInfoCard(
                                  title: powerLabel,
                                  value: '${battery.power.abs().toStringAsFixed(0)} W',
                                  icon: Icons.flash_on,
                                  iconColor: Colors.amber,
                                  // No imageColor passed! It will use the original asset colors.
                                  cornerImageAsset: "lib/assets/power.png",
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _LightInfoCard(
                                  title: 'Current',
                                  value: '${battery.current.abs().toStringAsFixed(1)} A',
                                  icon: Icons.electric_meter,
                                  iconColor: Colors.blueAccent,
                                  // No imageColor passed!
                                  cornerImageAsset: 'lib/assets/current.png',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Data Row 2
                          Row(
                            children: [
                              Expanded(
                                child: _LightInfoCard(
                                  title: 'Temperature',
                                  value: '${battery.temperature}°C',
                                  icon: Icons.thermostat_outlined,
                                  // DYNAMIC COLORS APPLIED HERE
                                  iconColor: _getTemperatureColor(battery.temperature,colors),
                                  imageColor: _getTemperatureColor(battery.temperature,colors),
                                  cornerImageAsset: 'lib/assets/temperature.png',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _LightInfoCard(
                                  title: 'Charge Cycles',
                                  value: '${battery.cycleCount}',
                                  icon: Icons.autorenew,
                                  iconColor: const Color(0xFF00BFFF),
                                  imageColor: const Color(0xFF00BFFF),
                                  cornerImageAsset: 'lib/assets/cycle.png',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Data Row 3
                          Row(
                            children: [
                              Expanded(
                                child: _LightInfoCard(
                                  title: 'Health (SOH)',
                                  value: '${battery.soh.toStringAsFixed(0)}%',
                                  icon: Icons.health_and_safety,
                                  // DYNAMIC COLORS APPLIED HERE
                                  iconColor: _getSohColor(battery.soh,colors),
                                  imageColor: _getSohColor(battery.soh,colors),
                                  cornerImageAsset: 'lib/assets/charge_ev_trans.png',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
//====================================================
/// Charging Info Card
//====================================================
                          _ChargingInfoCard(
                            isCharging: battery.current > 0,
                            socPercent: battery.soc.toDouble(),
                            currentAmps: battery.current.abs(),
                            powerWatts: battery.power.abs(),
                            packCapacityAh: 30.0, // TODO: replace with your battery's actual Ah capacity
                          ),

                          // Extra padding for the bottom navigation bar
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
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
    // Default fallback color if none is provided
    final effectiveIconColor = iconColor ?? Colors.black54;
    final theme = Theme.of(context).extension<AppColors>()!;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // ==========================================
            // BOTTOM RIGHT DECORATIVE IMAGE
            // ==========================================
            if (cornerImageAsset != null)
              Positioned(
                right: -15,
                bottom: -15,
                child: Opacity(
                  // Slightly reduce opacity if it's a colored image so it acts like a watermark
                  opacity: 1,
                  child: Image.asset(
                    cornerImageAsset!,
                    width: 90,
                    height: 90,
                    fit: BoxFit.contain,
                    color: imageColor, // If null, renders original colored PNG!
                  ),
                ),
              ),

            // ==========================================
            // ACTUAL DATA (TEXT & ICON)
            // ==========================================
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: TextStyle(
                            color: theme.primaryText.withValues(alpha: 0.54),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          maxLines: 1,
                          style: TextStyle(
                            color: theme.primaryText,
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

class _ChargingInfoCard extends StatefulWidget {
  const _ChargingInfoCard({
    required this.isCharging,
    required this.socPercent,
    required this.currentAmps,
    required this.powerWatts,
    required this.packCapacityAh,
  });

  final bool isCharging;
  final double socPercent;
  final double currentAmps;
  final double powerWatts;
  final double packCapacityAh;

  @override
  State<_ChargingInfoCard> createState() => _ChargingInfoCardState();
}

class _ChargingInfoCardState extends State<_ChargingInfoCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    if (widget.isCharging) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ChargingInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isCharging && !_animationController.isAnimating) {
      _animationController.repeat();
    } else if (!widget.isCharging && _animationController.isAnimating) {
      _animationController.stop();
      _animationController.value = 0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getTimeToFull() {
    if (!widget.isCharging ||
        widget.currentAmps <= 0 ||
        widget.packCapacityAh <= 0) {
      return '--';
    }

    final remainingAh =
        widget.packCapacityAh * (100 - widget.socPercent).clamp(0, 100) / 100;

    // Adds 15% to account for charging losses and slower charging near full.
    final hours = (remainingAh / widget.currentAmps) * 1.15;
    final totalMinutes = (hours * 60).ceil();
    final hourPart = totalMinutes ~/ 60;
    final minutePart = totalMinutes % 60;

    if (hourPart == 0) return '$minutePart min';
    if (minutePart == 0) return '$hourPart hr';
    return '$hourPart hr $minutePart min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AppColors>()!;
    final colors = Theme.of(context).colorScheme;
    final accent = widget.isCharging ? colors.primary : colors.secondary;
    final progress = (widget.socPercent / 100).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final scale = widget.isCharging
                      ? 1 + (math.sin(_animationController.value * math.pi * 2) * 0.08)
                      : 1.0;

                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        widget.isCharging
                            ? Icons.battery_charging_full
                            : Icons.battery_std,
                        color: accent,
                        size: 26,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isCharging ? 'CHARGING' : 'NOT CHARGING',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isCharging
                          ? 'Estimated time to full'
                          : 'Connect the charger to see charging details',
                      style: TextStyle(
                        color: theme.primaryText.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isCharging)
                Text(
                  _getTimeToFull(),
                  style: TextStyle(
                    color: theme.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: accent.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _ChargingValue(
                label: 'BATTERY',
                value: '${widget.socPercent.toStringAsFixed(0)}%',
                color: theme.primaryText,
              ),
              const Spacer(),
              _ChargingValue(
                label: 'CHARGE POWER',
                value: widget.isCharging
                    ? '${widget.powerWatts.toStringAsFixed(0)} W'
                    : '-- W',
                color: theme.primaryText,
              ),
              const Spacer(),
              _ChargingValue(
                label: 'CURRENT',
                value: widget.isCharging
                    ? '${widget.currentAmps.toStringAsFixed(1)} A'
                    : '-- A',
                color: theme.primaryText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChargingValue extends StatelessWidget {
  const _ChargingValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AppColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.primaryText.withValues(alpha: 0.55),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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