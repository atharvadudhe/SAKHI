# SAKHI Volunteer Mode - Implementation Checklist

Use this checklist to guide your implementation of the Volunteer Mode feature.

## 📋 Pre-Implementation

- [ ] Read [VOLUNTEER_MODE_README.md](VOLUNTEER_MODE_README.md) completely
- [ ] Review all 4 documentation files:
  - [ ] VOLUNTEER_MODE_README.md (Overview)
  - [ ] VOLUNTEER_MODE_SETUP.md (Firebase config)
  - [ ] VOLUNTEER_MODE_INTEGRATION.md (Integration guide)
  - [ ] VOLUNTEER_MODE_QUICK_REFERENCE.md (Quick reference)
- [ ] Understand the Haversine distance formula
- [ ] Review Firestore security rules
- [ ] Verify you have Riverpod set up (already have flutter_riverpod)

---

## 🔧 Firebase Configuration (Do This First!)

### Update Firestore Security Rules

- [ ] Go to Firebase Console → Select "sakhi-app-d88d8" project
- [ ] Navigate to Firestore Database → Rules tab
- [ ] Copy rules from [VOLUNTEER_MODE_SETUP.md](VOLUNTEER_MODE_SETUP.md) (Section 1)
- [ ] Replace all existing rules
- [ ] Click "Publish" to apply rules
- [ ] Verify "Rules deployed successfully" message appears

### Create Firestore Composite Indexes

Option A: Create Manually in Firebase Console

- [ ] Go to Firestore Database → Indexes tab
- [ ] Click "Create Index"

Index 1: Find Available Verified Volunteers
- [ ] Collection: `users`
- [ ] Field 1: `role` (Ascending)
- [ ] Field 2: `verificationStatus` (Ascending)
- [ ] Field 3: `isAvailable` (Ascending)
- [ ] Query Scope: Collection
- [ ] Create Index ✓

Index 2: Get Pending Requests for Volunteer
- [ ] Collection: `walkingRequests`
- [ ] Field 1: `volunteerId` (Ascending)
- [ ] Field 2: `status` (Ascending)
- [ ] Field 3: `createdAt` (Descending)
- [ ] Query Scope: Collection
- [ ] Create Index ✓

Index 3: Get User's Outgoing Requests
- [ ] Collection: `walkingRequests`
- [ ] Field 1: `requesterId` (Ascending)
- [ ] Field 2: `createdAt` (Descending)
- [ ] Query Scope: Collection
- [ ] Create Index ✓

Index 4: Find Requests for Specific Volunteer
- [ ] Collection: `walkingRequests`
- [ ] Field 1: `volunteerId` (Ascending)
- [ ] Field 2: `createdAt` (Descending)
- [ ] Query Scope: Collection
- [ ] Create Index ✓

Wait for all indexes to reach "READY" state (may take 5-10 minutes)

Option B: Via firestore.indexes.json (CLI Deployment)

- [ ] Update `firestore.indexes.json` with indexes from [VOLUNTEER_MODE_SETUP.md](VOLUNTEER_MODE_SETUP.md)
- [ ] Run: `firebase deploy --only firestore:indexes`
- [ ] Verify indexes are created in Firebase Console
- [ ] Wait for "READY" status

---

## 📦 Verify Files Are Created

### Models
- [ ] `lib/models/walking_request_model.dart` exists
  - [ ] WalkingRequestModel class
  - [ ] WalkingRequestStatus enum
  - [ ] fromJson() method
  - [ ] toJson() method

### Services
- [ ] `lib/services/volunteer_service.dart` exists
  - [ ] fetchNearbyVerifiedVolunteers()
  - [ ] streamNearbyVerifiedVolunteers()
  - [ ] getDistanceToVolunteer()
  - [ ] hasActiveRequestToVolunteer()
  - [ ] _calculateHaversineDistance()
  - [ ] _toRadians()

- [ ] `lib/services/walking_request_service.dart` exists
  - [ ] sendWalkingRequest()
  - [ ] streamIncomingRequests()
  - [ ] acceptRequest()
  - [ ] rejectRequest()
  - [ ] completeRequest()
  - [ ] cancelRequest()
  - [ ] getVolunteerRequestStats()

### Screens
- [ ] `lib/screens/find_volunteer_screen.dart` exists
  - [ ] FindVolunteerScreen widget
  - [ ] Location initialization
  - [ ] Display volunteer list
  - [ ] Send request functionality

- [ ] `lib/screens/volunteer_mode_screen.dart` exists
  - [ ] VolunteerModeScreen widget
  - [ ] Real-time request stream
  - [ ] Accept/Reject buttons
  - [ ] Loading states

