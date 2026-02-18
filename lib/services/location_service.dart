import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  StreamSubscription<Position>? _positionSub;

  /// Request location permissions
  Future<bool> requestPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
    }
    return status.isGranted;
  }

  /// Request background location permission (for active sessions)
  Future<bool> requestBackgroundPermission() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// Check if location services are enabled
  Future<bool> isServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;

      final serviceEnabled = await isServiceEnabled();
      if (!serviceEnabled) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  /// Start listening to location updates (event-based, not continuous)
  void startLocationUpdates({
    required void Function(Position position) onUpdate,
    int intervalSeconds = 15,
  }) {
    _positionSub?.cancel();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // minimum 10m movement to trigger
        intervalDuration: Duration(seconds: intervalSeconds),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText:
              'SAKHI is monitoring your location for safety',
          notificationTitle: 'SAKHI Safety Active',
          enableWakeLock: true,
        ),
      ),
    ).listen(
      onUpdate,
      onError: (e) => debugPrint('Location stream error: $e'),
    );
  }

  /// Stop location updates
  void stopLocationUpdates() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  /// Calculate distance between two points in km
  double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(
          startLat,
          startLng,
          endLat,
          endLng,
        ) /
        1000;
  }
}
