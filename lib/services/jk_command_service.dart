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

  Future<void> toggleMosfetSafe(BluetoothCharacteristic characteristic, String password, bool turnOn) async {
    try {
      // 1. (Optional but recommended) Set a boolean in your provider to temporarily stop
      // the 'CELL INFO REQUEST' loop from firing while we do this.
      // batteryProvider.pauseTelemetryLoop = true;

      debugPrint('1. Sending Authorization...');
      await sendAuthorization(characteristic, password); // Your padded 16-byte password

      // 2. CRITICAL FIX: The BMS needs time to unlock.
      // Force the app to wait half a second.
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('2. Sending Toggle Command...');
      // 3. Send your actual MOSFET command
      // Example: 0x1D is usually the register for Charge MOSFET on JK
      // payload must be EXACTLY 4 bytes! e.g., [0x01, 0x00, 0x00, 0x00] for ON
      final commandPayload = turnOn ? [0x01, 0x00, 0x00, 0x00] : [0x00, 0x00, 0x00, 0x00];

      // THE CRITICAL FIX: Pad the data to exactly 12 bytes!
      // This ensures buildWriteCommand generates a perfect 20-byte packet.
      // (Header 4 + Cmd 1 + Reg 1 + Len 1 + Payload 12 + CRC 1 = 20)
      while (commandPayload.length < 12) {
        commandPayload.add(0x00);
      }

      final toggleCommand = buildWriteCommand(0x1D, commandPayload);

      await characteristic.write(toggleCommand, withoutResponse: false);
      debugPrint('3. Toggle Command Sent (20-Byte Padded)!');

      // 4. Wait a tiny bit for it to process the toggle before asking for data again
      await Future.delayed(const Duration(milliseconds: 300));

      // 5. Resume your telemetry loop so the UI updates
      // batteryProvider.pauseTelemetryLoop = false;

    } catch (e) {
      debugPrint('TOGGLE ERROR: $e');
    }
  }

  Future<void> sendAuthorization(BluetoothCharacteristic characteristic, String password) async {
    try {
      // Converts the string (e.g. "1234" or "802626052E") into raw ASCII bytes
      final passwordBytes = password.codeUnits.toList();

      // Pad password to 12 bytes for 20-byte frame consistency
      while (passwordBytes.length < 12) {
        passwordBytes.add(0x00);
      }

      // Register 0x00 is the authorization register
      final command = buildWriteCommand(0x00, passwordBytes);

      await characteristic.write(command, withoutResponse: false);

      debugPrint('AUTHORIZATION HANDSHAKE SENT (20-Byte Padded): 802626052E');
    } catch (e) {
      debugPrint('AUTHORIZATION ERROR: $e');
    }
  }

  // =========================================================
  // TOGGLE CHARGE MOSFET
  // =========================================================

  Future<void> setChargeMosfet(BluetoothCharacteristic characteristic, bool enable) async {
    try {
      // FIX: 4-byte strict payload padded to 12 for 20-byte frame
      final valueBytes = enable ? [0x01, 0x00, 0x00, 0x00] : [0x00, 0x00, 0x00, 0x00];

      while (valueBytes.length < 12) {
        valueBytes.add(0x00);
      }

      // Register 0x1D is typically the Charge MOSFET setting
      final command = buildWriteCommand(0x1D, valueBytes);

      // FIX: Force to false so the phone's Bluetooth stack guarantees delivery
      await characteristic.write(command, withoutResponse: false);
      debugPrint('SENT CHARGE MOSFET TOGGLE (20-Byte Padded): ${enable ? "ON" : "OFF"}');
    } catch (e) {
      debugPrint('CHARGE TOGGLE ERROR: $e');
    }
  }

  // =========================================================
  // TOGGLE DISCHARGE MOSFET (MOTOR POWER)
  // =========================================================

  Future<void> setDischargeMosfet(BluetoothCharacteristic characteristic, bool enable) async {
    try {
      // FIX: 4-byte strict payload padded to 12 for 20-byte frame
      final valueBytes = enable ? [0x01, 0x00, 0x00, 0x00] : [0x00, 0x00, 0x00, 0x00];

      while (valueBytes.length < 12) {
        valueBytes.add(0x00);
      }

      // 0x1E is the JK register for the Discharge MOSFET
      final command = buildWriteCommand(0x1E, valueBytes);

      await characteristic.write(command, withoutResponse: false);
      debugPrint('SENT DISCHARGE MOSFET TOGGLE (20-Byte Padded): ${enable ? "ON" : "OFF"}');
    } catch (e) {
      debugPrint('DISCHARGE TOGGLE ERROR: $e');
    }
  }
}