### Widgets
- [ ] `lib/widgets/volunteer_widgets.dart` exists
  - [ ] VolunteerCard
  - [ ] WalkingRequestCard
  - [ ] VolunteerEmptyState
  - [ ] DistanceBadge
  - [ ] VolunteerAvailabilityBadge
  - [ ] RequestStatusBadge

### Providers
- [ ] `lib/providers/volunteer_providers.dart` exists
  - [ ] userLocationProvider
  - [ ] nearbyVolunteersProvider
  - [ ] nearbyVolunteersStreamProvider
  - [ ] incomingRequestsProvider
  - [ ] walkingRequestProvider
  - [ ] Helper functions

### Documentation
- [ ] `VOLUNTEER_MODE_README.md`
- [ ] `VOLUNTEER_MODE_SETUP.md`
- [ ] `VOLUNTEER_MODE_INTEGRATION.md`
- [ ] `VOLUNTEER_MODE_QUICK_REFERENCE.md`

### Example
- [ ] `lib/screens/example_volunteer_integration.dart` exists

---

## 🔌 Integration Steps

### Step 1: Update imports in your main app

- [ ] Add imports to your main navigation/home screen:
```dart
import '../services/firestore_service.dart';
import '../services/volunteer_service.dart';
import '../services/walking_request_service.dart';
import '../screens/find_volunteer_screen.dart';
import '../screens/volunteer_mode_screen.dart';
import '../providers/volunteer_providers.dart';
```

### Step 2: Wrap app with ProviderScope (if not already done)

