import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../models/walking_request_model.dart';
import 'firestore_service.dart';

/// Extension on FirestoreService for broadcast walking requests
extension WalkingRequestService on FirestoreService {
  static const String _walkingRequestsCollection = 'walking_sessions';

  // ═══════════════════════════════════════════════════════════════════════════
  // DEBUG FLAGS
  // ═══════════════════════════════════════════════════════════════════════════
  static const bool _debugWalkingRequests = true; // Enable debug logging
  static const bool _debugStreamSnapshots = true; // Log stream events

  void _log(String message) {
    if (_debugWalkingRequests) {
      print('🚶 [WalkingRequest] $message');
    }
  }

  void _logError(String message, dynamic error, [StackTrace? stackTrace]) {
    print('❌ [WalkingRequest] ERROR: $message');
    print('   Error: $error');
    if (stackTrace != null) {
      print('   Stack: $stackTrace');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CREATE REQUEST (USER SIDE)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create a broadcast walking request (user does not pick volunteer)
  Future<String> createBroadcastRequest({
    required String requesterId,
    required String requesterName,
    required GeoPoint requesterLocation,
    required GeoPoint destinationLocation,
    required String destinationName,
  }) async {
    _log('═══════════════════════════════════════════════════════════');
    _log('Creating new broadcast request');
    _log('  userId: $requesterId');
    _log('  userName: $requesterName');
    _log('  userLocation: (${requesterLocation.latitude}, ${requesterLocation.longitude})');
    _log('  destination: $destinationName');
    _log('═══════════════════════════════════════════════════════════');

    try {
      final sessionId = uuid.v4();
      final now = DateTime.now();

      final requestData = {
        'sessionId': sessionId,
        'userId': requesterId,
        'userName': requesterName,
        'userLocation': requesterLocation,
        'destinationLocation': destinationLocation,
        'destinationName': destinationName,
        'status': 'searching',
        'volunteerId': null,
        'volunteerName': null,
        'volunteerPhone': null,
        'volunteerPhotoUrl': null,
        'createdAt': Timestamp.fromDate(now),
        'volunteerAcceptedAt': null,
        'journeyStartedAt': null,
        'destinationReachedAt': null,
        'userConfirmedAt': null,
        'volunteerConfirmedArrival': false,
        'userReachedDestination': false,
        'completedAt': null,
        'cancelReason': null,
      };

      _log('Firestore write: collection=$_walkingRequestsCollection, doc=$sessionId');
      _log('Data keys: ${requestData.keys.join(", ")}');

      await db.collection(_walkingRequestsCollection).doc(sessionId).set(requestData);

      _log('✅ Request created successfully: $sessionId');
      return sessionId;
    } catch (e) {
      _logError('Failed to create broadcast request', e);
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAM PENDING REQUESTS (VOLUNTEER SIDE - PRIMARY METHOD)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream all pending broadcast requests for volunteers
  /// 
  /// This is the PRIMARY method that volunteers use to see incoming requests.
  /// It queries all documents with status=pending and returns them in real-time.
  /// 
  /// IMPORTANT: Volunteer eligibility filtering (role, verificationStatus, isAvailable)
  /// must be done on screen/provider level, NOT here. This is a broadcast model.
  /// Every authenticated volunteer should see every pending request.
  /// 
  /// For debugging:
  /// - Check Firestore console to see if walkingRequests collection exists
  /// - Check if documents have status='pending'
  /// - Check security rules allow READ access
  /// - Check emulator is properly configured
  // Stream<List<WalkingRequestModel>> streamPendingRequestsForVolunteer() {
  //   _log('═══════════════════════════════════════════════════════════');
  //   _log('🎬 STREAMING PENDING REQUESTS for volunteer');
  //   _log('═══════════════════════════════════════════════════════════');
  //   _log('Query: collection=$_walkingRequestsCollection');
  //   _log('       where status == "pending"');
  //   _log('       orderBy createdAt (descending)');

  //   return db
  //       .collection(_walkingRequestsCollection)
  //       .where('status', isEqualTo: WalkingRequestStatus.searching.name)
  //       .orderBy('createdAt', descending: true)
  //       .snapshots()
  //       .handleError((error, stackTrace) {
  //         _logError('Stream error in streamPendingRequestsForVolunteer', error, stackTrace);
  //         throw error;
  //       })
  //       .map((snapshot) {
  //         if (_debugStreamSnapshots) {
  //           _log('📊 Stream snapshot received');
  //           _log('   Connection state: ${snapshot.metadata.isFromCache ? 'CACHE' : 'SERVER'}');
  //           _log('   Document count: ${snapshot.docs.length}');
  //           _log('   Has pending listeners: ${snapshot.docs.isNotEmpty}');
  //         }

  //         if (snapshot.docs.isEmpty) {
  //           _log('⚠️  No pending requests found');
  //           return [];
  //         }

  //         try {
  //           final requests = snapshot.docs.map((doc) {
  //             final data = doc.data();
  //             if (_debugStreamSnapshots) {
  //               _log('   📄 Doc: ${doc.id}');
  //               _log('      status: ${data['status']}');
  //               _log('      requesterId: ${data['requesterId']}');
  //               _log('      requesterName: ${data['requesterName']}');
  //               _log('      createdAt: ${data['createdAt']}');
  //             }
  //             return WalkingRequestModel.fromJson(data);
  //           }).toList();

  //           _log('✅ Successfully mapped ${requests.length} requests');
  //           return requests;
  //         } catch (e) {
  //           _logError('Failed to map snapshot documents', e);
  //           return [];
  //         }
  //       });
  // }

  Stream<List<WalkingRequestModel>> streamPendingRequestsForVolunteer() {
    // Important debug prints that always show in console
    print('🔥🔥🔥 VOLUNTEER STREAM CALLED');
    print('Querying collection: $_walkingRequestsCollection where status==searching');
    _log('═══════════════════════════════════════════════════════════');
    _log('🎬 STREAMING PENDING REQUESTS for volunteer');
    _log('═══════════════════════════════════════════════════════════');

    return db
        .collection(_walkingRequestsCollection)
        .where('status', isEqualTo: 'searching')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error, stackTrace) {
          _logError('Stream error in streamPendingRequestsForVolunteer', error, stackTrace);
          throw error;
        })
        .map((snapshot) {
          print('🔥 TOTAL DOCS IN COLLECTION: ${snapshot.docs.length}');
          if (_debugStreamSnapshots) {
            _log('📊 Stream snapshot received');
            _log('   Connection state: ${snapshot.metadata.isFromCache ? 'CACHE' : 'SERVER'}');
            _log('   Document count: ${snapshot.docs.length}');
          }

          if (snapshot.docs.isEmpty) {
            _log('⚠️  No pending requests found');
            return [];
          }

          try {
            final requests = <WalkingRequestModel>[];

            for (final doc in snapshot.docs) {
              final data = doc.data();
              if (_debugStreamSnapshots) {
                _log('   📄 Doc: ${doc.id}');
                _log('      status: ${data['status']}');
                _log('      userId: ${data['userId']}');
                _log('      userName: ${data['userName']}');
                _log('      createdAt: ${data['createdAt']}');
              }

              try {
                // Transform Firestore schema to WalkingRequestModel schema
                final request = WalkingRequestModel(
                  requestId: data['sessionId'] ?? doc.id,
                  requesterId: data['userId'] ?? '',
                  requesterName: data['userName'] ?? 'Unknown',
                  requesterLocation: data['userLocation'] ?? const GeoPoint(0, 0),
                  status: _parseStatus(data['status']),
                  acceptedBy: data['volunteerId'],
                  createdAt: (data['createdAt'] as Timestamp).toDate(),
                  acceptedAt: data['volunteerAcceptedAt'] != null
                      ? (data['volunteerAcceptedAt'] as Timestamp).toDate()
                      : null,
                );
                requests.add(request);
              } catch (e) {
                _logError('Failed to transform document ${doc.id}', e);
              }
            }

            _log('✅ Successfully mapped ${requests.length} requests');
            return requests;
          } catch (e) {
            _logError('Failed to process snapshot', e);
            return [];
          }
        });
  }

  static WalkingRequestStatus _parseStatus(String? value) {
    switch (value) {
      case 'accepted':
        return WalkingRequestStatus.accepted;
      case 'rejected':
        return WalkingRequestStatus.rejected;
      case 'searching':
      default:
        return WalkingRequestStatus.searching;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DEBUG: FETCH ALL REQUESTS (No Filters)
  // ═══════════════════════════════════════════════════════════════════════════

  /// DEBUG FUNCTION: Fetch ALL walking requests with NO filters
  /// 
  /// Use this to diagnose Firestore connectivity and verify data exists.
  /// If this returns empty, the collection might not exist or be inaccessible.
  Future<List<WalkingRequestModel>> debugFetchAllRequests() async {
    _log('═══════════════════════════════════════════════════════════');
    _log('🔍 DEBUG: Fetching ALL requests (no filters)');
    _log('═══════════════════════════════════════════════════════════');

    try {
      final snapshot = await db.collection(_walkingRequestsCollection).get();

      _log('📊 Firestore returned ${snapshot.docs.length} documents');

      if (snapshot.docs.isEmpty) {
        _log('⚠️  WARNING: No documents found. Collection may not exist or be empty.');
        return [];
      }

      final requests = <WalkingRequestModel>[];

      for (int i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data();

        _log('────────────────────────────────────────────────────────');
        _log('📄 Document #${i + 1}: ${doc.id}');
        _log('   Raw Data:');
        _log('   - sessionId: ${data['sessionId']}');
        _log('   - userId: ${data['userId']}');
        _log('   - userName: ${data['userName']}');
        _log('   - status: ${data['status']}');
        _log('   - volunteerId: ${data['volunteerId']}');
        _log('   - createdAt: ${data['createdAt']}');
        _log('   - userLocation: ${data['userLocation']}');

        try {
          // Transform to WalkingRequestModel
          final request = WalkingRequestModel(
            requestId: data['sessionId'] ?? doc.id,
            requesterId: data['userId'] ?? '',
            requesterName: data['userName'] ?? 'Unknown',
            requesterLocation: data['userLocation'] ?? const GeoPoint(0, 0),
            status: _parseStatus(data['status']),
            acceptedBy: data['volunteerId'],
            createdAt: (data['createdAt'] as Timestamp).toDate(),
            acceptedAt: data['volunteerAcceptedAt'] != null
                ? (data['volunteerAcceptedAt'] as Timestamp).toDate()
                : null,
          );
          requests.add(request);
          _log('   ✅ Successfully parsed');
        } catch (e) {
          _log('   ❌ Failed to parse: $e');
        }
      }

      _log('────────────────────────────────────────────────────────');
      _log('✅ Total parsed requests: ${requests.length}');
      _log('═══════════════════════════════════════════════════════════\n');

      return requests;
    } catch (e) {
      _logError('Failed to fetch all requests', e);
      return [];
    }
  }

  /// DEBUG FUNCTION: Stream ALL requests with connection state logging
  Stream<List<WalkingRequestModel>> debugStreamAllRequests() {
    _log('═══════════════════════════════════════════════════════════');
    _log('🔍 DEBUG: Streaming ALL requests (no filters)');
    _log('═══════════════════════════════════════════════════════════');

    return db
        .collection(_walkingRequestsCollection)
        .snapshots()
        .handleError((error, stackTrace) {
          _logError('Stream error in debugStreamAllRequests', error, stackTrace);
          throw error;
        })
        .map((snapshot) {
          _log('📊 DEBUG Stream: ${snapshot.docs.length} docs, cache=${snapshot.metadata.isFromCache}');
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                // Transform to WalkingRequestModel
                try {
                  return WalkingRequestModel(
                    requestId: data['sessionId'] ?? doc.id,
                    requesterId: data['userId'] ?? '',
                    requesterName: data['userName'] ?? 'Unknown',
                    requesterLocation: data['userLocation'] ?? const GeoPoint(0, 0),
                    status: _parseStatus(data['status']),
                    acceptedBy: data['volunteerId'],
                    createdAt: (data['createdAt'] as Timestamp).toDate(),
                    acceptedAt: data['volunteerAcceptedAt'] != null
                        ? (data['volunteerAcceptedAt'] as Timestamp).toDate()
                        : null,
                  );
                } catch (e) {
                  _logError('Failed to transform doc ${doc.id}', e);
                  rethrow;
                }
              })
              .toList();
        });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GET SPECIFIC REQUEST
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get a specific walking request by ID
  Future<WalkingRequestModel?> getWalkingRequest(String requestId) async {
    _log('Fetching specific request: $requestId');

    try {
      final doc = await db
          .collection(_walkingRequestsCollection)
          .doc(requestId)
          .get();

      if (!doc.exists) {
        _log('⚠️  Request not found: $requestId');
        return null;
      }

      final data = doc.data()!;
      final request = WalkingRequestModel(
        requestId: data['sessionId'] ?? doc.id,
        requesterId: data['userId'] ?? '',
        requesterName: data['userName'] ?? 'Unknown',
        requesterLocation: data['userLocation'] ?? const GeoPoint(0, 0),
        status: _parseStatus(data['status']),
        acceptedBy: data['volunteerId'],
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        acceptedAt: data['volunteerAcceptedAt'] != null
            ? (data['volunteerAcceptedAt'] as Timestamp).toDate()
            : null,
      );
      _log('✅ Retrieved request: ${request.requestId}');
      return request;
    } catch (e) {
      _logError('Failed to fetch request $requestId', e);
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VOLUNTEER ACCEPTS REQUEST
  // ═══════════════════════════════════════════════════════════════════════════

  /// Volunteer accepts a broadcast request via transaction
  /// 
  /// This ensures atomicity: only one volunteer can accept a pending request
  Future<void> acceptRequest(
    String sessionId,
    String volunteerId,
  ) async {
    _log('═══════════════════════════════════════════════════════════');
    _log('👤 Volunteer accepting request');
    _log('   sessionId: $sessionId');
    _log('   volunteerId: $volunteerId');
    _log('═══════════════════════════════════════════════════════════');

    try {
      final now = DateTime.now();
      await db.runTransaction((transaction) async {
        final requestDoc = db.collection(_walkingRequestsCollection).doc(sessionId);
        final snap = await transaction.get(requestDoc);

        if (!snap.exists) {
          throw Exception('Request not found: $sessionId');
        }

        final data = snap.data() as Map<String, dynamic>;
        final status = data['status'] as String?;

        if (status != 'searching') {
          throw Exception('Request already handled: status=$status');
        }

        _log('   ✅ Request is pending, updating...');

        transaction.update(requestDoc, {
          'status': 'accepted',
          'volunteerId': volunteerId,
          'volunteerAcceptedAt': Timestamp.fromDate(now),
        });

        _log('   ✅ Transaction committed');
      });

      _log('✅ Request accepted successfully');
      _log('═══════════════════════════════════════════════════════════\n');
    } catch (e) {
      _logError('Failed to accept request', e);
      rethrow;
    }
  }

  /// Volunteer rejects a request and marks it as rejected.
  Future<void> rejectRequest(
    String sessionId,
    String volunteerId, {
    String? reason,
    String? rejectionReason,
  }) async {
    final finalReason = reason ?? rejectionReason;
    await db.collection(_walkingRequestsCollection).doc(sessionId).update({
      'status': 'rejected',
      'rejectedBy': volunteerId,
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectionReason': finalReason,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NAVIGATION HELPER
  // ═══════════════════════════════════════════════════════════════════════════

  /// Open external Google Maps navigation from volunteer -> user (walking)
  Future<void> openGoogleMapsNavigation({
    required double volunteerLat,
    required double volunteerLng,
    required double userLat,
    required double userLng,
  }) async {
    try {
      final url = 'https://www.google.com/maps/dir/?api=1&origin=$volunteerLat,$volunteerLng&destination=$userLat,$userLng&travelmode=walking';
      _log('Opening Maps navigation: $url');
      await launchUrlString(url);
    } catch (e) {
      _logError('Failed to launch Google Maps', e);
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAM USER'S OWN REQUEST (for user to monitor status)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream a single request document for requester to watch status changes
  Stream<WalkingRequestModel?> streamUserRequestStatus(String requestId) {
    _log('Streaming request status for: $requestId');

    return db
        .collection(_walkingRequestsCollection)
        .doc(requestId)
        .snapshots()
        .handleError((error, stackTrace) {
          _logError('Stream error in streamUserRequestStatus', error, stackTrace);
          throw error;
        })
        .map((doc) {
          if (!doc.exists) {
            _log('⚠️  Request document deleted: $requestId');
            return null;
          }

          final data = doc.data()!;
          if (_debugStreamSnapshots) {
            _log('📊 Status update: status=${data['status']}, volunteerId=${data['volunteerId']}');
          }

          return WalkingRequestModel(
            requestId: data['sessionId'] ?? doc.id,
            requesterId: data['userId'] ?? '',
            requesterName: data['userName'] ?? 'Unknown',
            requesterLocation: data['userLocation'] ?? const GeoPoint(0, 0),
            status: _parseStatus(data['status']),
            acceptedBy: data['volunteerId'],
            createdAt: (data['createdAt'] as Timestamp).toDate(),
            acceptedAt: data['volunteerAcceptedAt'] != null
                ? (data['volunteerAcceptedAt'] as Timestamp).toDate()
                : null,
          );
        });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHECK FOR ACTIVE REQUEST
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check if a user already has a pending broadcast request
  Future<bool> hasActiveBroadcastRequest(String userId) async {
    _log('Checking for active broadcast request: userId=$userId');

    try {
        final snapshot = await db
          .collection(_walkingRequestsCollection)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'searching')
          .get();

      final hasActive = snapshot.docs.isNotEmpty;
      _log('  Active request found: $hasActive');
      return hasActive;
    } catch (e) {
      _logError('Failed to check active broadcast request', e);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ADDITIONAL HELPER METHODS (compatibility with volunteer_providers.dart)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream incoming requests for a volunteer (alias for streamPendingRequestsForVolunteer)
  /// This method is referenced in volunteer_providers.dart
  Stream<List<WalkingRequestModel>> streamIncomingRequests(String volunteerId) {
    _log('🎬 streamIncomingRequests called for volunteer: $volunteerId');
    _log('   (Redirecting to streamPendingRequestsForVolunteer)');
    return streamPendingRequestsForVolunteer();
  }

  /// Stream outgoing requests for a user (all requests by this user)
  /// This method is referenced in volunteer_providers.dart
  Stream<List<WalkingRequestModel>> streamUserOutgoingRequests(String userId) {
    _log('🎬 streamUserOutgoingRequests called for user: $userId');
    
    return db
      .collection(_walkingRequestsCollection)
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error, stackTrace) {
          _logError('Stream error in streamUserOutgoingRequests', error, stackTrace);
          throw error;
        })
        .map((snapshot) {
          _log('   📊 Outgoing requests stream: ${snapshot.docs.length} requests');
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                return WalkingRequestModel(
                  requestId: data['sessionId'] ?? doc.id,
                  requesterId: data['userId'] ?? '',
                  requesterName: data['userName'] ?? 'Unknown',
                  requesterLocation: data['userLocation'] ?? const GeoPoint(0, 0),
                  status: _parseStatus(data['status']),
                  acceptedBy: data['volunteerId'],
                  createdAt: (data['createdAt'] as Timestamp).toDate(),
                  acceptedAt: data['volunteerAcceptedAt'] != null
                      ? (data['volunteerAcceptedAt'] as Timestamp).toDate()
                      : null,
                );
              }).toList();
        });
  }

  /// Check if a user has active request to a specific volunteer (legacy compatibility)
  Future<bool> hasActiveRequestToVolunteer(String userId, String volunteerId) async {
    _log('Checking for request from $userId to volunteer $volunteerId');
    
    try {
        final snapshot = await db
          .collection(_walkingRequestsCollection)
          .where('userId', isEqualTo: userId)
          .where('volunteerId', isEqualTo: volunteerId)
          .where('status', isEqualTo: 'accepted')
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      _logError('Failed to check active request to volunteer', e);
      return false;
    }
  }

  /// Get volunteer request statistics
  Future<Map<String, int>> getVolunteerRequestStats(String volunteerId) async {
    _log('Getting stats for volunteer: $volunteerId');

    try {
        final acceptedSnapshot = await db
          .collection(_walkingRequestsCollection)
          .where('volunteerId', isEqualTo: volunteerId)
          .where('status', isEqualTo: 'accepted')
          .get();

        final pendingSnapshot = await db
          .collection(_walkingRequestsCollection)
          .where('status', isEqualTo: 'searching')
          .get();

      return {
        'accepted': acceptedSnapshot.docs.length,
        'pending': pendingSnapshot.docs.length,
      };
    } catch (e) {
      _logError('Failed to get volunteer stats', e);
      return {'accepted': 0, 'pending': 0};
    }
  }
}
