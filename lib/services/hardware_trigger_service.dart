import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

import 'location_service.dart';
import 'firestore_service.dart';

/// Listens for rapid volume-button presses and fires an automatic SOS
/// broadcast when the pattern is detected (≥ 3 presses within 3 seconds).
///
/// Initialise once (e.g. from `main.dart` or after login) and keep alive
/// while the app is in the foreground / background.
class HardwareTriggerService {
  HardwareTriggerService._();
  static final HardwareTriggerService instance = HardwareTriggerService._();

  /// Optional callback for the UI layer (e.g. show a confirmation dialog).
  VoidCallback? onSOSTriggered;

  final List<DateTime> _pressTimestamps = [];
  StreamSubscription<double>? _volumeSub;
  bool _isInitialized = false;
  bool _isCooldown = false;
  Timer? _cooldownTimer;

  /// Number of rapid presses required to trigger SOS.
  static const int _requiredPresses = 3;

  /// Time window in which the presses must occur.
  static const Duration _windowDuration = Duration(seconds: 3);

  /// Cooldown after a successful trigger to avoid duplicate bursts.
  static const Duration _cooldownDuration = Duration(seconds: 10);

  // ────────────────────────────────────────────────────────────────────────

  /// Start listening for volume-button presses.
  /// Safe to call multiple times — only binds the listener once.
  void initialize() {
    if (_isInitialized || kIsWeb) return;
    _isInitialized = true;

    _volumeSub = FlutterVolumeController.addListener((volume) {
      _onVolumeChange();
    });

    debugPrint(
      '[HardwareTrigger] Initialised — listening for rapid volume presses',
    );
  }

  // ────────────────────────────────────────────────────────────────────────

  void _onVolumeChange() {
    if (_isCooldown) return;

    final now = DateTime.now();
    _pressTimestamps.add(now);

    // Drop timestamps outside the detection window
    _pressTimestamps.removeWhere(
      (t) => now.difference(t) > _windowDuration,
    );

    if (_pressTimestamps.length >= _requiredPresses) {
      _pressTimestamps.clear();
      _activateCooldown();
      _fireSOSTrigger();
    }
  }

  void _activateCooldown() {
    _isCooldown = true;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(_cooldownDuration, () => _isCooldown = false);
  }

  // ────────────────────────────────────────────────────────────────────────

  Future<void> _fireSOSTrigger() async {
    debugPrint('[HardwareTrigger] SOS pattern detected — triggering broadcast');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[HardwareTrigger] No authenticated user — aborting');
      return;
    }

    try {
      final position = await LocationService.instance.getCurrentPosition();

      if (position != null) {
        final geoPoint = GeoPoint(position.latitude, position.longitude);

        // 1. Send an SOS broadcast to nearby volunteers
        await FirestoreService.instance.sendBroadcast(
          uid: user.uid,
          message:
              'SOS! Emergency help needed immediately! (Hardware trigger)',
          alertType: 'need_help',
          location: geoPoint,
        );

        // 2. Begin continuous location sharing — guard against stale uid
        LocationService.instance.startLocationUpdates(
          onUpdate: (pos) {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser == null) {
              // User signed out — stop location updates
              LocationService.instance.stopLocationUpdates();
              return;
            }
            final point = GeoPoint(pos.latitude, pos.longitude);
            FirestoreService.instance.updateUserLocation(currentUser.uid, point);
          },
        );

        debugPrint('[HardwareTrigger] SOS broadcast sent successfully');

        // 3. Notify the UI layer only after successful SOS send
        onSOSTriggered?.call();
      } else {
        debugPrint('[HardwareTrigger] Could not acquire location');
      }
    } catch (e, st) {
      debugPrint('[HardwareTrigger] Error triggering SOS: $e\n$st');
    }
  }

  // ────────────────────────────────────────────────────────────────────────

  /// Release the volume listener. Call when the service is no longer needed.
  void dispose() {
    _volumeSub?.cancel();
    _volumeSub = null;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    _isInitialized = false;
    _pressTimestamps.clear();
  }
}
