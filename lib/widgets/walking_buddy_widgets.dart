import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/walking_buddy_models.dart';

/// Card displaying a walking buddy session
class WalkingSessionCard extends StatelessWidget {
  final WalkingSessionModel session;
  final VoidCallback onTap;
  final bool isCompact;

  const WalkingSessionCard({
    super.key,
    required this.session,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(session.status);
    final statusLabel = _getStatusLabel(session.status);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status + Destination
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    session.destinationName,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Volunteer info if assigned
              if (session.volunteerId != null && !isCompact) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: session.volunteerPhotoUrl != null
                            ? NetworkImage(session.volunteerPhotoUrl!)
                            : null,
                        child: session.volunteerPhotoUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      // Name and distance
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.volunteerName ?? 'Volunteer',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (session.distanceFromUser != null)
                              Text(
                                '${session.distanceFromUser!.toStringAsFixed(1)} km away',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Footer: Time info
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
      ),
    );
  }

  Color _getStatusColor(WalkingSessionStatus status) {
    switch (status) {
      case WalkingSessionStatus.searching:
        return SakhiTheme.searching;
      case WalkingSessionStatus.volunteerAccepted:
      case WalkingSessionStatus.userConfirmed:
      case WalkingSessionStatus.volunteerReached:
        return SakhiTheme.connected;
      case WalkingSessionStatus.journeyStarted:
      case WalkingSessionStatus.destinationReached:
        return SakhiTheme.safe;
      case WalkingSessionStatus.completed:
        return SakhiTheme.safe;
      case WalkingSessionStatus.cancelled:
        return SakhiTheme.danger;
    }
  }

  String _getStatusLabel(WalkingSessionStatus status) {
    switch (status) {
      case WalkingSessionStatus.searching:
        return 'Finding Volunteer';
      case WalkingSessionStatus.volunteerAccepted:
        return 'Volunteer Found';
      case WalkingSessionStatus.userConfirmed:
        return 'On the Way';
      case WalkingSessionStatus.volunteerReached:
        return 'Arrived';
      case WalkingSessionStatus.journeyStarted:
        return 'Journey Started';
      case WalkingSessionStatus.destinationReached:
        return 'Destination Reached';
      case WalkingSessionStatus.completed:
        return 'Completed';
      case WalkingSessionStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Card displaying a nearby volunteer
class VolunteerCard extends StatelessWidget {
  final VolunteerAvailabilityModel volunteer;
  final VoidCallback onAccept;
  final VoidCallback? onCall;
  final bool isLoading;

  const VolunteerCard({
    super.key,
    required this.volunteer,
    required this.onAccept,
    this.onCall,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar + Name + Distance
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: volunteer.photoUrl != null
                      ? NetworkImage(volunteer.photoUrl!)
                      : null,
                  child: volunteer.photoUrl == null
                      ? const Icon(Icons.person, size: 30)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        volunteer.volunteerName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${volunteer.distanceFromUser.toStringAsFixed(1)} km away',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (volunteer.averageRating > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                volunteer.averageRating
                                    .toStringAsFixed(1),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${volunteer.sessionsCompleted} sessions',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Verification badge
            if (volunteer.verificationStatus == 'verified')
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: SakhiTheme.safe.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SakhiTheme.safe),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified,
                        size: 14, color: SakhiTheme.safe),
                    const SizedBox(width: 6),
                    Text(
                      'Verified Volunteer',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: SakhiTheme.safe,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                if (onCall != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : onCall,
                      icon: const Icon(Icons.phone),
                      label: const Text('Call'),
                    ),
                  ),
                if (onCall != null) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onAccept,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Accept'),
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

/// Custom swipe action button (for Reached, Confirm Location, etc.)
class SwipeActionButton extends StatefulWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onSwipeComplete;
  final IconData icon;

  const SwipeActionButton({
    super.key,
    required this.label,
    this.backgroundColor = SakhiTheme.primary,
    this.textColor = Colors.white,
    required this.onSwipeComplete,
    required this.icon,
  });

  @override
  State<SwipeActionButton> createState() => _SwipeActionButtonState();
}

class _SwipeActionButtonState extends State<SwipeActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  double _dragOffset = 0;
  final _minDragDistance = 100.0;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset =
          (_dragOffset + details.delta.dx).clamp(0, _minDragDistance);
    });

    if (_dragOffset >= _minDragDistance) {
      widget.onSwipeComplete();
      _resetSlider();
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragOffset < _minDragDistance) {
      _resetSlider();
    }
  }

  void _resetSlider() {
    _slideController.reverse();
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: widget.backgroundColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.backgroundColor, width: 2),
        ),
        child: Stack(
          children: [
            // Sliding background
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _dragOffset,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            // Content
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    color: _dragOffset > 20
                        ? widget.textColor
                        : widget.backgroundColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: _dragOffset > 20
                              ? widget.textColor
                              : widget.backgroundColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            // Drag indicator
            if (_dragOffset == 0)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Icon(
                    Icons.chevron_right,
                    color: widget.backgroundColor,
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Draggable SOS button overlay for maps
class DraggableSOSButton extends StatefulWidget {
  final VoidCallback onSOS;
  final bool isVisible;

  const DraggableSOSButton({
    super.key,
    required this.onSOS,
    this.isVisible = true,
  });

  @override
  State<DraggableSOSButton> createState() => _DraggableSOSButtonState();
}

class _DraggableSOSButtonState extends State<DraggableSOSButton> {
  late Offset _offset = Offset(
    MediaQuery.of(context).size.width - 80,
    MediaQuery.of(context).size.height - 200,
  );

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _offset = details.globalPosition;
          });
        },
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                onPressed: widget.onSOS,
                backgroundColor: SakhiTheme.danger,
                child: const Icon(Icons.warning),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Emergency SOS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Location pin widget for map adjustments
class LocationPinWidget extends StatelessWidget {
  final String label;
  final Color color;

  const LocationPinWidget({
    super.key,
    required this.label,
    this.color = SakhiTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 4),
        Icon(
          Icons.location_on,
          color: color,
          size: 32,
        ),
      ],
    );
  }
}

/// Empty state for no volunteers available
class NoVolunteersWidget extends StatelessWidget {
  final VoidCallback onRetry;

  const NoVolunteersWidget({
    super.key,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'No Volunteers Available',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'No verified volunteers are available in your area right now.\nPlease try again in a few moments.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Search Again'),
            ),
          ],
        ),
      ),
    );
  }
}
