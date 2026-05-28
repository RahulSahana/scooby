import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class JkCommandService {

  // =========================================================
  // CALCULATE CHECKSUM
  // =========================================================

  int calculateCrc(List<int> frame) {
    int sum = 0;
    // JK BMS Checksum is the sum of bytes 0 through 18
    for (int i = 0; i < frame.length; i++) {
      if (i < 19) {
        sum += frame[i];
      }
    }
    // Return the lowest 8 bits (modulo 256)
    return sum & 0xFF;
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
  // BUILD WRITE COMMAND (FIXED FOR LONG PASSWORDS)
  // =========================================================

  List<int> buildWriteCommand(int register, List<int> valueBytes) {
    final frame = <int>[
      // HEADER
      0xAA, 0x55, 0x90, 0xEB,

      // COMMAND (0x02 = WRITE)
      0x02,

      // REGISTER ADDRESS
      register,

      // LENGTH OF VALUE
      valueBytes.length,
    ];

    // INJECT ALL VALUE BYTES (No more 4-byte limit!)
    frame.addAll(valueBytes);

    // PADDING (Fill the rest of the frame to reach 19 bytes before CRC)
    // A standard JK BLE frame must be exactly 20 bytes total.
    while (frame.length < 19) {
      frame.add(0x00);
    }

    // CALCULATE AND APPEND CRC
    final crc = calculateCrc(frame);
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

  // =========================================================
  // AUTHORIZATION HANDSHAKE
  // =========================================================

  Future<void> sendAuthorization(BluetoothCharacteristic characteristic) async {
    try {
      // JK Settings Password: "802626052E"
      // 8=0x38, 0=0x30, 2=0x32, 6=0x36, 2=0x32
      // 6=0x36, 0=0x30, 5=0x35, 2=0x32, E=0x45
      final passwordBytes = [
        0x38, 0x30, 0x32, 0x36, 0x32,
        0x36, 0x30, 0x35, 0x32, 0x45
      ];

      // Register 0x00 is the authorization register
      final command = buildWriteCommand(0x00, passwordBytes);

      await characteristic.write(command, withoutResponse: false);

      debugPrint('AUTHORIZATION HANDSHAKE SENT: 802626052E');
    } catch (e) {
      debugPrint('AUTHORIZATION ERROR: $e');
    }
  }

  // =========================================================
  // TOGGLE CHARGE MOSFET
  // =========================================================

  Future<void> setChargeMosfet(BluetoothCharacteristic characteristic, bool enable) async {
    try {
      // FIX: The BMS strictly expects 4 bytes for register values!
      // 0x01, 0x00, 0x00, 0x00 (ON) | 0x00, 0x00, 0x00, 0x00 (OFF)
      final valueBytes = enable ? [0x01, 0x00, 0x00, 0x00] : [0x00, 0x00, 0x00, 0x00];

      // Register 0x1D is typically the Charge MOSFET setting
      final command = buildWriteCommand(0x1D, valueBytes);

      // FIX: Force to false so the phone's Bluetooth stack guarantees delivery
      await characteristic.write(command, withoutResponse: false);
      debugPrint('SENT CHARGE MOSFET TOGGLE: ${enable ? "ON" : "OFF"}');
    } catch (e) {
      debugPrint('CHARGE TOGGLE ERROR: $e');
    }
  }

  // =========================================================
  // TOGGLE DISCHARGE MOSFET (MOTOR POWER)
  // =========================================================

  Future<void> setDischargeMosfet(BluetoothCharacteristic characteristic, bool enable) async {
    try {
      // FIX: 4-byte strict payload
      final valueBytes = enable ? [0x01, 0x00, 0x00, 0x00] : [0x00, 0x00, 0x00, 0x00];

      // 0x1E is the JK register for the Discharge MOSFET
      final command = buildWriteCommand(0x1E, valueBytes);

      await characteristic.write(command, withoutResponse: false);
      debugPrint('SENT DISCHARGE MOSFET TOGGLE: ${enable ? "ON" : "OFF"}');
    } catch (e) {
      debugPrint('DISCHARGE TOGGLE ERROR: $e');
    }
  }
}
