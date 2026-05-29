import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../parsers/jk_bms_parser.dart';
import '../providers/battery_provider.dart';
import 'jk_command_service.dart';

class BleService {
  final BatteryProvider batteryProvider;
  BleService({required this.batteryProvider});

  final JkCommandService _commandService = JkCommandService();

  StreamSubscription? _scanSubscription;
  StreamSubscription? _autoConnectSubscription;
  StreamSubscription? _notifySubscription;
  StreamSubscription? _connectionStateSubscription;

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? jkCharacteristic;
  List<BluetoothDevice> devices = [];

  final List<int> packetBuffer = [];
  int packetCount = 0;

  Timer? pollingTimer;
  Timer? _autoReconnectTimer;
  bool _isIntentionallyDisconnected = false;

  // =========================================================
  // SCANNING
  // =========================================================

  Future<void> startScan() async {
    devices.clear();
    debugPrint('STARTING BLE SCAN');
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10), androidScanMode: AndroidScanMode.lowLatency);

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final device = result.device;
        if (device.platformName.isNotEmpty && !devices.contains(device)) {
          devices.add(device);
        }
      }
    });
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  // =========================================================
  // CONNECTION PIPELINE
  // =========================================================

  Future<void> connect(BluetoothDevice device) async {
    if (connectedDevice?.remoteId == device.remoteId && batteryProvider.isConnected) return;

    // 1. Clean up old listeners to prevent ghost connections
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    connectedDevice = device;
    batteryProvider.setConnectingState(true);

    try {
      await device.connect(license: License.free, timeout: const Duration(seconds: 15));
      _isIntentionallyDisconnected = false;
      _autoReconnectTimer?.cancel();

      // Save to Garage
      await batteryProvider.saveScooterToGarage(device.remoteId.str, device.platformName);
      debugPrint('CONNECTED TO: ${device.platformName}');
    } catch (e) {
      debugPrint('CONNECT ERROR: $e');
      batteryProvider.setConnectionState(false);
      rethrow;
    }

    // 2. Setup listener ONLY for unexpected disconnects (No discovery here!)
    _connectionStateSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _onDeviceDisconnected();
        if (!_isIntentionallyDisconnected) _startAutoReconnectLoop();
      }
    });

    // 3. Handle Discovery safely
    await _discoverAndSetup(device);
  }

  Future<void> _discoverAndSetup(BluetoothDevice device) async {
    try {
      // CRITICAL FIX: Give Android GATT 500ms to settle before demanding services
      await Future.delayed(const Duration(milliseconds: 500));

      final services = await device.discoverServices();
      debugPrint('SERVICES FOUND: ${services.length}');

      for (final service in services) {
        if (service.uuid.toString().toLowerCase().contains('ffe0')) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase().contains('ffe1')) {
              debugPrint('FOUND JK CHARACTERISTIC');
              jkCharacteristic = characteristic;
              await _setupCharacteristic(characteristic);
              batteryProvider.setConnectionState(true);
              return;
            }
          }
        }
      }
      debugPrint('JK CHARACTERISTIC NOT FOUND');
    } catch (e) {
      debugPrint('DISCOVERY FAILED: $e');
      batteryProvider.setConnectionState(false);
    }
  }

  Future<bool> autoConnect({required License license}) async {
    try {
      final savedId = batteryProvider.primaryScooterId;
      if (savedId == null) return false;

      batteryProvider.setConnectingState(true);
      List<BluetoothDevice> connected = await FlutterBluePlus.systemDevices([]);
      for (var device in connected) {
        if (device.remoteId.str == savedId) {
          await connect(device);
          return true;
        }
      }

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8), androidScanMode: AndroidScanMode.lowLatency);
      await for (final results in FlutterBluePlus.onScanResults) {
        for (ScanResult r in results) {
          if (r.device.remoteId.str == savedId) {
            await FlutterBluePlus.stopScan();
            await connect(r.device);
            return true;
          }
        }
        if (!FlutterBluePlus.isScanningNow) break;
      }
      batteryProvider.setConnectingState(false);
      return false;
    } catch (e) {
      batteryProvider.setConnectingState(false);
      return false;
    }
  }

  // =========================================================
  // SETUP CHARACTERISTIC & POLLING
  // =========================================================

  Future<void> _setupCharacteristic(BluetoothCharacteristic characteristic) async {
    await characteristic.setNotifyValue(true);
    await Future.delayed(const Duration(seconds: 1)); // Wait for notifications to register

    _notifySubscription = characteristic.lastValueStream.listen((chunk) {
      if (chunk.isNotEmpty) _onDataChunk(chunk);
    });

    await _commandService.sendCellInfoRequest(characteristic);
    await Future.delayed(const Duration(seconds: 1));
    await _commandService.sendDeviceInfoRequest(characteristic);

    _startPolling();
  }

  void _startPolling() {
    if (jkCharacteristic == null) return;
    pollingTimer?.cancel();
    pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (jkCharacteristic == null) return;
      try {
        await _commandService.sendCellInfoRequest(jkCharacteristic!);
      } catch (e) {
        debugPrint('POLL ERROR: $e');
      }
    });
  }

  // =========================================================
  // DATA PARSING
  // =========================================================

  void _onDataChunk(List<int> chunk) {
    packetBuffer.addAll(chunk);
    packetCount++;

    while (packetBuffer.length >= 4) {
      if (!_bufferStartsWithHeader()) {
        _realignBuffer();
        if (packetBuffer.length < 4 || !_bufferStartsWithHeader()) break;
      }
      final frameEnd = _findNextFrameEnd();
      if (frameEnd == -1) break;

      final frame = packetBuffer.sublist(0, frameEnd);
      packetBuffer.removeRange(0, frameEnd);
      _processFrame(frame);
    }
  }

  int _findNextFrameEnd() {
    for (int i = 4; i <= packetBuffer.length - 4 && i <= 320; i++) {
      if (packetBuffer[i] == 0x55 && packetBuffer[i + 1] == 0xAA && packetBuffer[i + 2] == 0xEB && packetBuffer[i + 3] == 0x90) {
        return i;
      }
    }
    if (packetBuffer.length >= 320) return 320;
    return -1;
  }

  bool _bufferStartsWithHeader() {
    if (packetBuffer.length < 4) return false;
    return packetBuffer[0] == 0x55 && packetBuffer[1] == 0xAA && packetBuffer[2] == 0xEB && packetBuffer[3] == 0x90;
  }

  void _realignBuffer() {
    for (int i = 1; i < packetBuffer.length - 3; i++) {
      if (packetBuffer[i] == 0x55 && packetBuffer[i + 1] == 0xAA && packetBuffer[i + 2] == 0xEB && packetBuffer[i + 3] == 0x90) {
        final realigned = packetBuffer.sublist(i);
        packetBuffer.clear();
        packetBuffer.addAll(realigned);
        return;
      }
    }
    packetBuffer.clear();
  }

  void _processFrame(List<int> frame) {
    if (!JkBmsParser.isValidHeader(frame) || !JkBmsParser.isValidCrc(frame)) return;

    if (JkBmsParser.frameType(frame) == 0x02) {
      final batteryData = JkBmsParser.parseBatteryData(frame);
      batteryProvider.updateTelemetry(
        voltage: batteryData.voltage,
        current: batteryData.current,
        soc: batteryData.soc,
        temperature: batteryData.temperature,
        cellVoltages: batteryData.cellVoltages,
        cycleCount: batteryData.cycleCount,
        isCharging: batteryData.isCharging,
        isDischarging: batteryData.isDischarging,
        power: batteryData.power,
        isConnected: true,
      );
    }
  }

  // =========================================================
  // HARDWARE CONTROLS
  // =========================================================

  Future<void> toggleChargeMosfet(bool enable) async {
    if (jkCharacteristic == null) return;
    try {
      await _commandService.sendAuthorization(jkCharacteristic!, batteryProvider.bmsPassword);
      await Future.delayed(const Duration(milliseconds: 200));
      await _commandService.setChargeMosfet(jkCharacteristic!, enable);
      await Future.delayed(const Duration(milliseconds: 300));
      await _commandService.sendCellInfoRequest(jkCharacteristic!);
    } catch (e) {
      debugPrint('CHARGE TOGGLE FAILED: $e');
    }
  }

  Future<void> toggleDischargeMosfet(bool enable) async {
    if (jkCharacteristic == null) return;
    try {
      await _commandService.sendAuthorization(jkCharacteristic!, batteryProvider.bmsPassword);
      await Future.delayed(const Duration(milliseconds: 200));
      await _commandService.setDischargeMosfet(jkCharacteristic!, enable);
      await Future.delayed(const Duration(milliseconds: 300));
      await _commandService.sendCellInfoRequest(jkCharacteristic!);
    } catch (e) {
      debugPrint('DISCHARGE TOGGLE FAILED: $e');
    }
  }

  // =========================================================
  // AUTO RECONNECT LOOP
  // =========================================================

  void _startAutoReconnectLoop() {
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (connectedDevice == null || batteryProvider.isConnected) {
        timer.cancel();
        return;
      }
      try {
        await connectedDevice!.connect(license: License.free, timeout: const Duration(seconds: 4));
        // On success, trigger the setup safely
        await _discoverAndSetup(connectedDevice!);
        timer.cancel();
      } catch (e) {
        debugPrint('Auto-reconnect failed');
      }
    });
  }

  Future<void> forceManualReconnect() async {
    _autoReconnectTimer?.cancel();

    if (connectedDevice == null) {
      final success = await autoConnect(license: License.free);
      if (!success) {
        batteryProvider.setConnectingState(false);
      }
      return;
    }

    try {
      await connect(connectedDevice!);
    } catch (e) {
      _startAutoReconnectLoop();
    }
  }

  // =========================================================
  // DISCONNECT & TEARDOWN
  // =========================================================

  void _onDeviceDisconnected() {
    pollingTimer?.cancel();
    pollingTimer = null;
    packetBuffer.clear();
    jkCharacteristic = null;
    batteryProvider.setConnectionState(false);
  }

  Future<void> disconnect({bool forgetDevice = false}) async {
    try {
      _isIntentionallyDisconnected = true;
      _autoReconnectTimer?.cancel();
      _onDeviceDisconnected();

      await _autoConnectSubscription?.cancel();
      _autoConnectSubscription = null;
      await _notifySubscription?.cancel();
      _notifySubscription = null;
      await _connectionStateSubscription?.cancel();
      _connectionStateSubscription = null;

      await connectedDevice?.disconnect();
      connectedDevice = null;

      if (forgetDevice) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_device_id');
      }
    } catch (e) {
      debugPrint('DISCONNECT ERROR: $e');
    }
  }
}