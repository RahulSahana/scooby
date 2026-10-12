import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/battery_data.dart';
import '../services/ble/ble_service.dart';
import '../services/range_estimator.dart';
import '../services/notification_service.dart';

class BatteryProvider extends ChangeNotifier {
  late BleService bleService;
  BatteryData _batteryData = BatteryData.empty();
  String _bmsPassword = "1234";

  bool _chargingAlertShown = false;
  bool _temperatureAlertShown = false;
  bool _rangeAlertShown = false;

  Future<void> _alertCheckQueue = Future<void>.value();

  final RangeEstimator _rangeEstimator = RangeEstimator();

  Future<void> initializeRangeEstimator() async {
    await _rangeEstimator.loadSavedEstimate();
  }

  // Connection UI States
  bool _isConnected = false;
  bool _isConnecting = false;

  // The Garage Memory
  List<Map<String, String>> _savedGarage = [];
  String? _primaryScooterId;



  BatteryProvider() {
    bleService = BleService(batteryProvider: this);
    loadGarage();
    initializeRangeEstimator();
  }

  BatteryData get batteryData => _batteryData;
  String get bmsPassword => _bmsPassword;
  List<Map<String, String>> get savedGarage => _savedGarage;
  String? get primaryScooterId => _primaryScooterId;
  RangeEstimator get rangeEstimator => _rangeEstimator;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  // Called by BleService to push hardware data to UI
  void updateTelemetry({
    double? voltage,
    double? current,
    int? soc,
    double? remainingCapacityAh,
    double? temperature,
    List<double>? cellVoltages,
    int? cycleCount,
    bool? isCharging,
    bool? isDischarging,
    double? power,
    bool? isConnected,
    String? vendorId,
    String? hardwareVersion,
    String? softwareVersion,
    int? powerOnTimes,
    String? uptime,
    String? serialNumber,
    String? firstOnDate,
    String? totalTime,
  }) {
    final previousBatteryData = _batteryData;
    final effectiveVoltage = voltage ?? _batteryData.voltage;
    final effectiveCurrent = current ?? _batteryData.current;
    final effectiveSoc = soc ?? _batteryData.soc;
    final effectiveRemainingCap = remainingCapacityAh ?? _batteryData.remainingCapacityAh;

    if (voltage != null && current != null) {
      _rangeEstimator.addTelemetry(
        voltage: effectiveVoltage,
        current: effectiveCurrent,
      );
    }

    final calculatedRange = _rangeEstimator.estimateRangeKm(
      socPercent: effectiveSoc.toDouble(),
      remainingCapacityAh: effectiveRemainingCap,
      packVoltage: effectiveVoltage,
    );

    _batteryData = _batteryData.copyWith(
      voltage: voltage,
      current: current,
      soc: soc,
      power: power,
      temperature: temperature,
      range: calculatedRange,
      remainingCapacityAh: remainingCapacityAh,
      cycleCount: cycleCount,
      isCharging: isCharging,
      isDischarging: isDischarging,
      cellVoltages: cellVoltages,
      isConnected: isConnected ?? _isConnected,
      vendorId: vendorId ?? _batteryData.vendorId,
      hardwareVersion: hardwareVersion ?? _batteryData.hardwareVersion,
      softwareVersion: softwareVersion ?? _batteryData.softwareVersion,
      powerOnTimes: powerOnTimes ?? _batteryData.powerOnTimes,
      uptime: uptime ?? _batteryData.uptime,
      serialNumber: serialNumber ?? _batteryData.serialNumber,
      firstOnDate: firstOnDate ?? _batteryData.firstOnDate,
      totalTime: totalTime ?? _batteryData.totalTime,
    );

    _queueAlertCheck(previousBatteryData, _batteryData);

    if (isConnected != null) _isConnected = isConnected;
    if (_isConnected) _isConnecting = false;
    notifyListeners();
  }

  void updateBatteryData(BatteryData newData) {
    final previousBatteryData = _batteryData;
    _rangeEstimator.addTelemetry(
      voltage: newData.voltage,
      current: newData.current,
    );

    final calculatedRange = _rangeEstimator.estimateRangeKm(
      socPercent: newData.soc.toDouble(),
      remainingCapacityAh: newData.remainingCapacityAh,
      packVoltage: newData.voltage,
    );

    _batteryData = newData.copyWith(
      range: calculatedRange,
    );

    _queueAlertCheck(previousBatteryData, _batteryData);

    _isConnected = newData.isConnected;
    _isConnecting = false;
    notifyListeners();
  }

  void addPosition(Position position) {
    _rangeEstimator.addPosition(position);
  }

  Future<void> finishRide() async {
    await _rangeEstimator.finishRide();
    notifyListeners();
  }

