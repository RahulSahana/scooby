class BatteryData {

  // =========================================================
  // MAIN VALUES
  // =========================================================

  final double voltage;

  final double current;

  final int soc;

  final int soh; // <--- Added SOH

  final double power;

  final double temperature;

  final double range;

  final int cycleCount;

  final bool isCharging;

  final bool isConnected;

  final List<double> cellVoltages;

  // =========================================================
  // CONSTRUCTOR
  // =========================================================

  const BatteryData({

    required this.voltage,

    required this.current,

    required this.soc,

    required this.soh, // <--- Added SOH

    required this.power,

    required this.temperature,

    required this.range,

    required this.cycleCount,

    required this.isCharging,

    required this.isConnected,

    required this.cellVoltages,
  });

  // =========================================================
  // EMPTY DATA
  // =========================================================

  factory BatteryData.empty() {

    return const BatteryData(

      voltage: 0,

      current: 0,

      soc: 0,

      soh: 100, // <--- Defaulting empty SOH to 100%

      power: 0,

      temperature: 0,

      range: 0,

      cycleCount: 0,

      isCharging: false,

      isConnected: false,

      cellVoltages: [],
    );
  }

  // =========================================================
  // DEMO DATA
  // =========================================================

  factory BatteryData.demo() {

    return const BatteryData(

      voltage: 72.4,

      current: 12.8,

      soc: 84,

      soh: 96, // <--- Added demo SOH value

      power: 926,

      temperature: 31.5,

      range: 63,

      cycleCount: 214,

      isCharging: false,

      isConnected: true,

      cellVoltages: [

        3.701,
        3.698,
        3.702,
        3.699,
        3.700,
        3.703,
        3.701,
        3.700,

        3.699,
        3.701,
        3.700,
        3.702,
        3.701,
        3.700,
        3.699,
        3.701,
      ],
    );
  }

  // =========================================================
  // ESTIMATED RANGE
  // =========================================================

  double get estimatedRange {

    return soc * 0.75;
  }

  // =========================================================
  // COPY WITH
  // =========================================================

  BatteryData copyWith({

    double? voltage,

    double? current,

    int? soc,

    int? soh, // <--- Added SOH

    double? power,

    double? temperature,

    double? range,

    int? cycleCount,

    bool? isCharging,

    bool? isConnected,

    List<double>? cellVoltages,
  }) {

    return BatteryData(

      voltage:
      voltage ?? this.voltage,

      current:
      current ?? this.current,

      soc:
      soc ?? this.soc,

      soh:
      soh ?? this.soh, // <--- Added SOH

      power:
      power ?? this.power,

      temperature:
      temperature ?? this.temperature,

      range:
      range ??
          ((soc ?? this.soc) * 0.75),

      cycleCount:
      cycleCount ?? this.cycleCount,

      isCharging:
      isCharging ?? this.isCharging,

      isConnected:
      isConnected ?? this.isConnected,

      cellVoltages:
      cellVoltages ??
          this.cellVoltages,
    );
  }
}