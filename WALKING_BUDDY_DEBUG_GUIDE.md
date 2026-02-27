# Walking Buddy Broadcast Request System - Debugging Guide

## Overview

The Walking Buddy request system uses a **broadcast model**:
- **User** creates a request → **ALL verified volunteers** can see it in real-time
- **First volunteer** to accept → request is locked to them
- System ensures atomic operations via Firestore transactions

## Architecture

### Collections & Structure

```
walkingRequests/{requestId}
├── requestId (string)          - Unique request ID
├── requesterId (string)         - User's Firebase UID
├── requesterName (string)       - User's display name
├── requesterLocation (GeoPoint) - User's coordinates
├── status (string)              - "pending" | "accepted"
├── acceptedBy (string|null)     - Volunteer's UID (if accepted)
├── createdAt (timestamp)        - Request creation time
└── acceptedAt (timestamp|null)  - When volunteer accepted
```

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│ USER CREATES REQUEST                                        │
│ - createBroadcastRequest(requesterId, name, location)       │
│ - Creates doc in walkingRequests with status="pending"      │
│ - Firestore rule grants CREATE access                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │ STREAM TO FIRESTORE          │
        │ (writes in ~1-2 seconds)     │
        └──────────────────┬───────────┘
                           │
    ┌──────────────────────┴──────────────────────────┐
    │                                                 │
    ▼                                                 ▼
┌──────────────────────────────────┐  ┌──────────────────────────────────┐
│ USER SCREEN                      │  │ VOLUNTEER SCREEN                 │
│ streamUserRequestStatus(reqId)   │  │ streamPendingRequestsForVolunteer│
│ - Waits for acceptedBy           │  │ - Listens to ALL pending         │
│ - Shows "Waiting for volunteer"  │  │ - Shows pending requests         │
└──────────────────────────────────┘  └────────────┬─────────────────────┘
                                                   │
                                    ┌──────────────▼──────────────┐
                                    │ VOLUNTEER ACCEPTS REQUEST   │
                                    │ WITH TRANSACTION            │
                                    │ - Prevents race conditions  │
                                    │ - Atomically updates status │
                                    └──────────────┬──────────────┘
                                                   │
                                    ┌──────────────▼──────────────┐
                                    │ UPDATES:                    │
                                    │ - status = "accepted"       │
                                    │ - acceptedBy = volunteerId  │
                                    │ - acceptedAt = now()        │
                                    └─────────────────────────────┘
```

## Common Issues & Debugging

### Issue 1: "Volunteer sees NO requests even though user created one"

**Root Causes:**
1. Security rules don't allow READ on walkingRequests
2. Both emulators not connected to same Firebase project
3. Firestore emulator not running
4. Documents actually haven't been created (check user-side logs)
5. Status field has different value than "pending"

**Debug Steps:**

```dart
// 1. Enable debug logging (already enabled in service):
// Look for emoji logs like: 🚶 [WalkingRequest]

// 2. Test 1: Fetch ALL requests with no filters
final allRequests = await firestoreService.debugFetchAllRequests();
print('Total requests in collection: ${allRequests.length}');

// 3. Test 2: Check Firestore console directly
// Go to: https://console.firebase.google.com
// Look for: walkingRequests collection
// Expand documents and check fields

// 4. Test 3: Check security rules in demo.firestore.rules
// Must allow: allow read: if isAuthenticated();

// 5. Test 4: Confirm both emulators use SAME host
// Echo $FIRESTORE_EMULATOR_HOST
// Should be same on both devices
```

**Solution Checklist:**

- [ ] Both emulators logged in with DIFFERENT Firebase Auth users
- [ ] Both emulators pointing to SAME Firebase project
- [ ] `firebase emulators:start` is running on your machine
- [ ] Firestore security rules have walkingRequests collection with proper rules
- [ ] Created request has status = "pending" (not "waiting" or "new")

### Issue 2: "User sees 'Waiting for volunteer...' but request was already accepted"

**Root Cause:** User stream not receiving updates
- Firestore latency (usually 1-2 seconds)
- Stream listener not properly attached
- Document field name mismatch

**Debug Steps:**

```dart
// Check the user-side stream logs:
// 📊 Status update: status=accepted, acceptedBy=<volunteerId>

// If not seeing updates, try:
// 1. Close user emulator completely
// 2. Close volunteer emulator
// 3. Restart firebase emulator: Ctrl+C, then firebase emulators:start
// 4. Rerun both emulators
```

### Issue 3: "Race condition - multiple volunteers accepted same request"

**Solution:** Already handled via transaction!

```dart
// acceptRequest() uses Firestore transaction:
await db.runTransaction((transaction) async {
  final snap = await transaction.get(requestDoc);
  final request = WalkingRequestModel.fromJson(snap.data());
  
  // Check CURRENT status is still pending
  if (request.status != WalkingRequestStatus.pending) {
    throw Exception('Request already handled');
  }
  
  // Atomically update
  transaction.update(requestDoc, {
    'status': WalkingRequestStatus.accepted.name,
    'acceptedBy': volunteerId,
  });
});
```

The database ensures only ONE transaction succeeds. Others get exception.

## Testing Checklist

### Environment Setup

```bash
# 1. Start Firebase emulators
firebase emulators:start --project=YOUR_PROJECT_ID

