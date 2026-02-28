import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

// bring in walking buddy types and extension methods used below
import '../models/walking_buddy_models.dart';
import '../services/walking_buddy_service.dart';
import 'package:rxdart/rxdart.dart';

// We need Rx.combineLatest when merging safety sessions with walking buddy requests.

import '../models/user_model.dart';
import '../models/session_model.dart';
import '../models/emergency_contact.dart';
import '../models/broadcast_model.dart';
import '../models/live_location_model.dart';
import '../models/location_share_alert_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/evidence_service.dart';
import '../services/internal_heartbeat_service.dart';
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

/// Convert a [WalkingSessionModel] into a generic [SessionModel] so
/// the volunteer dashboard can display both safety and walking-buddy
/// requests in the same list. The resulting session uses
/// [isVirtualCompanionActive] to mark it as a walking-buddy request.
SessionModel _sessionFromWalking(WalkingSessionModel w) {
  return SessionModel(
    sessionId: w.sessionId,
    createdBy: w.userId,
    status: SessionStatus.searching,
    startTime: w.createdAt,
    lastUpdate: w.createdAt,
    userLocation: w.userLocation,
    destinationLocation: w.destinationLocation,
    timeLimit: w.estimatedDuration.round(),
    isVirtualCompanionActive: true,
  );
}

/// Stream of sessions searching for volunteers.  This provider now merges
/// two sources:
///  1. traditional `sessions` collection (safety feature)
///  2. walking buddy requests from `walking_sessions`.
///
/// The lists are combined on every update so the UI receives a unified
/// list containing both types of requests.
final searchingSessionsProvider = StreamProvider<List<SessionModel>>((ref) {
  final safetyStream = FirestoreService.instance.searchingSessionsStream();
  final buddyStream = FirestoreService.instance
      .getSearchingSessionsStream()
      .map((list) => list.map(_sessionFromWalking).toList());

  return Rx.combineLatest2<List<SessionModel>, List<SessionModel>,
      List<SessionModel>>(safetyStream, buddyStream, (safety, buddies) {
    // simply concatenate then sort by startTime descending so newest
    // sessions appear first.  This keeps behavior consistent regardless of
    // which stream emitted the update.
    final combined = [...safety, ...buddies];
    combined.sort((a, b) => b.startTime.compareTo(a.startTime));
    return combined;
  });
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
      // Stop and upload evidence if recording was active.
      if (EvidenceService.instance.isRecording) {
        // Fire-and-forget — don't block session end, but log errors.
        EvidenceService.instance
            .stopAndUploadEvidence(sessionId)
            .then((_) => debugPrint('[SessionController] Evidence uploaded for $sessionId'))
            .catchError((e) {
          debugPrint('[SessionController] Evidence upload failed for $sessionId: $e');
          // TODO: enqueue for retry if a retry manager is available
        });
      }
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
      // Start covert evidence recording (best-effort, log failures).
      try {
        await EvidenceService.instance.startCovertRecording(sessionId);
      } catch (e) {
        debugPrint('[SessionController] Covert recording failed for $sessionId: $e');
      }
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

    // Session-specific location updates
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

    // Start live tracking (writes to liveLocations collection for admin map)
    _startLiveTrackingForUser(uid, sessionId);
  }

  /// Resolve user details and activate live tracking.
  Future<void> _startLiveTrackingForUser(
    String uid,
    String sessionId,
  ) async {
    try {
      final userModel = await FirestoreService.instance.getUser(uid);
      final name = userModel?.name ?? 'Unknown';
      final role = userModel?.role.name ?? 'user';

      LocationService.instance.startLiveTracking(
        userId: uid,
        userName: name,
        role: role,
        reason: TrackingReason.session,
        sessionId: sessionId,
      );
    } catch (e) {
      // Non-fatal — session tracking still runs via startLocationUpdates
      debugPrint('Could not start live tracking: $e');
    }
  }

  void _stopTracking() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    LocationService.instance.stopLocationUpdates();

    // Also stop live tracking (guard against null uid on logout)
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      LocationService.instance.stopLiveTracking(userId: uid);
    }
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

/// Stream of active incoming location-share alerts for the current user.
final incomingLocationShareAlertsProvider =
    StreamProvider<List<LocationShareAlertModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return FirestoreService.instance.incomingLocationShareAlertsStream(user.uid);
});

/// Stream of the current user's active location shares.
final activeLocationSharesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return FirestoreService.instance.activeLocationSharesStream(user.uid);
});

// ───────── Broadcasts Feed Provider ─────────

/// Stream of community broadcast alerts
final broadcastsFeedProvider = StreamProvider<List<BroadcastModel>>((ref) {
  return FirestoreService.instance.broadcastsStream();
});

/// Current user's active SOS broadcast (if any).
final activeSosBroadcastProvider = StreamProvider<BroadcastModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return FirestoreService.instance.activeSosForUserStream(user.uid);
});

final internalHeartbeatServiceProvider = Provider<InternalHeartbeatService>((
  ref,
) {
  return InternalHeartbeatService.instance;
});

final internalHeartbeatStateProvider = StreamProvider<InternalHeartbeatState>((
  ref,
) {
  final service = ref.watch(internalHeartbeatServiceProvider);
  service.initialize();
  return service.stream;
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

/// Stream of volunteers with pending verification (admin)
final pendingVolunteersProvider = StreamProvider<List<UserModel>>((ref) {
  return FirestoreService.instance.volunteersWithStatusStream('pending');
});

// ───────── Live Location Providers ─────────

/// Stream of all actively-tracked live locations (admin map).
final activeLiveLocationsProvider =
    StreamProvider<List<LiveLocationModel>>((ref) {
  return FirestoreService.instance.activeLiveLocationsStream();
});
