import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../models/walking_buddy_models.dart';
import 'firestore_service.dart';

/// Extension on FirestoreService for Walking Buddy operations
extension WalkingBuddyService on FirestoreService {
  // ───────── Collections ─────────
  static const String _sessionsCollection = 'walking_sessions';
  static const String _locationsCollection = 'walking_buddy_locations';

  // ───────── Walking Session Operations ─────────

  /// Create a new walking buddy session
  Future<String> createWalkingSession({
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
    final sessionId = uuid.v4();
    final now = DateTime.now();

    await db.collection(_sessionsCollection).doc(sessionId).set({
      'sessionId': sessionId,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'userPhotoUrl': userPhotoUrl,
      'userLocation': userLocation,
      'destinationLocation': destinationLocation,
      'destinationName': destinationName,
      'destinationAddress': destinationAddress,
      'status': WalkingSessionStatus.searching.name,
      'volunteerId': null,
      'volunteerName': null,
      'volunteerPhone': null,
      'volunteerPhotoUrl': null,
      'distanceFromUser': null,
      'createdAt': Timestamp.fromDate(now),
      'volunteerAcceptedAt': null,
      'userConfirmedAt': null,
      'volunteerReachedAt': null,
      'journeyStartedAt': null,
      'destinationReachedAt': null,
      'completedAt': null,
      'userReachedDestination': false,
      'volunteerConfirmedArrival': false,
      'cancelReason': null,
      'estimatedDuration': estimatedDuration,
      'createdAtTimestamp': now.millisecondsSinceEpoch,
    });

    return sessionId;
  }

  /// Get a walking session by ID
  Future<WalkingSessionModel?> getWalkingSession(String sessionId) async {
    final doc = await db.collection(_sessionsCollection).doc(sessionId).get();
    if (!doc.exists) return null;
    return WalkingSessionModel.fromJson(doc.data()!);
  }

  /// Stream a walking session by ID for real-time status updates.
  Stream<WalkingSessionModel?> getWalkingSessionStream(String sessionId) {
    return db.collection(_sessionsCollection).doc(sessionId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return null;
      return WalkingSessionModel.fromJson(doc.data()!);
    });
  }

