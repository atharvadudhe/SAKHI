import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/walking_buddy_models.dart';
import '../../providers/walking_buddy_providers.dart';
import '../../providers/providers.dart';
import '../../services/firestore_service.dart';
import '../../services/walking_buddy_service.dart';
import '../../widgets/walking_buddy_widgets.dart';

/// Screen for selecting a volunteer from nearby available volunteers
class VolunteerSelectionScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const VolunteerSelectionScreen({
    super.key,
    required this.sessionId,
  });

  @override
  ConsumerState<VolunteerSelectionScreen> createState() =>
      _VolunteerSelectionScreenState();
}

class _VolunteerSelectionScreenState
    extends ConsumerState<VolunteerSelectionScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _selectVolunteer(VolunteerAvailabilityModel volunteer) async {
    // TODO: Implement volunteer call functionality
    // For now, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${volunteer.volunteerName}...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _acceptVolunteer(VolunteerAvailabilityModel volunteer) async {
    try {
      final controller = ref.read(walkingBuddyControllerProvider.notifier);
      final success = await controller.volunteerAcceptSession(
        sessionId: widget.sessionId,
        volunteerId: volunteer.volunteerId,
        volunteerName: volunteer.volunteerName,
        volunteerPhone: volunteer.phone,
        volunteerPhotoUrl: volunteer.photoUrl,
        distanceFromUser: volunteer.distanceFromUser,
      );

      if (success && mounted) {
        // Navigate to waiting screen
        context.pushReplacement(
          '/walking-buddy/waiting-for-user-confirm',
          extra: widget.sessionId,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Volunteer'),
        centerTitle: true,
      ),
      body: FutureBuilder<WalkingSessionModel?>(
        future: FirestoreService.instance.getWalkingSession(widget.sessionId),
        builder: (context, sessionSnapshot) {
          if (!sessionSnapshot.hasData || sessionSnapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final session = sessionSnapshot.data!;
          final userLocation = session.userLocation;

          return FutureBuilder<List<VolunteerAvailabilityModel>>(
            future: FirestoreService.instance.getNearbyVolunteers(
              userLocation: userLocation,
              radiusKm: 10,
            ),
            builder: (context, volunteersSnapshot) {
              if (volunteersSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final volunteers = volunteersSnapshot.data ?? [];

              if (volunteers.isEmpty) {
                return NoVolunteersWidget(
                  onRetry: () {
                    setState(() {});
                  },
                );
              }

              return Column(
                children: [
                  // Header with session info
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: SakhiTheme.primary.withOpacity(0.05),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Going to',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session.destinationName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${session.estimatedDuration.toStringAsFixed(0)} min estimated',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Volunteers list
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: volunteers.length,
                      itemBuilder: (context, index) {
                        final volunteer = volunteers[index];
                        return VolunteerCard(
                          volunteer: volunteer,
                          onAccept: () => _acceptVolunteer(volunteer),
                          onCall: () => _selectVolunteer(volunteer),
                        );
                      },
                    ),
                  ),

                  // Bottom action
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Showing ${volunteers.length} volunteers within 10 km',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {});
                          },
                          child: const Text('Refresh List'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Waiting screen while user confirms the volunteer
class WaitingForUserConfirmScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const WaitingForUserConfirmScreen({
    super.key,
    required this.sessionId,
  });

  @override
  ConsumerState<WaitingForUserConfirmScreen> createState() =>
      _WaitingForUserConfirmScreenState();
}

class _WaitingForUserConfirmScreenState
    extends ConsumerState<WaitingForUserConfirmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(walkingSessionProvider(widget.sessionId));

    return WillPopScope(
      onWillPop: () async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait for user to confirm'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Waiting for Confirmation'),
          automaticallyImplyLeading: false,
        ),
        body: sessionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Error: $error'),
          ),
          data: (session) {
            if (session == null) {
              return const Center(child: Text('Session not found'));
            }

            // If user already confirmed, navigate to active session
            if (session.status == WalkingSessionStatus.userConfirmed) {
              Future.microtask(() {
                context.pushReplacement(
                  '/walking-buddy/active-session',
                  extra: widget.sessionId,
                );
              });
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated volunteer avatar
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1.1)
                          .animate(_animationController),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: session.volunteerPhotoUrl != null
                            ? NetworkImage(session.volunteerPhotoUrl!)
                            : null,
                        child: session.volunteerPhotoUrl == null
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Volunteer name
                    Text(
                      session.volunteerName ?? 'Volunteer',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Distance
                    if (session.distanceFromUser != null)
                      Text(
                        '${session.distanceFromUser!.toStringAsFixed(1)} km away',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    const SizedBox(height: 48),

                    // Status message
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: SakhiTheme.searching.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: SakhiTheme.searching, width: 2),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Waiting for volunteer to be accepted...',
                              style:
                                  Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
