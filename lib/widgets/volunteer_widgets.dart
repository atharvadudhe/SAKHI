import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../models/walking_request_model.dart';

/// Reusable widget to display a volunteer card
/// 
/// Shows volunteer info including:
/// - Profile picture
/// - Name
/// - Distance
/// - Verification status
/// - Action button (customizable via callback)
class VolunteerCard extends StatelessWidget {
  final UserModel volunteer;
  final double distanceKm;
  final VoidCallback? onTap;
  final String actionLabel;
  final Color? actionColor;

  const VolunteerCard({
    super.key,
    required this.volunteer,
    required this.distanceKm,
    this.onTap,
    this.actionLabel = 'View',
    this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Profile picture
            CircleAvatar(
              radius: 28,
              backgroundImage: volunteer.photoUrl != null
                  ? NetworkImage(volunteer.photoUrl!)
                  : null,
              child: volunteer.photoUrl == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            // Volunteer info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    volunteer.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${distanceKm.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Verified badge or action button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified,
                    size: 12,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Verified',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to display a walking request card for volunteers
class WalkingRequestCard extends StatelessWidget {
  final WalkingRequestModel request;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final bool isLoading;

  const WalkingRequestCard({
    super.key,
    required this.request,
    this.onAccept,
    this.onReject,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: request.requesterPhotoUrl != null
                      ? NetworkImage(request.requesterPhotoUrl!)
                      : null,
                  child: request.requesterPhotoUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.requesterName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        request.requesterPhone,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Distance info
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  '${request.distanceToRequester.toStringAsFixed(2)} km away',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading ? null : onReject,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: isLoading ? null : onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Accept'),
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

/// Empty state widget
class VolunteerEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onRetry;

  const VolunteerEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Distance badge widget
class DistanceBadge extends StatelessWidget {
  final double distanceKm;
  final double maxRadiusKm;

  const DistanceBadge({
    super.key,
    required this.distanceKm,
    required this.maxRadiusKm,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (distanceKm / maxRadiusKm) * 100;
    final color = _getColorByPercentage(percentage);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        '${distanceKm.toStringAsFixed(2)} km',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getColorByPercentage(double percentage) {
    if (percentage <= 33) {
      return Colors.green;
    } else if (percentage <= 66) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

/// Volunteer availability status widget
class VolunteerAvailabilityBadge extends StatelessWidget {
  final bool isAvailable;

  const VolunteerAvailabilityBadge({
    super.key,
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAvailable ? Icons.check_circle : Icons.cancel,
            size: 12,
            color: isAvailable ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            isAvailable ? 'Available' : 'Unavailable',
            style: TextStyle(
              color: isAvailable ? Colors.green : Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Request status badge
class RequestStatusBadge extends StatelessWidget {
  final String status;

  const RequestStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            _formatStatus(status),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData) _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return (Colors.orange, Icons.schedule);
      case 'accepted':
        return (Colors.green, Icons.check_circle);
      case 'rejected':
        return (Colors.red, Icons.cancel);
      case 'completed':
        return (Colors.blue, Icons.done_all);
      case 'expired':
        return (Colors.grey, Icons.schedule);
      case 'cancelled':
        return (Colors.grey, Icons.block);
      default:
        return (Colors.grey, Icons.help);
    }
  }

  String _formatStatus(String status) {
    return status[0].toUpperCase() + status.substring(1);
  }
}