  /// Stream active walking sessions (searching for volunteers)
  Stream<List<WalkingSessionModel>> getSearchingSessionsStream() {
    return db
        .collection(_sessionsCollection)
        .where('status', isEqualTo: WalkingSessionStatus.searching.name)
        .orderBy('createdAtTimestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WalkingSessionModel.fromJson(doc.data()))
          .toList();
    });
  }

  /// Stream sessions for a specific user
  Stream<WalkingSessionModel?> getUserActiveWalkingSessionStream(
    String userId,
  ) {
    return db
        .collection(_sessionsCollection)
        .where('userId', isEqualTo: userId)
        .where('status',
            whereIn: [
              WalkingSessionStatus.searching.name,
              WalkingSessionStatus.volunteerAccepted.name,
              WalkingSessionStatus.userConfirmed.name,
              WalkingSessionStatus.volunteerReached.name,
              WalkingSessionStatus.journeyStarted.name,
              WalkingSessionStatus.destinationReached.name,
            ])
        .orderBy('createdAtTimestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return WalkingSessionModel.fromJson(snapshot.docs.first.data());
    });
  }

  /// Update session status
  Future<void> updateWalkingSessionStatus(
    String sessionId,
    WalkingSessionStatus status,
  ) async {
    final updates = <String, dynamic>{
      'status': status.name,
    };

    // Add timestamp for status transitions
    final now = DateTime.now();
    switch (status) {
      case WalkingSessionStatus.volunteerAccepted:
        updates['volunteerAcceptedAt'] = Timestamp.fromDate(now);
        break;
      case WalkingSessionStatus.userConfirmed:
        updates['userConfirmedAt'] = Timestamp.fromDate(now);
        break;
      case WalkingSessionStatus.volunteerReached:
        updates['volunteerReachedAt'] = Timestamp.fromDate(now);
        break;
      case WalkingSessionStatus.journeyStarted:
        updates['journeyStartedAt'] = Timestamp.fromDate(now);
        break;
      case WalkingSessionStatus.destinationReached:
        updates['destinationReachedAt'] = Timestamp.fromDate(now);
        break;
      case WalkingSessionStatus.completed:
        updates['completedAt'] = Timestamp.fromDate(now);
        break;
      default:
        break;
    }

    await db.collection(_sessionsCollection).doc(sessionId).update(updates);
  }

  /// Volunteer accepts a session request
  Future<void> volunteerAcceptSession(
    String sessionId,
    String volunteerId,
    String volunteerName,
    String volunteerPhone,
    String? volunteerPhotoUrl,
    double distanceFromUser,
  ) async {
    await db.collection(_sessionsCollection).doc(sessionId).update({
      'volunteerId': volunteerId,
      'volunteerName': volunteerName,
      'volunteerPhone': volunteerPhone,
      'volunteerPhotoUrl': volunteerPhotoUrl,
      'distanceFromUser': distanceFromUser,
      'status': WalkingSessionStatus.volunteerAccepted.name,
      'volunteerAcceptedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// User confirms and accepts the volunteer
  Future<void> userConfirmVolunteer(String sessionId) async {
    await db.collection(_sessionsCollection).doc(sessionId).update({
      'status': WalkingSessionStatus.userConfirmed.name,
      'userConfirmedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Volunteer confirms arrival at user location
  Future<void> volunteerConfirmArrival(String sessionId) async {
    await db.collection(_sessionsCollection).doc(sessionId).update({
      'status': WalkingSessionStatus.volunteerReached.name,
      'volunteerReachedAt': Timestamp.fromDate(DateTime.now()),
      'volunteerConfirmedArrival': true,
    });
  }

  /// User confirms volunteer arrival and journey starts
  Future<void> startJourney(String sessionId) async {
    await db.collection(_sessionsCollection).doc(sessionId).update({
      'status': WalkingSessionStatus.journeyStarted.name,
      'journeyStartedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// User confirms reached destination
  Future<void> userConfirmDestinationReached(String sessionId) async {
    await db.collection(_sessionsCollection).doc(sessionId).update({
      'userReachedDestination': true,
      'destinationReachedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Complete the walking session
  Future<void> completeWalkingSession(String sessionId) async {
    await db.collection(_sessionsCollection).doc(sessionId).update({
      'status': WalkingSessionStatus.completed.name,
      'completedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Cancel a walking session
  Future<void> cancelWalkingSession(
    String sessionId,
    String cancelReason,
  ) async {
    await db.collection(_sessionsCollection).doc(sessionId).update({
      'status': WalkingSessionStatus.cancelled.name,
      'cancelReason': cancelReason,
      'completedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ───────── Volunteer Discovery ─────────

  /// Get available volunteers near a location (within radius)
  Future<List<VolunteerAvailabilityModel>> getNearbyVolunteers({
    required GeoPoint userLocation,
    required double radiusKm,
  }) async {
    // Get users collection with volunteers who are available and verified
    final snapshot = await db
        .collection('users')
        .where('role', isEqualTo: 'volunteer')
        .where('isAvailable', isEqualTo: true)
        .where('verificationStatus', isEqualTo: 'verified')
        .get();

    final volunteers = <VolunteerAvailabilityModel>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final volunteerLocation = data['currentLocation'] as GeoPoint?;

      if (volunteerLocation != null) {
        final distance = _calculateDistance(
          userLocation.latitude,
          userLocation.longitude,
          volunteerLocation.latitude,
          volunteerLocation.longitude,
        );

        if (distance <= radiusKm) {
          volunteers.add(
            VolunteerAvailabilityModel(
              volunteerId: doc.id,
              volunteerName: data['name'] as String? ?? '',
              photoUrl: data['photoUrl'] as String?,
              phone: data['phone'] as String? ?? '',
              currentLocation: volunteerLocation,
              distanceFromUser: distance,
              verificationStatus:
                  data['verificationStatus'] as String? ?? 'unverified',
              sessionsCompleted:
                  data['walkingBuddySessions'] as int? ?? 0,
              averageRating:
                  (data['walkingBuddyRating'] as num?)?.toDouble() ?? 0,
            ),
          );
        }
      }
    }

    // Sort by distance
    volunteers.sort((a, b) => a.distanceFromUser.compareTo(b.distanceFromUser));
    return volunteers;
  }

  /// Calculate distance between two coordinates (in km) using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371;

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2));

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  // ───────── Location Updates ─────────

  /// Record location update for walking buddy session
  Future<void> recordWalkingBuddyLocation({
    required String sessionId,
    required String userId,
    required Position position,
  }) async {
    final locationId = uuid.v4();

    await db
        .collection(_sessionsCollection)
        .doc(sessionId)
        .collection(_locationsCollection)
        .doc(locationId)
        .set({
      'sessionId': sessionId,
      'userId': userId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': Timestamp.fromDate(DateTime.now()),
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'speed': position.speed,
    });
  }

  /// Get recent location updates for a session
  Future<List<WalkingBuddyLocationUpdate>>
      getRecentLocationUpdates(String sessionId) async {
    final now = DateTime.now();
    final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

    final snapshot = await db
        .collection(_sessionsCollection)
        .doc(sessionId)
        .collection(_locationsCollection)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(fiveMinutesAgo))
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          return WalkingBuddyLocationUpdate(
            sessionId: data['sessionId'] as String,
            userId: data['userId'] as String,
            latitude: data['latitude'] as double,
            longitude: data['longitude'] as double,
            timestamp: (data['timestamp'] as Timestamp).toDate(),
            accuracy: data['accuracy'] as double?,
            altitude: data['altitude'] as double?,
            speed: data['speed'] as double?,
          );
        })
        .toList();
  }

  /// Stream recent location updates for real-time tracking
  Stream<List<WalkingBuddyLocationUpdate>> streamLocationUpdates(
    String sessionId,
  ) {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

    return db
        .collection(_sessionsCollection)
        .doc(sessionId)
        .collection(_locationsCollection)
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(oneMinuteAgo))
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            return WalkingBuddyLocationUpdate(
              sessionId: data['sessionId'] as String,
              userId: data['userId'] as String,
              latitude: data['latitude'] as double,
              longitude: data['longitude'] as double,
              timestamp: (data['timestamp'] as Timestamp).toDate(),
              accuracy: data['accuracy'] as double?,
              altitude: data['altitude'] as double?,
              speed: data['speed'] as double?,
            );
          })
          .toList();
    });
  }

  // ───────---- Stats & Analytics ─────────

  /// Update volunteer stats after session completion
  Future<void> updateVolunteerWalkingBuddyStats(
    String volunteerId,
    double rating,
  ) async {
    await db.collection('users').doc(volunteerId).update({
      'walkingBuddySessions': FieldValue.increment(1),
      'walkingBuddyRating': FieldValue.increment(rating),
    });
  }

  /// Get user's walking buddy session history
  Future<List<WalkingSessionModel>> getUserWalkingSessionHistory(
    String userId,
    {int limit = 20}
  ) async {
    final snapshot = await db
        .collection(_sessionsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAtTimestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => WalkingSessionModel.fromJson(doc.data()))
        .toList();
  }
}
