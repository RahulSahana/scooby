import 'package:flutter/material.dart';

class JkCodeGenerator {

  // =======================================================
  // 1. TIME-BASED "FORCE UPDATE" CODE
  // (This is the code that changes every hour on the website)
  // =======================================================
  static String generateForceUpdateCode(DateTime time) {
    // The website generates this by prefixing '40' to the current YYMMDD
    // Note: The website uses UTC/Chinese time logic, so hours might offset slightly
    String year = time.year.toString().substring(2, 4); // '26' for 2026
    String month = time.month.toString().padLeft(2, '0');
    String day = time.day.toString().padLeft(2, '0');

    return '40$year$month$day';
  }

  // =======================================================
  // 2. SERIAL-BASED "SETTINGS PASSWORD"
  // (The algorithm that usually fails on newer V20 boards)
  // =======================================================
  static String generateSettingsPassword(String fullSerialNumber) {
    try {
      // WARNING: This is a recreation of the legacy JS algorithm.
      // Older JK BMS serials were strictly numbers (e.g., "200526001234").
      // Your V20 serial is "26050550930AM62139829".

      // The old algorithm tries to slice specific numeric indices out of the string
      // and perform math on them to generate a 6 to 8 digit unlock code.

      if (fullSerialNumber.contains(RegExp(r'[A-Za-z]'))) {
        debugPrint('WARNING: Serial contains letters. The legacy math will likely fail or output garbage.');
      }

      // 1. Strip the date from the front (we know your date is 6 chars: '260505')
      String rawSerial = fullSerialNumber.substring(6); // '50930AM62139829'

      // 2. The legacy JS usually extracts the last 4 to 6 digits to scramble
      // Because yours contains "AM6", doing math on this string will crash standard number parsers.

      // To truly test what the website spits out, you can run a hash or string extraction here.
      // (For now, we return a simulated output so you can test the UI)
      return 'CALC_FAILED_ALPHANUMERIC';

    } catch (e) {
      return 'ERROR: $e';
    }
  }
}