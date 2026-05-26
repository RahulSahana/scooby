class JkBmsParser {

  // =========================================================
  // CHECK IF PACKET LOOKS LIKE JK PACKET
  // =========================================================

  static bool isValidPacket(
      List<int> data,
      ) {

    if (data.length < 10) {
      return false;
    }

    // JK packets usually start with:
    // 4E 57

    return data[0] == 0x4E &&
        data[1] == 0x57;
  }

  // =========================================================
  // PARSE VOLTAGE
  // =========================================================

  static double parseVoltage(
      List<int> data,
      ) {

    try {

      // Example placeholder offsets
      // Adjust later using real packets

      final rawVoltage =
      (data[4] << 8) | data[5];

      return rawVoltage / 100;

    } catch (e) {

      return 0;
    }
  }

  // =========================================================
  // PARSE CURRENT
  // =========================================================

  static double parseCurrent(
      List<int> data,
      ) {

    try {

      final rawCurrent =
      (data[6] << 8) | data[7];

      return rawCurrent / 100;

    } catch (e) {

      return 0;
    }
  }

  // =========================================================
  // PARSE SOC
  // =========================================================

  static int parseSoc(
      List<int> data,
      ) {

    try {

      return data[8];

    } catch (e) {

      return 0;
    }
  }

  // =========================================================
  // PARSE TEMPERATURE
  // =========================================================

  static double parseTemperature(
      List<int> data,
      ) {

    try {

      final rawTemp =
      (data[9] << 8) | data[10];

      return rawTemp / 10;

    } catch (e) {

      return 0;
    }
  }

  // =========================================================
  // PARSE CELL VOLTAGES
  // =========================================================

  static List<double> parseCellVoltages(
      List<int> data,
      ) {

    List<double> cells = [];

    try {

      // Placeholder offsets
      // Will refine using real packets

      for (int i = 0; i < 19; i++) {

        int offset = 12 + (i * 2);

        if (offset + 1 >= data.length) {
          break;
        }

        final rawCell =
        (data[offset] << 8) |
        data[offset + 1];

        cells.add(rawCell / 1000);
      }

    } catch (e) {

      return [];
    }

    return cells;
  }

  // =========================================================
  // DEBUG FULL PACKET
  // =========================================================

  static void debugPacket(
      List<int> data,
      ) {

    final hex = data
        .map(
          (e) => e
          .toRadixString(16)
          .padLeft(2, '0'),
    )
        .join(' ');

    print(
      "JK PACKET: $hex",
    );
  }
}