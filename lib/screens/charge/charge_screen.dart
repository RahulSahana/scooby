import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/battery_provider.dart';

class ChargeScreen extends StatelessWidget {
  const ChargeScreen({super.key});

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
                          '${(battery.range).toStringAsFixed(0)}',
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

                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: stateColor, // Dot matches state color
                          shape: BoxShape.circle,
                        ),
                      ),

                      Column(
                        children: [
                          Text(
                            battery.soc < 80
                                ? TimeOfDay.fromDateTime(
                              DateTime.now().add(Duration(minutes: ((80 - battery.soc) * 3).toInt())),
                            ).format(context)
                                : TimeOfDay.fromDateTime(
                              DateTime.now().add(Duration(minutes: ((100 - battery.soc) * 3).toInt())),
                            ).format(context),
                            style: const TextStyle(
                              color: Color(0xFF4A4A4A),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            battery.soc < 80 ? '80% charge' : '100% charge',
                            style: const TextStyle(
                              color: Color(0xFF9B9B9B),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ===================================================
                // SCOOTER FILL ANIMATION (Fixed height for scrolling)
                // ===================================================
                SizedBox(
                  height: 380, // Fixed height so the page knows how to scroll below it
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // 1. Faded Outline
                      Opacity(
                        opacity: 0.99,
                        child: Image.asset(
                          'lib/assets/charge_ev.png',
                          fit: BoxFit.contain,
                        ),
                      ),

                      // 2. Dynamic Color Fill Layer
                      ClipRect(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          heightFactor: fillPercentage,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              stateColor, // Fill color changes based on state!
                              BlendMode.srcIn,
                            ),
                            child: Image.asset(
                              'lib/assets/charge_ev.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      // 3. Sharp Top Outline
                      ClipRect(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          heightFactor: fillPercentage,
                          child: Image.asset(
                            'lib/assets/charge_ev_trans.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ===================================================
                // INFO CARDS (Scrollable area)
                // ===================================================
                Padding(
                  padding: const EdgeInsets.all(24.0),
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

                      // Data Row 1
                      Row(
                        children: [
                          Expanded(
                            child: _LightInfoCard(
                              title: powerLabel,
                              value: '${battery.power.abs().toStringAsFixed(0)} W',
                              icon: Icons.flash_on,
                              iconColor: stateColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _LightInfoCard(
                              title: 'Current',
                              value: '${battery.current.abs().toStringAsFixed(1)} A',
                              icon: Icons.electric_meter,
                              iconColor: const Color(0xFF4A4A4A),
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
                              // Dynamically calling SOH and formatting it to remove decimals
                              value: '${battery.soh.toStringAsFixed(0)}%',
                              icon: Icons.health_and_safety,
                              iconColor: const Color(0xFF00C853),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _LightInfoCard(
                              title: 'Charge Cycles',
                              value: '${battery.cycleCount}',
                              icon: Icons.autorenew,
                              iconColor: const Color(0xFF00BFFF),
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
// LIGHT THEME INFO CARD
// =======================================================
class _LightInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _LightInfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.04), // Very faint border
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02), // Very soft shadow
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF4A4A4A),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF9B9B9B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}