# 2. Open TWO terminals with two emulators
# Terminal 1 (User):
flutter run

# Terminal 2 (Volunteer):
flutter run -d emulator-name-2   # Or second device/emulator
```

### Test 1: Create Request

```
USER EMULATOR:
1. Go to Walking Buddy screen
2. Tap "Create Request"
3. Confirm location
4. Check logs: 🚶 [WalkingRequest] Creating new broadcast request
5. Should see: ✅ Request created successfully: <requestId>
```

### Test 2: Volunteer Sees Request

```
VOLUNTEER EMULATOR:
1. Go to Volunteer Mode screen
2. Debug panel should show:
   - 🎬 Volunteer Mode Screen initialized
   - 📊 Stream snapshot: 1 pending requests
3. Should see request card with user name and location
4. If not, tap "Test Firestore Connection" button
```

### Test 3: Accept Request

```
VOLUNTEER EMULATOR:
1. Tap "Accept Request"
2. Check logs:
   - 👤 Accepting request from <userName>
   - ✅ Request accepted, updating availability...
3. Should navigate to live tracking screen

USER EMULATOR:
1. Should see: ✅ <volunteerId> accepted your request
2. Should navigate to live tracking with volunteer info
```

## Debug Logs Reference

### Service Logs (3 emojis = category)

```
🚶 [WalkingRequest]  - Walking request service actions
👤 [VolunteerEligibility] - Volunteer filtering
🎬 [VolunteerMode] - Volunteer screen actions
🔥 [Firebase] - Firebase initialization
```

### Log Levels

```
✅ Success       - Operation completed
❌ Error         - Operation failed with exception
⚠️  Warning      - Potential issue but continuing
📊 Data info     - Data snapshot/count
🔍 Debug         - Diagnostic information
📍 Location      - Location-related actions
```

### Stream State Logs

When stream connects:
```
🎬 STREAMING PENDING REQUESTS for volunteer
   Query: collection=walkingRequests
   where status == "pending"
   orderBy createdAt (descending)

📊 Stream snapshot received
   Connection state: SERVER
   Document count: 1
   
   📄 Doc: <requestId>
      status: pending
      requesterId: <userId>
      requesterName: John Doe
```

## Firestore Rules

```firestore
match /walkingRequests/{requestId} {
  // ✅ Authenticated users (volunteers) can READ ALL requests
  allow read: if isAuthenticated();
  
  // ✅ Authenticated users can CREATE requests
  allow create: if isAuthenticated()
                && request.resource.data.requesterId == request.auth.uid;
  
  // ✅ Requesters can update their requests, volunteers can update accepted
  allow update: if isAuthenticated()
                && (
                  resource.data.requesterId == request.auth.uid
                  || (
                    resource.data.status == 'pending'
                    && request.resource.data.status == 'accepted'
                    && request.resource.data.acceptedBy == request.auth.uid
                  )
                );
  
  // Only admins can delete
  allow delete: if isAdmin();
}
```

## Volunteer Eligibility

Displayed volunteers must match:

```dart
// ALL of these must be true:
- role == "volunteer"
- verificationStatus == "verified"
- isAvailable == true

// NOT filtered by volunteerId (broadcast model!)
// Every verified volunteer sees EVERY request
```

## Performance Considerations

- **Indexes:** Firestore auto-creates index for `status + createdAt`
- **Latency:** Expect 1-2s for documents to propagate in emulator
- **Listeners:** Each connected volunteer gets real-time updates via snapshot listener
- **Transactions:** Accept request uses transaction for atomic safety

## Expected Behavior

### First Time Setup

```
1. User creates request
   └─ Logs appear in user emulator console
   └─ Takes 1-2 seconds to reach Firestore
   
2. Volunteer taps "Volunteer Mode"
   └─ Stream connects to Firestore
   └─ Should see pending request within 1-2 seconds
   
3. Volunteer accepts
   └─ Transaction executes atomically
   └─ User sees update immediately (usually <1s)
   
4. Both navigate to live tracking
   └─ Location streaming begins
   └─ Both can see each other's location
```

### If Something Breaks

```
1. Check emulator is running: firebase emulators:start
2. Check both are authenticated with DIFFERENT users
3. Check both point to SAME Firebase project
4. Check Firestore console has walkingRequests collection
5. Use "Test Firestore Connection" button to verify access
6. Check device logs with: adb logcat | grep "WalkingRequest"
```

## Production Checklist

- [ ] Remove debug logging (or make configurable)
- [ ] Remove "Test Firestore Connection" debug button
- [ ] Verify security rules on production Firestore
- [ ] Test with actual location data
- [ ] Monitor Firestore read/write counts
- [ ] Add error reporting/Crashlytics integration
- [ ] Test with poor network conditions
- [ ] Verify volunteer availability state management
