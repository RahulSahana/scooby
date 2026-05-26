import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class JkCommandService {

  // =========================================================
  // CRC
  // =========================================================

  int calculateCrc(
      List<int> data,
      ) {

    int crc = 0;

    for (final byte in data) {

      crc =
      (crc + byte) & 0xFF;
    }

    return crc;
  }

  // =========================================================
  // BUILD COMMAND
  // =========================================================

  List<int> buildCommand(
      int command,
      ) {

    final frame = [

      // HEADER
      0xAA,
      0x55,
      0x90,
      0xEB,

      // COMMAND
      command,

      // LENGTH
      0x00,

      // VALUE
      0x00,
      0x00,
      0x00,
      0x00,

      // PADDING
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ];

    // CRC over bytes 0-18

    final crc =
    calculateCrc(frame);

    frame.add(crc);

    return frame;
  }

  // =========================================================
  // DEVICE INFO REQUEST
  // COMMAND = 0x97
  // =========================================================

  Future<void> sendDeviceInfoRequest(
      BluetoothCharacteristic characteristic,
      ) async {

    try {

      final command =
      buildCommand(0x97);

      await characteristic.write(

        command,

        withoutResponse: true,
      );

      final hex = command

          .map(
            (e) => e
            .toRadixString(16)
            .padLeft(2, '0'),
      )

          .join(' ');

      debugPrint(
        'DEVICE INFO REQUEST: $hex',
      );

    } catch (e) {

      debugPrint(
        'DEVICE INFO ERROR: $e',
      );
    }
  }

  // =========================================================
  // CELL INFO REQUEST
  // COMMAND = 0x96
  // =========================================================

  Future<void> sendCellInfoRequest(
      BluetoothCharacteristic characteristic,
      ) async {

    try {

      final command =
      buildCommand(0x96);

      await characteristic.write(

        command,

        withoutResponse: true,
      );

      final hex = command

          .map(
            (e) => e
            .toRadixString(16)
            .padLeft(2, '0'),
      )

          .join(' ');

      debugPrint(
        'CELL INFO REQUEST: $hex',
      );

    } catch (e) {

      debugPrint(
        'CELL INFO ERROR: $e',
      );
    }
  }
}