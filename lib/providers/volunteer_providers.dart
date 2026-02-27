// ignore_for_file: undefined_method,undefined_function,unused_import,avoid_print
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/user_model.dart';
import '../models/walking_request_model.dart';
import '../services/firestore_service.dart';
import '../services/volunteer_service.dart';
import '../services/walking_request_service.dart';

// =====================================================================
// User Location Provider
// =====================================================================

/// Get current user's location
final userLocationProvider = FutureProvider<LatLng?>((ref) async {
  try {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LatLng(position.latitude, position.longitude);
  } catch (e) {
    throw Exception('Failed to get location: $e');
  }
});

// =====================================================================
// Nearby Volunteers Providers
// =====================================================================

/// Find nearby verified volunteers for current user
final nearbyVolunteersProvider =
    FutureProvider.family<List<UserModel>, LatLng>((ref, userLocation) async {
  final firestoreService = FirestoreService.instance;
  return firestoreService.fetchNearbyVerifiedVolunteers(userLocation);
});

/// Stream nearby volunteers in real-time
final nearbyVolunteersStreamProvider =
    StreamProvider.family<List<UserModel>, LatLng>((ref, userLocation) {
  final firestoreService = FirestoreService.instance;
  return firestoreService.streamNearbyVerifiedVolunteers(userLocation);
});

/// Count of nearby volunteers
final nearbyVolunteerCountProvider =
    FutureProvider.family<int, LatLng>((ref, userLocation) async {
  final firestoreService = FirestoreService.instance;
  return firestoreService.countNearbyVerifiedVolunteers(userLocation);
});

// =====================================================================
// Walking Request Providers
// =====================================================================

/// Stream incoming requests for a volunteer
final incomingRequestsProvider =
    StreamProvider.family<List<WalkingRequestModel>, String>((ref, volunteerId) {
  final firestoreService = FirestoreService.instance;
  return firestoreService.streamIncomingRequests(volunteerId);
});

/// Stream outgoing requests for a user
final userOutgoingRequestsProvider =
    StreamProvider.family<List<WalkingRequestModel>, String>((ref, userId) {
  final firestoreService = FirestoreService.instance;
  return firestoreService.streamUserOutgoingRequests(userId);
});

/// Get a specific walking request
final walkingRequestProvider =
    FutureProvider.family<WalkingRequestModel?, String>((ref, requestId) async {
  final firestoreService = FirestoreService.instance;
  return firestoreService.getWalkingRequest(requestId);
});

/// Check for duplicate requests
final hasActiveRequestProvider = FutureProvider.family<bool, (String, String)>(
  (ref, params) async {
    final (userId, volunteerId) = params;
    final firestoreService = FirestoreService.instance;
    return firestoreService.hasActiveRequestToVolunteer(userId, volunteerId);
  },
);

// =====================================================================
// User Profile Providers
// =====================================================================

/// Get current user's profile
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  // In production, get the actual current user ID from auth
  final firestoreService = FirestoreService.instance;
  // Replace 'current_user_id' with actual user from FirebaseAuth
  return firestoreService.getUser('current_user_id');
});

/// Watch current user's profile in real-time
final currentUserStreamProvider = StreamProvider<UserModel?>((ref) {
  // In production, get the actual current user ID from auth
  final firestoreService = FirestoreService.instance;
  // Replace 'current_user_id' with actual user from FirebaseAuth
  return firestoreService.userStream('current_user_id');
});

// =====================================================================
// Volunteer Statistics Providers
// =====================================================================

/// Get volunteer request statistics
final volunteerStatsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, volunteerId) async {
  final firestoreService = FirestoreService.instance;
  return firestoreService.getVolunteerRequestStats(volunteerId);
});

// =====================================================================
// State Management Providers
// =====================================================================

/// Track loading state for accepting requests
final acceptingRequestProvider = StateProvider<Set<String>>((ref) {
  return {};
});

/// Track loading state for rejecting requests
final rejectingRequestProvider = StateProvider<Set<String>>((ref) {
  return {};
});

/// Currently selected volunteer
final selectedVolunteerProvider = StateProvider<UserModel?>((ref) {
  return null;
});

// =====================================================================
// Helper Methods
// =====================================================================

