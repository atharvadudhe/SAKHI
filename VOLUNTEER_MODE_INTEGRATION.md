/**
 * SAKHI VOLUNTEER MODE - COMPLETE INTEGRATION GUIDE
 * 
 * This guide walks you through implementing the Volunteer Mode feature
 * in your SAKHI Flutter app.
 */

// =====================================================================
// TABLE OF CONTENTS
// =====================================================================
/*
1. Overview
2. Files Created
3. Setup Instructions
4. Integration Steps
5. Feature Implementation
6. Error Handling
7. Testing
8. Troubleshooting
9. Production Checklist
*/

// =====================================================================
// 1. OVERVIEW
// =====================================================================

/*
Volunteer Mode enables users to:
- Find nearby verified volunteers within a configurable radius
- Send walking requests to volunteers
- Get real-time updates of request status

Volunteers can:
- Receive real-time notifications of incoming requests
- Accept or reject requests
- Become unavailable when they accept a request
- Complete sessions and become available again

The implementation follows clean architecture principles:
- Models: Data classes with JSON serialization
- Services: Extensions on FirestoreService for business logic
- Providers: Riverpod providers for state management
- Screens: Example UI widgets
- Widgets: Reusable components
*/

// =====================================================================
// 2. FILES CREATED
// =====================================================================

/*
Models:
- lib/models/walking_request_model.dart
  Defines WalkingRequestModel with status enum

Services:
- lib/services/volunteer_service.dart
  Extension with methods for finding volunteers, calculating distance
  
- lib/services/walking_request_service.dart
  Extension with methods for managing walking requests

Screens:
- lib/screens/find_volunteer_screen.dart
  UI for users to find and request volunteers
  
- lib/screens/volunteer_mode_screen.dart
  UI for volunteers to manage incoming requests

Widgets:
- lib/widgets/volunteer_widgets.dart
  Reusable widgets for displaying volunteers and requests

Providers:
- lib/providers/volunteer_providers.dart
  Riverpod providers for state management and data fetching

Documentation:
- VOLUNTEER_MODE_SETUP.md
  Firebase configuration, security rules, and indexes
  
- VOLUNTEER_MODE_INTEGRATION.md
  This file - detailed integration guide
*/

// =====================================================================
// 3. SETUP INSTRUCTIONS
// =====================================================================

/*
STEP 1: Update Firebase Console

1. Go to https://console.firebase.google.com
2. Select your "sakhi-app-d88d8" project
3. Navigate to Firestore Database

STEP 2: Update Security Rules

1. Go to Firestore → Rules tab
2. Replace all rules with the content from VOLUNTEER_MODE_SETUP.md
   (Section 1: FIRESTORE SECURITY RULES)
3. Click "Publish"

STEP 3: Create Firestore Indexes

1. Go to Firestore → Indexes tab
2. Create the following composite indexes:

Index 1: Find available verified volunteers
  Collection: users
  Fields: role (Asc), verificationStatus (Asc), isAvailable (Asc)

Index 2: Get pending requests for volunteer
  Collection: walkingRequests
  Fields: volunteerId (Asc), status (Asc), createdAt (Desc)

Index 3: Get user's outgoing requests
  Collection: walkingRequests
  Fields: requesterId (Asc), createdAt (Desc)

Index 4: Requests for specific volunteer
  Collection: walkingRequests
  Fields: volunteerId (Asc), createdAt (Desc)

Alternative: Update firestore.indexes.json (already in repo)
and deploy via Firebase CLI: firebase deploy --only firestore

STEP 4: Verify User Model in Firestore

Ensure users collection has these fields:
- uid (string)
- name (string)
- phone (string)
- role (string): "user" or "volunteer"
- isAvailable (boolean)
- currentLocation (GeoPoint)
- photoUrl (string, optional)
- verificationStatus (string): "verified", "pending", "rejected", "unverified"
- lastHeartbeat (timestamp)
*/

