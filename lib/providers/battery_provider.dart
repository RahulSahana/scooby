import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/battery_data.dart';
import '../services/ble/ble_service.dart';
import '../services/range_estimator.dart';
import '../services/notification_service.dart';
import '../services/remote_telemetry_service.dart';
import '../services/background_sync_service.dart';

class BatteryProvider extends ChangeNotifier {
  late BleService bleService;
  late final Future<void> garageReady;
  BatteryData _batteryData = BatteryData.empty();
  String _bmsPassword = "1234";

  bool _chargingAlertShown = false;
  bool _temperatureAlertShown = false;
  bool _rangeAlertShown = false;

  Future<void> _alertCheckQueue = Future<void>.value();

  final RangeEstimator _rangeEstimator = RangeEstimator();
  final RemoteTelemetryService remoteTelemetryService =
      RemoteTelemetryService();
  Timer? _localPublishTimer;
  Timer? _remotePollTimer;
  Timer? _bluetoothRetryTimer;
  bool _hasLocalBmsFrame = false;
  bool _hasPublishedForConnection = false;
  bool _isUsingRemoteTelemetry = false;
  bool _locationPermissionPrompted = false;
  bool _backgroundServiceStarted = false;
  double? _scooterLatitude;
  double? _scooterLongitude;
  DateTime? _remoteTelemetryReceivedAt;

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
    garageReady = loadGarage();
    initializeRangeEstimator();
  }

  BatteryData get batteryData => _batteryData;
  String get bmsPassword => _bmsPassword;
  List<Map<String, String>> get savedGarage => _savedGarage;
  String? get primaryScooterId => _primaryScooterId;
  RangeEstimator get rangeEstimator => _rangeEstimator;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isUsingRemoteTelemetry => _isUsingRemoteTelemetry;
  double? get scooterLatitude => _scooterLatitude;
  double? get scooterLongitude => _scooterLongitude;
  DateTime? get remoteTelemetryReceivedAt => _remoteTelemetryReceivedAt;
  String get telemetrySourceLabel => _isConnected
      ? 'Bluetooth'
      : (_isUsingRemoteTelemetry ? 'Remote' : 'Disconnected');

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
    final effectiveRemainingCap =
        remainingCapacityAh ?? _batteryData.remainingCapacityAh;

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

    if (_isConnected && voltage != null && current != null && soc != null) {
      _hasLocalBmsFrame = true;
      if (!_hasPublishedForConnection) {
        _hasPublishedForConnection = true;
        unawaited(_publishLocalTelemetry());
      }
    }
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

    _batteryData = newData.copyWith(range: calculatedRange);

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

  void setConnectionState(bool connected, {bool unexpectedDisconnect = false}) {
    final wasConnected = _isConnected;

    _isConnected = connected;
    if (connected) _isConnecting = false;

    if (connected && !wasConnected) {
      _hasLocalBmsFrame = false;
      _hasPublishedForConnection = false;
      _isUsingRemoteTelemetry = false;
      _remotePollTimer?.cancel();
      _bluetoothRetryTimer?.cancel();
      _bluetoothRetryTimer = null;
      _startLocalPublishTimer();
    } else if (!connected && wasConnected) {
      _localPublishTimer?.cancel();
      _localPublishTimer = null;
      _hasLocalBmsFrame = false;
      _startRemotePollTimer(immediate: true);
      _startBluetoothRetryTimer();
    }

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
    _startRemotePollTimer(immediate: true);
    notifyListeners();
    if (_primaryScooterId != null) {
      unawaited(_autoConnectThenUseRemote());
    }
  }

  Future<void> setPrimaryScooter(String macAddress) async {
    _primaryScooterId = macAddress;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('primary_scooter_id', macAddress);
    if (!_isConnected) _startRemotePollTimer(immediate: true);
    notifyListeners();
  }

  Future<void> saveScooterToGarage(String macAddress, String name) async {
    if (_savedGarage.any((scooter) => scooter['id'] == macAddress)) return;

    if (_savedGarage.length >= 3) {
      int indexToRemove = _savedGarage.indexWhere(
        (s) => s['id'] != _primaryScooterId,
      );
      if (indexToRemove != -1) _savedGarage.removeAt(indexToRemove);
    }

    _savedGarage.add({
      'id': macAddress,
      'name': name.isEmpty ? 'Unknown Scooty' : name,
    });

    if (_savedGarage.length == 1) {
      await setPrimaryScooter(macAddress);
    }

    if (bleService.connectedDevice?.remoteId.str == macAddress) {
      try {
        await remoteTelemetryService.ensureLocalPairing(
          macAddress,
          scooterName: name.isEmpty ? 'Unknown Scooty' : name,
        );
      } catch (error) {
        debugPrint('Could not prepare secure telemetry pairing: $error');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final garageString = _savedGarage
        .map((s) => '${s['id']}::${s['name']}')
        .join('||');
    await prefs.setString('saved_garage', garageString);
    notifyListeners();
  }

  void _startLocalPublishTimer() {
    _localPublishTimer?.cancel();
    _localPublishTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => unawaited(_publishLocalTelemetry()),
    );
  }

  Future<void> _autoConnectThenUseRemote() async {
    if (kIsWeb || _isConnected || _primaryScooterId == null) return;

    try {
      final permissions = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      if (permissions.values.any((status) => !status.isGranted)) {
        setConnectingState(false);
        _startRemotePollTimer(immediate: true);
        _startBluetoothRetryTimer();
        return;
      }

      await _startBackgroundServiceIfPaired();

      for (var attempt = 0; attempt < 3 && !_isConnected; attempt++) {
        final connected = await bleService.autoConnect();
        if (connected || _isConnected) return;
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    } catch (error) {
      debugPrint('Automatic BMS discovery failed: $error');
    }

    if (!_isConnected) {
      setConnectingState(false);
      _startRemotePollTimer(immediate: true);
      _startBluetoothRetryTimer();
    }
  }

  void _startBluetoothRetryTimer() {
    if (kIsWeb || _primaryScooterId == null || _isConnected) return;
    _bluetoothRetryTimer?.cancel();
    _bluetoothRetryTimer = Timer.periodic(const Duration(minutes: 2), (
      _,
    ) async {
      if (_isConnected || _isConnecting || _primaryScooterId == null) return;
      try {
        final permissions = await Future.wait([
          Permission.bluetoothScan.status,
          Permission.bluetoothConnect.status,
        ]);
        if (permissions.any((status) => !status.isGranted)) return;
        await bleService.autoConnect();
      } catch (error) {
        debugPrint('Scheduled BMS reconnection failed: $error');
      }
    });
  }

  Future<void> _publishLocalTelemetry() async {
    if (!_isConnected || !_hasLocalBmsFrame) return;
    final bleDeviceId = _primaryScooterId;
    if (bleDeviceId == null) return;

    try {
      final pairing = await remoteTelemetryService.ensureLocalPairing(
        bleDeviceId,
      );
      await _startBackgroundServiceIfPaired(pairingExists: true);
      Map<String, double>? location;
      if (await Geolocator.isLocationServiceEnabled()) {
        var permission = await Geolocator.checkPermission();
        if ((permission == LocationPermission.denied ||
                permission == LocationPermission.deniedForever) &&
            !_locationPermissionPrompted) {
          _locationPermissionPrompted = true;
          await Permission.locationWhenInUse.request();
          permission = await Geolocator.checkPermission();
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          try {
            final position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 12),
              ),
            );
            location = {
              'latitude': position.latitude,
              'longitude': position.longitude,
            };
            _scooterLatitude = position.latitude;
            _scooterLongitude = position.longitude;
          } catch (error) {
            debugPrint('Could not refresh scooter location: $error');
          }
        }
      }
      location ??= _scooterLatitude != null && _scooterLongitude != null
          ? {'latitude': _scooterLatitude!, 'longitude': _scooterLongitude!}
          : null;
      await remoteTelemetryService.publishLatest(
        pairing: pairing,
        battery: _batteryData,
        location: location,
      );
      _remoteTelemetryReceivedAt = DateTime.now();
    } catch (error) {
      debugPrint('Scooby remote telemetry upload failed: $error');
    }
    notifyListeners();
  }

  Future<void> _startBackgroundServiceIfPaired({
    bool pairingExists = false,
  }) async {
    if (_backgroundServiceStarted) return;
    final bleDeviceId = _primaryScooterId;
    if (bleDeviceId == null) return;
    if (!pairingExists &&
        await remoteTelemetryService.pairingFor(bleDeviceId) == null) {
      return;
    }
    _backgroundServiceStarted = await BackgroundSyncService.start();
  }

  void _startRemotePollTimer({bool immediate = false}) {
    _remotePollTimer?.cancel();
    if (_isConnected) return;
    if (immediate) unawaited(_pollRemoteTelemetry());
    _remotePollTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => unawaited(_pollRemoteTelemetry()),
    );
  }

  Future<void> _pollRemoteTelemetry() async {
    if (_isConnected) return;

    try {
      final snapshot = await remoteTelemetryService.fetchPublicLatest();
      if (snapshot == null) {
        _isUsingRemoteTelemetry = false;
        notifyListeners();
        return;
      }

      final values = snapshot.battery;
      double number(String key, double fallback) {
        final value = values[key];
        return value is num ? value.toDouble() : fallback;
      }

      int integer(String key, int fallback) {
        final value = values[key];
        return value is num ? value.toInt() : fallback;
      }

      final rawCells = values['cellVoltages'];
      final cells = rawCells is List
          ? rawCells.whereType<num>().map((value) => value.toDouble()).toList()
          : _batteryData.cellVoltages;
      _batteryData = _batteryData.copyWith(
        voltage: number('voltage', _batteryData.voltage),
        current: number('current', _batteryData.current),
        soc: integer('soc', _batteryData.soc),
        temperature: number('temperature', _batteryData.temperature),
        power: number('power', _batteryData.power),
        range: number('range', _batteryData.range),
        cycleCount: integer('cycleCount', _batteryData.cycleCount),
        cellVoltages: cells,
        isCharging: values['isCharging'] is bool
            ? values['isCharging'] as bool
            : _batteryData.isCharging,
        isDischarging: values['isDischarging'] is bool
            ? values['isDischarging'] as bool
            : _batteryData.isDischarging,
        isConnected: false,
      );
      _remoteTelemetryReceivedAt = snapshot.receivedAt;
      final location = snapshot.location;
      final latitude = location?['latitude'];
      final longitude = location?['longitude'];
      if (latitude is num && longitude is num) {
        _scooterLatitude = latitude.toDouble();
        _scooterLongitude = longitude.toDouble();
      }
      _isUsingRemoteTelemetry =
          DateTime.now().difference(snapshot.receivedAt) <=
          const Duration(minutes: 6);
      notifyListeners();
    } catch (error) {
      debugPrint('Scooby remote telemetry fetch failed: $error');
      _isUsingRemoteTelemetry = false;
      notifyListeners();
    }
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

  Future<void> _checkAlerts(BatteryData previous, BatteryData current) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = NotificationService.instance;

    final chargingEnabled =
        prefs.getBool('battery_percent_alert_enabled') ?? false;
    final chargingThreshold =
        prefs.getInt('battery_percent_alert_threshold') ?? 80;

    if (!chargingEnabled ||
        !current.isCharging ||
        current.soc < chargingThreshold) {
      _chargingAlertShown = false;
    } else if (!_chargingAlertShown) {
      _chargingAlertShown = true;
      await notifications.showChargingAlert(batteryPercent: current.soc);
    }

    final temperatureEnabled =
        prefs.getBool('temperature_alert_enabled') ?? false;
    final temperatureThreshold =
        prefs.getInt('temperature_alert_threshold_c') ?? 50;

    if (!temperatureEnabled || current.temperature < temperatureThreshold - 2) {
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

  @override
  void dispose() {
    _localPublishTimer?.cancel();
    _remotePollTimer?.cancel();
    _bluetoothRetryTimer?.cancel();
    remoteTelemetryService.dispose();
    super.dispose();
  }
}
