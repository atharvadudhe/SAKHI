import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/walking_buddy_models.dart';
import '../../providers/walking_buddy_providers.dart';

/// Simple screen shown to the user after a volunteer accepts the request.
class BuddyArrivingScreen extends ConsumerWidget {
  final String sessionId;
  final WalkingSessionModel session;

  const BuddyArrivingScreen({
    super.key,
    required this.sessionId,
    required this.session,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer Accepted'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SakhiTheme.primary.withValues(alpha: 0.08),
                ),
                child: session.volunteerPhotoUrl != null
                    ? ClipOval(
                        child: Image.network(session.volunteerPhotoUrl!, fit: BoxFit.cover),
                      )
                    : Icon(Icons.person, size: 56, color: SakhiTheme.primary),
              ),
              const SizedBox(height: 24),
              Text(
                'Your buddy is on the way',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                session.volunteerName ?? 'Volunteer',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Text(
                'They will reach your location shortly. You will be notified when they arrive.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () async {
                  final success = await ref
                      .read(walkingBuddyControllerProvider.notifier)
                      .userConfirmVolunteer(sessionId);

                  if (!context.mounted) return;
                  if (success) {
                    context.push('/walking-buddy/active-session', extra: sessionId);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not confirm volunteer. Please try again.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Accept Volunteer'),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  context.push('/walking-buddy/active-session', extra: sessionId);
                },
                icon: const Icon(Icons.map_rounded),
                label: const Text('View Live Tracking'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // Allow user to return home
                  context.go('/home');
                },
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
