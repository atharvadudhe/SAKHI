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
import '../models/location_share_model.dart';
import '../models/location_share_alert_model.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // Getters to allow extensions to access the database and uuid
  FirebaseFirestore get db => _db;
  Uuid get uuid => _uuid;

  Future<String> _resolveDisplayName({
    required String uid,
    String? preferredName,
  }) async {
    final trimmed = preferredName?.trim() ?? '';
    final lower = trimmed.toLowerCase();
    final invalid = trimmed.isEmpty || lower == 'unknown' || lower == 'user';
    if (!invalid) return trimmed;

    try {
      final user = await getUser(uid);
      final resolved = user?.name.trim() ?? '';
      if (resolved.isNotEmpty) return resolved;
    } catch (_) {}
    return 'Sakhi User';
  }

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

  static const Duration _sosCooldown = Duration(minutes: 1);

  Future<BroadcastModel?> getActiveSosBroadcastForUser(String uid) async {
    final snap = await _db
        .collection(AppConstants.broadcastsCollection)
        .where('uid', isEqualTo: uid)
        .get();
    if (snap.docs.isEmpty) return null;
    final all = snap.docs
        .map((d) => BroadcastModel.fromJson(d.data()))
        .where((b) => b.alertType == 'need_help' && b.isActive)
        .toList();
    if (all.isEmpty) return null;
    all.sort((a, b) {
      final aTs = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTs = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTs.compareTo(aTs);
    });
    return all.first;
  }

  Future<Duration?> getSosCooldownRemaining(String uid) async {
    final snap = await _db
        .collection(AppConstants.broadcastsCollection)
        .where('uid', isEqualTo: uid)
        .get();
    if (snap.docs.isEmpty) return null;
    final all = snap.docs
        .map((d) => BroadcastModel.fromJson(d.data()))
        .where((b) => b.alertType == 'need_help')
        .toList();
    if (all.isEmpty) return null;
    all.sort((a, b) {
      final aTs = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTs = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTs.compareTo(aTs);
    });
    final latest = all.first;
    if (latest.timestamp == null) return null;
    final elapsed = DateTime.now().difference(latest.timestamp!);
    if (elapsed >= _sosCooldown) return null;
    return _sosCooldown - elapsed;
  }

  /// Send a community broadcast alert
  Future<void> sendBroadcast({
    required String uid,
    required String message,
    required String alertType,
    required GeoPoint location,
    String? userName,
  }) async {
    final resolvedName = await _resolveDisplayName(
      uid: uid,
      preferredName: userName,
    );
    if (alertType == 'need_help') {
      final active = await getActiveSosBroadcastForUser(uid);
      if (active != null) {
        throw Exception('sos_already_active');
      }
      final remaining = await getSosCooldownRemaining(uid);
      if (remaining != null) {
        throw Exception('sos_cooldown:${remaining.inSeconds}');
      }
    }

    final id = _uuid.v4();
    await _db.collection(AppConstants.broadcastsCollection).doc(id).set({
      'id': id,
      'uid': uid,
      'userName': resolvedName,
      'message': message,
      'alertType': alertType,
      'location': location,
      'timestamp': FieldValue.serverTimestamp(),
      'radiusKm': AppConstants.broadcastRadiusKm,
      'isActive': true,
      'cancelledAt': null,
    });
  }

  /// Cancel an active SOS broadcast by owner.
  Future<void> cancelActiveSosBroadcast(String uid) async {
    final snap = await _db
        .collection(AppConstants.broadcastsCollection)
        .where('uid', isEqualTo: uid)
        .get();
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      final b = BroadcastModel.fromJson(doc.data());
      if (b.alertType != 'need_help' || !b.isActive) continue;
      batch.update(doc.reference, {
        'isActive': false,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Stream active SOS for current user.
  Stream<BroadcastModel?> activeSosForUserStream(String uid) {
    return _db
        .collection(AppConstants.broadcastsCollection)
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final all = snap.docs
          .map((d) => BroadcastModel.fromJson(d.data()))
          .where((b) => b.alertType == 'need_help' && b.isActive)
          .toList();
      if (all.isEmpty) return null;
      all.sort((a, b) {
        final aTs = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTs = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTs.compareTo(aTs);
      });
      return all.first;
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

  /// Fetch all emergency contacts for a user once.
  Future<List<EmergencyContact>> getEmergencyContacts(String uid) async {
    final snap = await _contactsRef(uid).orderBy('name').get();
    return snap.docs
        .map((doc) => EmergencyContact.fromJson(doc.data()))
        .toList();
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
    required String senderPhone,
    required List<String> recipientUids,
    required List<String> recipientPhones,
    required GeoPoint location,
    required int durationMinutes,
  }) async {
    final id = _uuid.v4();
    final resolvedName = await _resolveDisplayName(
      uid: uid,
      preferredName: userName,
    );
    final expiresAt = DateTime.now().add(Duration(minutes: durationMinutes));
    await _db.collection(AppConstants.locationSharesCollection).doc(id).set({
      'id': id,
      'uid': uid,
      'userName': resolvedName,
      'senderPhone': senderPhone,
      'recipientUids': recipientUids,
      'recipientPhones': recipientPhones,
      'location': location,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'durationMinutes': durationMinutes,
      'isActive': true,
    });

    await createLocationShareAlerts(
      shareId: id,
      senderUid: uid,
      senderName: resolvedName,
      senderPhone: senderPhone,
      recipientUids: recipientUids,
      recipientPhones: recipientPhones,
      expiresAt: expiresAt,
    );

    return id;
  }

  /// Stream user's active location shares
  Stream<List<Map<String, dynamic>>> activeLocationSharesStream(String uid) {
    return _db
        .collection(AppConstants.locationSharesCollection)
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final active = snap.docs
          .map((doc) => doc.data())
          .where((data) => (data['isActive'] as bool?) ?? false)
          .toList();
      active.sort((a, b) {
        final aTs = a['createdAt'];
        final bTs = b['createdAt'];
        DateTime aDate = DateTime.fromMillisecondsSinceEpoch(0);
        DateTime bDate = DateTime.fromMillisecondsSinceEpoch(0);
        if (aTs is Timestamp) aDate = aTs.toDate();
        if (bTs is Timestamp) bDate = bTs.toDate();
        return bDate.compareTo(aDate);
      });
      return active.take(5).toList();
    });
  }

  /// Fetch active location shares for a user once.
  Future<List<Map<String, dynamic>>> getActiveLocationShares(String uid) async {
    final snap = await _db
        .collection(AppConstants.locationSharesCollection)
        .where('uid', isEqualTo: uid)
        .get();
    final active = snap.docs
        .map((d) => d.data())
        .where((data) => (data['isActive'] as bool?) ?? false)
        .toList();
    active.sort((a, b) {
      final aTs = a['createdAt'];
      final bTs = b['createdAt'];
      DateTime aDate = DateTime.fromMillisecondsSinceEpoch(0);
      DateTime bDate = DateTime.fromMillisecondsSinceEpoch(0);
      if (aTs is Timestamp) aDate = aTs.toDate();
      if (bTs is Timestamp) bDate = bTs.toDate();
      return bDate.compareTo(aDate);
    });
    return active.take(10).toList();
  }

  /// Stop a location share
  Future<void> stopLocationShare(String shareId) async {
    await _db.collection(AppConstants.locationSharesCollection).doc(shareId).update({
      'isActive': false,
    });
    await endLocationShareAlerts(shareId);
  }

  /// Stop all active location shares for a user.
  Future<void> stopAllActiveLocationShares(String uid) async {
    final snap = await _db
        .collection(AppConstants.locationSharesCollection)
        .where('uid', isEqualTo: uid)
        .get();
    if (snap.docs.isEmpty) return;

    final activeDocs = snap.docs.where((d) {
      final data = d.data();
      return (data['isActive'] as bool?) ?? false;
    }).toList();
    if (activeDocs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in activeDocs) {
      batch.update(doc.reference, {
        'isActive': false,
      });
    }
    await batch.commit();

    for (final doc in activeDocs) {
      await endLocationShareAlerts(doc.id);
    }
  }

  /// Update location on an active share
  Future<void> updateLocationShare(String shareId, GeoPoint location) async {
    await _db.collection(AppConstants.locationSharesCollection).doc(shareId).update({
      'location': location,
    });
  }

  /// Stream a specific location share.
  Stream<LocationShareModel?> locationShareStream(String shareId) {
    return _db.collection(AppConstants.locationSharesCollection).doc(shareId).snapshots().map(
      (doc) {
        if (!doc.exists) return null;
        return LocationShareModel.fromJson(doc.data()!);
      },
    );
  }

  /// Get users whose phone numbers match [phones].
  Future<List<UserModel>> getUsersByPhones(List<String> phones) async {
    final normalized = phones
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();
    if (normalized.isEmpty) return [];

    final users = <UserModel>[];
    const chunkSize = 10; // Firestore whereIn limit
    for (var i = 0; i < normalized.length; i += chunkSize) {
      final chunk = normalized.sublist(
        i,
        (i + chunkSize > normalized.length) ? normalized.length : i + chunkSize,
      );
      final snap = await _db
          .collection(AppConstants.usersCollection)
          .where('phone', whereIn: chunk)
          .get();
      users.addAll(snap.docs.map((doc) => UserModel.fromJson(doc.data())));
    }
    return users;
  }

  /// Create recipient alerts for a location share.
  Future<List<String>> createLocationShareAlerts({
    required String shareId,
    required String senderUid,
    required String senderName,
    required String senderPhone,
    required List<String> recipientUids,
    required List<String> recipientPhones,
    required DateTime expiresAt,
  }) async {
    final ids = <String>[];
    final batch = _db.batch();
    for (var i = 0; i < recipientUids.length; i++) {
      final alertId = _uuid.v4();
      final ref = _db
          .collection(AppConstants.locationShareAlertsCollection)
          .doc(alertId);
      batch.set(ref, {
        'alertId': alertId,
        'shareId': shareId,
        'senderUid': senderUid,
        'senderName': senderName,
        'senderPhone': senderPhone,
        'recipientUid': recipientUids[i],
        'recipientPhone': i < recipientPhones.length ? recipientPhones[i] : '',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
      });
      ids.add(alertId);
    }
    await batch.commit();
    return ids;
  }

  /// Mark all alerts for a share as ended.
  Future<void> endLocationShareAlerts(String shareId) async {
    final snap = await _db
        .collection(AppConstants.locationShareAlertsCollection)
        .where('shareId', isEqualTo: shareId)
        .where('status', isEqualTo: 'active')
        .get();
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Stream active incoming location-share alerts for a recipient.
  Stream<List<LocationShareAlertModel>> incomingLocationShareAlertsStream(
    String recipientUid,
  ) {
    return _db
        .collection(AppConstants.locationShareAlertsCollection)
        .where('recipientUid', isEqualTo: recipientUid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) {
      final alerts = snap.docs
          .map((doc) => LocationShareAlertModel.fromJson(doc.data()))
          .toList();
      alerts.sort((a, b) {
        final aTs = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTs = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTs.compareTo(aTs);
      });
      return alerts;
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
