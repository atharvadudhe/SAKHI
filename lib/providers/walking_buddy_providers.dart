import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/walking_buddy_models.dart';
import '../services/firestore_service.dart';
import '../services/walking_buddy_service.dart';
import '../services/location_service.dart';

// ───────── Walking Session Providers ─────────

/// Stream of searching walking sessions (available to volunteers)
final searchingWalkingSessionsProvider =
    StreamProvider<List<WalkingSessionModel>>((ref) {
  print('🟢 PROVIDER EXECUTED: searchingWalkingSessionsProvider');
  return FirestoreService.instance.getSearchingSessionsStream().map((list) {
    print('🔵 STREAMED ${list.length} searching sessions');
    return list;
  });
});

/// Stream of user's active walking buddy session
final userActiveWalkingSessionProvider =
    StreamProvider.family<WalkingSessionModel?, String>((ref, userId) {
  return FirestoreService.instance
      .getUserActiveWalkingSessionStream(userId);
});

/// Get a specific walking session by ID
final walkingSessionProvider =
    FutureProvider.family<WalkingSessionModel?, String>((ref, sessionId) {
  return FirestoreService.instance.getWalkingSession(sessionId);
});

/// Stream a specific walking session by ID (real-time updates)
final walkingSessionStreamProvider =
    StreamProvider.family<WalkingSessionModel?, String>((ref, sessionId) {
  return FirestoreService.instance.getWalkingSessionStream(sessionId);
});

/// User's walking session history
final walkingSessionHistoryProvider =
    FutureProvider.family<List<WalkingSessionModel>, String>((ref, userId) {
  return FirestoreService.instance.getUserWalkingSessionHistory(userId);
});

// ───────---- Volunteer Discovery Providers ─────────

/// Search for nearby volunteers
final nearbyVolunteersProvider = FutureProvider.family<
    List<VolunteerAvailabilityModel>,
    ({GeoPoint location, double radiusKm})>((ref, params) async {
  return FirestoreService.instance.getNearbyVolunteers(
    userLocation: params.location,
    radiusKm: params.radiusKm,
  );
});

/// Get nearby volunteers with a default 5km radius
final nearbyVolunteersDefaultProvider =
    FutureProvider<List<VolunteerAvailabilityModel>>((ref) async {
  final position = await LocationService.instance.getPosition();
  if (!position.isSuccess || position.position == null) {
    return [];
  }

  final geoPoint = GeoPoint(
    position.position!.latitude,
    position.position!.longitude,
  );

  return FirestoreService.instance.getNearbyVolunteers(
    userLocation: geoPoint,
    radiusKm: 5.0, // 5km default radius
  );
});

// ───────---- Location Updates Providers ─────────

/// Stream location updates for real-time tracking
final sessionLocationUpdatesProvider = StreamProvider.family<
    List<WalkingBuddyLocationUpdate>,
    String>((ref, sessionId) {
  return FirestoreService.instance.streamLocationUpdates(sessionId);
});

/// Get recent location updates
final recentLocationUpdatesProvider = FutureProvider.family<
    List<WalkingBuddyLocationUpdate>,
    String>((ref, sessionId) {
  return FirestoreService.instance.getRecentLocationUpdates(sessionId);
});

// ───────---- Walking Buddy Controller ─────────

final walkingBuddyControllerProvider =
    NotifierProvider<WalkingBuddyController, AsyncValue<void>>(
      WalkingBuddyController.new,
    );

