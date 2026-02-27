import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/walking_request_model.dart';
import '../../services/firestore_service.dart';
import '../../services/walking_request_service.dart';
import '../../providers/volunteer_providers.dart';
import '../../config/theme.dart';

/// Volunteer Manager Screen - where volunteers manage incoming requests
/// Shows pending requests with accept/reject options
class VolunteerRequestsManagerScreen extends ConsumerStatefulWidget {
  const VolunteerRequestsManagerScreen({super.key});

  @override
  ConsumerState<VolunteerRequestsManagerScreen> createState() =>
      _VolunteerRequestsManagerScreenState();
}

class _VolunteerRequestsManagerScreenState
    extends ConsumerState<VolunteerRequestsManagerScreen> {
  late FirestoreService _firestoreService;
  late Map<String, bool> _loadingStates; // Track loading per request
  LatLng? _volLocation;
  StreamSubscription<Position>? _positionSub;

  String get _volunteerId {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return '';
    }
    return uid;
  }

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService.instance;
    _loadingStates = {};
    _initVolunteerLocation();
    _startVolunteerLocationUpdates();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _initVolunteerLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _volLocation = LatLng(pos.latitude, pos.longitude);
      });
    } catch (e) {
      print('Could not determine volunteer location: $e');
    }
  }

  void _startVolunteerLocationUpdates() {
    _positionSub ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      _firestoreService.updateLiveLocation(
          _volunteerId, GeoPoint(pos.latitude, pos.longitude));
    });
  }

  /// Handle accepting a walking request
  Future<void> _handleAcceptRequest(WalkingRequestModel request) async {
    try {
      setState(() {
        _loadingStates[request.requestId] = true;
      });

      await _firestoreService.acceptRequest(
        request.requestId,
        _volunteerId,
      );

      await _firestoreService.setVolunteerAvailability(_volunteerId, false);
      _startVolunteerLocationUpdates();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You accepted request from ${request.requesterName}'),
            backgroundColor: SakhiTheme.safe,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting request: $e'),
            backgroundColor: SakhiTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingStates[request.requestId] = false;
        });
      }
    }
  }

  /// Handle rejecting a walking request
  Future<void> _handleRejectRequest(WalkingRequestModel request) async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Reject request from ${request.requesterName}?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Reason (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: SakhiTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason != null) {
      try {
        setState(() {
          _loadingStates[request.requestId] = true;
        });

        await _firestoreService.rejectRequest(
          request.requestId,
          _volunteerId,
          reason: reason.isNotEmpty ? reason : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request from ${request.requesterName} rejected'),
              backgroundColor: SakhiTheme.danger,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error rejecting request: $e'),
              backgroundColor: SakhiTheme.danger,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _loadingStates[request.requestId] = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Volunteer Requests'),
          elevation: 0,
        ),
        body: const Center(child: Text('Please log in')),
      );
    }

    final volunteerId = user.uid;
    final requestsAsync = ref.watch(incomingRequestsProvider(volunteerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer Requests'),
        elevation: 0,
        backgroundColor: SakhiTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: requestsAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading requests...'),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: SakhiTheme.danger,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: $error',
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(incomingRequestsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 64,
                      color: SakhiTheme.safe.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No pending requests',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'New requests will appear here when users need your help',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _RequestCard(
                request: request,
                isLoading: _loadingStates[request.requestId] ?? false,
                onAccept: () => _handleAcceptRequest(request),
                onReject: () => _handleRejectRequest(request),
                volunteerLocation: _volLocation,
              );
            },
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final WalkingRequestModel request;
  final bool isLoading;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final LatLng? volunteerLocation;

  const _RequestCard({
    required this.request,
    required this.isLoading,
    required this.onAccept,
    required this.onReject,
    this.volunteerLocation,
  });

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) *
            math.sin(dLon / 2) *
            math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lon2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  @override
  Widget build(BuildContext context) {
    final distance = volunteerLocation != null
        ? _calculateDistance(
            volunteerLocation!.latitude,
            volunteerLocation!.longitude,
            request.requesterLocation.latitude,
            request.requesterLocation.longitude,
          )
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and distance
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.requesterName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Requested ${_formatTimeAgo(request.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: SakhiTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: SakhiTheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${distance.toStringAsFixed(1)} km',
                      style: TextStyle(
                        color: SakhiTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Location info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: SakhiTheme.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Location: (${request.requesterLocation.latitude.toStringAsFixed(4)}, ${request.requesterLocation.longitude.toStringAsFixed(4)})',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: SakhiTheme.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Reject',
                        style: TextStyle(
                          color: SakhiTheme.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SakhiTheme.safe,
                      foregroundColor: Colors.white,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text(
                              'Accept',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
