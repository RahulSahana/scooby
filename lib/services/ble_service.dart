import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

//import '../models/battery_data.dart';
import '../parsers/jk_bms_parser.dart';
import '../providers/battery_provider.dart';
import 'jk_command_service.dart';

class BleService {

  // =========================================================
  // PROVIDER
  // =========================================================

  final BatteryProvider batteryProvider;

  BleService({
    required this.batteryProvider,
  });

  // =========================================================
  // COMMANDS
  // =========================================================

  final JkCommandService _commandService = JkCommandService();

  // =========================================================
  // BLE
  // =========================================================

  StreamSubscription? _scanSubscription;

  StreamSubscription? _autoConnectSubscription;

  StreamSubscription? _notifySubscription;

  StreamSubscription? _connectionStateSubscription;

  BluetoothDevice? connectedDevice;

  BluetoothCharacteristic? jkCharacteristic;

  List<BluetoothDevice> devices = [];

  // =========================================================
  // BUFFER
  // =========================================================

  final List<int> packetBuffer = [];

  int packetCount = 0;

  // =========================================================
  // POLLING
  // =========================================================

  Timer? pollingTimer;

  // =========================================================
  // START SCAN
  // =========================================================

  Future<void> startScan() async {

    devices.clear();

    debugPrint(
      'STARTING BLE SCAN',
    );

    await FlutterBluePlus.startScan(

      timeout:
      const Duration(seconds: 10),

      androidScanMode:
      AndroidScanMode.lowLatency,
    );

    _scanSubscription =
        FlutterBluePlus.scanResults.listen(

              (results) {

            for (final result in results) {

              final device =
                  result.device;

              if (

              device.platformName
                  .isNotEmpty &&

                  !devices.contains(device)

              ) {

                devices.add(device);

                debugPrint(

                  'FOUND DEVICE: '

                      '${device.platformName} '

                      '${device.remoteId}',
                );
              }
            }
          },
        );
  }

  // =========================================================
  // STOP SCAN
  // =========================================================

  Future<void> stopScan() async {

    await FlutterBluePlus.stopScan();

    await _scanSubscription?.cancel();

    _scanSubscription = null;
  }

  // =========================================================
  // CONNECT
  // =========================================================

  Future<void> connect(
      BluetoothDevice device,
      ) async {
    // Avoid redundant connection attempts
    if (connectedDevice?.remoteId == device.remoteId) {
      debugPrint('ALREADY CONNECTED TO: ${device.remoteId}');
      return;
    }

    connectedDevice = device;

    try {
      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
      );

      final prefs =
      await SharedPreferences.getInstance();

      await prefs.setString(
        'last_device_id',
        device.remoteId.str,
      );

      debugPrint(
        'CONNECTED TO: '
            '${device.platformName}',
      );

      batteryProvider
          .setConnectionState(true);

    } catch (e) {

      debugPrint(
        'CONNECT ERROR: $e',
      );

      batteryProvider
          .setConnectionState(false);

      rethrow;
    }



    // =======================================================
    // CONNECTION STATE
    // =======================================================

    _connectionStateSubscription =

        device.connectionState.listen(

              (state) {

            debugPrint(
              'CONNECTION STATE: $state',
            );

            if (

            state ==
                BluetoothConnectionState
                    .disconnected

            ) {

              _onDeviceDisconnected();
            }
          },
        );

    // =======================================================
    // DISCOVER SERVICES
    // =======================================================

    final services =
    await device.discoverServices();

    debugPrint(
      'SERVICES FOUND: '
          '${services.length}',
    );

    for (final service in services) {

      final serviceUuid =

      service.uuid
          .toString()
          .toLowerCase();

      if (serviceUuid.contains('ffe0')) {

        debugPrint(
          'FOUND JK SERVICE',
        );

        for (final characteristic
        in service.characteristics) {

          final charUuid =

          characteristic.uuid
              .toString()
              .toLowerCase();

          if (charUuid.contains('ffe1')) {

            debugPrint(
              'FOUND JK CHARACTERISTIC',
            );

            jkCharacteristic =
                characteristic;

            await _setupCharacteristic(
              characteristic,
            );

            break;
          }
        }
      }
    }

