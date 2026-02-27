/**
 * SAKHI VOLUNTEER MODE - QUICK REFERENCE GUIDE
 * 
 * This is a quick reference for implementing and using the Volunteer Mode feature.
 * For detailed information, see VOLUNTEER_MODE_INTEGRATION.md
 */

// =====================================================================
// API QUICK REFERENCE
// =====================================================================

// Find Nearby Volunteers
final volunteers = await FirestoreService.instance
    .fetchNearbyVerifiedVolunteers(LatLng(37.7749, -122.4194));

// Stream Real-Time Volunteer Updates
FirestoreService.instance
    .streamNearbyVerifiedVolunteers(userLocation)
    .listen((vendors) => print('${vendors.length} volunteers nearby'));

// Calculate Distance Between Two Points
final distance = FirestoreService.instance
    .getDistanceToVolunteer(userLocation, volunteerLocation);

// Check for Duplicate Requests
final hasActive = await FirestoreService.instance
    .hasActiveRequestToVolunteer(userId, volunteerId);

// Send Walking Request
final requestId = await FirestoreService.instance.sendWalkingRequest(
  requesterId: 'user123',
  requesterName: 'John',
  requesterPhone: '+1234567890',
  requesterPhotoUrl: 'https://...',
  requesterLocation: GeoPoint(37.7749, -122.4194),
  volunteerId: 'volunteer456',
  volunteerName: 'Jane',
  volunteerPhone: '+0987654321',
  volunteerPhotoUrl: 'https://...',
  volunteerLocation: GeoPoint(37.7750, -122.4195),
  distanceToRequester: 0.5,
);

// Stream Incoming Requests (for volunteers)
FirestoreService.instance
    .streamIncomingRequests('volunteerId123')
    .listen((requests) {
  print('${requests.length} incoming requests');
});

// Accept a Request
await FirestoreService.instance.acceptRequest(requestId, volunteerId);

// Reject a Request
await FirestoreService.instance.rejectRequest(
  requestId,
  volunteerId,
  rejectionReason: 'Too far away',
);

// Complete a Request (mark session as done)
await FirestoreService.instance.completeRequest(requestId, volunteerId);

// Cancel a Request (user cancels pending request)
await FirestoreService.instance.cancelRequest(requestId, userId);

// Get Request Statistics for Volunteer
final stats = await FirestoreService.instance
    .getVolunteerRequestStats(volunteerId);
print('Accepted: ${stats["accepted"]}, Rejected: ${stats["rejected"]}');

// =====================================================================
// RIVERPOD PROVIDERS QUICK REFERENCE
// =====================================================================

// Get current user location (one-time)
final location = await ref.watch(userLocationProvider).when(
  data: (loc) => loc,
  loading: () => null,
  error: (e, st) => null,
);

// Find volunteers near location (one-time)
final volunteers = await ref.watch(nearbyVolunteersProvider(location!));

// Stream volunteers real-time
ref.watch(nearbyVolunteersStreamProvider(location!)).when(
  data: (volunteers) => show(volunteers),
  loading: () => showLoading(),
  error: (e, st) => showError(e),
);

// Count nearby volunteers
final count = await ref.watch(nearbyVolunteerCountProvider(location!));

// Stream incoming requests for volunteer
ref.watch(incomingRequestsProvider(volunteerId)).when(
  data: (requests) => showRequests(requests),
  loading: () => showLoading(),
  error: (e, st) => showError(e),
);

// Stream outgoing requests for user
ref.watch(userOutgoingRequestsProvider(userId)).when(
  data: (requests) => showMyRequests(requests),
  loading: () => showLoading(),
  error: (e, st) => showError(e),
);

// Get specific request
final request = await ref.watch(walkingRequestProvider(requestId));

// Check for duplicate request
final isDuplicate = await ref.watch(
  hasActiveRequestProvider((userId, volunteerId))
);

// =====================================================================
// SECURITY RULES SUMMARY
// =====================================================================

