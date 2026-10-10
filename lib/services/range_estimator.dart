import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RangeEstimator {
  RangeEstimator({
    this.fallbackKmPerSocPercent = 0.75,
    this.minimumGpsAccuracyMeters = 25,
    this.minimumTripDistanceKm = 2.0,
  });

  /// Used until the app has enough real ride data to learn consumption.
  /// 0.75 means 1% battery is estimated to provide 0.75 km.
  final double fallbackKmPerSocPercent;

  /// GPS points less accurate than this are ignored.
  final double minimumGpsAccuracyMeters;

  /// Minimum distance before a ride contributes to the learned estimate.
  final double minimumTripDistanceKm;

  static const _savedWhPerKmKey = 'scooby_learned_wh_per_km';

  double? _learnedWhPerKm;
  double _tripDistanceKm = 0;
  double _tripEnergyWh = 0;

  Position? _lastPosition;
  DateTime? _lastTelemetryTime;
  double? _lastDischargePowerW;

  double? get learnedWhPerKm => _learnedWhPerKm;

  bool get hasLearnedEstimate =>
      _learnedWhPerKm != null && _learnedWhPerKm! > 0;

  Future<void> loadSavedEstimate() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_savedWhPerKmKey);

    if (saved != null && saved > 0) {
      _learnedWhPerKm = saved;
    }
  }

  /// Call this whenever a new BMS voltage/current reading arrives.
  ///
  /// Your parser documents negative current as discharging and positive
  /// current as charging, so charging power is ignored.
  void addTelemetry({
    required double voltage,
    required double current,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final dischargePowerW = math.max(0.0, -(voltage * current));

    final previousTime = _lastTelemetryTime;
    final previousPower = _lastDischargePowerW;

    if (previousTime != null && previousPower != null) {
      final elapsedSeconds = now.difference(previousTime).inSeconds;

      // Ignore gaps, clock changes, and duplicate samples.
      if (elapsedSeconds > 0 && elapsedSeconds <= 15) {
        final averagePowerW = (previousPower + dischargePowerW) / 2;
        _tripEnergyWh += averagePowerW * elapsedSeconds / 3600;
      }
    }

    _lastTelemetryTime = now;
    _lastDischargePowerW = dischargePowerW;
  }

  /// Call this for each GPS position while a ride is active.
  void addPosition(Position position) {
    if (position.accuracy > minimumGpsAccuracyMeters) return;

    final previous = _lastPosition;
    _lastPosition = position;

    if (previous == null) return;

    final meters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      position.latitude,
      position.longitude,
    );

    // Filter GPS jitter and implausibly large jumps.
    if (meters < 3 || meters > 500) return;

    final elapsedSeconds =
        position.timestamp.difference(previous.timestamp).inSeconds;

    if (elapsedSeconds <= 0) return;

    final speedKmh = (meters / elapsedSeconds) * 3.6;

    // Reject a GPS jump that implies an unrealistic scooter speed.
    if (speedKmh > 100) return;

    _tripDistanceKm += meters / 1000;
  }

  /// Use this to get a range estimate for the dashboard.
  ///
  /// Pass remainingCapacityAh from the BMS when available.
  /// If it is unavailable, this uses the static SOC fallback.
  double estimateRangeKm({
    required double socPercent,
    double? remainingCapacityAh,
    double? packVoltage,
  }) {
    final consumption = _learnedWhPerKm;

    if (consumption != null &&
        consumption > 0 &&
        remainingCapacityAh != null &&
        remainingCapacityAh >= 0 &&
        packVoltage != null &&
        packVoltage > 0) {
      final remainingEnergyWh = remainingCapacityAh * packVoltage;
      return remainingEnergyWh / consumption;
    }

    return socPercent.clamp(0, 100) * fallbackKmPerSocPercent;
  }

  /// Call when a ride ends. Only rides with enough distance and energy
  /// contribute to the learned consumption.
  Future<void> finishRide() async {
    if (_tripDistanceKm >= minimumTripDistanceKm && _tripEnergyWh > 0) {
      final rideWhPerKm = _tripEnergyWh / _tripDistanceKm;

      // Reject implausible results, which often come from bad GPS or BMS data.
      if (rideWhPerKm >= 5 && rideWhPerKm <= 500) {
        if (_learnedWhPerKm == null) {
          _learnedWhPerKm = rideWhPerKm;
        } else {
          // Smooth the estimate so a single unusual ride does not change
          // the displayed range too sharply.
          _learnedWhPerKm =
              (_learnedWhPerKm! * 0.7) + (rideWhPerKm * 0.3);
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_savedWhPerKmKey, _learnedWhPerKm!);
      }
    }

    resetRide();
  }

  /// Call when the user starts a new ride, and after finishRide().
  void resetRide() {
    _tripDistanceKm = 0;
    _tripEnergyWh = 0;
    _lastPosition = null;
    _lastTelemetryTime = null;
    _lastDischargePowerW = null;
  }
}