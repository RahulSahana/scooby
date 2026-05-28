import 'package:flutter/foundation.dart';
import '../models/battery_data.dart';
import '../services/ble_service.dart';

// =========================================================
// BATTERY PROVIDER
// Central state for all battery telemetry.
// Works with both BLE (direct) and HTTP (via backend).
// =========================================================

class BatteryProvider extends ChangeNotifier {

  BatteryData _batteryData = BatteryData.empty();
  BatteryData get batteryData => _batteryData;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Which mode are we in?
  ConnectionMode _mode = ConnectionMode.none;
  ConnectionMode get mode => _mode;

  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  // =========================================================
  // BLE SERVICE
  // =========================================================
  late final BleService _bleService;
  BleService get bleService => _bleService;

  BatteryProvider() {
    _bleService = BleService(batteryProvider: this);
  }

  // Convenience getters directly on provider
  double get voltage => _batteryData.voltage;
  double get current => _batteryData.current;
  int get soc => _batteryData.soc;
  int get soh => _batteryData.soh;
  double get temperature => _batteryData.temperature;
  double get power => _batteryData.power;
  int get cycleCount => _batteryData.cycleCount;
  bool get isCharging => _batteryData.isCharging;
  List<double> get cellVoltages => _batteryData.cellVoltages;

  // =========================================================
  // SET MODE
  // =========================================================
  void setMode(ConnectionMode mode) {
    _mode = mode;
    notifyListeners();
  }

  // =========================================================
  // SET CONNECTION STATE
  // =========================================================
  void setConnectionState(bool connected) {
    _isConnected = connected;
    if (!connected) {
      // Don't wipe data on disconnect — keep last known values
      _batteryData = _batteryData.copyWith(isConnected: false);
    }
    notifyListeners();
  }

  // =========================================================
  // SET LOADING
  // =========================================================
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // =========================================================
  // UPDATE FULL TELEMETRY
  // =========================================================
  void updateTelemetry({
    double? voltage,
    double? current,
    int? soc,
    int? soh,
    double? power,
    double? temperature,
    double? range,
    int? cycleCount,
    bool? isCharging,
    bool? isConnected,
    List<double>? cellVoltages,
  }) {
    _isConnected = isConnected ?? _isConnected;

    _batteryData = _batteryData.copyWith(
      voltage: voltage,
      current: current,
      soc: soc,
      soh: soh,
      power: power,
      temperature: temperature,
      range: range,
      cycleCount: cycleCount,
      isCharging: isCharging,
      isConnected: isConnected,
      cellVoltages: cellVoltages,
    );

    _lastUpdated = DateTime.now();
    notifyListeners();
  }

  // =========================================================
  // UPDATE BATTERY DATA (full replace)
  // =========================================================
  void updateBatteryData(BatteryData data) {
    _batteryData = data;
    _isConnected = data.isConnected;
    _lastUpdated = DateTime.now();
    notifyListeners();
  }

  // =========================================================
  // RESET
  // =========================================================
  void reset() {
    _batteryData = BatteryData.empty();
    _isConnected = false;
    _lastUpdated = null;
    _mode = ConnectionMode.none;
    notifyListeners();
  }
}

enum ConnectionMode {
  none,
  ble,      // Direct BLE to BMS
  http,     // Via Python backend HTTP API
}