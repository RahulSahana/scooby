import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mappls_gl/mappls_gl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';


import '../../providers/battery_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../theme/app_colors.dart';
import 'pandal_picker_sheet.dart';
import '../../data/pandal_data.dart';

class NavigateScreen extends StatefulWidget {
  const NavigateScreen({super.key});

  @override
  State<NavigateScreen> createState() => _NavigateScreenState();
}

class _NavigateScreenState extends State<NavigateScreen> {
  // Sample Kolkata coordinates. Replace with verified Mappls search results.

  MapplsMapController? _mapController;
  bool _mapStyleLoaded = false;
  Line? _routeLine;
  List<LatLng> _pendingRoutePoints = [];
  final List<Symbol> _stopSymbols = [];
/// returning Home
  double? _distanceToHomeKm;
  DateTime? _lastHomeRouteRequestAt;
  Position? _lastHomeRouteOrigin;
  bool _homeRouteRequestInProgress = false;
  int _homeRouteRequestToken = 0;

  PandalStop? get _homeStop {
    for (final entry in pandalCatalog) {
      if (entry.stop.id == 'home') return entry.stop;
    }
    return null;
  }

  Future<void> _updateHomeRoute(
      Position origin, {
        bool force = false,
      }) async {
    final home = _homeStop;
    if (home == null || _homeRouteRequestInProgress) return;

    final now = DateTime.now();

    if (!force &&
        _lastHomeRouteRequestAt != null &&
        _lastHomeRouteOrigin != null) {
      final elapsed = now.difference(_lastHomeRouteRequestAt!);
      final movedMeters = Geolocator.distanceBetween(
        _lastHomeRouteOrigin!.latitude,
        _lastHomeRouteOrigin!.longitude,
        origin.latitude,
        origin.longitude,
      );

      if (elapsed < const Duration(minutes: 1) || movedMeters < 400) {
        return;
      }
    }

    _homeRouteRequestInProgress = true;
    _lastHomeRouteRequestAt = now;
    _lastHomeRouteOrigin = origin;
    final requestToken = ++_homeRouteRequestToken;

    try {
      final response = await MapplsDirection(
        origin: LatLng(origin.latitude, origin.longitude),
        destination: LatLng(home.latitude, home.longitude),
      ).callDirection();

      if (!mounted || requestToken != _homeRouteRequestToken) return;

      final routes = response?.routes;
      if (routes == null || routes.isEmpty) return;

      final distanceMeters = routes.first.distance;
      if (distanceMeters == null || distanceMeters <= 0) return;

      setState(() {
        _distanceToHomeKm = distanceMeters / 1000;
      });
    } catch (error) {
      debugPrint('Could not update route to Home: $error');
    } finally {
      if (requestToken == _homeRouteRequestToken) {
        _homeRouteRequestInProgress = false;
      }
    }
  }

  Future<void> _syncStopMarkers(List<PandalStop> stops) async {
    final controller = _mapController;
    if (!_mapStyleLoaded || controller == null) return;

    for (final symbol in List<Symbol>.from(_stopSymbols)) {
      await controller.removeSymbol(symbol);
    }
    _stopSymbols.clear();

    for (var index = 0; index < stops.length; index++) {
      final stop = stops[index];
      final letter = String.fromCharCode(65 + index); // A, B, C...

      final symbol = await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(stop.latitude, stop.longitude),
          textField: letter,
          textSize: 18,
          textColor: '#008F7A',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2,
        ),
      );

