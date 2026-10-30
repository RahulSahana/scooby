import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BackgroundSyncService {
  static const MethodChannel _channel = MethodChannel('scooby/background_sync');

  static Future<bool> start() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await _channel.invokeMethod<void>('start');
      return true;
    } on PlatformException catch (error) {
      debugPrint('Could not start Scooby background service: ${error.message}');
      return false;
    } on MissingPluginException {
      debugPrint('Scooby background service is unavailable on this platform.');
      return false;
    }
  }

  static Future<void> stop() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException catch (error) {
      debugPrint('Could not stop Scooby background service: ${error.message}');
    } on MissingPluginException {
      // The Android service was not started.
    }
  }
}