/*
✓ Users can read their own profile
✓ Users can update their own profile (but not UID)
✓ Any authenticated user can list users (for volunteer search)
✓ Users can create walkingRequests
✓ Users can read their own incoming/outgoing requests
✓ Volunteers can update request status (pending → accepted/rejected)
✓ Requests cannot be deleted (only status changes)
✓ Admin rules can be customized as needed
*/

// =====================================================================
// DATA MODELS SUMMARY
// =====================================================================

// UserModel (existing, enhanced for volunteer mode)
UserModel(
  uid: 'user123',
  name: 'John Doe',
  phone: '+1234567890',
  role: UserRole.volunteer, // or UserRole.user
  isAvailable: true,
  currentLocation: GeoPoint(37.7749, -122.4194),
  verificationStatus: VerificationStatus.verified,
  photoUrl: 'https://...',
  // ... other fields
);

// WalkingRequestModel (new)
WalkingRequestModel(
  requestId: 'req_abc123',
  requesterId: 'user123',
  requesterName: 'John',
  requesterPhone: '+1234567890',
  requesterLocation: GeoPoint(37.7749, -122.4194),
  volunteerId: 'volunteer456',
  volunteerName: 'Jane',
  volunteerPhone: '+0987654321',
  volunteerLocation: GeoPoint(37.7750, -122.4195),
  distanceToRequester: 0.5,
  status: WalkingRequestStatus.pending, // pending/accepted/rejected/completed
  createdAt: DateTime.now(),
  respondedAt: null,
  completedAt: null,
);

// =====================================================================
// COMMON UI PATTERNS
// =====================================================================

// Pattern 1: Display List of Volunteers
ListView.builder(
  itemCount: volunteers.length,
  itemBuilder: (context, index) {
    final volunteer = volunteers[index];
    return VolunteerCard(
      volunteer: volunteer,
      distanceKm: distance,
      onTap: () => sendRequest(volunteer),
      actionLabel: 'Request',
    );
  },
);

// Pattern 2: Real-Time Incoming Requests
StreamBuilder<List<WalkingRequestModel>>(
  stream: FirestoreService.instance.streamIncomingRequests(volunteerId),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
    final requests = snapshot.data!;
    
    if (requests.isEmpty) {
      return VolunteerEmptyState(
        title: 'No Pending Requests',
        subtitle: 'Check back later',
        icon: Icons.inbox,
      );
    }
    
    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return WalkingRequestCard(
          request: request,
          onAccept: () => acceptRequest(request),
          onReject: () => rejectRequest(request),
        );
      },
    );
  },
);

// Pattern 3: Loading State Management
final [accepting, rejecting] = ref.watch(
  Tuple2Provider(acceptingRequestProvider, rejectingRequestProvider),
);

// Pattern 4: Distance Display
DistanceBadge(
  distanceKm: 2.5,
  maxRadiusKm: 5.0,
)

// Pattern 5: Availability Badge
VolunteerAvailabilityBadge(
  isAvailable: volunteer.isAvailable,
)

// =====================================================================
// ERROR HANDLING PATTERNS
// =====================================================================

// Pattern 1: Try-Catch with User Friendly Messages
try {
  await sendRequest(...);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Request sent!'), backgroundColor: Colors.green),
  );
} on FirebaseException catch (e) {
  String message = _getErrorMessage(e.code);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Unknown error: $e'), backgroundColor: Colors.red),
  );
}

// Pattern 2: Validate Before Action
if (!await hasActiveRequest(userId, volunteerId)) {
  await sendRequest(...);
} else {
  showDialog(context, 'You already sent a request to this volunteer');
}

// Pattern 3: Permission Check
final permission = await Geolocator.requestPermission();
if (permission == LocationPermission.denied) {
  showError('Location permission denied');
} else {
  final position = await Geolocator.getCurrentPosition();
}

// Pattern 4: Stream Error Handling
stream!.listen(
  (data) => setState(() => _data = data),
  onError: (error) => showError('Error: $error'),
);

// =====================================================================
// FIRESTORE QUERIES REFERENCE
// =====================================================================