      _stopSymbols.add(symbol);
    }
  }

  StreamSubscription<Position>? _positionSubscription;
  String? _arrivalCandidateId;
  int _arrivalFixCount = 0;

  static const int _maximumStopsForGoogleMaps = 10;

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestAndDrawRoute(
      Position origin,
      NavigationProvider trip,
      ) async {
    final stops = trip.stops
        .where((stop) => !trip.completedStopIds.contains(stop.id))
        .toList();

    if (stops.isEmpty) return;

    try {
      final response = await MapplsDirection(
        origin: LatLng(origin.latitude, origin.longitude),
        destination: LatLng(
          stops.last.latitude,
          stops.last.longitude,
        ),
        waypoint: stops
            .take(stops.length - 1)
            .map((stop) => LatLng(stop.latitude, stop.longitude))
            .toList(),
      ).callDirection();

      if (response == null ||
          response.routes == null ||
          response.routes!.isEmpty) {
        _showMessage('Mappls did not return a route for these stops.');
        return;
      }

      final route = response.routes!.first;
      final distance = route.distance ?? 0.0;
      final duration = route.duration ?? 0.0;

      trip.updateRouteProgress(
        remainingDistanceKm: distance / 1000,
        remainingDuration: Duration(
          seconds: duration.round(),
        ),
      );

      final geometry = route.geometry;
      if (geometry == null || geometry.isEmpty) {
        _showMessage('Mappls returned a route without map geometry.');
        return;
      }

      _pendingRoutePoints = _decodePolyline6(geometry);
      await _drawPendingRoute();
    } catch (error) {
      _showMessage(
        'Could not get a Mappls route. Check route API access and pandal locations.',
      );
    }
  }

  Future<void> _drawPendingRoute() async {
    final controller = _mapController;
    final points = _pendingRoutePoints;

    if (!_mapStyleLoaded || controller == null || points.length < 2) return;

    final previousLine = _routeLine;
    if (previousLine != null) {
      await controller.removeLine(previousLine);
    }

    _routeLine = await controller.addLine(
      LineOptions(
        geometry: points,
        lineColor: '#13BFA5',
        lineWidth: 5,
      ),
    );

    final latitudes = points.map((point) => point.latitude).toList()..sort();
    final longitudes = points.map((point) => point.longitude).toList()..sort();

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          northeast: LatLng(latitudes.last, longitudes.last),
          southwest: LatLng(latitudes.first, longitudes.first),
        ),
        top: 32,
        left: 32,
        bottom: 32,
        right: 32,
      ),
    );
  }

  List<LatLng> _decodePolyline6(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;

    while (index < encoded.length) {
      var result = 0;
      var shift = 0;
      int byte;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);

      latitude += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      result = 0;
      shift = 0;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);

      longitude += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(
        LatLng(latitude / 1000000, longitude / 1000000),
      );
    }

    return points;
  }

  Future<void> _addStop() async {
    final trip = context.read<NavigationProvider>();
    final remainingSlots = _maximumStopsForGoogleMaps - trip.stops.length;

    if (remainingSlots <= 0) {
      _showMessage('You have reached the maximum number of stops for this trip.');
      return;
    }

    final selectedStops = await showModalBottomSheet<List<PandalStop>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PandalPickerSheet(
        excludedStopIds: trip.stops.map((stop) => stop.id).toSet(),
        maxSelectable: remainingSlots,
      ),
    );

    if (!mounted || selectedStops == null || selectedStops.isEmpty) return;

    final updatedStops = [...trip.stops, ...selectedStops];
    trip.setStops(updatedStops);
    await _syncStopMarkers(updatedStops);
  }

  void _removeStop(PandalStop stop) {
    final trip = context.read<NavigationProvider>();
    final updatedStops =
        trip.stops.where((item) => item.id != stop.id).toList();

    trip.setStops(updatedStops);
    unawaited(_syncStopMarkers(updatedStops));
  }

  Future<void> _startNavigation() async {
    final trip = context.read<NavigationProvider>();

    if (trip.stops.isEmpty) {
      _showMessage('Add at least one pandal before starting.');
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;

    if (!serviceEnabled) {
      _showMessage('Turn on Location on your phone to start trip tracking.');
      return;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (!mounted) return;

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showMessage('Allow location access to track pandal arrivals.');
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      trip.updateCurrentLocation(position.latitude, position.longitude);
      trip.startNavigation();
      await Future.wait([
        _requestAndDrawRoute(position, trip),
        _updateHomeRoute(position, force: true),
      ]);

      await _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(_onPosition);
    } catch (_) {
      _showMessage('Could not get your location. Check GPS and try again.');
    }
  }

  void _onPosition(Position position) {
    if (!mounted) return;

    final trip = context.read<NavigationProvider>();
    if (!trip.isNavigating) return;

    trip.updateCurrentLocation(position.latitude, position.longitude);

    // Ignore inaccurate GPS fixes for arrival detection.
    if (position.accuracy > 35) return;

    unawaited(_updateHomeRoute(position));

    final nextStop = trip.nextStop;
    if (nextStop == null) return;

    final distanceMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      nextStop.latitude,
      nextStop.longitude,
    );

    // Require two fixes within 60 m to reduce false arrivals.
    if (distanceMeters <= 60) {
      if (_arrivalCandidateId == nextStop.id) {
        _arrivalFixCount++;
      } else {
        _arrivalCandidateId = nextStop.id;
        _arrivalFixCount = 1;
      }

      if (_arrivalFixCount >= 2) {
        trip.markStopCompleted(nextStop.id);
        _arrivalCandidateId = null;
        _arrivalFixCount = 0;
      }
    } else {
      _arrivalCandidateId = null;
      _arrivalFixCount = 0;
    }
  }

  void _setStopCompleted(PandalStop stop, bool? checked) {
    if (checked != true) return;

    context.read<NavigationProvider>().markStopCompleted(stop.id);
  }

  Future<void> _openGoogleMaps(NavigationProvider trip) async {
    final remainingStops = trip.stops
        .where((stop) => !trip.completedStopIds.contains(stop.id))
        .toList();

    if (remainingStops.isEmpty) {
      _showMessage('All pandals in this trip are completed.');
      return;
    }

    final destination = remainingStops.last;
    final waypoints = remainingStops
        .take(remainingStops.length - 1)
        .map((stop) => '${stop.latitude},${stop.longitude}')
        .join('|');

    final uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'destination': '${destination.latitude},${destination.longitude}',
        'travelmode': 'driving',
        if (waypoints.isNotEmpty) 'waypoints': waypoints,
      },
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      _showMessage('Could not open Google Maps.');
    }
  }

  Future<void> _clearMapOverlays() async {
    final controller = _mapController;
    final routeLine = _routeLine;
    final symbols = List<Symbol>.from(_stopSymbols);

    // Clear local references so a later trip starts clean.
    _routeLine = null;
    _stopSymbols.clear();
    _pendingRoutePoints.clear();

    if (!_mapStyleLoaded || controller == null) return;

    try {
      if (routeLine != null) {
        await controller.removeLine(routeLine);
      }

      for (final symbol in symbols) {
        await controller.removeSymbol(symbol);
      }
    } catch (error) {
      debugPrint('Could not clear map overlays: $error');
    }
  }

  Future<void> _endTrip() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    await _clearMapOverlays();

    if (!mounted) return;

    context.read<NavigationProvider>().endTrip();

    setState(() {
      _arrivalCandidateId = null;
      _arrivalFixCount = 0;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  double? _calculateRemainingDistanceKm(NavigationProvider trip) {
    final latitude = trip.currentLatitude;
    final longitude = trip.currentLongitude;

    if (latitude == null || longitude == null) return null;

    final remainingStops = trip.stops
        .where((stop) => !trip.completedStopIds.contains(stop.id))
        .toList();

    if (remainingStops.isEmpty) return 0;

    var distanceMeters = Geolocator.distanceBetween(
      latitude,
      longitude,
      remainingStops.first.latitude,
      remainingStops.first.longitude,
    );

    for (var i = 0; i < remainingStops.length - 1; i++) {
      distanceMeters += Geolocator.distanceBetween(
        remainingStops[i].latitude,
        remainingStops[i].longitude,
        remainingStops[i + 1].latitude,
        remainingStops[i + 1].longitude,
      );
    }

    return distanceMeters / 1000;
  }

  String _formatEta(Duration remainingDuration) {
    if (remainingDuration == Duration.zero) return '--';
    final eta = DateTime.now().add(remainingDuration);
    final hour = eta.hour % 12 == 0 ? 12 : eta.hour % 12;
    final minute = eta.minute.toString().padLeft(2, '0');
    final period = eta.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  String _estimatedCompletionTime(double remainingKm, int stopsLeft) {
    // Preview only: assumes 20 km/h average speed and 15 minutes at each stop.
    final travelMinutes = (remainingKm / 20 * 60).ceil();
    final visitMinutes = stopsLeft * 15;
    final eta = DateTime.now().add(
      Duration(minutes: travelMinutes + visitMinutes),
    );

    final hour = eta.hour % 12 == 0 ? 12 : eta.hour % 12;
    final minute = eta.minute.toString().padLeft(2, '0');
    final period = eta.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<NavigationProvider>();
    final appColors = Theme.of(context).extension<AppColors>()!;
    final colors = Theme.of(context).colorScheme;
    final muted = appColors.primaryText.withValues(alpha: 0.58);
    final battery = context.watch<BatteryProvider>().batteryData;

    final hasStartedTrip = trip.tripStartedAt != null;
    final stopsLeft = trip.stops
        .where((stop) => !trip.completedStopIds.contains(stop.id))
        .length;
    final remainingKm = trip.isNavigating
        ? trip.remainingDistanceKm
        : _calculateRemainingDistanceKm(trip);
    final eta = trip.isNavigating
        ? _formatEta(trip.remainingDuration)
        : (remainingKm == null
            ? '--'
            : _estimatedCompletionTime(remainingKm, stopsLeft));

    return Scaffold(
      backgroundColor: appColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NavigateHeader(
                textColor: appColors.primaryText,
                mutedColor: muted,
                accent: colors.primary,
                isNavigating: trip.isNavigating,
              ),
              const SizedBox(height: 14),

              _MapPreview(
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                onStyleLoaded: () {
                  _mapStyleLoaded = true;
                  final trip = context.read<NavigationProvider>();

                  unawaited(_syncStopMarkers(trip.stops));
                  unawaited(_drawPendingRoute());
                },
              ),
              const SizedBox(height: 12),

              if (!hasStartedTrip)
                _PlanTripCard(
                  stops: trip.stops,
                  cardColor: appColors.cardColor,
                  textColor: appColors.primaryText,
                  mutedColor: muted,
                  accent: colors.primary,
                  onAddStop: _addStop,
                  onRemoveStop: _removeStop,
                  onNavigate: trip.stops.isEmpty ? null : _startNavigation,
                  onGoogleMaps: trip.stops.isEmpty ? null : () => _openGoogleMaps(trip),
                )
              else ...[
                _NextStopCard(
                  stop: trip.nextStop ?? trip.stops.last,
                  cardColor: appColors.cardColor,
                  textColor: appColors.primaryText,
                  mutedColor: muted,
                  accent: colors.primary,
                  isComplete: trip.nextStop == null,
                ),
                const SizedBox(height: 10),

                _TripSummaryCard(
                  cardColor: appColors.cardColor,
                  textColor: appColors.primaryText,
                  mutedColor: muted,
                  remainingKm: remainingKm,
                  stopsLeft: stopsLeft,
                  batteryRangeKm: battery.range.toDouble(),
                  eta: eta,
                  accent: colors.primary,
                  distanceToHomeKm: _distanceToHomeKm,
                ),

                const SizedBox(height: 10),
                _StopsChecklistCard(
                  stops: trip.stops,
                  completedStopIds: trip.completedStopIds,
                  cardColor: appColors.cardColor,
                  textColor: appColors.primaryText,
                  mutedColor: muted,
                  accent: colors.primary,
                  onChanged: _setStopCompleted,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openGoogleMaps(trip),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Navigate in Google Maps'),
                  ),
                ),
                if (trip.isNavigating)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _endTrip,
                      child: const Text('End trip'),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _endTrip,
                      child: const Text('Close trip'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigateHeader extends StatelessWidget {
  const _NavigateHeader({
    required this.textColor,
    required this.mutedColor,
    required this.accent,
    required this.isNavigating,
  });

  final Color textColor;
  final Color mutedColor;
  final Color accent;
  final bool isNavigating;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'DURGA PUJA ROUTE',
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            if (isNavigating)
              _Pill(text: 'NAVIGATING', color: accent),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Pandal hopping',
          style: TextStyle(
            color: textColor,
            fontSize: 29,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          'Battery-aware route · Kolkata',
          style: TextStyle(color: mutedColor, fontSize: 14),
        ),
      ],
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.onMapCreated,
    required this.onStyleLoaded,
  });

  final void Function(MapplsMapController) onMapCreated;
  final VoidCallback onStyleLoaded;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 400,
        child: MapplsMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(22.5744, 88.3639),
            zoom: 12,
          ),
          myLocationEnabled: true,
          onMapCreated: onMapCreated,
          onStyleLoadedCallback: onStyleLoaded,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
            ),
          },
        ),
      ),
    );
  }
}

