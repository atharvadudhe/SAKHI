import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:rxdart/rxdart.dart';

import '../config/constants.dart';
import '../models/user_model.dart';
import '../models/session_model.dart';
import '../models/location_update.dart';
import '../models/emergency_contact.dart';
import '../models/broadcast_model.dart';

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
  Future<void> setVolunteerAvailability(String uid, bool available) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'isAvailable': available,
    });
  }

  /// Update user profile name
  Future<void> updateUserName(String uid, String name) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'name': name,
    });
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
    // Stream for sessions created by the user
    final creatorStream = _db
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

    // Stream for sessions where the user is the volunteer
    // Note: excludes 'searching' status because volunteers are only assigned
    // when the session transitions to 'active' status atomically
    final volunteerStream = _db
        .collection(AppConstants.sessionsCollection)
        .where('volunteerId', isEqualTo: uid)
        .where('status', whereIn: ['active', 'sosTriggered'])
        .orderBy('startTime', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          return SessionModel.fromJson(snap.docs.first.data());
        });

    // Merge both streams and return the most recent session
    return Rx.combineLatest2<SessionModel?, SessionModel?, SessionModel?>(
      creatorStream,
      volunteerStream,
      (creator, volunteer) {
        if (creator == null && volunteer == null) return null;
        if (creator == null) return volunteer;
        if (volunteer == null) return creator;
        // Return the more recent session
        // Tiebreaker: prefer creator session (defensive measure for edge cases)
        if (creator.startTime.isAfter(volunteer.startTime)) {
          return creator;
        } else if (volunteer.startTime.isAfter(creator.startTime)) {
          return volunteer;
        } else {
          // Same timestamp: prefer creator session
          return creator;
        }
      },
    );
  }

  /// Stream sessions searching for volunteers (for volunteer dashboard)
  Stream<List<SessionModel>> searchingSessionsStream() {
    return _db
        .collection(AppConstants.sessionsCollection)
        .where('status', isEqualTo: 'searching')
        .orderBy('startTime', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => SessionModel.fromJson(doc.data()))
              .toList(),
        );
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
    await _db.collection(AppConstants.sessionsCollection).doc(sessionId).update(
      {'userLocation': location, 'lastUpdate': FieldValue.serverTimestamp()},
    );
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
  Stream<List<LocationUpdate>> locationUpdatesStream(String sessionId) {
    return _db
        .collection(AppConstants.sessionsCollection)
        .doc(sessionId)
        .collection(AppConstants.locationUpdatesSubcollection)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => LocationUpdate.fromJson(doc.data()))
              .toList(),
        );
  }

  // ───────── Community Broadcast ─────────

  /// Send a community broadcast alert
  Future<void> sendBroadcast({
    required String uid,
    required String message,
    required String alertType,
    required GeoPoint location,
    String? userName,
  }) async {
    final id = _uuid.v4();
    await _db.collection(AppConstants.broadcastsCollection).doc(id).set({
      'id': id,
      'uid': uid,
      'userName': userName,
      'message': message,
      'alertType': alertType,
      'location': location,
      'timestamp': FieldValue.serverTimestamp(),
      'radiusKm': AppConstants.broadcastRadiusKm,
    });
  }

  /// Stream nearby broadcasts as typed models
  Stream<List<BroadcastModel>> broadcastsStream() {
    return _db
        .collection(AppConstants.broadcastsCollection)
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => BroadcastModel.fromJson(doc.data()))
              .toList(),
        );
  }

  // ───────── Emergency Contacts ─────────

  /// Get emergency contacts subcollection reference
  CollectionReference<Map<String, dynamic>> _contactsRef(String uid) => _db
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection('emergencyContacts');

  /// Stream all emergency contacts for a user
  Stream<List<EmergencyContact>> emergencyContactsStream(String uid) {
    return _contactsRef(uid)
        .orderBy('name')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => EmergencyContact.fromJson(doc.data()))
              .toList(),
        );
  }

  /// Add an emergency contact
  Future<void> addEmergencyContact(String uid, EmergencyContact contact) async {
    final id = contact.id.isEmpty ? _uuid.v4() : contact.id;
    final data = contact.copyWith(id: id).toJson();
    await _contactsRef(uid).doc(id).set(data);
  }

  /// Update an emergency contact
  Future<void> updateEmergencyContact(
    String uid,
    EmergencyContact contact,
  ) async {
    if (contact.id.isEmpty) {
      throw ArgumentError('Cannot update contact with empty id');
    }
    await _contactsRef(uid).doc(contact.id).update(contact.toJson());
  }

  /// Delete an emergency contact
  Future<void> deleteEmergencyContact(String uid, String contactId) async {
    await _contactsRef(uid).doc(contactId).delete();
  }

  // ───────── Location Sharing ─────────

  /// Create a temporary location share link
  Future<String> createLocationShare({
    required String uid,
    required String userName,
    required GeoPoint location,
    required int durationMinutes,
  }) async {
    final id = _uuid.v4();
    await _db.collection(AppConstants.locationSharesCollection).doc(id).set({
      'id': id,
      'uid': uid,
      'userName': userName,
      'location': location,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(Duration(minutes: durationMinutes)),
      ),
      'durationMinutes': durationMinutes,
      'isActive': true,
    });
    return id;
  }

  /// Stream user's active location shares
  Stream<List<Map<String, dynamic>>> activeLocationSharesStream(String uid) {
    return _db
        .collection(AppConstants.locationSharesCollection)
        .where('uid', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  /// Stop a location share
  Future<void> stopLocationShare(String shareId) async {
    await _db.collection(AppConstants.locationSharesCollection).doc(shareId).update({
      'isActive': false,
    });
  }

  /// Update location on an active share
  Future<void> updateLocationShare(String shareId, GeoPoint location) async {
    await _db.collection(AppConstants.locationSharesCollection).doc(shareId).update({
      'location': location,
    });
  }

  // ───────── Admin Operations ─────────

  /// Stream all registered users (admin only)
  Stream<List<UserModel>> allUsersStream() {
    return _db
        .collection(AppConstants.usersCollection)
        .orderBy('name')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => UserModel.fromJson(doc.data()))
              .toList(),
        );
  }

  /// Stream all active sessions (admin only)
  Stream<List<SessionModel>> allActiveSessionsStream() {
    return _db
        .collection(AppConstants.sessionsCollection)
        .where('status', whereIn: ['searching', 'active', 'sosTriggered'])
        .orderBy('startTime', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => SessionModel.fromJson(doc.data()))
              .toList(),
        );
  }

  /// Update a user's role (admin only)
  Future<void> updateUserRole(String uid, String role) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'role': role,
    });
  }
}
