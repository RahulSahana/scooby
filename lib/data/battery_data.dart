class BatteryData {
  final double voltage;
  final double current;
  final int soc;
  final int soh;
  final double power;
  final double temperature;
  final double range;
  final double remainingCapacityAh;
  final int cycleCount;
  final bool isCharging;
  final bool isDischarging;
  final bool isConnected;
  final List<double> cellVoltages;
  final String vendorId;
  final String hardwareVersion;
  final String softwareVersion;
  final int powerOnTimes;
  final String uptime;
  final String serialNumber;
  final String firstOnDate;
  final String totalTime;

  // =========================================================
  // CONSTRUCTOR
  // =========================================================

  const BatteryData({
    required this.voltage,
    required this.current,
    required this.soc,
    required this.soh,
    required this.power,
    required this.temperature,
    required this.range,
    required this.cycleCount,
    required this.isCharging,
    required this.isDischarging,
    required this.isConnected,
    required this.cellVoltages,
    this.remainingCapacityAh = 0.0,
    this.vendorId = 'Unknown',
    this.hardwareVersion = 'Unknown',
    this.softwareVersion = 'Unknown',
    this.powerOnTimes = 0,
    this.uptime = '0D 0H 0M',
    this.serialNumber = 'Unknown',
    this.firstOnDate = 'Unknown',
    this.totalTime = '0D 0H 0M',
  });

  // =========================================================
  // EMPTY DATA
  // =========================================================

  factory BatteryData.empty() {
    return const BatteryData(
      voltage: 0,
      current: 0,
      soc: 0,
      soh: 100,
      power: 0,
      temperature: 0,
      range: 0,
      remainingCapacityAh: 0.0,
      cycleCount: 0,
      isCharging: false,
      isDischarging: false,
      isConnected: false,
      cellVoltages: [],
      vendorId: 'Unknown',
      hardwareVersion: 'Unknown',
      softwareVersion: 'Unknown',
      powerOnTimes: 0,
      uptime: '0D 0H 0M',
      serialNumber: 'Unknown',
      firstOnDate: 'Unknown',
      totalTime: '0D 0H 0M',
    );
  }

  // =========================================================
  //   // ESTIMATED RANGE
  //   // =========================================================

  double getEfficiency() {
    final now = DateTime.now();
    final hour = now.hour;

    // Define "Daylight" hours (e.g., 6 AM to 6 PM)
    // You can adjust these based on your local sunset/sunrise times
    if (hour >= 6 && hour < 18) {
      return 0.75; // Daytime Efficiency
    } else {
      return 0.6; // Nighttime Efficiency (Headlights likely ON)
    }
  }


  // =========================================================
  // COPY WITH
  // =========================================================

  BatteryData copyWith({
    double? voltage,
    double? current,
    int? soc,
    int? soh,
    double? power,
    double? temperature,
    double? range,
    double? remainingCapacityAh,
    int? cycleCount,
    bool? isCharging,
    bool? isDischarging,
    bool? isConnected,
    List<double>? cellVoltages,
    String? vendorId,
    String? hardwareVersion,
    String? softwareVersion,
    int? powerOnTimes,
    String? uptime,
    String? serialNumber,
    String? firstOnDate,
    String? totalTime,
  }) {
    return BatteryData(
      voltage: voltage ?? this.voltage,
      current: current ?? this.current,
      soc: soc ?? this.soc,
      soh: soh ?? this.soh,
      power: power ?? this.power,
      temperature: temperature ?? this.temperature,
      range: range ?? this.range,
      remainingCapacityAh: remainingCapacityAh ?? this.remainingCapacityAh,
      cycleCount: cycleCount ?? this.cycleCount,
      isCharging: isCharging ?? this.isCharging,
      isDischarging: isDischarging ?? this.isDischarging,
      isConnected: isConnected ?? this.isConnected,
      cellVoltages: cellVoltages ?? this.cellVoltages,
      vendorId: vendorId ?? this.vendorId,
      hardwareVersion: hardwareVersion ?? this.hardwareVersion,
      softwareVersion: softwareVersion ?? this.softwareVersion,
      powerOnTimes: powerOnTimes ?? this.powerOnTimes,
      uptime: uptime ?? this.uptime,
      serialNumber: serialNumber ?? this.serialNumber,
      firstOnDate: firstOnDate ?? this.firstOnDate,
      totalTime: totalTime ?? this.totalTime,
    );
  }
}
