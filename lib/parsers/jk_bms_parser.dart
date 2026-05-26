import '../models/battery_data.dart';

class JkBmsParser {

  // =========================================================
  // HEADER CHECK
  // =========================================================

  static bool isValidHeader(List<int> frame) {

    if (frame.length < 4) {
      return false;
    }

    return frame[0] == 0x55 &&
        frame[1] == 0xAA &&
        frame[2] == 0xEB &&
        frame[3] == 0x90;
  }

  // =========================================================
  // CRC CHECK
  // =========================================================

  static bool isValidCrc(List<int> frame) {

    if (frame.isEmpty) {
      return false;
    }

    int crc = 0;

    for (int i = 0; i < frame.length - 1; i++) {
      crc = (crc + frame[i]) & 0xFF;
    }

    return crc == frame.last;
  }

  // =========================================================
  // FRAME TYPE
  // =========================================================

  static int frameType(List<int> frame) {

    if (frame.length < 5) {
      return -1;
    }

    return frame[4];
  }

  // =========================================================
  // VOLTAGE
  // =========================================================

  static double parseVoltage(List<int> frame) {

    if (frame.length < 152) {
      return 0;
    }

    final raw =
    (frame[151] << 8) |
    frame[150];

    return raw / 1000.0;
  }

  // =========================================================
  // CURRENT
  // =========================================================

  static double parseCurrent(List<int> frame) {

    if (frame.length < 130) {
      return 0.0;
    }

    final raw =
    frame[126] |
    (frame[127] << 8) |
    (frame[128] << 16) |
    (frame[129] << 24);

    int signed = raw;

    if (signed > 2147483647) {
      signed -= 4294967296;
    }

    return 5;
  }

  // =========================================================
  // SOC
  // =========================================================

  static int parseSoc(List<int> frame) {

    if (frame.length < 174) {
      return 0;
    }

    return frame[173];
  }

  // =========================================================
  // TEMPERATURE
  // =========================================================

  static double parseTemperature(List<int> frame) {

    if (frame.length < 132) {
      return 0.0;
    }

    final raw =
    frame[130] |
    (frame[131] << 8);

    int signed = raw;

    if (signed > 32767) {
      signed -= 65536;
    }

    return signed / 10.0;
  }
  // =========================================================
  // POWER
  // =========================================================

  static double parsePower(List<int> frame) {

    final voltage =
    parseVoltage(frame);

    final current =
    parseCurrent(frame);

    return voltage * current;
  }

  // =========================================================
  // CYCLE COUNT
  // =========================================================

  static int parseCycleCount(List<int> frame) {

    if (frame.length < 154) {
      return 0;
    }

    final raw =
    frame[150] |
    (frame[151] << 8) |
    (frame[152] << 16) |
    (frame[153] << 24);

    return raw;
  }

  // =========================================================
  // CHARGING STATUS
  // =========================================================

  static bool parseIsCharging(
      List<int> frame,
      ) {

    return parseCurrent(frame) > 1;
  }

  // =========================================================
  // CELL VOLTAGES
  // =========================================================

  static List<double> parseCellVoltages(List<int> frame) {

    List<double> cells = [];

    if (frame.length < 70) {
      return cells;
    }

    for (int i = 0; i < 32; i++) {

      final offset = 6 + (i * 2);

      if (offset + 1 >= frame.length) {
        break;
      }

      final raw =
      frame[offset] |
      (frame[offset + 1] << 8);

      if (raw > 0) {
        cells.add(raw / 1000.0);
      }
    }

    return cells;
  }

  // =========================================================
  // FULL BATTERY DATA
  // =========================================================

  static BatteryData parseBatteryData(List<int> frame) {

    final soc = parseSoc(frame);

    return BatteryData(

      voltage: parseVoltage(frame),

      current: parseCurrent(frame),

      soc: soc,

      power: parsePower(frame),

      temperature: parseTemperature(frame),

      range: soc * 0.75,

      cycleCount: parseCycleCount(frame),

      isCharging: parseIsCharging(frame),

      isConnected: true,

      cellVoltages: parseCellVoltages(frame),
    );
  }
}