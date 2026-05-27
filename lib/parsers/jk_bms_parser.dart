import 'dart:typed_data';

import '../models/battery_data.dart';

/// Parser for JK BMS BLE protocol (JK02_32S Cell Info Frame)
///
/// Frame header: 0x55 0xAA 0xEB 0x90
/// All multi-byte integers are little-endian.
/// CRC = sum of all bytes except the last byte, masked to uint8.
class JkBmsParser {

  // =========================================================
  // CONSTANTS
  // =========================================================

  static const List<int> _frameHeader = [0x55, 0xAA, 0xEB, 0x90];

  static const int _frameTypeCell     = 0x02;
  static const int _frameTypeSettings = 0x01;
  static const int _frameTypeDevice   = 0x03;

  static const int _minFrameLength    = 300;
  static const int _maxFrameLength    = 320;
  static const int _crcByteIndex      = 299;

  // Cell Info frame offsets
  static const int _offCellVoltagesStart  = 6;    // uint16 × 32 → bytes 6–69
  static const int _offCellVoltagesEnd    = 70;
  static const int _offPowerTubeTemp      = 144;  // int16,  coeff 0.1 °C
  static const int _offBatteryVoltage     = 150;  // uint32, coeff 0.001 V
  static const int _offChargeCurrent      = 158;  // int32,  coeff 0.001 A
  static const int _offTempSensor1        = 162;  // int16,  coeff 0.1 °C
  static const int _offTempSensor2        = 164;  // int16,  coeff 0.1 °C
  static const int _offErrorsBitmask      = 166;  // uint32
  static const int _offBalanceCurrent     = 170;  // int16,  coeff 0.001 A
  static const int _offBalancingAction    = 172;  // uint8
  static const int _offSoc                = 173;  // uint8,  %
  static const int _offRemainingCapacity  = 174;  // uint32, coeff 0.001 Ah
  static const int _offNominalCapacity    = 178;  // uint32, coeff 0.001 Ah
  static const int _offCycleCount         = 182;  // uint32
  static const int _offTotalCycleCapacity = 186;  // uint32, coeff 0.001 Ah
  static const int _offSoh                = 190;  // uint8,  %
  static const int _offTotalRuntime       = 194;  // uint32, seconds
  static const int _offChargeMosfet       = 198;  // uint8,  0=off 1=on
  static const int _offDischargeMosfet    = 199;  // uint8,  0=off 1=on
  static const int _offHeatingStatus      = 215;  // uint8,  0=off 1=on
  static const int _offTempSensor3        = 258;  // int16,  coeff 0.1 °C
  static const int _offTempSensor4        = 256;  // int16,  coeff 0.1 °C
  static const int _offTempSensor5        = 254;  // int16,  coeff 0.1 °C

  /// Empirically calibrated range coefficient for this scooter.
  /// Approximately 0.75 km per 1 % SOC under typical riding conditions.
  static const double _kmPerSocPercent = 0.75;

  // =========================================================
  // FRAME VALIDATION
  // =========================================================

  /// Returns true if the first 4 bytes match 0x55 0xAA 0xEB 0x90.
  static bool isValidHeader(List<int> frame) {
    if (frame.length < 4) return false;
    for (int i = 0; i < 4; i++) {
      if (frame[i] != _frameHeader[i]) return false;
    }
    return true;
  }

  /// Returns true if the CRC byte at index 299 matches
  /// the sum8 of all preceding bytes.
  static bool isValidCrc(List<int> frame) {
    if (frame.length <= _crcByteIndex) return false;
    int sum = 0;
    for (int i = 0; i < _crcByteIndex; i++) {
      sum = (sum + frame[i]) & 0xFF;
    }
    return sum == frame[_crcByteIndex];
  }

  /// Returns frame type byte (0x01 settings, 0x02 cell info, 0x03 device info)
  /// or -1 if the frame is too short.
  static int frameType(List<int> frame) {
    if (frame.length < 5) return -1;
    return frame[4];
  }

  /// Returns true only for Cell Info frames (0x02) that pass all checks.
  static bool isCellInfoFrame(List<int> frame) {
    return frame.length >= _minFrameLength &&
        frame.length <= _maxFrameLength &&
        isValidHeader(frame) &&
        frameType(frame) == _frameTypeCell &&
        isValidCrc(frame);
  }

  // =========================================================
  // HELPERS
  // =========================================================

  static ByteData _bd(List<int> frame) =>
      ByteData.sublistView(Uint8List.fromList(frame));

  // =========================================================
  // VOLTAGE  (bytes 150–153, uint32, coeff 0.001)
  // =========================================================

  static double parseVoltage(List<int> frame) {
    if (frame.length < _offBatteryVoltage + 4) return 0.0;
    return _bd(frame).getUint32(_offBatteryVoltage, Endian.little) / 1000.0;
  }

  // =========================================================
  // CURRENT  (bytes 158–161, int32, coeff 0.001)
  // Positive = charging, negative = discharging.
  // =========================================================