  void setConnectionState(
      bool connected, {
        bool unexpectedDisconnect = false,
      }) {
    final wasConnected = _isConnected;

    _isConnected = connected;
    if (connected) _isConnecting = false;

    if (!connected && wasConnected && unexpectedDisconnect) {
      _sendDisconnectAlert();
    }

    notifyListeners();
  }

  void setConnectingState(bool connecting) {
    _isConnecting = connecting;
    notifyListeners();
  }

  void setBmsPassword(String newPassword) {
    _bmsPassword = newPassword;
    notifyListeners();
  }

  Future<void> forceManualReconnect() async {
    if (_isConnected || _isConnecting) return;
    setConnectingState(true);
    await bleService.forceManualReconnect();
    // Note: Success will be handled by BleService calling setConnectionState
  }

  // =========================================================
  // GARAGE METHODS
  // =========================================================
  Future<void> loadGarage() async {
    final prefs = await SharedPreferences.getInstance();
    _primaryScooterId = prefs.getString('primary_scooter_id');

    final garageString = prefs.getString('saved_garage');
    if (garageString != null && garageString.isNotEmpty) {
      _savedGarage = garageString.split('||').map((item) {
        final parts = item.split('::');
        return {'id': parts[0], 'name': parts[1]};
      }).toList();
    }
    notifyListeners();
  }

  Future<void> setPrimaryScooter(String macAddress) async {
    _primaryScooterId = macAddress;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('primary_scooter_id', macAddress);
    notifyListeners();
  }

  Future<void> saveScooterToGarage(String macAddress, String name) async {
    if (_savedGarage.any((scooter) => scooter['id'] == macAddress)) return;

    if (_savedGarage.length >= 3) {
      int indexToRemove = _savedGarage.indexWhere((s) => s['id'] != _primaryScooterId);
      if (indexToRemove != -1) _savedGarage.removeAt(indexToRemove);
    }

    _savedGarage.add({
      'id': macAddress,
      'name': name.isEmpty ? 'Unknown Scooty' : name
    });

    if (_savedGarage.length == 1) {
      await setPrimaryScooter(macAddress);
    }

    final prefs = await SharedPreferences.getInstance();
    final garageString = _savedGarage.map((s) => '${s['id']}::${s['name']}').join('||');
    await prefs.setString('saved_garage', garageString);
    notifyListeners();
  }

  void toggleCharging(bool value) {
    bleService.toggleChargeMosfet(value);
  }

  void toggleDischarging(bool value) {
    bleService.toggleDischargeMosfet(value);
  }

  void _queueAlertCheck(BatteryData previous, BatteryData current) {
    _alertCheckQueue = _alertCheckQueue
        .then((_) => _checkAlerts(previous, current))
        .catchError((Object error) {
      debugPrint('Notification check failed: $error');
    });
  }

  Future<void> _checkAlerts(
      BatteryData previous,
      BatteryData current,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = NotificationService.instance;

    final chargingEnabled =
        prefs.getBool('battery_percent_alert_enabled') ?? false;
    final chargingThreshold =
        prefs.getInt('battery_percent_alert_threshold') ?? 80;

    if (!chargingEnabled || !current.isCharging || current.soc < chargingThreshold) {
      _chargingAlertShown = false;
    } else if (!_chargingAlertShown) {
      _chargingAlertShown = true;
      await notifications.showChargingAlert(batteryPercent: current.soc);
    }

    final temperatureEnabled =
        prefs.getBool('temperature_alert_enabled') ?? false;
    final temperatureThreshold =
        prefs.getInt('temperature_alert_threshold_c') ?? 50;

    if (!temperatureEnabled ||
        current.temperature < temperatureThreshold - 2) {
      _temperatureAlertShown = false;
    } else if (current.temperature >= temperatureThreshold &&
        !_temperatureAlertShown) {
      _temperatureAlertShown = true;
      await notifications.showTemperatureAlert(
        temperatureCelsius: current.temperature,
      );
    }

    final rangeEnabled = prefs.getBool('range_alert_enabled') ?? false;
    final rangeThreshold = prefs.getInt('range_alert_threshold_km') ?? 10;

    if (!rangeEnabled || current.range > rangeThreshold + 2) {
      _rangeAlertShown = false;
    } else if (current.range > 0 &&
        current.range <= rangeThreshold &&
        !_rangeAlertShown) {
      _rangeAlertShown = true;
      await notifications.showRangeAlert(rangeKm: current.range);
    }
  }

  Future<void> _sendDisconnectAlert() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('disconnect_alert_enabled') ?? false) {
      await NotificationService.instance.showDisconnectAlert();
    }
  }
}