- [ ] In `main.dart`, wrap MaterialApp with ProviderScope:
```dart
void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### Step 3: Add "Find Buddy" button for regular users

- [ ] In your home screen or main navigation:
```dart
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FindVolunteerScreen()),
    );
  },
  child: const Text('Find Walking Buddy'),
)
```

### Step 4: Add "Volunteer Mode" button for volunteers

- [ ] Add this to your volunteer's home screen:
```dart
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
  )
}
```

### Step 5: Ensure location updates are sent regularly

- [ ] In your location service, update user location every 15-30 seconds:
```dart
await FirestoreService.instance.updateUserLocation(
  userId,
  GeoPoint(position.latitude, position.longitude),
);
```

- [ ] Verify this is called from your background location service
- [ ] Test on real device to ensure location is updating

### Step 6: Test Example Integration Screen (Optional)

- [ ] Copy example from `lib/screens/example_volunteer_integration.dart`
- [ ] Adapt to your UI/navigation style
- [ ] Use as reference for integrating volunteers and users flows

---

## 🧪 Testing Checklist

### Functional Testing

#### Find Volunteer Feature
- [ ] App requests location permission on first open
- [ ] User accepts permission and location enabled
- [ ] After 2-3 seconds, list of volunteers appears
- [ ] Volunteers are sorted by distance (nearest first)
- [ ] Each volunteer shows: name, distance, verified badge
- [ ] "Request Buddy" button is clickable for each volunteer
- [ ] Clicking "Request Buddy" shows loading indicator
- [ ] Request sends successfully and shows success message
- [ ] User can't immediately send duplicate requests

#### Volunteer Mode Feature
- [ ] Only visible if role == "volunteer" AND verified == true
- [ ] Shows "No pending requests" when idle
- [ ] New requests appear in real-time
- [ ] Each request shows: requester name, phone, distance, time sent
- [ ] "Accept" button shows loading spinner
- [ ] After accepting, volunteer becomes unavailable in search
- [ ] "Reject" button opens dialog to add reason
- [ ] Rejecting works and next request shows
- [ ] Requests auto-expire after 5 minutes
- [ ] Expired requests disappear from view

### Edge Cases
- [ ] No location permission → Shows error with open settings button
- [ ] Location fails → Shows error with retry button
- [ ] No volunteers nearby → Shows empty state
- [ ] Network error → Shows error with retry
- [ ] No internet → Shows appropriate error
- [ ] User moves far away → Volunteers list updates
- [ ] Volunteer becomes unavailable → Disappears from list
- [ ] Request expires → Auto-removes and shows next request
- [ ] Handle multiple rapid requests → One succeeds, others fail gracefully

### Android Testing
- [ ] Test on Android device (API 21+)
- [ ] Location permission works
- [ ] Geolocator works correctly
- [ ] Firestore writes and reads work
- [ ] Streams update in real-time
- [ ] UI renders correctly at different screen sizes

### iOS Testing
- [ ] Test on iOS device (iOS 11+)
- [ ] Location permission works
- [ ] Geolocator works correctly
- [ ] Firestore writes and reads work
- [ ] Streams update in real-time
- [ ] UI renders correctly at different screen sizes

---

## 📊 Verification Tests

### Before Deployment

- [ ] All indexes are in "READY" state
- [ ] Security rules are deployed
- [ ] No compilation errors in Flutter
- [ ] All imports resolve correctly
- [ ] No null safety warnings
- [ ] All models serialize/deserialize correctly
- [ ] Location permission works on real device
- [ ] Firestore rules allow read/write operations
- [ ] Distance calculation is accurate
- [ ] Real-time streams work properly

### Performance Tests

- [ ] Finding 10 volunteers completes in <2 seconds
- [ ] Real-time updates arrive within 1 second
- [ ] App doesn't lag with 100 pending requests
- [ ] Memory usage is reasonable (< 100MB)
- [ ] Battery drain is minimal when idle

---

## 🚀 Pre-Production Checklist

### Code Quality
- [ ] No print() statements (use proper logging)
- [ ] No hardcoded IDs or API keys in code
- [ ] Error messages are user-friendly
- [ ] All error scenarios are handled
- [ ] Loading indicators have timeouts
- [ ] Proper resource cleanup
- [ ] All null safety properly handled

### Security
- [ ] Firestore rules prevent unauthorized access
- [ ] User can only access their own data
- [ ] Volunteers can only manage their own requests
- [ ] No sensitive data in logs
- [ ] Location data handled securely
- [ ] Transactions prevent race conditions

### Performance
- [ ] Database queries are optimized
- [ ] No N+1 queries
- [ ] Images are cached/optimized
- [ ] Streams don't cause memory leaks
- [ ] Pagination for large lists
- [ ] Lazy loading implemented

### Documentation
- [ ] Code is well-commented
- [ ] Difficult logic has comments
- [ ] Public methods have doc comments
- [ ] README updated with new features
- [ ] Integration guide completed

### Monitoring
- [ ] Firebase Crashlytics configured
- [ ] Error logging in place
- [ ] Performance monitoring enabled
- [ ] Alerts set up for high error rates

---

## 📱 Deployment Steps

### Test Build

- [ ] Create test APK: `flutter build apk --release`
- [ ] Test on Android device
- [ ] Create test IPA: `flutter build ios --release`
- [ ] Test on iOS device
- [ ] Verify all features work

### Version Update

- [ ] Increment version in `pubspec.yaml`
- [ ] Update CHANGELOG with new features
- [ ] Commit changes to git

### Release to Store

- [ ] Upload to Google Play Store (Android)
- [ ] Upload to App Store (iOS)
- [ ] Set release notes
- [ ] Schedule release

### Post-Deployment

- [ ] Monitor Crashlytics for errors
- [ ] Check analytics
- [ ] Monitor Firestore read/write counts
- [ ] Be ready to rollback if issues

---

## 📞 Support

### If You Encounter Issues

1. Check [VOLUNTEER_MODE_QUICK_REFERENCE.md](VOLUNTEER_MODE_QUICK_REFERENCE.md) for code examples
2. Review [VOLUNTEER_MODE_INTEGRATION.md](VOLUNTEER_MODE_INTEGRATION.md) Troubleshooting section
3. Check Firestore security rules are deployed
4. Verify all indexes are in READY state
5. Check app logs for specific error messages
6. Verify location permission is granted
7. Test with Firestore Emulator locally

### Common Issues

**Issue: "No volunteers found"**
- [ ] Check users have role="volunteer"
- [ ] Check users have verificationStatus="verified"
- [ ] Check users have isAvailable=true
- [ ] Check currentLocation is set
- [ ] Check distance calculation is correct

**Issue: "Volunteer doesn't see requests"**
- [ ] Check request has correct volunteerId
- [ ] Check request status="pending"
- [ ] Check Firestore rules allow reading walkingRequests
- [ ] Check indexes are created
- [ ] Test with Firestore Emulator

**Issue: "Permission denied"**
- [ ] Sign out and sign in again
- [ ] Verify Firestore rules
- [ ] Check user UID is correct
- [ ] Clear app cache and reinstall

---

## ✅ Final Sign-Off

When you're ready for production:

- [ ] All checklist items above are complete
- [ ] Feature has been tested on real devices
- [ ] Code review completed
- [ ] All edge cases handled
- [ ] Documentation is complete
- [ ] Team is trained on new feature
- [ ] Monitoring is set up
- [ ] Rollback plan is ready

---

## 🎉 You're Done!

Congratulations! You have successfully implemented the Volunteer Mode feature for SAKHI.

Your implementation includes:
- ✅ Complete model definitions
- ✅ Production-ready services
- ✅ Beautiful UI screens
- ✅ Reusable widgets
- ✅ State management with Riverpod
- ✅ Comprehensive documentation
- ✅ Error handling
- ✅ Security best practices

The feature is ready for production deployment!