  static double parseCurrent(List<int> frame) {
    if (frame.length < _offChargeCurrent + 4) return 0.0;
    return _bd(frame).getInt32(_offChargeCurrent, Endian.little) / 1000.0;
  }

  // =========================================================
  // POWER  (derived: voltage × current)
  // =========================================================

  static double parsePower(List<int> frame) {
    return parseVoltage(frame) * parseCurrent(frame);
  }

  // =========================================================
  // SOC  (byte 173, uint8, %)
  // =========================================================

  static int parseSoc(List<int> frame) {
    if (frame.length < _offSoc + 1) return 0;
    return frame[_offSoc];
  }

  // =========================================================
  // SOH  (byte 190, uint8, %)
  // =========================================================

  static int parseSoh(List<int> frame) {
    if (frame.length < _offSoh + 1) return 0;
    return frame[_offSoh];
  }

  // =========================================================
  // TEMPERATURE SENSOR 1  (bytes 162–163, int16, coeff 0.1)
  // =========================================================

  static double parseTemperature(List<int> frame) {
    if (frame.length < _offTempSensor1 + 2) return 0.0;
    return _bd(frame).getInt16(_offTempSensor1, Endian.little) / 10.0;
  }

  // =========================================================
  // TEMPERATURE SENSOR 2  (bytes 164–165, int16, coeff 0.1)
  // =========================================================

  static double parseTemperature2(List<int> frame) {
    if (frame.length < _offTempSensor2 + 2) return 0.0;
    return _bd(frame).getInt16(_offTempSensor2, Endian.little) / 10.0;
  }

  // =========================================================
  // POWER TUBE TEMPERATURE  (bytes 144–145, int16, coeff 0.1)
  // =========================================================

  static double parsePowerTubeTemperature(List<int> frame) {
    if (frame.length < _offPowerTubeTemp + 2) return 0.0;
    return _bd(frame).getInt16(_offPowerTubeTemp, Endian.little) / 10.0;
  }

  // =========================================================
  // CYCLE COUNT  (bytes 182–185, uint32)
  // =========================================================

  static int parseCycleCount(List<int> frame) {
    if (frame.length < _offCycleCount + 4) return 0;
    return _bd(frame).getUint32(_offCycleCount, Endian.little);
  }

  // =========================================================
  // REMAINING CAPACITY  (bytes 174–177, uint32, coeff 0.001 Ah)
  // =========================================================

  static double parseRemainingCapacity(List<int> frame) {
    if (frame.length < _offRemainingCapacity + 4) return 0.0;
    return _bd(frame).getUint32(_offRemainingCapacity, Endian.little) / 1000.0;
  }

  // =========================================================
  // NOMINAL CAPACITY  (bytes 178–181, uint32, coeff 0.001 Ah)
  // =========================================================

  static double parseNominalCapacity(List<int> frame) {
    if (frame.length < _offNominalCapacity + 4) return 0.0;
    return _bd(frame).getUint32(_offNominalCapacity, Endian.little) / 1000.0;
  }

  // =========================================================
  // TOTAL CYCLE CAPACITY  (bytes 186–189, uint32, coeff 0.001 Ah)
  // =========================================================

  static double parseTotalCycleCapacity(List<int> frame) {
    if (frame.length < _offTotalCycleCapacity + 4) return 0.0;
    return _bd(frame).getUint32(_offTotalCycleCapacity, Endian.little) / 1000.0;
  }

  // =========================================================
  // TOTAL RUNTIME  (bytes 194–197, uint32, seconds)
  // =========================================================

  static int parseTotalRuntime(List<int> frame) {
    if (frame.length < _offTotalRuntime + 4) return 0;
    return _bd(frame).getUint32(_offTotalRuntime, Endian.little);
  }

  // =========================================================
  // BALANCE CURRENT  (bytes 170–171, int16, coeff 0.001 A)
  // =========================================================

  static double parseBalanceCurrent(List<int> frame) {
    if (frame.length < _offBalanceCurrent + 2) return 0.0;
    return _bd(frame).getInt16(_offBalanceCurrent, Endian.little) / 1000.0;
  }

  // =========================================================
  // BALANCING ACTION  (byte 172)
  // 0 = off, 1 = charging balancer, 2 = discharging balancer
  // =========================================================

  static int parseBalancingAction(List<int> frame) {
    if (frame.length < _offBalancingAction + 1) return 0;
    return frame[_offBalancingAction];
  }

  // =========================================================
  // MOSFET STATUS
  // =========================================================

  static bool parseChargeMosfet(List<int> frame) {
    if (frame.length < _offChargeMosfet + 1) return false;
    return frame[_offChargeMosfet] == 1;
  }

  static bool parseDischargeMosfet(List<int> frame) {
    if (frame.length < _offDischargeMosfet + 1) return false;
    return frame[_offDischargeMosfet] == 1;
  }