class WalkingBuddyController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Create a new walking buddy session
  Future<String?> createWalkingSession({
    required String userId,
    required String userName,
    required String userPhone,
    required String? userPhotoUrl,
    required GeoPoint userLocation,
    required GeoPoint destinationLocation,
    required String destinationName,
    required String? destinationAddress,
    required double estimatedDuration,
  }) async {
    state = const AsyncLoading();
    try {
      final sessionId = await FirestoreService.instance.createWalkingSession(
        userId: userId,
        userName: userName,
        userPhone: userPhone,
        userPhotoUrl: userPhotoUrl,
        userLocation: userLocation,
        destinationLocation: destinationLocation,
        destinationName: destinationName,
        destinationAddress: destinationAddress,
        estimatedDuration: estimatedDuration,
      );
      state = const AsyncData(null);
      return sessionId;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Volunteer accepts a session request
  Future<bool> volunteerAcceptSession({
    required String sessionId,
    required String volunteerId,
    required String volunteerName,
    required String volunteerPhone,
    required String? volunteerPhotoUrl,
    required double distanceFromUser,
  }) async {
    state = const AsyncLoading();
    try {
      await FirestoreService.instance.volunteerAcceptSession(
        sessionId,
        volunteerId,
        volunteerName,
        volunteerPhone,
        volunteerPhotoUrl,
        distanceFromUser,
      );

      // Send FCM notification to user
      await _sendNotificationToUser(
        sessionId: sessionId,
        title: 'Volunteer Found!',
        body: '$volunteerName is $distanceFromUser km away and ready to help.',
        notificationType: 'volunteer_accepted',
      );

      state = const AsyncData(null);
      ref.invalidate(searchingWalkingSessionsProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// User confirms volunteer acceptance
  Future<bool> userConfirmVolunteer(String sessionId) async {
    state = const AsyncLoading();
    try {
      await FirestoreService.instance.userConfirmVolunteer(sessionId);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// Volunteer confirms arrival at user location
  Future<bool> volunteerConfirmArrival(String sessionId) async {
    state = const AsyncLoading();
    try {
      await FirestoreService.instance.volunteerConfirmArrival(sessionId);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// Volunteer rejects/declines a session request.
  Future<bool> volunteerRejectSession({
    required String sessionId,
    required String volunteerId,
    String? rejectionReason,
  }) async {
    state = const AsyncLoading();
    try {
      await FirestoreService.instance.cancelWalkingSession(
        sessionId,
        rejectionReason ?? 'volunteer_rejected',
      );
      state = const AsyncData(null);
      ref.invalidate(searchingWalkingSessionsProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// User confirms volunteer arrival and journey starts
  Future<bool> startJourney(String sessionId) async {
    state = const AsyncLoading();
    try {
      await FirestoreService.instance.startJourney(sessionId);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// User confirms reached destination
  Future<bool> userConfirmDestinationReached(String sessionId) async {
    state = const AsyncLoading();
    try {
      await FirestoreService.instance.userConfirmDestinationReached(sessionId);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// Complete walking session
  Future<bool> completeWalkingSession(String sessionId) async {
    state = const AsyncLoading();
    try {
      await FirestoreService.instance.completeWalkingSession(sessionId);
      state = const AsyncData(null);
      ref.invalidate(userActiveWalkingSessionProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// Cancel walking session
  Future<bool> cancelWalkingSession(
    String sessionId,
    String cancelReason,
  ) async {
    state = const AsyncLoading();
    try {
      await FirestoreService.instance.cancelWalkingSession(
        sessionId,
        cancelReason,
      );
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// Record location update
  Future<bool> recordLocation(
    String sessionId,
    String userId,
    Position position,
  ) async {
    try {
      await FirestoreService.instance.recordWalkingBuddyLocation(
        sessionId: sessionId,
        userId: userId,
        position: position,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update volunteer stats after session
  Future<bool> updateVolunteerStats(
    String volunteerId,
    double rating,
  ) async {
    try {
      await FirestoreService.instance.updateVolunteerWalkingBuddyStats(
        volunteerId,
        rating,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Helper to send FCM notification (integrate with your notification service)
  Future<void> _sendNotificationToUser({
    required String sessionId,
    required String title,
    required String body,
    required String notificationType,
  }) async {
    // TODO: Implement FCM notification sending
    // Use your existing NotificationService or FCM API
    // This should send to the user's FCM token
  }
}

// ───────---- Destination Search State Notifiers ─────────

class RecentDestinationsNotifier extends Notifier<List<DestinationModel>> {
  @override
  List<DestinationModel> build() => const [];

  void addDestination(DestinationModel destination) {
    final filtered = state
        .where((d) => d.placeId != destination.placeId)
        .toList();
    state = [
      destination,
      ...filtered.take(9), // Keep last 10
    ];
  }

  void clearDestinations() {
    state = [];
  }
}

/// For storing recently searched destinations
final recentDestinationsProvider =
    NotifierProvider<RecentDestinationsNotifier, List<DestinationModel>>(
      () => RecentDestinationsNotifier(),
    );

/// Add destination to recent searches
final addRecentDestinationProvider =
    Provider<Function(DestinationModel)>((ref) {
  return (DestinationModel destination) {
    ref.read(recentDestinationsProvider.notifier).addDestination(destination);
    return ref.read(recentDestinationsProvider);
  };
});

// ───────---- UI State Notifiers ─────────

class SelectedDestinationNotifier extends Notifier<DestinationModel?> {
  @override
  DestinationModel? build() => null;

  void setDestination(DestinationModel? destination) {
    state = destination;
  }

  void clearDestination() {
    state = null;
  }
}

class UserLocationNotifier extends Notifier<GeoPoint?> {
  @override
  GeoPoint? build() => null;

  void setLocation(GeoPoint location) {
    state = location;
  }

  void clear() {
    state = null;
  }
}

class SessionCreationLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setLoading(bool loading) {
    state = loading;
  }
}

class SelectedVolunteerNotifier extends Notifier<VolunteerAvailabilityModel?> {
  @override
  VolunteerAvailabilityModel? build() => null;

  void setVolunteer(VolunteerAvailabilityModel? volunteer) {
    state = volunteer;
  }

  void clear() {
    state = null;
  }
}

/// Current selection state for destination
final selectedDestinationProvider =
    NotifierProvider<SelectedDestinationNotifier, DestinationModel?>(
      () => SelectedDestinationNotifier(),
    );

/// Current user location for walking buddy
final walkingBuddyUserLocationProvider =
    NotifierProvider<UserLocationNotifier, GeoPoint?>(
      () => UserLocationNotifier(),
    );

/// Session creation loading state
final sessionCreationLoadingProvider =
    NotifierProvider<SessionCreationLoadingNotifier, bool>(
      () => SessionCreationLoadingNotifier(),
    );

/// Volunteer selection state
final selectedVolunteerProvider =
    NotifierProvider<SelectedVolunteerNotifier, VolunteerAvailabilityModel?>(
      () => SelectedVolunteerNotifier(),
    );
