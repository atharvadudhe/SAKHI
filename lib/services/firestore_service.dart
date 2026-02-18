import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../config/constants.dart';
import '../models/user_model.dart';
import '../models/session_model.dart';
import '../models/location_update.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ───────── User Operations ─────────

  /// Stream the current user's profile
  Stream<UserModel?> userStream(String uid) {
    return _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromJson(doc.data()!);
    });
  }

  /// Get user by uid
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return UserModel.fromJson(doc.data()!);
  }

  /// Update user location
  Future<void> updateUserLocation(String uid, GeoPoint location) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'currentLocation': location,
      'lastHeartbeat': FieldValue.serverTimestamp(),
    });
  }

  /// Update heartbeat timestamp
  Future<void> updateHeartbeat(String uid) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'lastHeartbeat': FieldValue.serverTimestamp(),
    });
  }

  /// Toggle volunteer availability
  Future<void> setVolunteerAvailability(
      String uid, bool available) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({'isAvailable': available});
  }

  // ───────── Session Operations ─────────

  /// Create a new safety session
  Future<SessionModel> createSession({
    required String userId,
    required int timeLimitMinutes,
    GeoPoint? destination,
    GeoPoint? currentLocation,
  }) async {
    final sessionId = _uuid.v4();
    final now = DateTime.now();

    final session = SessionModel(
      sessionId: sessionId,
      createdBy: userId,
      status: SessionStatus.searching,
      startTime: now,
      timeLimit: timeLimitMinutes,
      lastUpdate: now,
      destinationLocation: destination,
      userLocation: currentLocation,
    );

    await _db
        .collection(AppConstants.sessionsCollection)
        .doc(sessionId)
        .set(session.toJson());

    return session;
  }

  /// Stream active session for a user (as creator or volunteer)
  Stream<SessionModel?> activeSessionStream(String uid) {
    return _db
        .collection(AppConstants.sessionsCollection)
        .where('createdBy', isEqualTo: uid)
        .where('status', whereIn: ['searching', 'active', 'sosTriggered'])
        .orderBy('startTime', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          return SessionModel.fromJson(snap.docs.first.data());
        });
  }

  /// Stream sessions searching for volunteers (for volunteer dashboard)
  Stream<List<SessionModel>> searchingSessionsStream() {
    return _db
        .collection(AppConstants.sessionsCollection)
        .where('status', isEqualTo: 'searching')
        .orderBy('startTime', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SessionModel.fromJson(doc.data()))
            .toList());
  }

  /// Volunteer accepts a session
  Future<void> acceptSession({
    required String sessionId,
    required String volunteerId,
    required String volunteerName,
  }) async {
    await _db
        .collection(AppConstants.sessionsCollection)
        .doc(sessionId)
        .update({
      'status': SessionStatus.active.name,
      'volunteerId': volunteerId,
      'volunteerName': volunteerName,
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }

  /// End a session
  Future<void> endSession(String sessionId) async {
    await _db
        .collection(AppConstants.sessionsCollection)
        .doc(sessionId)
        .update({
      'status': SessionStatus.ended.name,
      'endTime': FieldValue.serverTimestamp(),
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }

  /// Trigger SOS on a session
  Future<void> triggerSOS(String sessionId) async {
    await _db
        .collection(AppConstants.sessionsCollection)
        .doc(sessionId)
        .update({
      'status': SessionStatus.sosTriggered.name,
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }

  /// Update session heartbeat / location
  Future<void> updateSessionLocation(
    String sessionId,
    GeoPoint location,
  ) async {
    await _db
        .collection(AppConstants.sessionsCollection)
        .doc(sessionId)
        .update({
      'userLocation': location,
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }

  // ───────── Location Updates ─────────

  /// Write a throttled location update for a session
  Future<void> writeLocationUpdate({
    required String sessionId,
    required String uid,
    required GeoPoint geoPoint,
  }) async {
    final update = LocationUpdate(
      uid: uid,
      geoPoint: geoPoint,
      timestamp: DateTime.now(),
    );

    await _db
        .collection(AppConstants.sessionsCollection)
        .doc(sessionId)
        .collection(AppConstants.locationUpdatesSubcollection)
        .add(update.toJson());
  }

  /// Stream location updates for a session
  Stream<List<LocationUpdate>> locationUpdatesStream(
      String sessionId) {
    return _db
        .collection(AppConstants.sessionsCollection)
        .doc(sessionId)
        .collection(AppConstants.locationUpdatesSubcollection)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LocationUpdate.fromJson(doc.data()))
            .toList());
  }

  // ───────── Community Broadcast ─────────

  /// Send a community broadcast alert
  Future<void> sendBroadcast({
    required String uid,
    required String message,
    required String alertType,
    required GeoPoint location,
  }) async {
    final id = _uuid.v4();
    await _db
        .collection(AppConstants.broadcastsCollection)
        .doc(id)
        .set({
      'id': id,
      'uid': uid,
      'message': message,
      'alertType': alertType,
      'location': location,
      'timestamp': FieldValue.serverTimestamp(),
      'radiusKm': AppConstants.broadcastRadiusKm,
    });
  }

  /// Stream nearby broadcasts
  Stream<List<Map<String, dynamic>>> broadcastsStream() {
    return _db
        .collection(AppConstants.broadcastsCollection)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }
}
