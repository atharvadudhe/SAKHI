import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/walking_request_model.dart';
import '../services/firestore_service.dart';
import '../services/walking_request_service.dart';
import 'live_tracking_screen.dart';

/// Example screen for volunteers to see incoming requests
/// 
/// Features:
/// - Real-time stream of incoming requests with full debug logging
/// - Only visible if volunteer.role == "volunteer" and isVerified == true
/// - Display requester information
/// - Accept or reject requests
/// - Real-time updates
/// - Debug buttons to test Firestore connectivity
class VolunteerModeScreen extends StatefulWidget {
  final String volunteerId;

  const VolunteerModeScreen({
    Key? key,
    required this.volunteerId,
  }) : super(key: key);

  @override
  State<VolunteerModeScreen> createState() => _VolunteerModeScreenState();
}

class _VolunteerModeScreenState extends State<VolunteerModeScreen> {
  late FirestoreService _firestoreService;
  late Map<String, bool> _loadingStates; // Track loading per request
  LatLng? _volLocation;
  StreamSubscription<Position>? _positionSub;
  
  // Debug state
  bool _showDebugPanel = true;
  List<String> _debugLogs = [];
  int _lastSnapshotCount = 0;

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService.instance;
    _loadingStates = {};
    _addDebugLog('🎬 Volunteer Mode Screen initialized');
    _addDebugLog('Volunteer ID: ${widget.volunteerId}');
    _initVolunteerLocation();
  }

  void _addDebugLog(String log) {
    if (mounted) {
      setState(() {
        _debugLogs.insert(0, '[${DateTime.now().toIso8601String().split('T')[1]}] $log');
        if (_debugLogs.length > 20) {
          _debugLogs = _debugLogs.sublist(0, 20);
        }
      });
    }
    print('🎬 [VolunteerMode] $log');
  }

  Future<void> _initVolunteerLocation() async {
    try {
      _addDebugLog('📍 Requesting location...');
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _volLocation = LatLng(pos.latitude, pos.longitude);
      });
      _addDebugLog('📍 Location obtained: ${pos.latitude}, ${pos.longitude}');
    } catch (e) {
      _addDebugLog('❌ Location error: $e');
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
          widget.volunteerId, GeoPoint(pos.latitude, pos.longitude));
      _addDebugLog('📍 Location updated: ${pos.latitude}, ${pos.longitude}');
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

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

  /// Handle accepting a walking request
  Future<void> _handleAcceptRequest(WalkingRequestModel request) async {
    try {
      setState(() {
        _loadingStates[request.requestId] = true;
      });

      _addDebugLog('👤 Accepting request from ${request.requesterName}');

      await _firestoreService.acceptRequest(
        request.requestId,
        widget.volunteerId,
      );
      
      _addDebugLog('✅ Request accepted, updating availability...');
      await _firestoreService.setVolunteerAvailability(widget.volunteerId, false);

      // start sharing our location so user can track us
      _startVolunteerLocationUpdates();
      _addDebugLog('📍 Started location sharing');

      // attempt to open walking navigation for convenience
      try {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        _addDebugLog('🗺️ Opening navigation to user...');
        await _firestoreService.openGoogleMapsNavigation(
          volunteerLat: pos.latitude,
          volunteerLng: pos.longitude,
          userLat: request.requesterLocation.latitude,
          userLng: request.requesterLocation.longitude,
        );
      } catch (e) {
        _addDebugLog('⚠️ Navigation failed: $e');
        print('Could not open navigation: $e');
      }

      // navigate to live tracking screen so volunteer can also monitor
      if (mounted) {
        _addDebugLog('🚀 Navigating to live tracking screen...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LiveTrackingScreen(
              userId: request.requesterId,
              volunteerId: widget.volunteerId,
            ),
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You accepted request from ${request.requesterName}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _addDebugLog('❌ Error accepting request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting request: $e'),
            backgroundColor: Colors.red,
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

  // Debug functions
  Future<void> _debugFetchAllRequests() async {
    _addDebugLog('🔍 Fetching ALL requests (no filters)...');
    try {
      final requests = await _firestoreService.debugFetchAllRequests();
      _addDebugLog('✅ Fetched ${requests.length} total requests');
      setState(() {});
    } catch (e) {
      _addDebugLog('❌ Debug fetch failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer Mode'),
        elevation: 0,
        backgroundColor: Colors.purple.shade400,
        actions: [
          IconButton(
            icon: Icon(_showDebugPanel ? Icons.close : Icons.bug_report),
            onPressed: () {
              setState(() {
                _showDebugPanel = !_showDebugPanel;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildBody(),
          ),
          if (_showDebugPanel) _buildDebugPanel(),
        ],
      ),
    );
  }

  Widget _buildDebugPanel() {
    return Container(
      color: Colors.grey.shade200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: Colors.grey.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'DEBUG LOGS',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Fetch All'),
                    onPressed: _debugFetchAllRequests,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Clear'),
                    onPressed: () {
                      setState(() {
                        _debugLogs.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.black87,
            height: 150,
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: Text(
                _debugLogs.isNotEmpty
                    ? _debugLogs.join('\n')
                    : 'No logs yet...',
                style: const TextStyle(
                  color: Colors.lime,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<List<WalkingRequestModel>>(
      stream: _firestoreService.streamPendingRequestsForVolunteer(),
      builder: (context, snapshot) {
        // Log snapshot state for debugging
        String connectionState = '';
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
            connectionState = 'waiting';
            break;
          case ConnectionState.active:
            connectionState = 'active';
            break;
          case ConnectionState.done:
            connectionState = 'done';
            break;
          case ConnectionState.none:
            connectionState = 'none';
            break;
        }

        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          _addDebugLog('⏳ Stream state: connecting...');
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Connecting to requests stream...'),
              ],
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          _addDebugLog('❌ Stream error: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connection State: $connectionState',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _debugFetchAllRequests,
                    child: const Text('Test Firestore Access'),
                  ),
                ],
              ),
            ),
          );
        }

        final requests = snapshot.data ?? [];

        // Update debug log with latest snapshot
        if (requests.length != _lastSnapshotCount) {
          _addDebugLog('📊 Stream snapshot: ${requests.length} pending requests');
          _lastSnapshotCount = requests.length;
        }

        if (requests.isEmpty) {
          _addDebugLog('⚠️ NO REQUESTS FOUND');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 64,
                    color: Colors.green.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No pending requests right now',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'New requests will appear here when users need your help',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _debugFetchAllRequests,
                    child: const Text('Test Firestore Connection'),
                  ),
                ],
              ),
            ),
          );
        }

        // Display requests
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _WalkingBuddyRequestCard(
              request: request,
              isLoading: _loadingStates[request.requestId] ?? false,
              onAccept: () => _handleAcceptRequest(request),
              volunteerLocation: _volLocation,
            );
          },
        );
      },
    );
  }
}

class _WalkingBuddyRequestCard extends StatelessWidget {
  final WalkingRequestModel request;
  final bool isLoading;
  final VoidCallback onAccept;
  final LatLng? volunteerLocation;

  const _WalkingBuddyRequestCard({
    required this.request,
    required this.isLoading,
    required this.onAccept,
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        'Status: ${request.status.name}',
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${distance.toStringAsFixed(1)} km',
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Location: (${request.requesterLocation.latitude.toStringAsFixed(4)}, ${request.requesterLocation.longitude.toStringAsFixed(4)})',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Text(
              'Created ${_formatTimeAgo(request.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Accepting...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      )
                    : const Text(
                        'Accept Request',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
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
