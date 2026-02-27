/**
 * SAKHI - Volunteer Mode Documentation
 * 
 * This document contains:
 * 1. Firestore Security Rules
 * 2. Required Firestore Indexes
 * 3. Collection Structure
 * 4. Integration Guide
 * 5. Usage Examples
 */

// =====================================================================
// 1. FIRESTORE SECURITY RULES
// =====================================================================
// 
// Add these rules to your Firestore Security Rules console:
// https://console.firebase.google.com/project/{PROJECT_ID}/firestore/rules
//
// Replace the existing rules with the following:

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ────── Users Collection ──────
    match /users/{userId} {
      // Allow users to read their own profile
      allow read: if request.auth.uid == userId;
      
      // Allow users to update their own profile
      allow update: if request.auth.uid == userId
        && request.resource.data.uid == resource.data.uid; // Prevent UID change
      
      // Allow authenticated users to list users for volunteer search
      allow list: if request.auth != null;
    }
    
    // ────── Walking Requests Collection ──────
    match /walkingRequests/{requestId} {
      // Allow requesters to read their own requests
      allow read: if request.auth.uid == resource.data.requesterId;
      
      // Allow volunteers to read requests sent to them
      allow read: if request.auth.uid == resource.data.volunteerId;
      
      // Allow requesters to create requests
      allow create: if request.auth.uid == request.resource.data.requesterId
        && request.auth != null
        && request.resource.data.status == 'pending';
      
      // Allow users to update their own requests (cancel)
      allow update: if request.auth.uid == resource.data.requesterId
        && request.resource.data.status == 'cancelled';
      
      // Allow volunteers to update status (accept/reject)
      allow update: if request.auth.uid == resource.data.volunteerId
        && (request.resource.data.status == 'accepted' 
            || request.resource.data.status == 'rejected'
            || request.resource.data.status == 'completed');
      
      // Deny deletes
      allow delete: if false;
    }
    
    // ────── Location Updates Subcollection ──────
    match /users/{userId}/locationUpdates/{locationId} {
      allow read: if request.auth.uid == userId;
      allow create: if request.auth.uid == userId;
    }
    
    // ────── Default: Deny All ──────
    match /{document=**} {
      allow read, write: if request.auth != null && false;
    }
  }
}

// =====================================================================
// 2. REQUIRED FIRESTORE INDEXES
// =====================================================================
//
// Add these composite indexes to your Firestore:
// https://console.firebase.google.com/project/{PROJECT_ID}/firestore/indexes
//
// You can add them manually or they will be auto-created when queries
// are first executed from the app.

// Index 1: Find available verified volunteers
Collection: users
Fields: role (Ascending), verificationStatus (Ascending), isAvailable (Ascending)
Query Scope: Collection

// Index 2: Get pending requests for volunteer
Collection: walkingRequests
Fields: volunteerId (Ascending), status (Ascending), createdAt (Descending)
Query Scope: Collection

// Index 3: Get user's outgoing requests
Collection: walkingRequests
Fields: requesterId (Ascending), createdAt (Descending)
Query Scope: Collection

// Index 4: Find requests sent to specific volunteer
Collection: walkingRequests
Fields: volunteerId (Ascending), createdAt (Descending)
Query Scope: Collection

// =====================================================================
// 3. COLLECTION STRUCTURE
// =====================================================================

// users (existing collection, enhanced for volunteer mode)
{
  uid: string (document ID)
  name: string
  phone: string
  role: string // "user" | "volunteer"
  isAvailable: boolean
  currentLocation: GeoPoint { latitude, longitude }
  lastHeartbeat: timestamp
  photoUrl: string (optional)
  verificationStatus: string // "verified" | "pending" | "rejected" | "unverified"
  verifiedStatus: boolean (deprecated, use verificationStatus)
  
  // KYC fields
  idFrontUrl: string (optional)
  idBackUrl: string (optional)
  verificationSubmittedAt: timestamp (optional)
  
  // PINs
  safePin: string (optional)
  duressPin: string (optional)
}

// walkingRequests (new collection)
{
  requestId: string (document ID, UUID)
  
  // Requester info
  requesterId: string (user UID)
  requesterName: string
  requesterPhone: string
  requesterPhotoUrl: string (optional)
  requesterLocation: GeoPoint
  
  // Volunteer info
  volunteerId: string (user UID)
  volunteerName: string
  volunteerPhone: string
  volunteerPhotoUrl: string (optional)
  volunteerLocation: GeoPoint
  
  // Distance
  distanceToRequester: double (kilometers)
  
  // Status
  status: string // "pending" | "accepted" | "rejected" | "completed" | "expired" | "cancelled"
  
  // Timestamps
  createdAt: timestamp
  respondedAt: timestamp (optional)
  completedAt: timestamp (optional)
  
  // Rejection
  rejectionReason: string (optional)
}

// =====================================================================
// 4. INTEGRATION GUIDE
// =====================================================================

// STEP 1: Import the services in your widget
import '../services/firestore_service.dart';
import '../services/volunteer_service.dart';
import '../services/walking_request_service.dart';
import '../screens/find_volunteer_screen.dart';
import '../screens/volunteer_mode_screen.dart';

