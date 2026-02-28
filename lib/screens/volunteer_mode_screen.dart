import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/walking_request_model.dart';
import '../services/firestore_service.dart';
import '../services/walking_request_service.dart';
import '../providers/volunteer_providers.dart'; // <- provider for incoming requests
import 'session/volunteer_requests_manager_screen.dart';

/// Screen that shows incoming requests to volunteers
/// Accept/reject actions are in VolunteerRequestsManagerScreen
/// 
/// Features:
/// - Real-time stream of incoming requests
/// - Only visible if volunteer.role == "volunteer" and isVerified == true
/// - Display requester information
/// - Navigation to manager for actions
/// - Real-time updates
class VolunteerModeScreen extends ConsumerStatefulWidget {
  const VolunteerModeScreen({super.key});

  @override
  ConsumerState<VolunteerModeScreen> createState() => _VolunteerModeScreenState();
}

class _VolunteerModeScreenState extends ConsumerState<VolunteerModeScreen> {
  late FirestoreService _firestoreService;
  LatLng? _volLocation;
  StreamSubscription<Position>? _positionSub;
  double _maxRangeKm = 5.0; // Volunteer can set from 2km and above
  static const double _minRangeKm = 2.0;
  static const double _maxAllowedRangeKm = 50.0;
  
  // Debug state
  final bool _showDebugPanel = true;
  List<String> _debugLogs = [];  

  String get _volunteerId {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _addDebugLog('⚠️ volunteerId requested but no auth user');
      return '';
    }
    return uid;
  }

  @override
  void initState() {
    super.initState();
    // use singleton instance
    _firestoreService = FirestoreService.instance;
    _addDebugLog('🛠️ initState called, volunteerId=$_volunteerId');

    // initialize location (if permission granted)
    _loadSavedRange();
    _initVolunteerLocation();
    _startVolunteerLocationUpdates();
    // Listen to provider events for debugging (will log lengths/errors)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final vid = user.uid;
          ref.listen<AsyncValue<List<WalkingRequestModel>>>(
            incomingRequestsProvider(vid),
            (previous, next) {
              next.when(
                data: (list) => _addDebugLog('📬 Provider listener: ${list.length} requests'),
                loading: () => _addDebugLog('⏳ Provider listener: loading'),
                error: (e, st) => _addDebugLog('❌ Provider listener error: $e'),
              );
            },
          );
        } else {
          _addDebugLog('⚠️ Provider listener: no auth user');
        }
      } catch (e) {
        _addDebugLog('⚠️ Failed to attach provider listener: $e');
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
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

  String get _rangePrefKey => 'volunteer_range_km_$_volunteerId';

  Future<void> _loadSavedRange() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_rangePrefKey);
      if (saved == null || !mounted) return;
      setState(() {
        _maxRangeKm = saved.clamp(_minRangeKm, _maxAllowedRangeKm);
      });
      _addDebugLog('📦 Loaded saved range: ${_maxRangeKm.toStringAsFixed(1)} km');
    } catch (e) {
      _addDebugLog('⚠️ Failed to load saved range: $e');
    }
  }

  Future<void> _saveRange(double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
        _rangePrefKey,
        value.clamp(_minRangeKm, _maxAllowedRangeKm),
      );
    } catch (e) {
      _addDebugLog('⚠️ Failed to save range: $e');
    }
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
      // update firestore with most recent coords
      _firestoreService.updateLiveLocation(
          _volunteerId, GeoPoint(pos.latitude, pos.longitude));
      _addDebugLog('📍 Location updated: ${pos.latitude}, ${pos.longitude}');
    });
  }

  // Accept/reject actions moved to VolunteerRequestsManagerScreen

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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const VolunteerRequestsManagerScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Manage'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.purple.shade400,
                ),
              ),
            ),
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
    print('🔥 ACTIVE SCREEN: VolunteerModeScreen');
    print('🟥 VOLUNTEER DASHBOARD BUILD');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _addDebugLog('⚠️ No authenticated user');
      return const Center(child: Text('Please log in'));
    }
    final volunteerId = user.uid;
    _addDebugLog('👀 Provider watch executed build; volunteerId=$volunteerId');

    // provider watch
    final requestsAsync = ref.watch(incomingRequestsProvider(volunteerId));
    print('🟢 PROVIDER WATCHED for volunteerId=$volunteerId');

    return requestsAsync.when(
      loading: () {
        _addDebugLog('⏳ Provider state: loading');
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading pending requests...'),
            ],
          ),
        );
      },
      error: (error, stack) {
        _addDebugLog('❌ Provider error: $error');
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
                  'Error: $error',
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
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
      },
      data: (requests) {
        _addDebugLog('📊 Provider returned ${requests.length} requests');
        final filteredRequests = _filterByRange(requests);
        if (requests.isEmpty) {
          _addDebugLog('⚠️ NO REQUESTS FOUND (provider)');
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

        return Column(
          children: [
            _RangeFilterCard(
              valueKm: _maxRangeKm,
              onChanged: (value) {
                setState(() => _maxRangeKm = value);
                _saveRange(value);
              },
            ),
            Expanded(
              child: filteredRequests.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _volLocation == null
                              ? 'Location unavailable. Showing range filter only.'
                              : 'No requests within ${_maxRangeKm.toStringAsFixed(1)} km',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filteredRequests.length,
                      itemBuilder: (context, index) {
                        final request = filteredRequests[index];
                        return _WalkingBuddyRequestCard(
                          request: request,
                          volunteerLocation: _volLocation,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  List<WalkingRequestModel> _filterByRange(List<WalkingRequestModel> requests) {
    final vol = _volLocation;
    if (vol == null) return requests;
    return requests.where((request) {
      final distance = Geolocator.distanceBetween(
            vol.latitude,
            vol.longitude,
            request.requesterLocation.latitude,
            request.requesterLocation.longitude,
          ) /
          1000.0;
      return distance <= _maxRangeKm;
    }).toList();
  }
}

class _RangeFilterCard extends StatelessWidget {
  final double valueKm;
  final ValueChanged<double> onChanged;

  const _RangeFilterCard({
    required this.valueKm,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request Range: ${valueKm.toStringAsFixed(1)} km',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.purple.shade700,
            ),
          ),
          Slider(
            value: valueKm,
            min: 2,
            max: _VolunteerModeScreenState._maxAllowedRangeKm,
            divisions: 96, // 0.5km step
            label: '${valueKm.toStringAsFixed(1)} km',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _WalkingBuddyRequestCard extends StatelessWidget {
  final WalkingRequestModel request;
  final LatLng? volunteerLocation;

  const _WalkingBuddyRequestCard({
    required this.request,
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap button below to view & manage requests',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
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
