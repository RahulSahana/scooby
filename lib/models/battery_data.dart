class BatteryData {
  final double voltage;
  final double current;
  final int soc;

  final double power;
  final double temperature;

  final double range;

  final int cycleCount;

  final bool isCharging;
  final bool isConnected;

  final List<double> cellVoltages;

  BatteryData({
    required this.voltage,
    required this.current,
    required this.soc,
    required this.power,
    required this.temperature,
    required this.range,
    required this.cycleCount,
    required this.isCharging,
    required this.isConnected,
    required this.cellVoltages,
  });

  /// Calculate average cell voltage
  double get averageCellVoltage {
    if (cellVoltages.isEmpty) return 0;
    return cellVoltages.reduce((a, b) => a + b) /
        cellVoltages.length;
  }

  /// Highest cell voltage
  double get maxCellVoltage {
    if (cellVoltages.isEmpty) return 0;
    return cellVoltages.reduce(
          (a, b) => a > b ? a : b,
    );
  }

  /// Lowest cell voltage
  double get minCellVoltage {
    if (cellVoltages.isEmpty) return 0;
    return cellVoltages.reduce(
          (a, b) => a < b ? a : b,
    );
  }

  /// Cell imbalance
  double get cellDifference {
    return maxCellVoltage - minCellVoltage;
  }

  /// Empty/default battery data
  factory BatteryData.empty() {
    return BatteryData(
      voltage: 0,
      current: 0,
      soc: 0,
      power: 0,
      temperature: 0,
      range: 0,
      cycleCount: 0,
      isCharging: false,
      isConnected: false,
      cellVoltages: [],
    );
  }

  /// Fake demo data for UI testing
  factory BatteryData.demo() {
    return BatteryData(
      voltage: 62.57,
      current: 12.4,
      soc: 34,
      power: 775.8,
      temperature: 36.5,
      range: 26,
      cycleCount: 14,
      isCharging: false,
      isConnected: true,
      cellVoltages: [
        3.292,
        3.293,
        3.294,
        3.292,
        3.293,
        3.294,
        3.292,
        3.293,
        3.294,
        3.292,
        3.293,
        3.294,
        3.292,
        3.293,
        3.294,
        3.292,
        3.293,
        3.294,
        3.292,
      ],
    );
  }

  /// Convert object to map
  Map<String, dynamic> toMap() {
    return {
      'voltage': voltage,
      'current': current,
      'soc': soc,
      'power': power,
      'temperature': temperature,
      'range': range,
      'cycleCount': cycleCount,
      'isCharging': isCharging,
      'isConnected': isConnected,
      'cellVoltages': cellVoltages,
    };
  }

  /// Create object from map
  factory BatteryData.fromMap(
      Map<String, dynamic> map,
      ) {
    return BatteryData(
      voltage: map['voltage'] ?? 0,
      current: map['current'] ?? 0,
      soc: map['soc'] ?? 0,
      power: map['power'] ?? 0,
      temperature: map['temperature'] ?? 0,
      range: map['range'] ?? 0,
      cycleCount: map['cycleCount'] ?? 0,
      isCharging: map['isCharging'] ?? false,
      isConnected: map['isConnected'] ?? false,
      cellVoltages:
      List<double>.from(
        map['cellVoltages'] ?? [],
      ),
    );
  }

  /// Copy with updated values
  BatteryData copyWith({
    double? voltage,
    double? current,
    int? soc,
    double? power,
    double? temperature,
    double? range,
    int? cycleCount,
    bool? isCharging,
    bool? isConnected,
    List<double>? cellVoltages,
  }) {
    return BatteryData(
      voltage: voltage ?? this.voltage,
      current: current ?? this.current,
      soc: soc ?? this.soc,
      power: power ?? this.power,
      temperature:
      temperature ?? this.temperature,
      range: range ?? this.range,
      cycleCount:
      cycleCount ?? this.cycleCount,
      isCharging:
      isCharging ?? this.isCharging,
      isConnected:
      isConnected ?? this.isConnected,
      cellVoltages:
      cellVoltages ?? this.cellVoltages,
    );
  }
}