// STEP 2: Use FindVolunteerScreen for regular users
// When user clicks "Find Walking Buddy":
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const FindVolunteerScreen()),
);

// STEP 3: Use VolunteerModeScreen for volunteers
// Show this only if user.role == "volunteer" && user.verificationStatus == "verified"
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => VolunteerModeScreen(volunteerId: currentUserId),
  ),
);

// =====================================================================
// 5. USAGE EXAMPLES
// =====================================================================

// Example 1: Find nearby volunteers
Future<void> findNearbyVolunteers() async {
  final firestoreService = FirestoreService.instance;
  final userLocation = LatLng(37.7749, -122.4194); // San Francisco
  
  try {
    final volunteers = await firestoreService.fetchNearbyVerifiedVolunteers(
      userLocation,
    );
    
    print('Found ${volunteers.length} nearby volunteers');
    for (final volunteer in volunteers) {
      final distance = await firestoreService.getDistanceToVolunteer(
        userLocation,
        volunteer.currentLocation!,
      );
      print('${volunteer.name} - ${distance.toStringAsFixed(2)} km away');
    }
  } catch (e) {
    print('Error: $e');
  }
}

// Example 2: Stream real-time volunteer updates
streamVolunteerUpdates() {
  final firestoreService = FirestoreService.instance;
  final userLocation = LatLng(37.7749, -122.4194);
  
  firestoreService
      .streamNearbyVerifiedVolunteers(userLocation)
      .listen((volunteers) {
    print('Volunteers near you: ${volunteers.length}');
  });
}

// Example 3: Send a walking request
Future<void> sendWalkingRequest(
  String requesterId,
  UserModel requester,
  UserModel volunteer,
  LatLng userLocation,
) async {
  final firestoreService = FirestoreService.instance;
  
  try {
    const distance = 2.5; // kilometers
    
    final requestId = await firestoreService.sendWalkingRequest(
      requesterId: requesterId,
      requesterName: requester.name,
      requesterPhone: requester.phone,
      requesterPhotoUrl: requester.photoUrl,
      requesterLocation: GeoPoint(userLocation.latitude, userLocation.longitude),
      volunteerId: volunteer.uid,
      volunteerName: volunteer.name,
      volunteerPhone: volunteer.phone,
      volunteerPhotoUrl: volunteer.photoUrl,
      volunteerLocation: volunteer.currentLocation!,
      distanceToRequester: distance,
    );
    
    print('Request sent: $requestId');
  } catch (e) {
    print('Error sending request: $e');
  }
}

// Example 4: Stream incoming requests for volunteer
streamIncomingRequests(String volunteerId) {
  final firestoreService = FirestoreService.instance;
  
  firestoreService
      .streamIncomingRequests(volunteerId)
      .listen((requests) {
    print('Pending requests: ${requests.length}');
  });
}

// Example 5: Accept a walking request
Future<void> acceptRequest(String requestId, String volunteerId) async {
  final firestoreService = FirestoreService.instance;
  
  try {
    await firestoreService.acceptRequest(requestId, volunteerId);
    print('Request accepted!');
  } catch (e) {
    print('Error accepting request: $e');
  }
}

// Example 6: Reject a walking request
Future<void> rejectRequest(String requestId, String volunteerId) async {
  final firestoreService = FirestoreService.instance;
  
  try {
    await firestoreService.rejectRequest(
      requestId,
      volunteerId,
      rejectionReason: 'Too far away',
    );
    print('Request rejected!');
  } catch (e) {
    print('Error rejecting request: $e');
  }
}

// =====================================================================
// 6. TESTING CHECKLIST
// =====================================================================

/*
□ User can find nearby verified volunteers
□ Volunteers within search radius are displayed
□ Volunteers are sorted by distance (nearest first)
□ Volunteer has isAvailable == true
□ Volunteer has verificationStatus == "verified"
□ User can send a request to a volunteer
□ Volunteer receives request in real-time
□ Volunteer can accept the request
□ On accept: request status → "accepted"
□ On accept: volunteer.isAvailable → false
□ Volunteer can reject the request
□ On reject: request status → "rejected"
□ Request auto-expires after 5 minutes
□ Duplicate requests are prevented
□ Only verified volunteers see incoming requests
□ Only available volunteers appear in search
□ Location permission works on both Android and iOS
□ Haversine distance calculation is accurate
□ Firestore transactions prevent race conditions
□ Error handling shows user-friendly messages
□ Null safety is maintained throughout
*/

// =====================================================================
// 7. FIRESTORE INDEXES IMPORT FORMAT
// =====================================================================

/*
If you're managing indexes via firestore.indexes.json, add:

{
  "indexes": [
    {
      "collectionGroup": "users",
      "queryScope": "Collection",
      "fields": [
        {
          "fieldPath": "role",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "verificationStatus",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "isAvailable",
          "order": "ASCENDING"
        }
      ]
    },
    {
      "collectionGroup": "walkingRequests",
      "queryScope": "Collection",
      "fields": [
        {
          "fieldPath": "volunteerId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "status",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "walkingRequests",
      "queryScope": "Collection",
      "fields": [
        {
          "fieldPath": "requesterId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    }
  ],
  "fieldOverrides": []
}
*/
