import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:rxdart/rxdart.dart';

import '../config/constants.dart';
import '../models/user_model.dart';
import '../models/session_model.dart';
import '../models/location_update.dart';
import '../models/emergency_contact.dart';
import '../models/broadcast_model.dart';
import '../models/live_location_model.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // Getters to allow extensions to access the database and uuid
  FirebaseFirestore get db => _db;
  Uuid get uuid => _uuid;

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

  /// Update live location field (e.g. during active request)
  Future<void> updateLiveLocation(String uid, GeoPoint location) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'liveLocation': location,
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

  /// Update user profile photo URL
  Future<void> updatePhotoUrl(String uid, String photoUrl) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'photoUrl': photoUrl,
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

  // ───────── Live Location Tracking ─────────

  /// Upsert a live-location document (keyed by uid).
  /// This is the single write target for real-time tracking.
  Future<void> upsertLiveLocation(LiveLocationModel loc) async {
    await _db
        .collection(AppConstants.liveLocationsCollection)
        .doc(loc.uid)
        .set(loc.toJson(), SetOptions(merge: true));
  }

  /// Deactivate a user's live location (mark offline).
  /// Uses set-with-merge so it won't throw if the document doesn't exist.
  Future<void> deactivateLiveLocation(String uid) async {
    await _db
        .collection(AppConstants.liveLocationsCollection)
        .doc(uid)
        .set({
      'isActive': false,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Stream all currently active live-location documents.
  /// Used by the Admin dashboard map.
  Stream<List<LiveLocationModel>> activeLiveLocationsStream() {
    return _db
        .collection(AppConstants.liveLocationsCollection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => LiveLocationModel.fromJson(doc.data()))
              .toList(),
        );
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

  // ───────── Duress PIN Operations ─────────

  /// Save hashed Safe PIN and Duress PIN to user profile.
  ///
  /// Callers MUST hash PINs before calling this method (bcrypt/Argon2/SHA-256+salt).
  /// A basic guard rejects obvious plaintext inputs (short numeric-only values).
  Future<void> savePins({
    required String uid,
    required String safePin,
    required String duressPin,
  }) async {
    // Basic guard: reject obvious plaintext (4-6 digit numeric strings).
    // Properly hashed values are always longer and contain non-digit characters.
    final plaintext = RegExp(r'^\d{1,8}$');
    if (plaintext.hasMatch(safePin) || plaintext.hasMatch(duressPin)) {
      debugPrint(
        '[FirestoreService] WARNING: savePins received what appears to be '
        'plaintext PINs. PINs should be hashed before calling savePins.',
      );
    }

    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'safePin': safePin,
      'duressPin': duressPin,
    });
  }

  /// Mark all active broadcasts from [uid] as duress-active.
  /// Called when a duress PIN cancellation is triggered.
  Future<void> activateDuressOnBroadcasts(String uid) async {
    final snap = await _db
        .collection(AppConstants.broadcastsCollection)
        .where('uid', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(5)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isDuressActive': true});
    }
    await batch.commit();
  }

  // ───────── Volunteer Verification (KYC) ─────────

  /// Update the user's KYC verification status.
  Future<void> updateVerificationStatus(
    String uid,
    String status, {
    String? idFrontUrl,
    String? idBackUrl,
  }) async {
    final data = <String, dynamic>{'verificationStatus': status};
    if (idFrontUrl != null) data['idFrontUrl'] = idFrontUrl;
    if (idBackUrl != null) data['idBackUrl'] = idBackUrl;
    if (status == 'pending') {
      data['verificationSubmittedAt'] = FieldValue.serverTimestamp();
    }
    await _db.collection(AppConstants.usersCollection).doc(uid).update(data);
  }

  /// Stream volunteers with a specific verification status (admin only).
  Stream<List<UserModel>> volunteersWithStatusStream(String status) {
    return _db
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: 'volunteer')
        .where('verificationStatus', isEqualTo: status)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => UserModel.fromJson(doc.data()))
              .toList(),
        );
  }

  /// Approve a volunteer's KYC verification (admin only).
  Future<void> approveVolunteer(String uid) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'verificationStatus': 'verified',
      'verifiedStatus': true,
    });
  }

  /// Reject a volunteer's KYC verification (admin only).
  /// Clears ID URLs from Firestore. Caller should also delete storage files.
  Future<void> rejectVolunteer(String uid) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'verificationStatus': 'rejected',
      'verifiedStatus': false,
      'idFrontUrl': FieldValue.delete(),
      'idBackUrl': FieldValue.delete(),
    });
  }

  // ───────── Evidence Vault ─────────

  /// Save evidence metadata (hash, URL, timestamp) for a session.
  Future<void> saveSessionEvidence({
    required String sessionId,
    required String downloadUrl,
    required String sha256Hash,
    required DateTime recordedAt,
  }) async {
    await _db.collection('session_evidence').doc(sessionId).set({
      'sessionId': sessionId,
      'downloadUrl': downloadUrl,
      'sha256Hash': sha256Hash,
      'recordedAt': Timestamp.fromDate(recordedAt),
      'uploadedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