    if (jkCharacteristic == null) {

      debugPrint(
        'JK CHARACTERISTIC NOT FOUND',
      );
    }
  }

  Future<bool> autoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('last_device_id');

      if (savedId == null) {
        debugPrint('AUTO-CONNECT: No saved device ID found.');
        return false;
      }

      debugPrint('AUTO-CONNECT: Searching for $savedId...');

      // 1. Check if it is already connected via the system cache
      List<BluetoothDevice> connected = await FlutterBluePlus.systemDevices([]);
      for (var device in connected) {
        if (device.remoteId.str == savedId) {
          debugPrint('AUTO-CONNECT: Device already connected via system.');
          await connect(device);
          return true;
        }
      }

      // 2. Start a targeted scan
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8), // Give it 8 seconds to find the scooter
        androidScanMode: AndroidScanMode.lowLatency,
      );

      // Wait and listen to the scan results
      await for (final results in FlutterBluePlus.onScanResults) {
        for (ScanResult r in results) {
          if (r.device.remoteId.str == savedId) {
            debugPrint('AUTO-CONNECT: Found target device!');
            await FlutterBluePlus.stopScan();
            await connect(r.device);
            return true;
          }
        }
        // If scan times out, the stream usually closes or stops sending results.
        // FlutterBluePlus.isScanning will become false.
        if (!FlutterBluePlus.isScanningNow) break;
      }

      debugPrint('AUTO-CONNECT: Device not found in range.');
      return false;

    } catch (e) {
      debugPrint('AUTO-CONNECT ERROR: $e');
      return false;
    }
  }

  // =========================================================
  // SETUP CHARACTERISTIC
  // =========================================================

  Future<void> _setupCharacteristic(
      BluetoothCharacteristic characteristic,
      ) async {

    // =======================================================
    // ENABLE NOTIFICATIONS
    // =======================================================

    await characteristic.setNotifyValue(true);

    debugPrint(
      'NOTIFICATIONS ENABLED',
    );

    // IMPORTANT FOR JK BMS
    // WAIT AFTER ENABLING NOTIFICATIONS

    await Future.delayed(
      const Duration(seconds: 2),
    );

    // =======================================================
    // LISTEN DATA
    // =======================================================

    _notifySubscription =
        characteristic.lastValueStream.listen(

              (chunk) {

            if (chunk.isEmpty) return;

            _onDataChunk(chunk);
          },
        );

    // =======================================================
    // CELL INFO REQUEST (0x96) FIRST
    // =======================================================

    await _commandService
        .sendCellInfoRequest(
      characteristic,
    );

    debugPrint(
      'CELL INFO REQUEST SENT',
    );

    // WAIT BEFORE DEVICE INFO

    await Future.delayed(
      const Duration(seconds: 1),
    );

    // =======================================================
    // DEVICE INFO REQUEST (0x97)
    // =======================================================

    await _commandService
        .sendDeviceInfoRequest(
      characteristic,
    );

    debugPrint(
      'DEVICE INFO REQUEST SENT',
    );

    debugPrint(
      'INITIAL REQUESTS SENT',
    );

    // =======================================================
    // START POLLING
    // =======================================================

    _startPolling();
  }

  // =========================================================
  // DATA CHUNK
  // =========================================================

  void _onDataChunk(
      List<int> chunk,
      ) {

    packetBuffer.addAll(chunk);

    packetCount++;

    if (kDebugMode) {
      final hex = chunk
          .map((e) => e.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      debugPrint('CHUNK #$packetCount [${chunk.length}B]: $hex');
    }

    while (packetBuffer.length >= 4) {
      // Find header at start
      if (!_bufferStartsWithHeader()) {
        _realignBuffer();
        if (packetBuffer.length < 4 || !_bufferStartsWithHeader()) break;
      }

      // Wait for up to 320 bytes or next header
      final frameEnd = _findNextFrameEnd();
      if (frameEnd == -1) break; // not enough data yet

      final frame = packetBuffer.sublist(0, frameEnd);
      packetBuffer.removeRange(0, frameEnd);
      _processFrame(frame);
    }
  }

  int _findNextFrameEnd() {
    // Look for next header after byte 4 to find true frame boundary
    for (int i = 4; i <= packetBuffer.length - 4 && i <= 320; i++) {
      if (packetBuffer[i] == 0x55 &&
          packetBuffer[i + 1] == 0xAA &&
          packetBuffer[i + 2] == 0xEB &&
          packetBuffer[i + 3] == 0x90) {
        return i;
      }
    }
    // No next header found — if buffer >= 320, take 320
    if (packetBuffer.length >= 320) return 320;
    return -1; // still accumulating
  }

  bool _bufferStartsWithHeader() {
    if (packetBuffer.length < 4) return false;
    return packetBuffer[0] == 0x55 &&
        packetBuffer[1] == 0xAA &&
        packetBuffer[2] == 0xEB &&
        packetBuffer[3] == 0x90;
  }

  // =========================================================
  // PROCESS FRAME
  // =========================================================

  void _processFrame(
      List<int> frame,
      ) {

    // QUICK CHECK
    debugPrint("FRAME LENGTH: ${frame.length}");
    if (frame.length >= 4) {
      debugPrint("HEADER: ${frame[0]} ${frame[1]} ${frame[2]} ${frame[3]}");
    }

    debugPrint(
      'PROCESSING FRAME '
          '[${frame.length} bytes]',
    );

    if (!JkBmsParser.isValidHeader(frame) ||
        !JkBmsParser.isValidCrc(frame)) {

      debugPrint(
        'INVALID FRAME',
      );

      return;
    }

    debugPrint(
      'VALID JK FRAME',
    );

    final frameType =
    JkBmsParser.frameType(frame);

    debugPrint(
      'FRAME TYPE: $frameType',
    );

    // =======================================================
    // CELL INFO
    // =======================================================

    if (frameType == 0x02) {

      JkBmsParser.debugTemperatures(frame);
      final batteryData =
      JkBmsParser.parseBatteryData(frame);

      debugPrint(
        'SOC: ${batteryData.soc}',
      );

      debugPrint(
        'VOLTAGE: ${batteryData.voltage}',
      );

      debugPrint(
        'CURRENT: ${batteryData.current}',
      );

      batteryProvider.updateTelemetry(

        voltage:
        batteryData.voltage,

        current:
        batteryData.current,

        soc:
        batteryData.soc,

        temperature:
        batteryData.temperature,

        cellVoltages:
        batteryData.cellVoltages,

        cycleCount:
        batteryData.cycleCount,

        isCharging:
        batteryData.isCharging,

        power:
        batteryData.power,

        isConnected: true,
      );
    }

    // =======================================================
    // DEVICE INFO
    // =======================================================

    else if (frameType == 0x03) {

      debugPrint(
        'DEVICE INFO FRAME RECEIVED',
      );
    }

    // =======================================================
    // SETTINGS
    // =======================================================

    else if (frameType == 0x01) {

      debugPrint(
        'SETTINGS FRAME RECEIVED',
      );
    }
  }

  // =========================================================
  // REALIGN BUFFER
  // =========================================================

  void _realignBuffer() {

    for (

    int i = 1;

    i < packetBuffer.length - 3;

    i++

    ) {

      if (

      packetBuffer[i] == 0x55 &&

          packetBuffer[i + 1] == 0xAA &&

          packetBuffer[i + 2] == 0xEB &&

          packetBuffer[i + 3] == 0x90

      ) {

        final realigned =
        packetBuffer.sublist(i);

        packetBuffer.clear();

        packetBuffer.addAll(realigned);

        debugPrint(
          'BUFFER REALIGNED',
        );

        return;
      }
    }

    packetBuffer.clear();
  }

  // =========================================================
  // POLLING
  // =========================================================

  void _startPolling() {

    if (jkCharacteristic == null) {
      return;
    }

    pollingTimer?.cancel();

    pollingTimer = Timer.periodic(

      const Duration(seconds: 3),

          (_) async {

        if (jkCharacteristic == null) {
          return;
        }

        try {

          await _commandService
              .sendCellInfoRequest(
            jkCharacteristic!,
          );

        } catch (e) {

          debugPrint(
            'POLL ERROR: $e',
          );
        }
      },
    );

    debugPrint(
      'POLLING STARTED',
    );
  }

  // =========================================================
  // DEVICE DISCONNECTED
  // =========================================================

  void _onDeviceDisconnected() {

    pollingTimer?.cancel();

    pollingTimer = null;

    packetBuffer.clear();

    jkCharacteristic = null;

    batteryProvider
        .setConnectionState(false);

    debugPrint(
      'DEVICE DISCONNECTED',
    );
  }

  // =========================================================
  // DISCONNECT
  // =========================================================

  Future<void> disconnect() async {

    try {

      pollingTimer?.cancel();

      pollingTimer = null;

      await _autoConnectSubscription?.cancel();
      _autoConnectSubscription = null;

      await _notifySubscription?.cancel();

      _notifySubscription = null;

      await _connectionStateSubscription
          ?.cancel();

      _connectionStateSubscription = null;

      packetBuffer.clear();

      jkCharacteristic = null;

      batteryProvider
          .setConnectionState(false);

      await connectedDevice?.disconnect();

      connectedDevice = null;

      debugPrint(
        'DISCONNECTED',
      );

    } catch (e) {

      debugPrint(
        'DISCONNECT ERROR: $e',
      );
    }
  }
}