// =====================================================================
// 4. INTEGRATION STEPS
// =====================================================================

/*
STEP 1: Add Imports to Your Screens

import '../services/firestore_service.dart';
import '../services/volunteer_service.dart';
import '../services/walking_request_service.dart';
import '../screens/find_volunteer_screen.dart';
import '../screens/volunteer_mode_screen.dart';
import '../widgets/volunteer_widgets.dart';

STEP 2: Update Your Main App Widget

import '../providers/volunteer_providers.dart';

// If using Riverpod:
void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

STEP 3: Add Navigation to Find Volunteer Screen

// In your main app or home screen, add a button:
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FindVolunteerScreen(),
      ),
    );
  },
  child: const Text('Find Walking Buddy'),
)

STEP 4: Add Navigation to Volunteer Mode Screen

// For volunteer users (check role and verification status):
if (currentUser.role == UserRole.volunteer &&
    currentUser.verificationStatus == VerificationStatus.verified) {
  ElevatedButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VolunteerModeScreen(
            volunteerId: currentUser.uid,
          ),
        ),
      );
    },
    child: const Text('Volunteer Mode'),
  );
}

STEP 5: Update User Profile Sharing

Ensure location is updated regularly:
import '../services/firestore_service.dart';

Future<void> updateUserLocation() {
  final position = await Geolocator.getCurrentPosition();
  final firestoreService = FirestoreService.instance;
  
  await firestoreService.updateUserLocation(
    currentUserId,
    GeoPoint(position.latitude, position.longitude),
  );
}

Call this in your location update service timer.
*/

// =====================================================================
// 5. FEATURE IMPLEMENTATION
// =====================================================================

/*
FEATURE 1: Find Nearby Verified Volunteers

Location: lib/screens/find_volunteer_screen.dart

How it works:
1. Request user location permission
2. Get current user location
3. Call FirestoreService.fetchNearbyVerifiedVolunteers(location)
4. The service:
   - Queries users collection for: role="volunteer", verified, available
   - Calculates distance using Haversine formula
   - Filters results within volunteerSearchRadiusKm (5.0 km)
   - Sorts by distance (nearest first)
   - Returns list of UserModel objects

Distance Calculation:
Uses Haversine formula to calculate great-circle distance:
- a = sin²(Δφ/2) + cos(φ1) * cos(φ2) * sin²(Δλ/2)
- c = 2 * atan2(√a, √(1−a))
- d = R * c (where R = 6371 km)

Why Haversine?
- Accounts for Earth's spherical shape
- More accurate than simple coordinate difference
- Standard for geographic distance calculations

Edge cases handled:
- No location permission → Show friendly error
- No location available → Show retry button
- No volunteers nearby → Show empty state
- Network errors → Show error with retry


FEATURE 2: Request + Approval System

Location: lib/screens/volunteer_mode_screen.dart

How it works:

User Side:
1. User selects a volunteer from the list
2. Call FirestoreService.sendWalkingRequest(...)
3. Creates document in walkingRequests collection
4. Status: "pending"
5. UI shows "Waiting for response..."

Volunteer Side:
1. Volunteer sees incoming requests in real-time
2. StreamBuilder watches walkingRequests with volunteerId and status="pending"
3. Requests auto-expire after 5 minutes
4. Shows requester info: name, phone, location, distance
5. Two action buttons: Accept or Reject

Accept Flow:
1. Volunteer taps "Accept"
2. Transaction updates:
   - Request status → "accepted"
   - Request respondedAt → current time
   - Volunteer.isAvailable → false
3. Requester sees accepted status
4. Session begins (walking buddy feature takes over)

Reject Flow:
1. Volunteer taps "Reject"
2. Can add optional rejection reason
3. Transaction updates:
   - Request status → "rejected"
   - Request respondedAt → current time
   - Request rejectionReason → user's reason
4. Requester sees rejection
5. Can select another volunteer

Features:
- Real-time updates using StreamBuilder
- Atomic operations using Firestore transactions
- Auto-expiration after 5 minutes
- Prevents duplicate active requests
- Prevents rejecting already-handled requests
- Shows loading indicators during operations
*/