/// Send a walking request (non-provider utility)
Future<String> sendWalkingRequest(
  WidgetRef ref, {
  required String requesterId,
  required UserModel requester,
  required UserModel volunteer,
  required LatLng userLocation,
}) async {
  final firestoreService = FirestoreService.instance;
  
  // Calculate distance
  final distance = await firestoreService.getDistanceToVolunteer(
    userLocation,
    volunteer.currentLocation!,
  );

  // Send request
  return firestoreService.sendWalkingRequest(
    requesterId: requesterId,
    requesterName: requester.name,
    requesterPhone: requester.phone,
    requesterPhotoUrl: requester.photoUrl,
    requesterLocation: GeoPoint(
      userLocation.latitude,
      userLocation.longitude,
    ),
    volunteerId: volunteer.uid,
    volunteerName: volunteer.name,
    volunteerPhone: volunteer.phone,
    volunteerPhotoUrl: volunteer.photoUrl,
    volunteerLocation: volunteer.currentLocation!,
    distanceToRequester: distance,
  );
}

/// Accept a walking request
Future<void> acceptWalkingRequest(
  WidgetRef ref,
  String requestId,
  String volunteerId,
) async {
  final firestoreService = FirestoreService.instance;
  
  // Add to loading set
  ref.read(acceptingRequestProvider.notifier).update(
    (state) => {...state, requestId},
  );

  try {
    await firestoreService.acceptRequest(requestId, volunteerId);
  } finally {
    // Remove from loading set
    ref.read(acceptingRequestProvider.notifier).update(
      (state) => state..remove(requestId),
    );
  }
}

/// Reject a walking request
Future<void> rejectWalkingRequest(
  WidgetRef ref,
  String requestId,
  String volunteerId, {
  String? reason,
}) async {
  final firestoreService = FirestoreService.instance;
  
  // Add to loading set
  ref.read(rejectingRequestProvider.notifier).update(
    (state) => {...state, requestId},
  );

  try {
    await firestoreService.rejectRequest(
      requestId,
      volunteerId,
      rejectionReason: reason,
    );
  } finally {
    // Remove from loading set
    ref.read(rejectingRequestProvider.notifier).update(
      (state) => state..remove(requestId),
    );
  }
}

/// Cancel a walking request
Future<void> cancelWalkingRequest(
  WidgetRef ref,
  String requestId,
  String userId,
) async {
  final firestoreService = FirestoreService.instance;
  await firestoreService.cancelRequest(requestId, userId);
}

/// Complete a walking request
Future<void> completeWalkingRequest(
  WidgetRef ref,
  String requestId,
  String volunteerId,
) async {
  final firestoreService = FirestoreService.instance;
  await firestoreService.completeRequest(requestId, volunteerId);
}

// =====================================================================
// Example Usage in Widgets
// =====================================================================

/*
// Example 1: Use in ConsumerWidget to find nearby volunteers
class FindVolunteerWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(userLocationProvider);
    
    return locationAsync.when(
      data: (location) {
        if (location == null) {
          return const Center(child: Text('Location not available'));
        }
        
        final volunteersAsync = ref.watch(nearbyVolunteersProvider(location));
        
        return volunteersAsync.when(
          data: (volunteers) {
            if (volunteers.isEmpty) {
              return const Center(child: Text('No volunteers nearby'));
            }
            
            return ListView.builder(
              itemCount: volunteers.length,
              itemBuilder: (context, index) {
                final volunteer = volunteers[index];
                return ListTile(
                  title: Text(volunteer.name),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      await sendWalkingRequest(
                        ref,
                        requesterId: 'current_user_id',
                        requester: UserModel(...), // Current user
                        volunteer: volunteer,
                        userLocation: location,
                      );
                    },
                    child: const Text('Request'),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text('Error: $error'),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Error: $error'),
      ),
    );
  }
}

// Example 2: Use in ConsumerWidget for volunteer mode
class VolunteerModeWidget extends ConsumerWidget {
  final String volunteerId;

  const VolunteerModeWidget({required this.volunteerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(incomingRequestsProvider(volunteerId));
    final accepting = ref.watch(acceptingRequestProvider);
    
    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(child: Text('No pending requests'));
        }
        
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final isLoading = accepting.contains(request.requestId);
            
            return ListTile(
              title: Text(request.requesterName),
              subtitle: Text('${request.distanceToRequester.toStringAsFixed(2)} km away'),
              trailing: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ElevatedButton(
                      onPressed: () => acceptWalkingRequest(
                        ref,
                        request.requestId,
                        volunteerId,
                      ),
                      child: const Text('Accept'),
                    ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Error: $error'),
      ),
    );
  }
}
*/
