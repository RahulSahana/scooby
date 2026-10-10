import 'package:flutter/foundation.dart';

class PandalStop {
  const PandalStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
}

class NavigationProvider extends ChangeNotifier {
  List<PandalStop> _stops = [];
  final Set<String> _completedStopIds = {};

  bool _isNavigating = false;
  DateTime? _tripStartedAt;
  double? _currentLatitude;
  double? _currentLongitude;
  double _remainingDistanceKm = 0;
  Duration _remainingDuration = Duration.zero;

  List<PandalStop> get stops => List.unmodifiable(_stops);
  Set<String> get completedStopIds => Set.unmodifiable(_completedStopIds);
  bool get isNavigating => _isNavigating;
  DateTime? get tripStartedAt => _tripStartedAt;
  double? get currentLatitude => _currentLatitude;
  double? get currentLongitude => _currentLongitude;
  double get remainingDistanceKm => _remainingDistanceKm;
  Duration get remainingDuration => _remainingDuration;

  int get completedCount => _completedStopIds.length;

  PandalStop? get nextStop {
    for (final stop in _stops) {
      if (!_completedStopIds.contains(stop.id)) return stop;
    }
    return null;
  }

  void setStops(List<PandalStop> stops) {
    _stops = List.of(stops);
    _completedStopIds.clear();
    _isNavigating = false;
    _tripStartedAt = null;
    notifyListeners();
  }

  void startNavigation() {
    if (_stops.isEmpty) return;

    _isNavigating = true;
    _tripStartedAt ??= DateTime.now();
    notifyListeners();
  }

  void markStopCompleted(String stopId) {
    if (!_stops.any((stop) => stop.id == stopId)) return;

    _completedStopIds.add(stopId);

    if (_completedStopIds.length == _stops.length) {
      _isNavigating = false;
      _remainingDistanceKm = 0;
      _remainingDuration = Duration.zero;
    }

    notifyListeners();
  }

  void updateCurrentLocation(double latitude, double longitude) {
    _currentLatitude = latitude;
    _currentLongitude = longitude;
    notifyListeners();
  }

  void updateRouteProgress({
    required double remainingDistanceKm,
    required Duration remainingDuration,
  }) {
    _remainingDistanceKm = remainingDistanceKm;
    _remainingDuration = remainingDuration;
    notifyListeners();
  }

  void endTrip() {
    _stops = [];
    _completedStopIds.clear();
    _isNavigating = false;
    _tripStartedAt = null;
    _currentLatitude = null;
    _currentLongitude = null;
    _remainingDistanceKm = 0;
    _remainingDuration = Duration.zero;
    notifyListeners();
  }
}