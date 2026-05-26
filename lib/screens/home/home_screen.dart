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
                    // ===================================================
                    // SCOOTER IMAGE
                    // ===================================================
                    Image.asset(
                      'lib/assets/scooty.png',
                      height: 300,
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
                            color: Colors.black.withOpacity(0.05),
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
                          Text(
                            batteryProvider.isConnected ? "BMS Connected" : "BMS Disconnected",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: batteryProvider.isConnected ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===================================================
                    // INFO CARDS
                    // ===================================================
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
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
                              color: Colors.black.withOpacity(0.05),
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
                                      color: Colors.deepPurple.withOpacity(0.1),
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