  // =========================================================
  // HEATING STATUS  (byte 215)
  // =========================================================

  static bool parseHeatingStatus(List<int> frame) {
    if (frame.length < _offHeatingStatus + 1) return false;
    return frame[_offHeatingStatus] == 1;
  }

  // =========================================================
  // ERRORS BITMASK  (bytes 166–169, uint32)
  // =========================================================

  static int parseErrorsBitmask(List<int> frame) {
    if (frame.length < _offErrorsBitmask + 4) return 0;
    return _bd(frame).getUint32(_offErrorsBitmask, Endian.little);
  }

  /// Returns a list of human-readable active error labels.
  static List<String> parseActiveErrors(List<int> frame) {
    final bitmask = parseErrorsBitmask(frame);
    if (bitmask == 0) return [];
    final List<String> errors = [];
    for (final entry in _errorBitLabels.entries) {
      if (bitmask & (1 << entry.key) != 0) {
        errors.add(entry.value);
      }
    }
    return errors;
  }

  static const Map<int, String> _errorBitLabels = {
    0:  'Wire resistance',
    1:  'MOSFET overtemperature',
    2:  'Cell count mismatch',
    4:  'Battery fully charged',
    5:  'Battery pack overvoltage',
    6:  'Charge overcurrent',
    7:  'Charge short circuit',
    8:  'Charge overtemperature',
    9:  'Charge undertemperature',
    10: 'Coprocessor communication error',
    11: 'Cell undervoltage',
    12: 'Battery pack undervoltage',
    13: 'Discharge overcurrent',
    14: 'Discharge short circuit',
    15: 'Discharge overtemperature',
    16: 'Charging MOSFET abnormal',
    17: 'Discharging MOSFET abnormal',
    18: 'GPS disconnected',
    19: 'Modify password in time',
    20: 'Discharge on failed',
    21: 'Battery overtemperature',
    22: 'Temperature sensor anomaly',
    23: 'PL module anomaly',
    24: 'SCP release failed',
    25: 'Discharge OCP II',
    26: 'Discharge OCP III',
    27: 'Discharge undertemperature alarm',
    28: 'GPS remote lock',
  };

  // =========================================================
  // CELL VOLTAGES  (bytes 6–69, uint16 × 32, coeff 0.001 V)
  // Only cells with voltage in the valid range 1.0–5.0 V
  // are included; zero-padded inactive cells are skipped.
  // =========================================================

  static List<double> parseCellVoltages(List<int> frame) {
    if (frame.length < _offCellVoltagesEnd) return [];
    final List<double> voltages = [];
    for (int offset = _offCellVoltagesStart;
    offset < _offCellVoltagesEnd;
    offset += 2) {
      final raw = _bd(frame).getUint16(offset, Endian.little);
      final voltage = raw / 1000.0;
      if (voltage >= 1.0 && voltage <= 5.0) {
        voltages.add(voltage);
      }
    }
    return voltages;
  }

  // =========================================================
  // CELL STATISTICS  (derived from cell voltages)
  // =========================================================

  static double parseCellVoltageMax(List<int> frame) {
    final cells = parseCellVoltages(frame);
    if (cells.isEmpty) return 0.0;
    return cells.reduce((a, b) => a > b ? a : b);
  }

  static double parseCellVoltageMin(List<int> frame) {
    final cells = parseCellVoltages(frame);
    if (cells.isEmpty) return 0.0;
    return cells.reduce((a, b) => a < b ? a : b);
  }

  static double parseCellVoltageDelta(List<int> frame) {
    return parseCellVoltageMax(frame) - parseCellVoltageMin(frame);
  }

  static double parseCellVoltageAverage(List<int> frame) {
    final cells = parseCellVoltages(frame);
    if (cells.isEmpty) return 0.0;
    return cells.reduce((a, b) => a + b) / cells.length;
  }

  // =========================================================
  // CHARGING STATUS  (derived from current)
  // =========================================================

  static bool parseIsCharging(List<int> frame) {
    return parseCurrent(frame) > 0.5;
  }

  // =========================================================
  // ESTIMATED RANGE  (empirically calibrated: ~0.75 km / 1% SOC)
  // =========================================================

  static double parseRange(List<int> frame) {
    return parseSoc(frame) * _kmPerSocPercent;
  }

  // =========================================================
  // FULL BATTERY DATA
  // =========================================================

  static BatteryData parseBatteryData(List<int> frame) {
    final soc = parseSoc(frame);
    return BatteryData(
      voltage:      parseVoltage(frame),
      current:      parseCurrent(frame),
      soc:          soc,
      power:        parsePower(frame),
      temperature:  parseTemperature(frame),
      range:        soc * _kmPerSocPercent,
      cycleCount:   parseCycleCount(frame),
      soh:          parseSoh(frame), // <--- Plugged in here!
      isCharging:   parseIsCharging(frame),
      isConnected:  true,
      cellVoltages: parseCellVoltages(frame),
    );
  }
}