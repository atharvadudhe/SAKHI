import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/user_model.dart';
import '../models/session_model.dart';
import '../models/emergency_contact.dart';
import '../models/broadcast_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../config/constants.dart';

// ───────── Auth Providers ─────────

/// Stream of Firebase Auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return AuthService.instance.authStateChanges;
});

/// Whether the user is currently logged in
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).value != null;
});

// ───────── User Providers ─────────

/// Stream of the current user's profile from Firestore
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return Stream.value(null);
  return FirestoreService.instance.userStream(user.uid);
});

/// Whether the current user is a volunteer
final isVolunteerProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.role == UserRole.volunteer;
});

/// Whether the current user is an admin
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.role == UserRole.admin;
});

// ───────── Session Providers ─────────

/// Stream of the user's active session
final activeSessionProvider = StreamProvider<SessionModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return FirestoreService.instance.activeSessionStream(user.uid);
});

/// Stream of sessions searching for volunteers
final searchingSessionsProvider = StreamProvider<List<SessionModel>>((ref) {
  return FirestoreService.instance.searchingSessionsStream();
});

// ───────── Session Controller ─────────

final sessionControllerProvider =
    NotifierProvider<SessionController, AsyncValue<void>>(
      SessionController.new,
    );

class SessionController extends Notifier<AsyncValue<void>> {
  Timer? _heartbeatTimer;

  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Start a new safety session
  Future<SessionModel?> startSession({int timeLimitMinutes = 30}) async {
    state = const AsyncLoading();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Get current location
      final position = await LocationService.instance.getCurrentPosition();
      GeoPoint? currentLocation;
      if (position != null) {
        currentLocation = GeoPoint(position.latitude, position.longitude);
      }

      // Create session in Firestore
      final session = await FirestoreService.instance.createSession(
        userId: user.uid,
        timeLimitMinutes: timeLimitMinutes,
        currentLocation: currentLocation,
      );

      // Start location updates
      _startTracking(session.sessionId, user.uid);

      state = const AsyncData(null);
      return session;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// End the current session
  Future<void> endSession(String sessionId) async {
    state = const AsyncLoading();
    try {
      await FirestoreService.instance.endSession(sessionId);
      _stopTracking();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Trigger SOS
  Future<void> triggerSOS(String sessionId) async {
    try {
      await FirestoreService.instance.triggerSOS(sessionId);
    } catch (e) {
      // SOS should never silently fail
      rethrow;
    }
  }

  /// Accept a session as volunteer
  Future<void> acceptSession(String sessionId) async {
    state = const AsyncLoading();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      final userModel = await FirestoreService.instance.getUser(user.uid);
      if (userModel == null) throw Exception('Profile not found');

      await FirestoreService.instance.acceptSession(
        sessionId: sessionId,
        volunteerId: user.uid,
        volunteerName: userModel.name,
      );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Toggle volunteer availability
  Future<void> toggleAvailability(String uid, bool isAvailable) async {
    try {
      await FirestoreService.instance.setVolunteerAvailability(
        uid,
        isAvailable,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void _startTracking(String sessionId, String uid) {
    // Heartbeat every 30 seconds
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: AppConstants.heartbeatIntervalSec),
      (_) => FirestoreService.instance.updateHeartbeat(uid),
    );

    // Location updates
    LocationService.instance.startLocationUpdates(
      intervalSeconds: AppConstants.locationUpdateIntervalSec,
      onUpdate: (Position pos) {
        final geoPoint = GeoPoint(pos.latitude, pos.longitude);

        // Update session location
        FirestoreService.instance.updateSessionLocation(sessionId, geoPoint);

        // Write location update to subcollection
        FirestoreService.instance.writeLocationUpdate(
          sessionId: sessionId,
          uid: uid,
          geoPoint: geoPoint,
        );

        // Update user location
        FirestoreService.instance.updateUserLocation(uid, geoPoint);
      },
    );
  }

  void _stopTracking() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    LocationService.instance.stopLocationUpdates();
  }
}

// ───────── Location Provider ─────────

final currentPositionProvider = FutureProvider<Position?>((ref) async {
  return await LocationService.instance.getCurrentPosition();
});

// ───────── Emergency Contacts Provider ─────────

/// Stream of emergency contacts for the current user
final emergencyContactsProvider = StreamProvider<List<EmergencyContact>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return FirestoreService.instance.emergencyContactsStream(user.uid);
});

// ───────── Broadcasts Feed Provider ─────────

/// Stream of community broadcast alerts
final broadcastsFeedProvider = StreamProvider<List<BroadcastModel>>((ref) {
  return FirestoreService.instance.broadcastsStream();
});

// ───────── Admin Providers ─────────

/// Stream of all registered users (admin)
final allUsersProvider = StreamProvider<List<UserModel>>((ref) {
  return FirestoreService.instance.allUsersStream();
});

/// Stream of all active sessions (admin)
final allActiveSessionsProvider = StreamProvider<List<SessionModel>>((ref) {
  return FirestoreService.instance.allActiveSessionsStream();
});
