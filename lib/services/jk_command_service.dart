import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class JkCommandService {

  Future<void> sendInfoRequest(
      BluetoothCharacteristic characteristic,
      ) async {

    List<int> request = [
      0x4E,
      0x57,
      0x00,
      0x13,
      0x00,
      0x00,
      0x00,
      0x00,
      0x06,
      0x03,
      0x00,
      0x00,
      0x00,
      0x00,
      0x68,
      0x00,
      0x00,
      0x01,
      0x29,
    ];

    final hex = request
        .map(
          (e) => e
          .toRadixString(16)
          .padLeft(2, '0'),
    )
        .join(' ');

    debugPrint(
      "JK REQUEST SENT: $hex",
    );

    await characteristic.write(
      request,
      withoutResponse: false,
    );
  }
}