import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/battery_data.dart';
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
  // SCAN
  // =========================================================

  StreamSubscription? scanSubscription;

  List<BluetoothDevice> devices = [];

  // =========================================================
  // CONNECTION
  // =========================================================

  BluetoothDevice? connectedDevice;

  BluetoothCharacteristic? jkCharacteristic;

  // =========================================================
  // DATA
  // =========================================================

  final List<int> packetBuffer = [];

  final List<String> logs = [];

  int packetCount = 0;

  // =========================================================
  // POLLING
  // =========================================================

  Timer? pollingTimer;

  // =========================================================
  // START SCAN
  // =========================================================

  Future<void> startScan() async {

    debugPrint("STARTING BLE SCAN");

    devices.clear();

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 5),
      androidScanMode:
      AndroidScanMode.lowLatency,
    );

    scanSubscription =
        FlutterBluePlus.scanResults.listen(
              (results) {

            for (ScanResult result in results) {

              final device = result.device;

              if (device.platformName.isNotEmpty &&
                  !devices.contains(device)) {

                devices.add(device);

                debugPrint(
                  "FOUND DEVICE: "
                      "${device.platformName} "
                      "${device.remoteId}",
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

    debugPrint("STOPPING SCAN");

    await FlutterBluePlus.stopScan();

    await scanSubscription?.cancel();
  }

  // =========================================================
  // CONNECT
  // =========================================================

  Future<void> connect(
      BluetoothDevice device,
      ) async {

    connectedDevice = device;

    try {

      await device.connect(
        license: License.free,
      );

    } catch (e) {

      debugPrint(
        "CONNECT WARNING: $e",
      );
    }

    debugPrint(
      "CONNECTED TO: "
          "${device.platformName}",
    );

    batteryProvider.setConnectionState(
      true,
    );

    // =====================================================
    // CONNECTION STATE
    // =====================================================

    device.connectionState.listen((state) {

      debugPrint(
        "CONNECTION STATE: $state",
      );
    });

    // =====================================================
    // DISCOVER SERVICES
    // =====================================================

    List<BluetoothService> services =
    await device.discoverServices();

    debugPrint(
      "SERVICES FOUND: "
          "${services.length}",
    );

    // =====================================================
    // FIND JK SERVICE
    // =====================================================

    for (BluetoothService service
    in services) {

      final serviceUuid =
      service.uuid
          .toString()
          .toLowerCase();

      debugPrint(
        "SERVICE: $serviceUuid",
      );

      // ===================================================
      // JK MAIN SERVICE
      // ===================================================

      if (serviceUuid == "ffe0") {

        debugPrint(
          "FOUND JK SERVICE",
        );

        for (BluetoothCharacteristic
        characteristic
        in service.characteristics) {

          final uuid =
          characteristic.uuid
              .toString()
              .toLowerCase();

          debugPrint(
            "CHARACTERISTIC: $uuid",
          );

          // =================================================
          // MAIN JK UART CHARACTERISTIC
          // =================================================

          if (uuid == "ffe1") {

            debugPrint(
              "FOUND JK CHARACTERISTIC",
            );

            jkCharacteristic = characteristic;

            // ===============================================
            // ENABLE NOTIFICATIONS
            // ===============================================

            await characteristic
                .setNotifyValue(true);

            debugPrint(
              "NOTIFICATIONS ENABLED",
            );

            // ===============================================
            // LISTEN FOR DATA
            // ===============================================

            characteristic
                .lastValueStream
                .listen((value) {

              if (value.isEmpty) return;

              // Add chunk to buffer
              packetBuffer.addAll(value);

              // Packet count
              packetCount++;

              debugPrint(
                "PACKET COUNT: "
                    "$packetCount",
              );

              // ---------------------------------------------
              // CURRENT CHUNK
              // ---------------------------------------------

              final chunkHex = value
                  .map(
                    (e) => e
                    .toRadixString(16)
                    .padLeft(2, '0'),
              )
                  .join(' ');

              debugPrint(
                "CHUNK: $chunkHex",
              );

              // ---------------------------------------------
              // FULL BUFFER
              // ---------------------------------------------

              final bufferHex = packetBuffer
                  .map(
                    (e) => e
                    .toRadixString(16)
                    .padLeft(2, '0'),
              )
                  .join(' ');

              debugPrint(
                "BUFFER: $bufferHex",
              );

              // Save logs
              logs.add(bufferHex);

              // =============================================
              // CHECK JK PACKET
              // =============================================

              if (JkBmsParser
                  .isValidPacket(
                packetBuffer,
              )) {

                debugPrint(
                  "VALID JK PACKET DETECTED",
                );

                // -------------------------------------------
                // PARSE VALUES
                // -------------------------------------------

                final voltage =
                JkBmsParser
                    .parseVoltage(
                  packetBuffer,
                );

                final current =
                JkBmsParser
                    .parseCurrent(
                  packetBuffer,
                );

                final soc =
                JkBmsParser
                    .parseSoc(
                  packetBuffer,
                );

                final temperature =
                JkBmsParser
                    .parseTemperature(
                  packetBuffer,
                );

                final cells =
                JkBmsParser
                    .parseCellVoltages(
                  packetBuffer,
                );

                // -------------------------------------------
                // UPDATE PROVIDER
                // -------------------------------------------

                batteryProvider
                    .updateTelemetry(

                  voltage: voltage,

                  current: current,

                  soc: soc,

                  temperature: temperature,

                  cellVoltages: cells,

                  isConnected: true,
                );

                // -------------------------------------------
                // DEBUG OUTPUT
                // -------------------------------------------

                debugPrint(
                  "VOLTAGE: "
                      "$voltage V",
                );

                debugPrint(
                  "CURRENT: "
                      "$current A",
                );

                debugPrint(
                  "SOC: "
                      "$soc %",
                );

                debugPrint(
                  "TEMPERATURE: "
                      "$temperature °C",
                );

                debugPrint(
                  "CELL COUNT: "
                      "${cells.length}",
                );

                // -------------------------------------------
                // CLEAR BUFFER
                // -------------------------------------------

                packetBuffer.clear();
              }
            });

            // ===============================================
            // SEND INITIAL JK REQUEST
            // ===============================================

            final commandService =
            JkCommandService();

            await commandService
                .sendInfoRequest(
              characteristic,
            );

            debugPrint(
              "INITIAL JK REQUEST SENT",
            );

            // ===============================================
            // START POLLING
            // ===============================================

            startPolling();
          }
        }
      }
    }
  }

  // =========================================================
  // START POLLING
  // =========================================================

  void startPolling() {

    if (jkCharacteristic == null) {
      return;
    }

    pollingTimer?.cancel();

    pollingTimer = Timer.periodic(
      const Duration(seconds: 2),
          (_) async {

        try {

          final commandService =
          JkCommandService();

          await commandService
              .sendInfoRequest(
            jkCharacteristic!,
          );

          debugPrint(
            "POLL REQUEST SENT",
          );

        } catch (e) {

          debugPrint(
            "POLL ERROR: $e",
          );
        }
      },
    );
  }

  // =========================================================
  // DISCONNECT
  // =========================================================

  Future<void> disconnect() async {

    try {

      pollingTimer?.cancel();

      packetBuffer.clear();

      batteryProvider
          .setConnectionState(false);

      await connectedDevice
          ?.disconnect();

      debugPrint(
        "DEVICE DISCONNECTED",
      );

    } catch (e) {

      debugPrint(
        "DISCONNECT ERROR: $e",
      );
    }
  }
}