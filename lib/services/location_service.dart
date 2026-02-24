import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of a location fetch attempt with a specific failure reason.
class LocationResult {
  final Position? position;
  final LocationFailure? failure;

  LocationResult.success(Position this.position) : failure = null;
  LocationResult.failed(this.failure) : position = null;

  bool get isSuccess => failure == null;
}

enum LocationFailure {
  permissionDenied,
  permissionPermanentlyDenied,
  serviceDisabled,
  timeout,
  unknown,
}

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

  /// Check if permission is permanently denied
  Future<bool> isPermissionPermanentlyDenied() async {
    final status = await Permission.location.status;
    return status.isPermanentlyDenied;
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

  /// Get current position with a detailed failure reason.
  Future<LocationResult> getPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        final permanent = await isPermissionPermanentlyDenied();
        return LocationResult.failed(
          permanent
              ? LocationFailure.permissionPermanentlyDenied
              : LocationFailure.permissionDenied,
        );
      }

      final serviceEnabled = await isServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.failed(LocationFailure.serviceDisabled);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );
      return LocationResult.success(position);
    } on TimeoutException {
      debugPrint('Location timeout (dart:async)');
      return LocationResult.failed(LocationFailure.timeout);
    } on LocationServiceDisabledException {
      debugPrint('Location service disabled (geolocator)');
      return LocationResult.failed(LocationFailure.serviceDisabled);
    } on PermissionDeniedException {
      debugPrint('Permission denied (geolocator)');
      return LocationResult.failed(LocationFailure.permissionDenied);
    } catch (e) {
      debugPrint('Error getting location: $e');
      return LocationResult.failed(LocationFailure.unknown);
    }
  }

  /// Legacy helper – returns Position? (null on any failure).
  Future<Position?> getCurrentPosition() async {
    final result = await getPosition();
    return result.position;
  }

  /// Start listening to location updates (event-based, not continuous)
  void startLocationUpdates({
    required void Function(Position position) onUpdate,
    int intervalSeconds = 15,
  }) {
    _positionSub?.cancel();

    // Build platform-specific location settings
    // Use kIsWeb and defaultTargetPlatform to avoid dart:io on web
    LocationSettings locationSettings;
    if (kIsWeb) {
      // Web platform: use generic LocationSettings
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // minimum 10m movement to trigger
        intervalDuration: Duration(seconds: intervalSeconds),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'SAKHI is monitoring your location for safety',
          notificationTitle: 'SAKHI Safety Active',
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      // Fallback for other platforms (Linux, Windows, Fuchsia)
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(onUpdate, onError: (e) => debugPrint('Location stream error: $e'));
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
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) /
        1000;
  }
}
