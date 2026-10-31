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
  bool _isIntentionallyDisconnected = false;

  @override
  Future<void> startScan() async {
    devices.clear();
    debugPrint('MOBILE BLE: STARTING SCAN');

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final device = result.device;
        if (device.platformName.isNotEmpty && !devices.contains(device)) {
          devices.add(device);
        }
      }
    });

    try {
      // Listen before starting the scan so early advertisements are not missed.
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidScanMode: AndroidScanMode.lowLatency,
        webOptionalServices: [Guid(BleServiceBase.jkServiceUuid)],
      );
    } catch (_) {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      rethrow;
    }
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  @override
  Future<void> connect(BluetoothDevice device) async {
    if (connectedDevice?.remoteId == device.remoteId &&
        batteryProvider.isConnected) {
      return;
    }

    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    connectedDevice = device;
    batteryProvider.setConnectingState(true);

    try {
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
      );
      _isIntentionallyDisconnected = false;

      await batteryProvider.saveScooterToGarage(
        device.remoteId.str,
        device.platformName,
      );
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
      } else if (state == BluetoothConnectionState.connected) {
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
        if (service.uuid.toString().toLowerCase().contains(
          BleServiceBase.jkServiceUuid,
        )) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase().contains(
              BleServiceBase.jkCharUuid,
            )) {
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

  Future<void> _setupCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
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
    StreamSubscription<List<ScanResult>>? scanSubscription;
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

      // Subscribe before starting the scan. The results stream itself stays
      // open after scanning stops, so wait on a bounded future instead of
      // awaiting the stream to close.
      final matchedDevice = Completer<BluetoothDevice?>();
      scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
        if (matchedDevice.isCompleted) return;
        BluetoothDevice? candidate;
        for (final result in results) {
          if (result.device.remoteId.str == savedId) {
            candidate = result.device;
            break;
          }
        }
        candidate ??= _knownScooterFrom(results);
        if (candidate != null) matchedDevice.complete(candidate);
      });

      await FlutterBluePlus.startScan(
        // Android stops unfiltered scans when the screen turns off. Restrict
        // this retry scan to the saved BMS address or known BMS names so
        // background reconnect attempts can continue efficiently.
        withRemoteIds: [savedId],
        withNames: const ['Scooty', 'JK-BMS', 'JKBMS'],
        timeout: const Duration(seconds: 8),
        androidScanMode: AndroidScanMode.lowLatency,
      );
      final candidate = await matchedDevice.future.timeout(
        const Duration(seconds: 9),
        onTimeout: () => null,
      );
      await scanSubscription.cancel();
      scanSubscription = null;
      if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();

      if (candidate == null) {
        debugPrint('MOBILE BLE: AUTO SCAN FOUND NO MATCHING SCOOTER');
        batteryProvider.setConnectingState(false);
        return false;
      }

      // Some Android phones expose a different BLE address after the BMS
      // has been reset. Fall back only to the scooter's known advertised
      // names, never to arbitrary nearby Bluetooth devices.
      final foundNewAddress = candidate.remoteId.str != savedId;
      if (foundNewAddress) {
        debugPrint(
          'MOBILE BLE: FOUND KNOWN SCOOTER NAME '
          '${candidate.platformName.isNotEmpty ? candidate.platformName : candidate.advName}; '
          'will update saved BLE address after connection',
        );
      }
      await connect(candidate);
      if (foundNewAddress) {
        await batteryProvider.setPrimaryScooter(candidate.remoteId.str);
      }
      return true;
    } catch (error) {
      debugPrint('MOBILE BLE: AUTO CONNECT FAILED $error');
      batteryProvider.setConnectingState(false);
      return false;
    } finally {
      await scanSubscription?.cancel();
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    }
  }

  BluetoothDevice? _knownScooterFrom(List<ScanResult> results) {
    for (final result in results) {
      final names = [
        result.device.platformName,
        result.device.advName,
      ].map((name) => name.trim().toLowerCase().replaceAll('-', ''));
      if (names.any((name) => name == 'scooty' || name.contains('jkbms'))) {
        return result.device;
      }
    }
    return null;
  }

  @override
  Future<void> forceManualReconnect() async {
    if (connectedDevice == null) {
      final success = await autoConnect();
      if (!success) batteryProvider.setConnectingState(false);
      return;
    }
    try {
      await connect(connectedDevice!);
    } catch (_) {
      batteryProvider.setConnectingState(false);
    }
  }

  void _onDeviceDisconnected({bool unexpected = false}) {
    stopPolling();
    packetBuffer.clear();
    jkCharacteristic = null;

    batteryProvider.setConnectionState(false, unexpectedDisconnect: unexpected);
  }

  @override
  Future<void> disconnect({bool forgetDevice = false}) async {
    try {
      _isIntentionallyDisconnected = true;
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
