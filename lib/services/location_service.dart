import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/constants.dart';
import '../models/live_location_model.dart';
import 'firestore_service.dart';

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

  // ───────── Live Tracking (writes to liveLocations collection) ─────────

  StreamSubscription<Position>? _liveTrackingSub;
  DateTime? _lastLiveWriteTime;
  bool _isLiveTracking = false;

  /// Whether live tracking is currently active.
  bool get isLiveTracking => _isLiveTracking;

  /// Start real-time location tracking for the given user.
  ///
  /// Streams position updates with a distance filter of 15 m and a
  /// time-based throttle of 10 s to minimise Firestore write costs.
  ///
  /// [userId]  – Firebase Auth UID.
  /// [userName] – Display name for the admin map marker.
  /// [role]    – 'user', 'volunteer', or 'admin'.
  /// [reason]  – Why this user is being tracked.
  /// [sessionId] – Optional associated session ID.
  void startLiveTracking({
    required String userId,
    required String userName,
    required String role,
    TrackingReason reason = TrackingReason.session,
    String? sessionId,
  }) {
    // Prevent duplicate subscriptions
    if (_isLiveTracking) stopLiveTracking();
    _isLiveTracking = true;
    _lastLiveWriteTime = null;

    final distFilter = AppConstants.liveTrackingDistanceFilterM;
    final intervalSec = AppConstants.liveTrackingIntervalSec;

    LocationSettings locationSettings;
    if (kIsWeb) {
      locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distFilter,
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distFilter,
        intervalDuration: Duration(seconds: intervalSec),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'SAKHI is sharing your live location',
          notificationTitle: 'SAKHI Live Tracking',
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distFilter,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distFilter,
      );
    }

    _liveTrackingSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position pos) {
        // Time-based throttle: skip writes if <10 s since last one
        final now = DateTime.now();
        if (_lastLiveWriteTime != null &&
            now.difference(_lastLiveWriteTime!).inSeconds < intervalSec) {
          return;
        }
        _lastLiveWriteTime = now;

        final loc = LiveLocationModel(
          uid: userId,
          userName: userName,
          role: role,
          latitude: pos.latitude,
          longitude: pos.longitude,
          lastUpdatedAt: now,
          isActive: true,
          trackingReason: reason,
          sessionId: sessionId,
        );

        FirestoreService.instance.upsertLiveLocation(loc).catchError(
          (e) => debugPrint('[LocationService] upsertLiveLocation failed: $e'),
        );

        // Also keep the user document in sync (existing behaviour)
        FirestoreService.instance.updateUserLocation(
          userId,
          GeoPoint(pos.latitude, pos.longitude),
        ).catchError(
          (e) => debugPrint('[LocationService] updateUserLocation failed: $e'),
        );
      },
      onError: (e) => debugPrint('Live tracking stream error: $e'),
    );

    debugPrint(
      '[LocationService] Live tracking started for $userId ($role, $reason)',
    );
  }

  /// Stop live tracking and mark the user as inactive in Firestore.
  void stopLiveTracking({String? userId}) {
    _liveTrackingSub?.cancel();
    _liveTrackingSub = null;
    _isLiveTracking = false;
    _lastLiveWriteTime = null;

    if (userId != null) {
      FirestoreService.instance.deactivateLiveLocation(userId);
    }

    debugPrint('[LocationService] Live tracking stopped');
  }

  /// Upgrade an existing live-tracking session to SOS priority.
  void upgradeLiveTrackingToSOS({
    required String userId,
    required String userName,
    required String role,
    String? sessionId,
  }) {
    // Restart with SOS reason so the admin map picks up the change
    stopLiveTracking();
    startLiveTracking(
      userId: userId,
      userName: userName,
      role: role,
      reason: TrackingReason.sos,
      sessionId: sessionId,
    );
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
