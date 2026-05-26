import 'package:flutter/foundation.dart';

import '../models/battery_data.dart';

class BatteryProvider extends ChangeNotifier {

  // =========================================================
  // BATTERY DATA
  // =========================================================

  BatteryData _batteryData =
  BatteryData.empty();

  BatteryData get batteryData =>
      _batteryData;

  // =========================================================
  // CONNECTION STATE
  // =========================================================

  bool _isConnected = false;

  bool get isConnected =>
      _isConnected;

  // =========================================================
  // LOADING STATE
  // =========================================================

  bool _isLoading = false;

  bool get isLoading =>
      _isLoading;

  // =========================================================
  // LAST UPDATE
  // =========================================================

  DateTime? _lastUpdated;

  DateTime? get lastUpdated =>
      _lastUpdated;

  // =========================================================
  // UPDATE CONNECTION STATE
  // =========================================================

  void setConnectionState(
      bool connected,
      ) {

    _isConnected = connected;

    notifyListeners();
  }

  // =========================================================
  // UPDATE LOADING STATE
  // =========================================================

  void setLoading(
      bool loading,
      ) {

    _isLoading = loading;

    notifyListeners();
  }

  // =========================================================
  // UPDATE BATTERY DATA
  // =========================================================

  void updateBatteryData(
      BatteryData data,
      ) {

    _batteryData = data;

    _lastUpdated = DateTime.now();

    notifyListeners();
  }

  // =========================================================
  // UPDATE INDIVIDUAL VALUES
  // =========================================================

  void updateVoltage(
      double voltage,
      ) {

    _batteryData =
        _batteryData.copyWith(
          voltage: voltage,
        );

    notifyListeners();
  }

  void updateCurrent(
      double current,
      ) {

    _batteryData =
        _batteryData.copyWith(
          current: current,
        );

    notifyListeners();
  }

  void updateSoc(
      int soc,
      ) {

    _batteryData =
        _batteryData.copyWith(
          soc: soc,
        );

    notifyListeners();
  }

  void updateTemperature(
      double temperature,
      ) {

    _batteryData =
        _batteryData.copyWith(
          temperature: temperature,
        );

    notifyListeners();
  }

  void updateCellVoltages(
      List<double> cells,
      ) {

    _batteryData =
        _batteryData.copyWith(
          cellVoltages: cells,
        );

    notifyListeners();
  }

  // =========================================================
  // UPDATE FULL TELEMETRY
  // =========================================================

  void updateTelemetry({

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

    _batteryData =
        _batteryData.copyWith(

          voltage:
          voltage ??
              _batteryData.voltage,

          current:
          current ??
              _batteryData.current,

          soc:
          soc ??
              _batteryData.soc,

          power:
          power ??
              _batteryData.power,

          temperature:
          temperature ??
              _batteryData.temperature,

          range:
          range ??
              _batteryData.range,

          cycleCount:
          cycleCount ??
              _batteryData.cycleCount,

          isCharging:
          isCharging ??
              _batteryData.isCharging,

          isConnected:
          isConnected ??
              _batteryData.isConnected,

          cellVoltages:
          cellVoltages ??
              _batteryData.cellVoltages,
        );

    _lastUpdated = DateTime.now();

    notifyListeners();
  }

  // =========================================================
  // RESET DATA
  // =========================================================

  void reset() {

    _batteryData =
        BatteryData.empty();

    _isConnected = false;

    _lastUpdated = null;

    notifyListeners();
  }
}