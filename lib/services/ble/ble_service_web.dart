import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_service_base.dart';

class BleService extends BleServiceBase {
  BleService({required super.batteryProvider});

  StreamSubscription? _notifySubscription;
  StreamSubscription? _connectionStateSubscription;

  @override
  Future<void> startScan() async {
    // Check if Bluetooth is supported in the browser
    if (!await FlutterBluePlus.isSupported) {
      debugPrint('WEB BLE: Bluetooth not supported in this browser');
      return;
    }

    devices.clear();
    debugPrint('WEB BLE: STARTING SCAN (Opening Browser Chooser)');

    try {
      // On Web, startScan() triggers the browser's device chooser.
      // webOptionalServices is critical here to authorize GATT access.
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        webOptionalServices: [Guid(BleServiceBase.jkServiceUuid)],
      );

      // Listen for the device selection
      final results = await FlutterBluePlus.scanResults.first;
      if (results.isNotEmpty) {
        for (final result in results) {
          if (!devices.contains(result.device)) {
            devices.add(result.device);
          }
        }
      }
    } catch (e) {
      debugPrint('WEB BLE: SCAN ERROR or USER CANCELLED: $e');
    }
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  @override
  Future<void> connect(BluetoothDevice device) async {
    debugPrint('WEB BLE: CONNECTING TO ${device.platformName}');
    connectedDevice = device;
    batteryProvider.setConnectingState(true);

    try {
      // Connect to the selected device
      await device.connect(license: License.nonprofit, timeout: const Duration(seconds: 15));
      debugPrint('WEB BLE: CONNECTED');
      
      // Save to Garage
      await batteryProvider.saveScooterToGarage(device.remoteId.str, device.platformName);
    } catch (e) {
      debugPrint('WEB BLE: CONNECT ERROR: $e');
      batteryProvider.setConnectionState(false);
      rethrow;
    }

    // Monitor connection state
    _connectionStateSubscription = device.connectionState.listen((state) {
      debugPrint('WEB BLE: Connection state changed to $state');
      if (state == BluetoothConnectionState.disconnected) {
        _onDeviceDisconnected();
      } else if (state == BluetoothConnectionState.connected) {
        batteryProvider.setConnectionState(true);
      }
    });

    await _discoverAndSetup(device);
  }

  Future<void> _discoverAndSetup(BluetoothDevice device) async {
    try {
      debugPrint('WEB BLE: Discovering services...');
      final services = await device.discoverServices();
      debugPrint('WEB BLE: Services found: ${services.length}');

      for (final service in services) {
        if (service.uuid.toString().toLowerCase().contains(BleServiceBase.jkServiceUuid)) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase().contains(BleServiceBase.jkCharUuid)) {
              debugPrint('WEB BLE: FOUND JK CHARACTERISTIC');
              jkCharacteristic = characteristic;
              await _setupCharacteristic(characteristic);
              batteryProvider.setConnectionState(true);
              return;
            }
          }
        }
      }
      debugPrint('WEB BLE: JK CHARACTERISTIC NOT FOUND');
    } catch (e) {
      debugPrint('WEB BLE: DISCOVERY FAILED: $e');
      batteryProvider.setConnectionState(false);
    }
  }

  Future<void> _setupCharacteristic(BluetoothCharacteristic characteristic) async {
    debugPrint('WEB BLE: Setting up notifications...');
    await characteristic.setNotifyValue(true);
    
    _notifySubscription = characteristic.lastValueStream.listen((chunk) {
      if (chunk.isNotEmpty) onDataChunk(chunk);
    });

    debugPrint('WEB BLE: Sending initial requests...');
    await commandService.sendCellInfoRequest(characteristic);
    await Future.delayed(const Duration(milliseconds: 500));
    await commandService.sendDeviceInfoRequest(characteristic);

    startPolling();
  }

  @override
  Future<bool> autoConnect() async {
    // Web Bluetooth auto-connect is limited. 
    // We try systemDevices to see if the browser already has a permitted device.
    try {
      final savedId = batteryProvider.primaryScooterId;
      if (savedId == null) return false;

      debugPrint('WEB BLE: Checking system devices for auto-connect...');
      List<BluetoothDevice> connected = await FlutterBluePlus.systemDevices([]);
      for (var device in connected) {
        if (device.remoteId.str == savedId) {
          debugPrint('WEB BLE: Found previously authorized device, reconnecting...');
          await connect(device);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('WEB BLE: AUTO-CONNECT FAILED: $e');
      return false;
    }
  }

  @override
  Future<void> forceManualReconnect() async {
    // On Web, forceManualReconnect should probably just trigger startScan
    // since we need user interaction anyway.
    if (connectedDevice != null) {
      try {
        await connect(connectedDevice!);
      } catch (e) {
        await startScan();
      }
    } else {
      await startScan();
    }
  }

  void _onDeviceDisconnected() {
    debugPrint('WEB BLE: DEVICE DISCONNECTED');
    stopPolling();
    packetBuffer.clear();
    jkCharacteristic = null;
    batteryProvider.setConnectionState(false);
  }

  @override
  Future<void> disconnect({bool forgetDevice = false}) async {
    debugPrint('WEB BLE: DISCONNECTING');
    _onDeviceDisconnected();

    await _notifySubscription?.cancel();
    _notifySubscription = null;
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    if (connectedDevice != null) {
      try {
        await connectedDevice!.disconnect();
      } catch (e) {
        debugPrint('WEB BLE: Error during disconnect: $e');
      }
      connectedDevice = null;
    }
  }
}
