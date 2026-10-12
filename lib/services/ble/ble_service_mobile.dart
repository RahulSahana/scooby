import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ble_service_base.dart';

class BleService extends BleServiceBase {
  BleService({required super.batteryProvider});

  StreamSubscription? _scanSubscription;
  StreamSubscription? _notifySubscription;
  StreamSubscription? _connectionStateSubscription;
  Timer? _autoReconnectTimer;
  bool _isIntentionallyDisconnected = false;

  @override
  Future<void> startScan() async {
    devices.clear();
    debugPrint('MOBILE BLE: STARTING SCAN');
    
    // On mobile, we still pass optional services for consistency and best practice
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10), 
      androidScanMode: AndroidScanMode.lowLatency,
      webOptionalServices: [Guid(BleServiceBase.jkServiceUuid)],
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final device = result.device;
        if (device.platformName.isNotEmpty && !devices.contains(device)) {
          devices.add(device);
        }
      }
    });
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  @override
  Future<void> connect(BluetoothDevice device) async {
    if (connectedDevice?.remoteId == device.remoteId && batteryProvider.isConnected) return;

    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    connectedDevice = device;
    batteryProvider.setConnectingState(true);

    try {
      await device.connect(license: License.nonprofit, timeout: const Duration(seconds: 15));
      _isIntentionallyDisconnected = false;
      _autoReconnectTimer?.cancel();

      await batteryProvider.saveScooterToGarage(device.remoteId.str, device.platformName);
      debugPrint('MOBILE BLE: CONNECTED TO ${device.platformName}');
    } catch (e) {
      debugPrint('MOBILE BLE: CONNECT ERROR $e');
      batteryProvider.setConnectionState(false);
      rethrow;
    }

    _connectionStateSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        final unexpected = !_isIntentionallyDisconnected;
        _onDeviceDisconnected(unexpected: unexpected);

        if (unexpected) _startAutoReconnectLoop();
      } else if (state == BluetoothConnectionState.connected) {
        _autoReconnectTimer?.cancel();
        batteryProvider.setConnectionState(true);
      }
    });

    await _discoverAndSetup(device);
  }

  Future<void> _discoverAndSetup(BluetoothDevice device) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final services = await device.discoverServices();
      
      for (final service in services) {
        if (service.uuid.toString().toLowerCase().contains(BleServiceBase.jkServiceUuid)) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase().contains(BleServiceBase.jkCharUuid)) {
              jkCharacteristic = characteristic;
              await _setupCharacteristic(characteristic);
              batteryProvider.setConnectionState(true);
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('MOBILE BLE: DISCOVERY FAILED $e');
      batteryProvider.setConnectionState(false);
    }
  }

  Future<void> _setupCharacteristic(BluetoothCharacteristic characteristic) async {
    await characteristic.setNotifyValue(true);
    await Future.delayed(const Duration(seconds: 1));

    _notifySubscription = characteristic.lastValueStream.listen((chunk) {
      if (chunk.isNotEmpty) onDataChunk(chunk);
    });

    await commandService.sendCellInfoRequest(characteristic);
    await Future.delayed(const Duration(seconds: 1));
    await commandService.sendDeviceInfoRequest(characteristic);

    startPolling();
  }

  @override
  Future<bool> autoConnect() async {
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

  void _startAutoReconnectLoop() {
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (connectedDevice == null || batteryProvider.isConnected) {
        timer.cancel();
        return;
      }
      try {
        await connectedDevice!.connect(license: License.nonprofit, timeout: const Duration(seconds: 4));
        await _discoverAndSetup(connectedDevice!);
        timer.cancel();
      } catch (e) {
        debugPrint('MOBILE BLE: Auto-reconnect failed');
      }
    });
  }

  @override
  Future<void> forceManualReconnect() async {
    _autoReconnectTimer?.cancel();
    if (connectedDevice == null) {
      final success = await autoConnect();
      if (!success) batteryProvider.setConnectingState(false);
      return;
    }
    try {
      await connect(connectedDevice!);
    } catch (e) {
      _startAutoReconnectLoop();
    }
  }

  void _onDeviceDisconnected({bool unexpected = false}) {
    stopPolling();
    packetBuffer.clear();
    jkCharacteristic = null;

    batteryProvider.setConnectionState(
      false,
      unexpectedDisconnect: unexpected,
    );
  }

  @override
  Future<void> disconnect({bool forgetDevice = false}) async {
    try {
      _isIntentionallyDisconnected = true;
      _autoReconnectTimer?.cancel();
      _onDeviceDisconnected();

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
      debugPrint('MOBILE BLE: DISCONNECT ERROR $e');
    }
  }
}
