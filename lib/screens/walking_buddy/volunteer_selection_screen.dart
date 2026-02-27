import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/walking_buddy_models.dart';
import '../../providers/walking_buddy_providers.dart';

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

  Future<void> _cancelSession(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel request?'),
        content: const Text(
            'Are you sure you want to cancel the walking buddy request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final controller = ref.read(walkingBuddyControllerProvider.notifier);
      await controller.cancelWalkingSession(widget.sessionId, 'User cancelled');
      if (mounted) context.go('/home');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    print('🔥 ACTIVE SCREEN: VolunteerSelectionScreen');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request in Progress'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _cancelSession(context),
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final sessionAsync = ref.watch(
            walkingSessionStreamProvider(widget.sessionId),
          );
          return sessionAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(child: Text('Error: $err')),
            data: (session) {
              if (session == null) {
                return const Center(child: Text('Session not found'));
              }
              if (session.status == WalkingSessionStatus.searching) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Searching for a volunteer to accept your request...',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                );
              }
              if (session.status == WalkingSessionStatus.volunteerAccepted) {
                Future.microtask(() {
                  context.pushReplacement(
                    '/walking-buddy/waiting-for-user-confirm',
                    extra: widget.sessionId,
                  );
                });
              }
              return const SizedBox.shrink();
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

  Future<void> _cancelSession(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel request?'),
        content: const Text(
            'Are you sure you want to cancel the walking buddy request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final controller = ref.read(walkingBuddyControllerProvider.notifier);
      await controller.cancelWalkingSession(widget.sessionId, 'User cancelled');
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(
      walkingSessionStreamProvider(widget.sessionId),
    );

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
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _cancelSession(context),
            ),
          ],
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


            // If volunteer has been accepted, navigate to buddy arriving screen
            if (session.status == WalkingSessionStatus.volunteerAccepted) {
              Future.microtask(() {
                context.pushReplacement(
                  '/walking-buddy/buddy-arriving',
                  extra: {
                    'sessionId': widget.sessionId,
                    'session': session,
                  },
                );
              });
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
                              'Volunteer accepted. Please confirm to continue...',
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
