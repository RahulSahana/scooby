import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../data/battery_data.dart';

class ScooterPairing {
  const ScooterPairing({
    required this.deviceId,
    required this.token,
    required this.bleDeviceId,
    required this.scooterName,
  });

  final String deviceId;
  final String token;
  final String bleDeviceId;
  final String scooterName;
}

class RemoteTelemetrySnapshot {
  const RemoteTelemetrySnapshot({
    required this.battery,
    required this.receivedAt,
    this.location,
  });

  final Map<String, dynamic> battery;
  final DateTime receivedAt;
  final Map<String, dynamic>? location;
}

class RemoteTelemetryService {
  RemoteTelemetryService({http.Client? client})
    : _client = client ?? http.Client();

  static final Uri _baseUri = Uri.parse('https://scooby-backend.vercel.app');

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final http.Client _client;
  final Random _random = Random.secure();

  String _storageKey(String bleDeviceId, String suffix) {
    final encodedId = base64Url
        .encode(utf8.encode(bleDeviceId))
        .replaceAll('=', '');
    return 'scooby.remote.$encodedId.$suffix';
  }

  String _legacyDeviceId(String bleDeviceId) {
    final normalized = bleDeviceId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final candidate = 'scooby_$normalized';
    return candidate.length <= 80 ? candidate : candidate.substring(0, 80);
  }

  String _makeDeviceId(String bleDeviceId) {
    final normalized = bleDeviceId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final suffix = _makeToken().substring(0, 12);
    final maxBaseLength = 80 - 'scooby__'.length - suffix.length;
    final base = normalized.length <= maxBaseLength
        ? normalized
        : normalized.substring(0, maxBaseLength);
    return 'scooby_${base}_$suffix';
  }

  String _makeToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Future<ScooterPairing?> pairingFor(String bleDeviceId) async {
    final deviceId = await _secureStorage.read(
      key: _storageKey(bleDeviceId, 'deviceId'),
    );
    final token = await _secureStorage.read(
      key: _storageKey(bleDeviceId, 'token'),
    );
    final name = await _secureStorage.read(
      key: _storageKey(bleDeviceId, 'name'),
    );
    if (deviceId == null || token == null) return null;
    return ScooterPairing(
      deviceId: deviceId,
      token: token,
      bleDeviceId: bleDeviceId,
      scooterName: name ?? 'Scooby scooter',
    );
  }

  Future<ScooterPairing> ensureLocalPairing(
    String bleDeviceId, {
    String scooterName = 'Scooby scooter',
  }) async {
    final existing = await pairingFor(bleDeviceId);
    // Older builds used the BMS Bluetooth address as the server publisher ID.
    // That made every phone share one server record but generate a different
    // token, so all but the first phone were rejected with HTTP 403.
    if (existing != null &&
        existing.deviceId != _legacyDeviceId(bleDeviceId)) {
      return existing;
    }

    final pairing = ScooterPairing(
      deviceId: _makeDeviceId(bleDeviceId),
      token: _makeToken(),
      bleDeviceId: bleDeviceId,
      scooterName: scooterName,
    );
    await _writePairing(pairing);
    return pairing;
  }

  Future<void> _writePairing(ScooterPairing pairing) async {
    await _secureStorage.write(
      key: _storageKey(pairing.bleDeviceId, 'deviceId'),
      value: pairing.deviceId,
    );
    await _secureStorage.write(
      key: _storageKey(pairing.bleDeviceId, 'token'),
      value: pairing.token,
    );
    await _secureStorage.write(
      key: _storageKey(pairing.bleDeviceId, 'name'),
      value: pairing.scooterName,
    );
  }

  Future<void> publishLatest({
    required ScooterPairing pairing,
    required BatteryData battery,
    Map<String, double>? location,
  }) async {
    final response = await _client
        .post(
          _baseUri.resolve('/api/telemetry'),
          headers: {
            'Authorization': 'Bearer ${pairing.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'deviceId': pairing.deviceId,
            'publisherId':
                'phone_${_deviceIdForPublisher(pairing.bleDeviceId)}',
            'observedAt': DateTime.now().toUtc().toIso8601String(),
            'battery': {
              'voltage': battery.voltage,
              'current': battery.current,
              'soc': battery.soc,
              'temperature': battery.temperature,
              'power': battery.power,
              'range': battery.range,
              'cycleCount': battery.cycleCount,
              'cellVoltages': battery.cellVoltages,
              'isCharging': battery.isCharging,
              'isDischarging': battery.isDischarging,
            },
            'location': location == null
                ? null
                : {
                    'latitude': location['latitude'],
                    'longitude': location['longitude'],
                  },
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Telemetry upload failed (${response.statusCode}).');
    }
  }

  String _deviceIdForPublisher(String value) {
    final normalized = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final candidate = normalized.length < 8 ? 'scooby_$normalized' : normalized;
    return candidate.length <= 80 ? candidate : candidate.substring(0, 80);
  }

  Future<RemoteTelemetrySnapshot?> fetchPublicLatest() async {
    final response = await _client
        .get(_baseUri.resolve('/api/public-latest'))
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Telemetry fetch failed (${response.statusCode}).');
    }

    return _decodeSnapshot(response.body);
  }

  RemoteTelemetrySnapshot _decodeSnapshot(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['payload'] is! Map) {
      throw const FormatException('Server returned invalid telemetry.');
    }
    final payload = Map<String, dynamic>.from(decoded['payload'] as Map);
    final battery = payload['battery'];
    if (battery is! Map) {
      throw const FormatException('Server returned incomplete battery data.');
    }
    final receivedAt = DateTime.tryParse(
      decoded['receivedAt'] as String? ?? '',
    );
    if (receivedAt == null) {
      throw const FormatException('Server returned an invalid timestamp.');
    }
    final rawLocation = payload['location'];

    return RemoteTelemetrySnapshot(
      battery: Map<String, dynamic>.from(battery),
      receivedAt: receivedAt.toLocal(),
      location: rawLocation is Map
          ? Map<String, dynamic>.from(rawLocation)
          : null,
    );
  }

  void dispose() => _client.close();
}
