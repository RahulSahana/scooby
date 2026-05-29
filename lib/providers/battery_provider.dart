import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ble_service.dart';
import '../models/battery_data.dart';

class BatteryProvider extends ChangeNotifier {
  late BleService bleService;
  BatteryData _batteryData = BatteryData.empty();
  String _bmsPassword = "1234";

  // Connection UI States
  bool _isConnected = false;
  bool _isConnecting = false;

  // The Garage Memory
  List<Map<String, String>> _savedGarage = [];
  String? _primaryScooterId;

  BatteryProvider() {
    bleService = BleService(batteryProvider: this);
    loadGarage();
  }

  BatteryData get batteryData => _batteryData;
  String get bmsPassword => _bmsPassword;
  List<Map<String, String>> get savedGarage => _savedGarage;
  String? get primaryScooterId => _primaryScooterId;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  // Called by BleService to push hardware data to UI
  void updateTelemetry({
    double? voltage,
    double? current,
    int? soc,
    double? temperature,
    List<double>? cellVoltages,
    int? cycleCount,
    bool? isCharging,
    bool? isDischarging,
    double? power,
    bool? isConnected,
  }) {
    _batteryData = _batteryData.copyWith(
      voltage: voltage,
      current: current,
      soc: soc,
      power: power,
      temperature: temperature,
      cycleCount: cycleCount,
      isCharging: isCharging,
      isDischarging: isDischarging,
      cellVoltages: cellVoltages,
      isConnected: isConnected ?? _isConnected,
    );

    if (isConnected != null) _isConnected = isConnected;
    if (_isConnected) _isConnecting = false;
    notifyListeners();
  }

  void updateBatteryData(BatteryData newData) {
    _batteryData = newData;
    _isConnected = newData.isConnected;
    _isConnecting = false;
    notifyListeners();
  }

  void setConnectionState(bool connected) {
    _isConnected = connected;
    if (connected) _isConnecting = false;
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
}