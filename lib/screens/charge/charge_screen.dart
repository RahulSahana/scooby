import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wave/wave.dart';
import 'package:wave/config.dart';

import '../../providers/battery_provider.dart';

class ChargeScreen extends StatelessWidget {
  const ChargeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final battery = context.watch<BatteryProvider>().batteryData;
    final bool isCharging = battery.current > 0;

    // FORCE DARK THEME FOR CHARGE SCREEN
    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1020),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1020),
        body: SafeArea(

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(20),

          child: Column(

            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [

              // ===================================================
              // HEADER
              // ===================================================

              Row(

                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,

                children: [

                  Column(

                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: const [

                      Text(
                        'Charging',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 6),

                      Text(
                        'Battery charging efficiently ⚡',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  if (isCharging)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'ETA',
                            style: TextStyle(
                              color: Color(0xFFB794F4),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            TimeOfDay.fromDateTime(
                              DateTime.now().add(
                                Duration(minutes: ((100 - battery.soc) * 3).toInt()),
                              ),
                            ).format(context).toLowerCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 40),

              // ===================================================
              // CHARGING RING
              // ===================================================

              Center(

                child: Stack(

                  alignment: Alignment.center,

                  children: [

                    SizedBox(

                      width: 260,
                      height: 260,

                      child: CircularProgressIndicator(

                        value: battery.soc / 100,

                        strokeWidth: 16,

                        backgroundColor:
                        Colors.white10,

                        valueColor:
                        const AlwaysStoppedAnimation(
                          Color(0xFF8B5CF6),
                        ),
                      ),
                    ),

                    Column(

                      children: [

                        Text(
                          '${battery.soc}%',

                          style: const TextStyle(

                            color: Colors.white,

                            fontSize: 58,

                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(

                          isCharging
                              ? 'Charging'
                              : 'Idle',

                          style: const TextStyle(

                            color: Color(0xFFB794F4),

                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ===================================================
              // LIVE STATS
              // ===================================================

              Row(

                mainAxisAlignment:
                MainAxisAlignment.spaceAround,

                children: [

                  _TopStat(

                    title: 'Voltage',

                    value:
                    '${battery.voltage.toStringAsFixed(1)}V',
                  ),

                  _TopStat(

                    title: 'Current',

                    value:
                    '${battery.current.toStringAsFixed(1)}A',
                  ),

                  _TopStat(

                    title: 'Power',

                    value:
                    '${battery.power.toStringAsFixed(0)}W',
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // ===================================================
              // ETA CARD
              // ===================================================

              Container(

                padding:
                const EdgeInsets.all(20),

                decoration: BoxDecoration(

                  gradient: const LinearGradient(

                    begin: Alignment.topLeft,

                    end: Alignment.bottomRight,

                    colors: [

                      Color(0xFF161B33),

                      Color(0xFF1D2547),
                    ],
                  ),

                  borderRadius:
                  BorderRadius.circular(26),

                  border: Border.all(
                    color: Colors.white12,
                  ),
                ),

                child: Column(

                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    Row(

                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,

                      children: const [

                        Text(

                          'Estimated Full Charge',

                          style: TextStyle(

                            color: Colors.white70,

                            fontSize: 14,
                          ),
                        ),

                        Icon(

                          Icons.bolt,

                          color: Color(0xFF8B5CF6),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Text(

                      isCharging
                          ? (() {
                              final totalMinutes = ((100 - battery.soc) * 3).toInt();
                              final hours = totalMinutes ~/ 60;
                              final minutes = totalMinutes % 60;
                              if (hours > 0) {
                                return '$hours hrs $minutes min remaining';
                              } else {
                                return '$minutes min remaining';
                              }
                            })()
                          : 'Not Charging',

                      style: const TextStyle(

                        color: Colors.white,

                        fontSize: 30,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 22),

                    SizedBox(

                      height: 24,

                      child: ClipRRect(

                        borderRadius:
                        BorderRadius.circular(20),

                        child: Stack(

                          children: [

                            // BACKGROUND

                            Container(
                              color: Colors.white10,
                            ),

                            // WAVE

                            FractionallySizedBox(

                              widthFactor:
                              battery.soc / 100,

                              child: WaveWidget(

                                config: CustomConfig(

                                  gradients: [

                                    [
                                      const Color(0xFF7C3AED),
                                      const Color(0xFFA855F7),
                                    ],

                                    [
                                      const Color(0xFF8B5CF6),
                                      const Color(0xFFC084FC),
                                    ],
                                  ],

                                  durations: [
                                    3500,
                                    19440,
                                  ],

                                  heightPercentages: [
                                    0.20,
                                    0.23,
                                  ],

                                  blur: const MaskFilter.blur(
                                    BlurStyle.solid,
                                    2,
                                  ),
                                ),

                                waveAmplitude: 4,

                                size: const Size(
                                  double.infinity,
                                  double.infinity,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ===================================================
              // POWER + TEMP
              // ===================================================

              Row(

                children: [

                  Expanded(

                    child: _InfoCard(

                      title: 'Charging Power',

                      value:
                      '${battery.power.toStringAsFixed(0)}W',

                      icon: Icons.bolt,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(

                    child: _InfoCard(

                      title: 'Battery Temp',

                      value:
                      '${battery.temperature.toStringAsFixed(1)}°C',

                      icon: Icons.thermostat,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ===================================================
              // SESSION CARD
              // ===================================================

              _GlassCard(

                child: Column(

                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    const Text(

                      'Charging Session',

                      style: TextStyle(

                        color: Colors.white,

                        fontSize: 22,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    _SessionRow(
                      title: 'Started at',
                      value: '8:42 PM',
                    ),

                    const SizedBox(height: 14),

                    _SessionRow(
                      title: 'Energy Added',
                      value: '2.8 kWh',
                    ),

                    const SizedBox(height: 14),

                    _SessionRow(
                      title: 'Added Range',
                      value:
                      '+${(battery.soc * 0.75).toStringAsFixed(0)} km',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ===================================================
              // LAST CHARGE
              // ===================================================

              _GlassCard(

                child: Column(

                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: const [

                    Text(

                      'Last Full Charge',

                      style: TextStyle(

                        color: Colors.white,

                        fontSize: 22,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 18),

                    Text(

                      'Yesterday • 11:18 PM',

                      style: TextStyle(

                        color: Colors.white70,

                        fontSize: 16,
                      ),
                    ),

                    SizedBox(height: 16),

                    Text(

                      '63% → 100%   •   2h 11m',

                      style: TextStyle(

                        color: Color(0xFFB794F4),

                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ===================================================
              // BATTERY HEALTH
              // ===================================================

              _GlassCard(

                child: Column(

                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    const Text(

                      'Battery Health',

                      style: TextStyle(

                        color: Colors.white,

                        fontSize: 22,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(

                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,

                      children: [

                        _HealthItem(
                          title: 'SOH',
                          value: '96%',
                        ),

                        _HealthItem(
                          title: 'Cycles',
                          value:
                          '${battery.cycleCount}',
                        ),

                        _HealthItem(
                          title: 'Status',
                          value: 'Good',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ===================================================
              // CELL VOLTAGES
              // ===================================================

              _GlassCard(

                child: Column(

                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    const Text(

                      'Cell Voltages',

                      style: TextStyle(

                        color: Colors.white,

                        fontSize: 22,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Wrap(

                      spacing: 10,

                      runSpacing: 10,

                      children: battery.cellVoltages
                          .asMap()
                          .entries
                          .map(

                            (entry) {

                          final index =
                              entry.key + 1;

                          final voltage =
                              entry.value;

                          return Container(

                            padding:
                            const EdgeInsets.symmetric(

                              horizontal: 14,

                              vertical: 10,
                            ),

                            decoration: BoxDecoration(

                              color: Colors.white10,

                              borderRadius:
                              BorderRadius.circular(14),
                            ),

                            child: Text(

                              'C$index ${voltage.toStringAsFixed(3)}V',

                              style: const TextStyle(

                                color: Colors.white,

                                fontSize: 14,
                              ),
                            ),
                          );
                        },
                      ).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),

      ));
  }
}

// =======================================================
// TOP STAT
// =======================================================

class _TopStat extends StatelessWidget {

  final String title;

  final String value;

  const _TopStat({

    required this.title,

    required this.value,
  });

  @override
  Widget build(BuildContext context) {

    return Column(

      children: [

        Text(

          value,

          style: const TextStyle(

            color: Colors.white,

            fontSize: 28,

            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        Text(

          title,

          style: const TextStyle(

            color: Colors.white54,

            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// =======================================================
// INFO CARD
// =======================================================

class _InfoCard extends StatelessWidget {

  final String title;

  final String value;

  final IconData icon;

  const _InfoCard({

    required this.title,

    required this.value,

    required this.icon,
  });

  @override
  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(

        gradient: const LinearGradient(

          colors: [

            Color(0xFF151A32),

            Color(0xFF1D2545),
          ],
        ),

        borderRadius:
        BorderRadius.circular(24),

        border: Border.all(
          color: Colors.white10,
        ),
      ),

      child: Column(

        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          Icon(
            icon,
            color: const Color(0xFFB794F4),
          ),

          const SizedBox(height: 18),

          Text(

            title,

            style: const TextStyle(

              color: Colors.white70,

              fontSize: 14,
            ),
          ),

          const SizedBox(height: 10),

          Text(

            value,

            style: const TextStyle(

              color: Colors.white,

              fontSize: 28,

              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// GLASS CARD
// =======================================================

class _GlassCard extends StatelessWidget {

  final Widget child;

  const _GlassCard({

    required this.child,
  });

  @override
  Widget build(BuildContext context) {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(

        gradient: const LinearGradient(

          colors: [

            Color(0xFF151A32),

            Color(0xFF1D2545),
          ],
        ),

        borderRadius:
        BorderRadius.circular(28),

        border: Border.all(
          color: Colors.white10,
        ),
      ),

      child: child,
    );
  }
}

// =======================================================
// SESSION ROW
// =======================================================

class _SessionRow extends StatelessWidget {

  final String title;

  final String value;

  const _SessionRow({

    required this.title,

    required this.value,
  });

  @override
  Widget build(BuildContext context) {

    return Row(

      mainAxisAlignment:
      MainAxisAlignment.spaceBetween,

      children: [

        Text(

          title,

          style: const TextStyle(

            color: Colors.white70,

            fontSize: 15,
          ),
        ),

        Text(

          value,

          style: const TextStyle(

            color: Color(0xFFB794F4),

            fontSize: 16,

            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// =======================================================
// HEALTH ITEM
// =======================================================

class _HealthItem extends StatelessWidget {

  final String title;

  final String value;

  const _HealthItem({

    required this.title,

    required this.value,
  });

  @override
  Widget build(BuildContext context) {

    return Column(

      children: [

        Text(

          title,

          style: const TextStyle(

            color: Colors.white54,

            fontSize: 14,
          ),
        ),

        const SizedBox(height: 8),

        Text(

          value,

          style: const TextStyle(

            color: Color(0xFFB794F4),

            fontSize: 24,

            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}