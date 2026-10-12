import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(settings: settings);
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<void> showChargingAlert({required int batteryPercent}) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'scooby_battery_alerts',
        'Battery alerts',
        channelDescription: 'Charging and battery warning alerts',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(
      id: 1,
      title: 'Scooby charging alert',
      body: 'Your battery has reached $batteryPercent%.',
      notificationDetails: details,
    );
  }

  Future<void> showTemperatureAlert({
    required double temperatureCelsius,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'scooby_temperature_alerts',
        'Temperature alerts',
        channelDescription: 'Battery temperature warning alerts',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(
      id: 2,
      title: 'Scooby temperature alert',
      body: 'Your battery temperature has reached '
          '${temperatureCelsius.toStringAsFixed(1)}°C.',
      notificationDetails: details,
    );
  }

  Future<void> showRangeAlert({required double rangeKm}) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'scooby_range_alerts',
        'Range alerts',
        channelDescription: 'Low remaining range alerts',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(
      id: 3,
      title: 'Scooby low range alert',
      body: 'Estimated remaining range is '
          '${rangeKm.toStringAsFixed(1)} km.',
      notificationDetails: details,
    );
  }

  Future<void> showDisconnectAlert() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'scooby_connection_alerts',
        'Connection alerts',
        channelDescription: 'Scooter Bluetooth connection alerts',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(
      id: 4,
      title: 'Scooby disconnected',
      body: 'The scooter lost its Bluetooth connection.',
      notificationDetails: details,
    );
  }
}