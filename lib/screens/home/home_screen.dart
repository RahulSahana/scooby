import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/battery_provider.dart';
import '../../widgets/battery_arc.dart';
import '../../widgets/info_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final batteryProvider = Provider.of<BatteryProvider>(context);
    final batteryData = batteryProvider.batteryData;
    final screenHeight = MediaQuery.sizeOf(context).height;

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
                      child: Image.asset(
                        // If current is pulling more than 0.6A (moving), show the GIF.
                        // Otherwise, show your static parked scooter image.
                        batteryData.current <= -0.6
                            ? 'lib/assets/moving_scooty.gif'
                            : 'lib/assets/scooty.png',
                        fit: BoxFit.contain,
                        // Optional: Give it a fixed height so the UI doesn't jump
                        // if the GIF and PNG have different dimensions
                        height: 250,
                      ),
                    ),

                    // ===================================================
                    // BATTERY ARC
                    // ===================================================
                    BatteryArc(
                      percentage: batteryData.soc / 100,
                      range: batteryData.range.toInt(),
                    ),

                    const SizedBox(height: 20),

                    // ===================================================
                    // CONNECTION STATUS
                    // ===================================================
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            batteryProvider.isConnected
                                ? Icons.bluetooth_connected
                                : Icons.bluetooth_disabled,
                            color: batteryProvider.isConnected ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              batteryProvider.isConnected ? "BMS Connected" : "BMS Disconnected",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: batteryProvider.isConnected ? Colors.green : Colors.red,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===================================================
                    // MOTOR POWER (DISCHARGE) CONTROL CARD
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
                                  color: batteryData.isDischarging
                                      ? Colors.blue.withValues(alpha: 0.2)
                                      : Colors.redAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.electric_scooter,
                                  color: batteryData.isDischarging ? Colors.blue : Colors.redAccent,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Motor Power',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    batteryData.current <= -0.6
                                        ? 'Locked while driving'
                                        : (batteryData.isDischarging ? 'Ready to Ride' : 'Immobilized (Anti-Theft)'),
                                    style: TextStyle(
                                      color: batteryData.current <= -0.6
                                          ? Colors.orange
                                          : (batteryData.isDischarging ? Colors.blue : Colors.redAccent),
                                      fontSize: 12,
                                      fontWeight: batteryData.current <= -0.6 ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: batteryData.isDischarging,
                            activeThumbColor: Colors.blue,
                            activeTrackColor: Colors.blue.withValues(alpha: 0.5),
                            inactiveThumbColor: Colors.redAccent,
                            inactiveTrackColor: Colors.white10,
                            // Disable the switch if the scooter is currently driving
                            onChanged: batteryData.current <= -0.6
                                ? null
                                : (bool newValue) {
                              context.read<BatteryProvider>().toggleDischarging(newValue);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===================================================
                    // INFO CARDS
                    // ===================================================
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 130,
                      ),
                      children: [
                        InfoCard(
                          title: 'Voltage',
                          value: batteryData.voltage.toStringAsFixed(1),
                          unit: 'V',
                          icon: Icons.battery_charging_full,
                        ),
                        InfoCard(
                          title: 'Current',
                          value: batteryData.current.toStringAsFixed(1),
                          unit: 'A',
                          icon: Icons.electric_bolt,
                        ),
                        InfoCard(
                          title: 'Temperature',
                          value: batteryData.temperature.toStringAsFixed(1),
                          unit: '°C',
                          icon: Icons.thermostat,
                        ),
                        InfoCard(
                          title: 'Battery',
                          value: batteryData.soc.toString(),
                          unit: '%',
                          icon: Icons.battery_std,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ===================================================
                    // CELL VOLTAGES
                    // ===================================================
                    if (batteryData.cellVoltages.isNotEmpty)
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
                                batteryData.cellVoltages.length,
                                (index) {
                                  final cellVoltage = batteryData.cellVoltages[index];
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
