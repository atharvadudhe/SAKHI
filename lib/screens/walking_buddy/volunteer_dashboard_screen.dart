import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

import '../../config/theme.dart';
import '../../models/walking_buddy_models.dart';
import '../../providers/walking_buddy_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/walking_buddy_widgets.dart';

/// Volunteer dashboard showing available walking buddy requests
class VolunteerDashboardWalkingBuddyScreen extends ConsumerStatefulWidget {
  const VolunteerDashboardWalkingBuddyScreen({super.key});

  @override
  ConsumerState<VolunteerDashboardWalkingBuddyScreen> createState() =>
      _VolunteerDashboardWalkingBuddyScreenState();
}

class _VolunteerDashboardWalkingBuddyScreenState extends ConsumerState<VolunteerDashboardWalkingBuddyScreen> {
  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(searchingWalkingSessionsProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    // Only show for volunteers
    if (currentUser?.role.name != 'volunteer') {
      return Scaffold(
        appBar: AppBar(title: const Text('Walking Buddy Requests')),
        body: const Center(
          child: Text('Only volunteers can view this'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Walking Buddy Requests'),
        centerTitle: true,
        elevation: 0,
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Active Requests',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No walking buddy requests nearby right now.\nCheck back soon!',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _WalkingBuddyRequestCard(
                session: session,
                onAccept: () => _acceptRequest(context, session),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _acceptRequest(
    BuildContext context,
    WalkingSessionModel session,
  ) async {
    final authState = ref.read(authStateProvider).value;
    final currentUser = ref.read(currentUserProvider).value;

    if (authState == null || currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Request?'),
        content: Text(
          'Accept walking buddy request to ${session.destinationName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final controller = ref.read(walkingBuddyControllerProvider.notifier);
      
      // Calculate distance from volunteer to user
      final distance = _calculateDistance(
        session.userLocation.latitude,
        session.userLocation.longitude,
        currentUser.currentLocation?.latitude ?? 0,
        currentUser.currentLocation?.longitude ?? 0,
      );

      final success = await controller.volunteerAcceptSession(
        sessionId: session.sessionId,
        volunteerId: authState.uid,
        volunteerName: currentUser.name,
        volunteerPhone: currentUser.phone,
        volunteerPhotoUrl: currentUser.photoUrl,
        distanceFromUser: distance,
      );

      if (success && mounted) {
        context.push(
          '/walking-buddy/volunteer-active',
          extra: session.sessionId,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) => degrees * 3.141592653589793 / 180;
}

/// Card for individual walking buddy request
class _WalkingBuddyRequestCard extends StatelessWidget {
  final WalkingSessionModel session;
  final VoidCallback onAccept;

  const _WalkingBuddyRequestCard({
    required this.session,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onAccept,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: session.userPhotoUrl != null
                        ? NetworkImage(session.userPhotoUrl!)
                        : null,
                    child: session.userPhotoUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.userName,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Looking for a buddy',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: SakhiTheme.searching.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'NEW',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: SakhiTheme.searching,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Destination
              Row(
                children: [
                  const Icon(Icons.location_on, color: SakhiTheme.danger, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'To',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Colors.grey),
                        ),
                        Text(
                          session.destinationName,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Duration
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.grey.shade600, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    '~${session.estimatedDuration.toStringAsFixed(0)} min journey',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAccept,
                  child: const Text('Accept Request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Active session screen for volunteers
class VolunteerActiveSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const VolunteerActiveSessionScreen({
    super.key,
    required this.sessionId,
  });

  @override
  ConsumerState<VolunteerActiveSessionScreen> createState() =>
      _VolunteerActiveSessionScreenState();
}

class _VolunteerActiveSessionScreenState
    extends ConsumerState<VolunteerActiveSessionScreen> {
  late GoogleMapController _mapController;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(walkingSessionProvider(widget.sessionId));

    return sessionAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Active Session')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $error')),
      ),
      data: (session) {
        if (session == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Session Not Found')),
            body: const Center(child: Text('Session not found')),
          );
        }

        return _buildVolunteerUI(context, session);
      },
    );
  }

  Widget _buildVolunteerUI(
    BuildContext context,
    WalkingSessionModel session,
  ) {
    final userLocation = LatLng(
      session.userLocation.latitude,
      session.userLocation.longitude,
    );

    final destLocation = LatLng(
      session.destinationLocation.latitude,
      session.destinationLocation.longitude,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heading to User'),
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: userLocation,
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: {
              Marker(
                markerId: const MarkerId('user'),
                position: userLocation,
                infoWindow: const InfoWindow(title: 'User Location'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                ),
              ),
              Marker(
                markerId: const MarkerId('destination'),
                position: destLocation,
                infoWindow: InfoWindow(title: session.destinationName),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
              ),
            },
          ),

          // Bottom action
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: session.userPhotoUrl != null
                              ? NetworkImage(session.userPhotoUrl!)
                              : null,
                          child: session.userPhotoUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.userName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Waiting for you',
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.call),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Calling user...'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SwipeActionButton(
                  label: 'I\'ve Arrived',
                  icon: Icons.location_on,
                  onSwipeComplete: () {
                    _confirmArrival(context, session);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmArrival(
    BuildContext context,
    WalkingSessionModel session,
  ) async {
    final controller = ref.read(walkingBuddyControllerProvider.notifier);
    final success =
        await controller.volunteerConfirmArrival(widget.sessionId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arrival confirmed! Waiting for user...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
