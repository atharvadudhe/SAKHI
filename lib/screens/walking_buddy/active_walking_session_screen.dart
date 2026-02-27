import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/theme.dart';
import '../../models/walking_buddy_models.dart';
import '../../providers/walking_buddy_providers.dart';
import '../../providers/providers.dart';
import '../../services/location_service.dart';
import '../../widgets/walking_buddy_widgets.dart';
import 'dart:async';

/// Active walking buddy session screen
class ActiveWalkingSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const ActiveWalkingSessionScreen({
    super.key,
    required this.sessionId,
  });

  @override
  ConsumerState<ActiveWalkingSessionScreen> createState() =>
      _ActiveWalkingSessionScreenState();
}

class _ActiveWalkingSessionScreenState
    extends ConsumerState<ActiveWalkingSessionScreen> {
  late GoogleMapController _mapController;
  late StreamSubscription<Position> _locationSubscription;
  late Timer _locationUploadTimer;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  void _startLocationTracking() {
    // Listen to location updates from Geolocator
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    ).listen((Position position) {
      _uploadLocation(position);
    });

    // Also upload location periodically every 10 seconds
    _locationUploadTimer =
        Timer.periodic(const Duration(seconds: 10), (_) async {
      final position = await LocationService.instance.getPosition();
      if (position.isSuccess && position.position != null) {
        _uploadLocation(position.position!);
      }
    });
  }

  Future<void> _uploadLocation(Position position) async {
    final authState = ref.read(authStateProvider);
    if (authState.value != null) {
      await ref.read(walkingBuddyControllerProvider.notifier).recordLocation(
            widget.sessionId,
            authState.value!.uid,
            position,
          );
    }
  }

  @override
  void dispose() {
    _locationSubscription.cancel();
    _locationUploadTimer.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🔥 ACTIVE SCREEN: ActiveWalkingSessionScreen');
    final sessionAsync = ref.watch(
      walkingSessionStreamProvider(widget.sessionId),
    );

    return sessionAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Walking Buddy')),
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
            body: const Center(
              child: Text('Walking session not found'),
            ),
          );
        }

        return _buildSessionUI(context, session);
      },
    );
  }

  Widget _buildSessionUI(BuildContext context, WalkingSessionModel session) {
    final userLocation = LatLng(
      session.userLocation.latitude,
      session.userLocation.longitude,
    );

    final destLocation = LatLng(
      session.destinationLocation.latitude,
      session.destinationLocation.longitude,
    );

    final volunteerLocation = session.volunteerReachedAt != null
        ? userLocation // Volunteer has reached user
        : LatLng(20.5937, 78.9629); // Mock location

    return Scaffold(
      appBar: AppBar(
        title: const Text('Walking Buddy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showSessionMenu(context, session),
          ),
        ],
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
                infoWindow: const InfoWindow(title: 'Your Location'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                ),
              ),
              Marker(
                markerId: const MarkerId('volunteer'),
                position: volunteerLocation,
                infoWindow: InfoWindow(title: session.volunteerName ?? 'Volunteer'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
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

          // DraggableSOSButton
          if (session.status == WalkingSessionStatus.journeyStarted)
            DraggableSOSButton(
              onSOS: () => _triggerSOS(context, session),
              isVisible: true,
            ),

          // Bottom sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildSessionBottomSheet(context, session),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionBottomSheet(
    BuildContext context,
    WalkingSessionModel session,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status indicator
            _buildStatusIndicator(context, session),
            const SizedBox(height: 16),

            // Volunteer info
            if (session.volunteerName != null)
              _buildVolunteerInfo(context, session),
            const SizedBox(height: 16),

            // Action buttons based on status
            ..._buildActionButtons(context, session),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(
    BuildContext context,
    WalkingSessionModel session,
  ) {
    final statusText = _getStatusText(session.status);
    final statusColor = _getStatusColor(session.status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolunteerInfo(
    BuildContext context,
    WalkingSessionModel session,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: session.volunteerPhotoUrl != null
                  ? NetworkImage(session.volunteerPhotoUrl!)
                  : null,
              child: session.volunteerPhotoUrl == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
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
                  if (session.volunteerPhone != null)
                    Text(
                      session.volunteerPhone!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: () => _callVolunteer(context, session),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(
    BuildContext context,
    WalkingSessionModel session,
  ) {
    List<Widget> buttons = [];

    switch (session.status) {
      case WalkingSessionStatus.volunteerAccepted:
        buttons.addAll([
          ElevatedButton(
            onPressed: () => _confirmVolunteer(context, session),
            child: const Text('Accept Volunteer'),
          ),
        ]);
        break;

      case WalkingSessionStatus.userConfirmed:
        buttons.addAll([
          Text(
            'Volunteer is on the way...',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ]);
        break;

      case WalkingSessionStatus.volunteerReached:
        buttons.addAll([
          SwipeActionButton(
            label: 'Volunteer Reached',
            icon: Icons.check_circle,
            onSwipeComplete: () => _startJourney(context, session),
          ),
        ]);
        break;

      case WalkingSessionStatus.journeyStarted:
        buttons.addAll([
          SwipeActionButton(
            label: 'Reached Destination',
            icon: Icons.location_on,
            backgroundColor: SakhiTheme.safe,
            onSwipeComplete: () =>
                _confirmDestinationReached(context, session),
          ),
        ]);
        break;

      case WalkingSessionStatus.destinationReached:
        buttons.addAll([
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SakhiTheme.safe.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: SakhiTheme.safe),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Destination Reached',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Waiting for volunteer confirmation...',
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
        ]);
        break;

      default:
        break;
    }

    buttons.add(const SizedBox(height: 12));
    buttons.add(
      OutlinedButton(
        onPressed: () => _cancelSession(context, session),
        child: const Text('Cancel Session'),
      ),
    );

    return buttons;
  }

  Future<void> _confirmVolunteer(
    BuildContext context,
    WalkingSessionModel session,
  ) async {
    final controller = ref.read(walkingBuddyControllerProvider.notifier);
    final success = await controller.userConfirmVolunteer(widget.sessionId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Volunteer confirmed! Journey is starting...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _startJourney(
    BuildContext context,
    WalkingSessionModel session,
  ) async {
    final controller = ref.read(walkingBuddyControllerProvider.notifier);
    final success = await controller.startJourney(widget.sessionId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journey started!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDestinationReached(
    BuildContext context,
    WalkingSessionModel session,
  ) async {
    final controller = ref.read(walkingBuddyControllerProvider.notifier);
    final success =
        await controller.userConfirmDestinationReached(widget.sessionId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Great! You have reached your destination safely.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cancelSession(
    BuildContext context,
    WalkingSessionModel session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Session?'),
        content: const Text(
          'Are you sure you want to cancel this walking buddy session?',
        ),
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

      if (mounted) {
        context.go('/home');
      }
    }
  }

  void _triggerSOS(BuildContext context, WalkingSessionModel session) {
    // TODO: Implement SOS functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS Alert sent to emergency contacts!'),
        backgroundColor: SakhiTheme.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _callVolunteer(BuildContext context, WalkingSessionModel session) {
    // TODO: Implement call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${session.volunteerName}...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSessionMenu(BuildContext context, WalkingSessionModel session) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Location'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement share functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Session Details'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show session details
              },
            ),
            if (session.status !=
                WalkingSessionStatus.completed) ListTile(
              leading: const Icon(Icons.close, color: SakhiTheme.danger),
              title: const Text('Cancel Session',
                  style: TextStyle(color: SakhiTheme.danger)),
              onTap: () {
                Navigator.pop(context);
                _cancelSession(context, session);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(WalkingSessionStatus status) {
    switch (status) {
      case WalkingSessionStatus.volunteerAccepted:
        return 'Volunteer found! Please confirm to proceed.';
      case WalkingSessionStatus.userConfirmed:
        return 'Waiting for volunteer to arrive at your location...';
      case WalkingSessionStatus.volunteerReached:
        return 'Volunteer has arrived! Confirm and start your journey.';
      case WalkingSessionStatus.journeyStarted:
        return 'Journey started. Heading to destination...';
      case WalkingSessionStatus.destinationReached:
        return 'You are at your destination! Waiting for confirmation...';
      default:
        return '';
    }
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
}
