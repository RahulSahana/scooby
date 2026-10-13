import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory PandalStop.fromJson(Map<String, dynamic> json) {
    return PandalStop(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class SavedTrip {
  const SavedTrip({
    required this.id,
    required this.name,
    required this.description,
    required this.savedAt,
    required this.stops,
  });

  final String id;
  final String name;
  final String description;
  final DateTime savedAt;
  final List<PandalStop> stops;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'savedAt': savedAt.toIso8601String(),
        'stops': stops.map((stop) => stop.toJson()).toList(),
      };

  factory SavedTrip.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'] as List? ?? const [];

    return SavedTrip(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Saved trip',
      description: json['description'] as String? ?? '',
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.now(),
      stops: rawStops
          .map((item) => PandalStop.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
    );
  }
}

class NavigationProvider extends ChangeNotifier {
  static const _savedTripsKey = 'scooby_saved_trips_v1';
  static const _nextTripNumberKey = 'scooby_next_trip_number_v1';

  List<PandalStop> _stops = [];
  final Set<String> _completedStopIds = {};

  final List<SavedTrip> _savedTrips = [];
  int _nextTripNumber = 1;

  bool _isNavigating = false;
  DateTime? _tripStartedAt;
  double? _currentLatitude;
  double? _currentLongitude;
  double _remainingDistanceKm = 0;
  Duration _remainingDuration = Duration.zero;

  Completer<void>? _initCompleter;

  NavigationProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTripsJson = prefs.getString(_savedTripsKey);

    if (savedTripsJson != null) {
      try {
        final decoded = jsonDecode(savedTripsJson) as List;
        _savedTrips
          ..clear()
          ..addAll(
            decoded.map(
              (item) => SavedTrip.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            ),
          );
      } catch (error) {
        debugPrint('Could not restore saved trips: $error');
      }
    }

    _nextTripNumber =
        prefs.getInt(_nextTripNumberKey) ?? (_savedTrips.length + 1);

    notifyListeners();
  }

  Future<void> get ready => (_initCompleter ??= Completer<void>()..complete(_init())).future;

  List<PandalStop> get stops => List.unmodifiable(_stops);
  Set<String> get completedStopIds => Set.unmodifiable(_completedStopIds);
  List<SavedTrip> get savedTrips => List.unmodifiable(_savedTrips);
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

  Future<SavedTrip?> saveCurrentTrip({
    String description = '',
  }) async {
    await ready;

    if (_stops.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();

    final savedTrip = SavedTrip(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: 'Trip $_nextTripNumber',
      description: description.trim(),
      savedAt: DateTime.now(),
      stops: List<PandalStop>.of(_stops),
    );

    _nextTripNumber++;
    _savedTrips.insert(0, savedTrip);

    await prefs.setString(
      _savedTripsKey,
      jsonEncode(_savedTrips.map((trip) => trip.toJson()).toList()),
    );
    await prefs.setInt(_nextTripNumberKey, _nextTripNumber);

    notifyListeners();
    return savedTrip;
  }

  Future<void> deleteSavedTrip(String id) async {
    await ready;

    final prefs = await SharedPreferences.getInstance();
    _savedTrips.removeWhere((trip) => trip.id == id);

    await prefs.setString(
      _savedTripsKey,
      jsonEncode(_savedTrips.map((trip) => trip.toJson()).toList()),
    );

    notifyListeners();
  }

  Future<void> loadSavedTrip(String id) async {
    await ready;

    SavedTrip? savedTrip;
    for (final trip in _savedTrips) {
      if (trip.id == id) {
        savedTrip = trip;
        break;
      }
    }
    if (savedTrip == null) return;

    // Load it as a plan. The user can start navigation separately.
    setStops(savedTrip.stops);
  }
}
