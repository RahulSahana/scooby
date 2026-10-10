import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../providers/battery_provider.dart';
import '../jk_command_service.dart';
import '../../parsers/jk_bms_parser.dart';

abstract class BleServiceBase {
  final BatteryProvider batteryProvider;
  BleServiceBase({required this.batteryProvider});

  // JK BMS Protocol UUIDs
  static const String jkServiceUuid = "ffe0";
  static const String jkCharUuid = "ffe1";

  final JkCommandService commandService = JkCommandService();

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? jkCharacteristic;
  List<BluetoothDevice> devices = [];

  final List<int> packetBuffer = [];
  int packetCount = 0;

  Timer? pollingTimer;
  bool isHardwareCommandPending = false;

  Future<void> startScan();
  Future<void> stopScan();
  Future<void> connect(BluetoothDevice device);
  Future<void> disconnect({bool forgetDevice = false});
  Future<bool> autoConnect();

  // Common Hardware Controls
  Future<void> toggleChargeMosfet(bool enable) async {
    if (jkCharacteristic == null) return;
    try {
      isHardwareCommandPending = true;
      await commandService.sendAuthorization(jkCharacteristic!, batteryProvider.bmsPassword);
      await Future.delayed(const Duration(milliseconds: 500));
      await commandService.setChargeMosfet(jkCharacteristic!, enable);
      await Future.delayed(const Duration(milliseconds: 500));
      await commandService.sendCellInfoRequest(jkCharacteristic!);
    } catch (e) {
      debugPrint('CHARGE TOGGLE FAILED: $e');
    } finally {
      isHardwareCommandPending = false;
    }
  }

  Future<void> toggleDischargeMosfet(bool enable) async {
    if (jkCharacteristic == null) return;
    try {
      isHardwareCommandPending = true;
      await commandService.sendAuthorization(jkCharacteristic!, batteryProvider.bmsPassword);
      await Future.delayed(const Duration(milliseconds: 500));
      await commandService.setDischargeMosfet(jkCharacteristic!, enable);
      await Future.delayed(const Duration(milliseconds: 500));
      await commandService.sendCellInfoRequest(jkCharacteristic!);
    } catch (e) {
      debugPrint('DISCHARGE TOGGLE FAILED: $e');
    } finally {
      isHardwareCommandPending = false;
    }
  }

  Future<void> forceManualReconnect();

  // Common Polling
  void startPolling() {
    if (jkCharacteristic == null) return;
    pollingTimer?.cancel();
    pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (jkCharacteristic == null) return;

      if (isHardwareCommandPending) {
        debugPrint('Skipping Telemetry: Hardware command in progress...');
        return;
      }

      try {
        await commandService.sendCellInfoRequest(jkCharacteristic!);
      } catch (e) {
        debugPrint('POLL ERROR: $e');
      }
    });
  }

  void stopPolling() {
    pollingTimer?.cancel();
    pollingTimer = null;
  }

  // Common Data Parsing
  void onDataChunk(List<int> chunk) {
    packetBuffer.addAll(chunk);
    packetCount++;

    while (packetBuffer.length >= 4) {
      if (!bufferStartsWithHeader()) {
        realignBuffer();
        if (packetBuffer.length < 4 || !bufferStartsWithHeader()) break;
      }
      final frameEnd = findNextFrameEnd();
      if (frameEnd == -1) break;

      final frame = packetBuffer.sublist(0, frameEnd);
      packetBuffer.removeRange(0, frameEnd);
      processFrame(frame);
    }
  }

  int findNextFrameEnd() {
    for (int i = 4; i <= packetBuffer.length - 4 && i <= 320; i++) {
      if (packetBuffer[i] == 0x55 && packetBuffer[i + 1] == 0xAA && packetBuffer[i + 2] == 0xEB && packetBuffer[i + 3] == 0x90) {
        return i;
      }
    }
    if (packetBuffer.length >= 320) return 320;
    return -1;
  }

  bool bufferStartsWithHeader() {
    if (packetBuffer.length < 4) return false;
    return packetBuffer[0] == 0x55 && packetBuffer[1] == 0xAA && packetBuffer[2] == 0xEB && packetBuffer[3] == 0x90;
  }

  void realignBuffer() {
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

  void processFrame(List<int> frame) {
    if (!JkBmsParser.isValidHeader(frame) || !JkBmsParser.isValidCrc(frame)) return;

    final frameType = JkBmsParser.frameType(frame);

    if (frameType == 0x02) {
      final batteryData = JkBmsParser.parseBatteryData(frame);
      batteryProvider.updateTelemetry(
        voltage: batteryData.voltage,
        current: batteryData.current,
        soc: batteryData.soc,
        remainingCapacityAh: batteryData.remainingCapacityAh,
        temperature: batteryData.temperature,
        cellVoltages: batteryData.cellVoltages,
        cycleCount: batteryData.cycleCount,
        isCharging: batteryData.isCharging,
        isDischarging: batteryData.isDischarging,
        power: batteryData.power,
        isConnected: true,
      );
    } else if (frameType == 0x03) {
      final deviceInfo = JkBmsParser.parseDeviceInfo(frame);

      batteryProvider.updateTelemetry(
        vendorId: deviceInfo['vendorId'],
        hardwareVersion: deviceInfo['hardwareVersion'],
        softwareVersion: deviceInfo['softwareVersion'],
        serialNumber: deviceInfo['serialNumber'],
        firstOnDate: deviceInfo['firstOnDate'],
        totalTime: deviceInfo['totalTime'],
      );
    }
  }
}
