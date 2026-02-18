import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/session_model.dart';
import '../../providers/providers.dart';

class VolunteerDashboardScreen extends ConsumerWidget {
  const VolunteerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(searchingSessionsProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Volunteer Dashboard'),
        actions: [
          // Availability toggle
          userAsync.when(
            data: (user) {
              final isAvailable = user?.isAvailable ?? false;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isAvailable ? 'Available' : 'Offline',
                      style: TextStyle(
                        fontSize: 13,
                        color: isAvailable
                            ? SakhiTheme.safe
                            : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Switch(
                      value: isAvailable,
                      activeColor: SakhiTheme.safe,
                      onChanged: (val) {
                        // TODO: Toggle availability via Firestore
                      },
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: sessionsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (sessions) {
            if (sessions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.volunteer_activism_rounded,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No active requests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back soon — someone may need your help.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _VolunteerStatsBar(
                        requestCount: sessions.length),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SessionRequestCard(
                    session: sessions[index - 1],
                    onAccept: () {
                      ref
                          .read(
                              sessionControllerProvider.notifier)
                          .acceptSession(
                              sessions[index - 1].sessionId);
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _VolunteerStatsBar extends StatelessWidget {
  final int requestCount;

  const _VolunteerStatsBar({required this.requestCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            SakhiTheme.safe.withValues(alpha: 0.1),
            SakhiTheme.safe.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
            color: SakhiTheme.safe.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.people_rounded,
              color: SakhiTheme.safe, size: 24),
          const SizedBox(width: 12),
          Text(
            '$requestCount nearby request${requestCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: SakhiTheme.safe,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRequestCard extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onAccept;

  const _SessionRequestCard({
    required this.session,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(session.startTime);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SakhiTheme.searching.withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: SakhiTheme.searching,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Safety buddy needed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${elapsed.inMinutes}m ago • ${session.timeLimit}min session',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SakhiTheme.searching.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: SakhiTheme.searching,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {}, // Decline
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SakhiTheme.safe,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