// =====================================================================
// 6. ERROR HANDLING
// =====================================================================

/*
Implement proper error handling in your screens:

Errors to Handle:
1. Location Permission Denied
   - Show permission request dialog
   - Provide "Open Settings" button to grant permission

2. Location Unavailable
   - Show "Unable to get your location" message
   - Provide "Retry" button

3. Network Errors
   - Show "No internet connection" message
   - Implement automatic retry with exponential backoff

4. Firestore Errors
   - Document not found → "Request expired or invalid"
   - Permission denied → "Not authorized for this action"
   - Transaction failed → "Action failed, try again"

5. Validation Errors
   - Empty volunteer list → "No volunteers nearby"
   - Duplicate request → "You already sent this request"
   - Request already handled → "This request was already handled"

Example Error Handling Pattern:

try {
  final requestId = await sendWalkingRequest(
    requesterId: userId,
    // ... other parameters
  );
  
  // Show success
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Request sent successfully')),
  );
} on FirebaseException catch (e) {
  // Handle Firebase errors
  String message = 'An error occurred';
  
  if (e.code == 'permission-denied') {
    message = 'You don\'t have permission to perform this action';
  } else if (e.code == 'not-found') {
    message = 'The volunteer is no longer available';
  }
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );
} catch (e) {
  // Handle other errors
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
  );
}
*/

// =====================================================================
// 7. TESTING
// =====================================================================

/*
Manual Testing Checklist:

□ Location Permission
  - App requests permission on first screen open
  - Permission dialog shows with "Allow" and "Don't Allow"
  - Selecting "Allow" enables location services
  - Selecting "Don't Allow" shows error message

□ Find Volunteers
  - Screen opens and shows loading spinner
  - Volunteers within 5km radius are displayed
  - List is sorted by distance (nearest first)
  - Each volunteer card shows: name, distance, verified badge
  - "Request Buddy" button is clickable

□ Send Request
  - Clicking "Request Buddy" shows loading dialog
  - Network delay is handled gracefully
  - Success shows "Request sent!" message
  - User can't send duplicate requests immediately

□ Volunteer Mode
  - Only shown if user.role == "volunteer" and verified
  - Shows "No pending requests" when idle
  - New requests appear in real-time
  - Each request shows: requester name, phone, distance, time

□ Accept Request
  - "Accept" button shows loading spinner
  - Request status changes to "accepted"
  - Volunteer becomes unavailable
  - Requester receives notification (if implemented)
  - Screen now shows next pending request

□ Reject Request
  - "Reject" button shows rejection dialog
  - Can add optional rejection reason
  - Request status changes to "rejected"
  - Dialog closes and next request shows
  - Volunteer remains available

□ Auto-Expiration
  - Requests older than 5 minutes auto-expire
  - Expired requests disappear from volunteer's view
  - Status in database is updated to "expired"

□ Error Handling
  - Network errors show user-friendly messages
  - Retry buttons work correctly
  - Permission errors show Settings button
  - Invalid requests show appropriate errors

Testing Scenarios:

Scenario 1: Two Users
- User A (non-volunteer) finds User B (verified volunteer)
- User A sends request, User B sees it
- User B accepts, User A sees accepted status
- User B becomes unavailable in search results
- User B completes session, becomes available again

Scenario 2: Request Rejection
- User A sends request to User B
- User B rejects with reason "Too far"
- User A sees rejection, selects another volunteer

Scenario 3: Request Expiration
- User A sends request
- User B ignores request for 6 minutes
- Request auto-expires
- User A sees timeout, needs to resend or pick another volunteer

Scenario 4: Location Updates
- User A's location changes
- New volunteers in new area appear
- Old volunteers out of range disappear
*/

// =====================================================================
// 8. TROUBLESHOOTING
// =====================================================================