/*
Find available verified volunteers:
Query: users
Where: role == "volunteer"
And: verificationStatus == "verified"
And: isAvailable == true
OrderBy: none (filtered in-memory by distance)
Result: Array of available volunteers

Get pending requests for volunteer:
Query: walkingRequests
Where: volunteerId == "volunteer456"
And: status == "pending"
OrderBy: createdAt (descending)
Result: Array of pending requests

Get user's outgoing requests:
Query: walkingRequests
Where: requesterId == "user123"
OrderBy: createdAt (descending)
Result: Array of all requests from this user

Get all requests for volunteer:
Query: walkingRequests
Where: volunteerId == "volunteer456"
OrderBy: createdAt (descending)
Result: Array of all requests to this volunteer
*/

// =====================================================================
// TESTING SNIPPETS
// =====================================================================

// Test finding volunteers
Future<void> testFindVolunteers() async {
  final fs = FirestoreService.instance;
  final location = LatLng(37.7749, -122.4194);
  
  final startTime = DateTime.now();
  final volunteers = await fs.fetchNearbyVerifiedVolunteers(location);
  final duration = DateTime.now().difference(startTime);
  
  print('Found ${volunteers.length} volunteers in ${duration.inMilliseconds}ms');
  for (final v in volunteers) {
    final dist = await fs.getDistanceToVolunteer(location, v.currentLocation!);
    print('  - ${v.name}: ${dist.toStringAsFixed(2)} km');
  }
}

// Test sending request
Future<void> testSendRequest() async {
  final fs = FirestoreService.instance;
  
  final requestId = await fs.sendWalkingRequest(
    requesterId: 'test_user',
    requesterName: 'Test User',
    requesterPhone: '+1234567890',
    requesterLocation: GeoPoint(37.7749, -122.4194),
    volunteerId: 'test_volunteer',
    volunteerName: 'Test Volunteer',
    volunteerPhone: '+0987654321',
    volunteerLocation: GeoPoint(37.7750, -122.4195),
    distanceToRequester: 0.5,
  );
  
  print('Created request: $requestId');
  final request = await fs.getWalkingRequest(requestId);
  print('Status: ${request?.status}');
}

// Test accepting request
Future<void> testAcceptRequest(String requestId) async {
  final fs = FirestoreService.instance;
  
  try {
    await fs.acceptRequest(requestId, 'test_volunteer');
    print('Request accepted!');
  } catch (e) {
    print('Error: $e');
  }
}

// =====================================================================
// PERFORMANCE OPTIMIZATION TIPS
// =====================================================================

/*
1. Volunteer Search
   - Cache results for 30 seconds
   - Use StreamBuilder for real-time updates
   - Don't refetch if user hasn't moved >100m

2. Request Handling
   - Use transactions to prevent race conditions
   - Batch updates when possible
   - Clean up old (>24h) requests periodically

3. Location Updates
   - Update every 15-30 seconds (configurable)
   - Don't update if movement < distanceFilterM (15-30m)
   - Use background service for continuous updates

4. Image Loading
   - Use cachedNetworkImage for profile pictures
   - Compress images before upload
   - Use placeholder images while loading

5. Database
   - Create indexes before querying (auto-created)
   - Monitor read/write counts
   - Archive old requests periodically
*/

// =====================================================================
// COMMON MISTAKES TO AVOID
// =====================================================================

/*
❌ DON'T: Forget to check location permission
✅ DO: Always request and check permission before accessing location

❌ DON'T: Call expensive queries in build()
✅ DO: Use FutureBuilder/StreamBuilder with queries in providers

❌ DON'T: Hardcode user IDs
✅ DO: Get from FirebaseAuth.instance.currentUser!.uid

❌ DON'T: Update volunteer availability in multiple places
✅ DO: Use transactions to update atomically

❌ DON'T: Show raw error messages to users
✅ DO: Map error codes to user-friendly messages

❌ DON'T: Ignore null safety
✅ DO: Use ! and ? operators properly, handle nulls

❌ DON'T: Store duplicate data
✅ DO: Normalize data, use references where possible

❌ DON'T: Fetch all volunteers then filter
✅ DO: Use Firestore queries to filter at source
*/
