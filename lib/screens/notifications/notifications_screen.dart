import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/broadcast_model.dart';
import '../../providers/providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final broadcastsAsync = ref.watch(broadcastsFeedProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
      ),
      body: broadcastsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (broadcasts) {
          if (broadcasts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_off_rounded,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Community alerts will appear here.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: broadcasts.length,
            itemBuilder: (context, index) {
              return _BroadcastNotificationCard(broadcast: broadcasts[index]);
            },
          );
        },
      ),
    );
  }
}

class _BroadcastNotificationCard extends StatelessWidget {
  final BroadcastModel broadcast;

  const _BroadcastNotificationCard({required this.broadcast});

  @override
  Widget build(BuildContext context) {
    final alertColor = _colorForType(broadcast.alertType);
    final alertIcon = _iconForType(broadcast.alertType);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: alertColor.withValues(alpha: 0.1),
              ),
              child: Icon(alertIcon, color: alertColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          broadcast.alertLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: alertColor,
                          ),
                        ),
                      ),
                      Text(
                        broadcast.timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    broadcast.message,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (broadcast.userName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'by ${broadcast.userName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'unsafe_area':
        return SakhiTheme.searching;
      case 'suspicious_activity':
        return SakhiTheme.danger;
      case 'need_help':
        return SakhiTheme.primaryDark;
      case 'road_issue':
        return SakhiTheme.connected;
      default:
        return Colors.grey;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'unsafe_area':
        return Icons.warning_amber_rounded;
      case 'suspicious_activity':
        return Icons.visibility_rounded;
      case 'need_help':
        return Icons.sos_rounded;
      case 'road_issue':
        return Icons.report_problem_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}