/*
Issue: "No volunteers found" even though verified volunteers exist

Solution:
1. Check Firestore data:
   - Users collection has isAvailable == true
   - Users have role == "volunteer"
   - Users have verificationStatus == "verified"
   - Users have currentLocation with valid GeoPoint

2. Check AppConstants:
   - volunteerSearchRadiusKm is set correctly (default: 5.0)

3. Check Location:
   - User's location is being updated correctly
   - Coordinates are valid (lat: -90 to 90, lon: -180 to 180)

4. Check Firestore Rules:
   - Security rules allow reading from users collection
   - Indexes are created and in "READY" state


Issue: Volunteer doesn't receive incoming requests

Solution:
1. Check FirebaseAuth:
   - Volunteer is signed in with correct UID
   - UID matches walkingRequests.volunteerId

2. Check Firestore Data:
   - walkingRequests document exists with correct volunteerId
   - status field is exactly "pending"
   - Ensure no typos in field names

3. Check Stream:
   - StreamBuilder isn't building correctly
   - ConnectionState.waiting is shown, then data
   - Try calling streamIncomingRequests directly in debugger

4. Test with Emulator:
   - Use Firestore Emulator to test locally
   - Check emulator logs for errors


Issue: "Permission denied" errors

Solution:
1. Check Security Rules:
   - Rules allow users to read from users collection
   - Rules allow authenticated users to create walkingRequests
   - Rules allow volunteers to update their own requests

2. Check Firestore Auth:
   - User is authenticated (request.auth != null)
   - User UID matches data being accessed

3. Clear Auth Cache:
   - Sign out and sign in again
   - Clear app cache and reinstall


Issue: Haversine distance calculation seems wrong

Solution:
1. Verify inputs:
   - Latitude range: -90 to 90
   - Longitude range: -180 to 180
   - Values are in decimal degrees, not radians

2. Test calculation:
   - San Francisco (37.7749° N, 122.4194° W) to 
     Los Angeles (34.0522° N, 118.2437° W)
   - Expected distance: ~559 km
   - If result doesn't match, check formula

3. Check GeoPoint parsing:
   - GeoPoint.latitude and GeoPoint.longitude are readable
   - Values aren't being converted incorrectly
*/

// =====================================================================
// 9. PRODUCTION CHECKLIST
// =====================================================================

/*
Before deploying to production:

Code Quality:
□ All null safety is handled (@required, ?)
□ No print statements (use proper logging)
□ No hardcoded IDs or API keys
□ Error messages are user-friendly
□ Loading indicators have timeouts
□ Proper resource cleanup (close streams, cancel requests)

Testing:
□ All manual tests pass
□ Edge cases are handled
□ Network failures don't crash app
□ Location permission works on real devices
□ Works on both Android and iOS

Firebase Configuration:
□ Security rules are in production mode
□ Firestore indexes are in READY state
□ No overly permissive rules
□ Backup is enabled

Data Validation:
□ All user inputs are validated
□ Firestore data matches expected schema
□ Old data is cleaned up (e.g., expired requests)
□ No duplicate documents

Performance:
□ Volunteer search completes in <2 seconds
□ Stream updates are responsive
□ No N+1 queries
□ Images are optimized
□ Pagination implemented for large lists

Security:
□ Never expose API keys in code
□ Location data is handled securely
□ Phone numbers validated before storage
□ User data is encrypted in transit
□ Volunteer verification is solid

Monitoring:
□ Error logging set up (Firebase Crashlytics)
□ Performance monitoring enabled
□ Set up alerts for high error rates
□ Monitor Firestore read/write counts

Documentation:
□ Code is well commented
□ Integration guide is complete
□ README updated with new features
□ API changes documented


Final Deployment Steps:

1. Update version number in pubspec.yaml
2. Generate release APK: flutter build apk --release
3. Test release APK on real device
4. Upload to Play Store / App Store
5. Monitor crash logs for first 24 hours
6. Be ready to roll back if issues occur
*/
