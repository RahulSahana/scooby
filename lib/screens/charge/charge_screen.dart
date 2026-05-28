import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/battery_provider.dart';
import 'dart:math' as math;

class ChargeScreen extends StatelessWidget {
  const ChargeScreen({super.key});

  Color _getTemperatureColor(double temp) {
    if (temp >= 45.0) return Colors.red;         // Overheating
    if (temp >= 35.0) return Colors.green;      // Getting warm
    if (temp <= 15.0) return Colors.blue;        // Cold
    return Colors.green;                         // Optimal
  }

  Color _getSohColor(num soh) {
    if (soh >= 90) return Colors.green;           // Excellent / Optimal
    if (soh >= 80) return Colors.orange;          // Fair / Degrading
    return Colors.red;                            // Poor / Replace soon
  }

  @override
  Widget build(BuildContext context) {
    final battery = context.watch<BatteryProvider>().batteryData;
    final double fillPercentage = battery.soc / 100.0;

    // ===================================================
    // STATE LOGIC (Determined by Current)
    // ===================================================
    String stateText;
    Color stateColor;
    String powerLabel;

    if (battery.current > 0) {
      stateText = 'CHARGING';
      stateColor = const Color(0xFF00C853); // Ather Green
      powerLabel = 'Charging Power';
    } else if (battery.current < 0) {
      stateText = 'WORKING';
      stateColor = const Color(0xFFFF9800); // Orange
      powerLabel = 'Power Draw';
    } else {
      stateText = 'IDLE';
      stateColor = const Color(0xFF00BFFF); // Sky Blue
      powerLabel = 'Power';
    }

    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF9F9F9),
        fontFamily: 'Roboto',
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        body: SafeArea(
          // Wrap everything in a scroll view to allow cards below
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ===================================================
                // HEADER
                // ===================================================


                const Divider(color: Color(0xFFE0E0E0), height: 1),

                const SizedBox(height: 30),

                // ===================================================
                // DYNAMIC STATS (Color and Text changes based on state)
                // ===================================================
                Column(
                  children: [
                    Text(
                      stateText, // Changes to CHARGING, WORKING, or IDLE
                      style: TextStyle(
                        color: stateColor, // Changes dynamically
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          battery.range.toStringAsFixed(0),
                          style: const TextStyle(
                            color: Color(0xFF4A4A4A),
                            fontSize: 64,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'km',
                          style: TextStyle(
                            color: Color(0xFF4A4A4A),
                            fontSize: 32,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bolt,
                          color: stateColor, // Bolt matches state color
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.battery_4_bar_outlined,
                          color: Color(0xFF4A4A4A),
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${battery.soc}%',
                          style: const TextStyle(
                            color: Color(0xFF4A4A4A),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // ===================================================
                // TIME / ETA ROW
                // ===================================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            TimeOfDay.now().format(context),
                            style: const TextStyle(
                              color: Color(0xFF4A4A4A),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(battery.range).toStringAsFixed(0)} km range',
                            style: const TextStyle(
                              color: Color(0xFF9B9B9B),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),

                      // ==========================================
                      // CONDITIONAL RIGHT SIDE: DIVIDER & ETA
                      // ==========================================
                      if (battery.isCharging) ...[

                        // THE VERTICAL LINE DIVIDER
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Container(
                            width: 1, // 1 pixel wide line
                            height: 35, // Height of the divider
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),

                        // RIGHT SIDE: ETA
                        Column(
                          children: [
                            Text(
                              // Example ETA calculation: current time + remaining charge time
                              TimeOfDay.fromDateTime(
                                DateTime.now().add(
                                  Duration(minutes: ((100 - battery.soc) * 3).toInt()),
                                ),
                              ).format(context),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '100% charge',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ===================================================
                // SCOOTER FILL ANIMATION
                // ===================================================
                _WavyScooterFill(
                  fillPercentage: fillPercentage,
                  stateColor: stateColor,
                  isCharging: battery.isCharging, // Controls if the wave moves or freezes
                ),

                // ===================================================
                // INFO CARDS (Scrollable area)
                // ===================================================
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ===================================================
                      // CONTROLS CARD (WITH SAFETY INTERLOCK)
                      // ===================================================
                      _GlassCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: battery.isCharging
                                        ? Colors.green.withValues(alpha: 0.2)
                                        : Colors.white10,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.power,
                                    color: battery.isCharging ? Colors.green : Colors.white54,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Charge Input',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // DYNAMIC TEXT BASED ON RIDING STATE
                                    Text(
                                      battery.current <= -0.6 
                                          ? 'Locked while in motion' 
                                          : (battery.isCharging ? 'Active (Allowing Current)' : 'Disabled (Cutoff)'),
                                      style: TextStyle(
                                        color: battery.current <= -0.6 
                                            ? Colors.redAccent 
                                            : (battery.isCharging ? Colors.green : Colors.white54),
                                        fontSize: 12,
                                        fontWeight: battery.current <= -0.6 ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),

                                    // ADD THIS NEW HELPER TEXT
                                    if (!battery.isCharging)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          '* May require replugging the charger to resume',
                                          style: TextStyle(
                                            color: Colors.orangeAccent.withValues(alpha: 0.8),
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            // THE SWITCH LOCK LOGIC
                            Switch(
                              value: battery.isCharging, 
                              activeThumbColor: const Color(0xFF8B5CF6),
                              inactiveThumbColor: Colors.grey,
                              inactiveTrackColor: Colors.white10,
                              // If current is pulling more than 2 Amps, disable the switch by setting onChanged to null
                              onChanged: battery.current <= -0.6
                                  ? null 
                                  : (bool newValue) {
                                      context.read<BatteryProvider>().toggleCharging(newValue);
                                    },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

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

                      // Data Row 1
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
                              title: 'Health (SOH)',
                              value: '${battery.soh.toStringAsFixed(0)}%',
                              icon: Icons.health_and_safety,
                              // DYNAMIC COLORS APPLIED HERE
                              iconColor: _getSohColor(battery.soh),
                              imageColor: _getSohColor(battery.soh),
                              cornerImageAsset: 'lib/assets/charge_ev_trans.png',
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
                              title: 'Temperature',
                              value: '${battery.temperature}°C',
                              icon: Icons.thermostat_outlined,
                              // DYNAMIC COLORS APPLIED HERE
                              iconColor: _getTemperatureColor(battery.temperature),
                              imageColor: _getTemperatureColor(battery.temperature),
                              cornerImageAsset: 'lib/assets/temperature.png',
                            ),
                          ),
                        ],
                      ),

                      // Extra padding for the bottom navigation bar
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =======================================================
// ANIMATED WAVY SCOOTER FILL
// =======================================================
class _WavyScooterFill extends StatefulWidget {
  final double fillPercentage;
  final Color stateColor;
  final bool isCharging;

  const _WavyScooterFill({
    required this.fillPercentage,
    required this.stateColor,
    required this.isCharging,
  });

  @override
  State<_WavyScooterFill> createState() => _WavyScooterFillState();
}

class _WavyScooterFillState extends State<_WavyScooterFill> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Speed of the wave
    );

    // Only animate if it is actively charging on boot
    if (widget.isCharging) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _WavyScooterFill oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Smart logic: Start the wave when charging starts, freeze it when unplugged/locked!
    if (widget.isCharging && !oldWidget.isCharging) {
      _controller.repeat();
    } else if (!widget.isCharging && oldWidget.isCharging) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 380,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Faded Outline (Base Layer)
          Opacity(
            opacity: 0.99,
            child: Image.asset(
              'lib/assets/charge_ev.png',
              fit: BoxFit.contain,
            ),
          ),

          // 2. Dynamic WAVY Color Fill Layer
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return ClipPath(
                clipper: _WaveClipper(
                  fillPercentage: widget.fillPercentage,
                  animationValue: _controller.value, // Passes the moving ticker to the math
                ),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    widget.stateColor,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'lib/assets/charge_ev.png',
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),

          // 3. Sharp Top Outline (Always 100% visible)
          Image.asset(
            'lib/assets/charge_ev_trans.png',
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}

// =======================================================
// GLASS THEME CARD
// =======================================================
class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark card for glass effect on light bg
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

// =======================================================
// LIGHT THEME INFO CARD
// =======================================================
class _LightInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;      // Optional: Colors the small top-left icon
  final Color? imageColor;     // Optional: Tints the background image
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
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
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
// WAVE CLIPPER MATH
// =======================================================
class _WaveClipper extends CustomClipper<Path> {
  final double fillPercentage;
  final double animationValue;

  _WaveClipper({required this.fillPercentage, required this.animationValue});

  @override
  Path getClip(Size size) {
    final path = Path();
    if (fillPercentage <= 0.0) return path;

    // If it's 100% full, just return a full rectangle without waves
    if (fillPercentage >= 1.0) {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      return path;
    }

    final waveHeight = 6.0; // How tall the waves are (amplitude)
    final baseHeight = size.height * (1 - fillPercentage); // The fill level

    path.moveTo(0, size.height); // Start at bottom-left corner
    path.lineTo(0, baseHeight);  // Draw line straight up to the fill level

    // Draw the sine wave from left to right
    for (double x = 0; x <= size.width; x++) {
      // Calculates the wave pattern. The animationValue shifts it horizontally.
      final y = baseHeight +
          math.sin((x / size.width * 2 * math.pi) + (animationValue * 2 * math.pi)) * waveHeight;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height); // Draw down to bottom-right corner
    path.close(); // Connect back to bottom-left

    return path;
  }

  @override
  bool shouldReclip(_WaveClipper oldClipper) =>
      oldClipper.fillPercentage != fillPercentage ||
          oldClipper.animationValue != animationValue;
}