class _PlanTripCard extends StatelessWidget {
  const _PlanTripCard({
    required this.stops,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
    required this.accent,
    required this.onAddStop,
    required this.onRemoveStop,
    required this.onNavigate,
    required this.onGoogleMaps,
  });

  final List<PandalStop> stops;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;
  final Color accent;
  final VoidCallback onAddStop;
  final ValueChanged<PandalStop> onRemoveStop;
  final VoidCallback? onNavigate;
  final VoidCallback? onGoogleMaps;

  @override
  Widget build(BuildContext context) {
    return _Card(
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan your trip',
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add the pandals you want to visit.',
            style: TextStyle(color: mutedColor, fontSize: 14),
          ),
          if (stops.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...stops.asMap().entries.map(
                  (entry) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 12,
                  backgroundColor: accent.withValues(alpha: 0.12),
                  child: Text(
                    '${entry.key + 1}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  entry.value.name,
                  style: TextStyle(color: textColor, fontSize: 15),
                ),
                trailing: IconButton(
                  onPressed: () => onRemoveStop(entry.value),
                  icon: Icon(Icons.close, color: mutedColor, size: 20),
                ),
              ),
            ),
          ],
          TextButton.icon(
            onPressed: onAddStop,
            icon: const Icon(Icons.add),
            label: const Text('Add a stop'),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onNavigate,
              icon: const Icon(Icons.navigation),
              label: const Text('Navigate'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onGoogleMaps,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Navigate in Google Maps'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStopCard extends StatelessWidget {
  const _NextStopCard({
    required this.stop,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
    required this.accent,
    required this.isComplete,
  });

  final PandalStop stop;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;
  final Color accent;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return _Card(
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isComplete ? 'TRIP COMPLETE' : 'NEXT PANDAL',
            style: TextStyle(
              color: mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  isComplete ? 'All stops visited' : stop.name,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                isComplete ? Icons.check_circle : Icons.navigation,
                color: accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
    required this.remainingKm,
    required this.stopsLeft,
    required this.batteryRangeKm,
    required this.eta,
    required this.accent,
    required this.distanceToHomeKm,
  });

  final Color cardColor;
  final Color textColor;
  final Color mutedColor;
  final double? remainingKm;
  final int stopsLeft;
  final double batteryRangeKm;
  final String eta;
  final Color accent;

  // Distance from the current location to home.
  final double? distanceToHomeKm;

  @override
  Widget build(BuildContext context) {
    final distanceText = remainingKm == null
        ? 'Locating…'
        : '${remainingKm!.toStringAsFixed(1)} km';

    final homeDistanceText = distanceToHomeKm == null
        ? 'Locating…'
        : '${distanceToHomeKm!.toStringAsFixed(1)} km';

    final distancesAvailable =
        remainingKm != null && distanceToHomeKm != null;

    // Remaining route + return journey.
    final totalRequiredKm = distancesAvailable
        ? remainingKm! + distanceToHomeKm!
        : 0.0;

    // Can the scooter complete the route and return home?
    final tripPossible = distancesAvailable &&
        batteryRangeKm >= totalRequiredKm;

    // Can the scooter reach home from its current location?
    final returnPossible = distanceToHomeKm != null &&
        batteryRangeKm >= distanceToHomeKm!;

    // Target a 20% distance reserve.
    final tripHasReserve = distancesAvailable &&
        batteryRangeKm >= totalRequiredKm * 1.2;

    final homeHasReserve = distanceToHomeKm != null &&
        batteryRangeKm >= distanceToHomeKm! * 1.2;

    final tripCoverage = !distancesAvailable ||
        totalRequiredKm <= 0
        ? 0.0
        : (batteryRangeKm / totalRequiredKm)
        .clamp(0.0, 1.0)
        .toDouble();

    final homeCoverage = distanceToHomeKm == null ||
        distanceToHomeKm! <= 0
        ? 0.0
        : (batteryRangeKm / distanceToHomeKm!)
        .clamp(0.0, 1.0)
        .toDouble();

    final rangeColor = !distancesAvailable
        ? mutedColor
        : !tripPossible
        ? Theme.of(context).colorScheme.error
        : !tripHasReserve
        ? Colors.amber
        : Colors.green;

    final rangeStatus = !distancesAvailable
        ? 'CALCULATING'
        : !tripPossible
        ? 'RANGE INSUFFICIENT'
        : !tripHasReserve
        ? 'LOW RESERVE'
        : 'TRIP + HOME OK';

    final homeRangeColor = distanceToHomeKm == null
        ? mutedColor
        : !returnPossible
        ? Theme.of(context).colorScheme.error
        : !homeHasReserve
        ? Colors.amber
        : Colors.green;

    final homeRangeStatus = distanceToHomeKm == null
        ? 'CHECKING'
        : !returnPossible
        ? 'DANGER'
        : !homeHasReserve
        ? 'LOW RESERVE'
        : 'SAFE RANGE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==================================================
        // CARD 1: TRIP COMPLETION SUMMARY
        // ==================================================
        _Card(
          color: cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Trip completion ETA',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _Pill(
                    text: !distancesAvailable
                        ? 'CHECKING'
                        : tripPossible
                        ? 'TRIP POSSIBLE'
                        : 'LOW RANGE',
                    color: !distancesAvailable
                        ? mutedColor
                        : tripPossible
                        ? accent
                        : Theme.of(context)
                        .colorScheme
                        .error,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  _Metric(
                    label: 'REMAINING DISTANCE',
                    value: distanceText,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                  const Spacer(),
                  _Metric(
                    label: 'ESTIMATED ARRIVAL',
                    value: eta,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ESTIMATED BATTERY RANGE',
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    rangeStatus,
                    style: TextStyle(
                      color: rangeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: tripCoverage,
                  minHeight: 8,
                  backgroundColor:
                  rangeColor.withValues(alpha: 0.16),
                  valueColor:
                  AlwaysStoppedAnimation<Color>(rangeColor),
                ),
              ),

              const SizedBox(height: 6),

              Text(
                distancesAvailable
                    ? '${batteryRangeKm.toStringAsFixed(1)} km range · '
                    '${totalRequiredKm.toStringAsFixed(1)} km '
                    'required including return'
                    : '${batteryRangeKm.toStringAsFixed(1)} km '
                    'estimated range · Waiting for location',
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                '$stopsLeft stops remaining',
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ==================================================
        // CARD 2: RETURN HOME SAFETY
        // ==================================================
        _Card(
          color: cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.home_rounded,
                    color: accent,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Return Home Safety',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _Pill(
                    text: homeRangeStatus,
                    color: homeRangeColor,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'DISTANCE TO HOME',
                      value: homeDistanceText,
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                  ),
                  const Spacer(),
                  Expanded(
                    child: _Metric(
                      label: 'AVAILABLE RANGE',
                      value:
                      '${batteryRangeKm.toStringAsFixed(1)} km',
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: homeCoverage,
                  minHeight: 8,
                  backgroundColor:
                  homeRangeColor.withValues(alpha: 0.16),
                  valueColor:
                  AlwaysStoppedAnimation<Color>(
                    homeRangeColor,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                distanceToHomeKm == null
                    ? 'Waiting for your current location '
                    'and home route distance.'
                    : !returnPossible
                    ? 'WARNING: Your estimated battery range '
                    'is insufficient to reach home. '
                    'Avoid extending the trip and seek '
                    'a safe charging point or assistance.'
                    : !homeHasReserve
                    ? 'CAUTION: You may reach home, but '
                    'the estimated 20% distance '
                    'reserve is not available.'
                    : 'Your estimated battery range is '
                    'sufficient to return home with '
                    'a 20% distance reserve.',
                style: TextStyle(
                  color: distanceToHomeKm == null
                      ? mutedColor
                      : !returnPossible
                      ? Theme.of(context)
                      .colorScheme
                      .error
                      : !homeHasReserve
                      ? Colors.amber
                      : textColor,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Actual range may vary with speed, traffic, '
                    'terrain, temperature and battery condition.',
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _StopsChecklistCard extends StatelessWidget {
  const _StopsChecklistCard({
    required this.stops,
    required this.completedStopIds,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
    required this.accent,
    required this.onChanged,
  });

  final List<PandalStop> stops;
  final Set<String> completedStopIds;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;
  final Color accent;
  final void Function(PandalStop stop, bool? checked) onChanged;

  @override
  Widget build(BuildContext context) {
    final completedCount =
        stops.where((stop) => completedStopIds.contains(stop.id)).length;

    return _Card(
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$completedCount of ${stops.length} pandals completed',
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ...stops.map((stop) {
            final isCompleted = completedStopIds.contains(stop.id);

            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: accent,
              value: isCompleted,
              onChanged: isCompleted ? null : (value) => onChanged(stop, value),
              title: Text(
                stop.name,
                style: TextStyle(
                  color: isCompleted ? mutedColor : textColor,
                  fontSize: 14,
                  decoration:
                  isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                isCompleted ? 'Visited' : 'On your route',
                style: TextStyle(color: mutedColor, fontSize: 11),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.textColor,
    required this.mutedColor,
  });

  final String label;
  final String value;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: mutedColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}