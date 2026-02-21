import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

class LocationSharingScreen extends ConsumerStatefulWidget {
  const LocationSharingScreen({super.key});

  @override
  ConsumerState<LocationSharingScreen> createState() =>
      _LocationSharingScreenState();
}

class _LocationSharingScreenState extends ConsumerState<LocationSharingScreen> {
  int _selectedDuration = 30; // minutes
  bool _isSharing = false;
  String? _activeShareId;
  Timer? _expiryTimer;

  final _durations = [15, 30, 60, 120];

  @override
  void dispose() {
    _expiryTimer?.cancel();
    // Clean up active sharing when leaving the screen
    if (_activeShareId != null) {
      LocationService.instance.stopLocationUpdates();
      FirestoreService.instance.stopLocationShare(_activeShareId!);
    }
    super.dispose();
  }

  Future<void> _startSharing() async {
    setState(() => _isSharing = true);

    try {
      final position = await LocationService.instance.getCurrentPosition();
      if (position == null) {
        throw Exception('Could not get your location');
      }

      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null) throw Exception('Not logged in');

      final user = ref.read(currentUserProvider).value;
      final userName = user?.name ?? 'Unknown';

      final shareId = await FirestoreService.instance.createLocationShare(
        uid: uid,
        userName: userName,
        location: GeoPoint(position.latitude, position.longitude),
        durationMinutes: _selectedDuration,
      );

      setState(() {
        _activeShareId = shareId;
      });

      // Start updating location on the share
      LocationService.instance.startLocationUpdates(
        onUpdate: (pos) {
          if (_activeShareId != null) {
            FirestoreService.instance.updateLocationShare(
              _activeShareId!,
              GeoPoint(pos.latitude, pos.longitude),
            );
            // Also update user location
            FirestoreService.instance.updateUserLocation(
              uid,
              GeoPoint(pos.latitude, pos.longitude),
            );
          }
        },
        intervalSeconds: 10,
      );

      // Set expiry timer
      _expiryTimer?.cancel();
      _expiryTimer = Timer(Duration(minutes: _selectedDuration), () {
        _stopSharing();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location sharing started!'),
            backgroundColor: SakhiTheme.safe,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSharing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: SakhiTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _stopSharing() async {
    _expiryTimer?.cancel();
    LocationService.instance.stopLocationUpdates();

    if (_activeShareId != null) {
      try {
        await FirestoreService.instance.stopLocationShare(_activeShareId!);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _activeShareId = null;
        _isSharing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location sharing stopped'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Share Location'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: SakhiTheme.connected.withValues(alpha: 0.08),
                  border: Border.all(
                    color: SakhiTheme.connected.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: SakhiTheme.connected,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Time-Bound Location Sharing',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Share your real-time location with emergency contacts for a set duration.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              if (_activeShareId != null) ...[
                // Active sharing UI
                _ActiveSharingCard(
                  duration: _selectedDuration,
                  onStop: _stopSharing,
                ),
              ] else ...[
                // Duration selection
                const Text(
                  'Share Duration',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 12),
                Row(
                  children: _durations.map((mins) {
                    final isSelected = _selectedDuration == mins;
                    final label = mins < 60 ? '${mins}m' : '${mins ~/ 60}h';
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _selectedDuration = mins),
                          selectedColor: SakhiTheme.connected,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : SakhiTheme.connected,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: SakhiTheme.connected.withValues(
                            alpha: 0.08,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.transparent
                                  : SakhiTheme.connected.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                // What happens
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'When you share:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _BulletItem(
                        text:
                            'Your real-time location is shared for $_selectedDuration minutes',
                      ),
                      const _BulletItem(
                        text: 'Emergency contacts can see your position',
                      ),
                      const _BulletItem(
                        text: 'Sharing stops automatically when time expires',
                      ),
                      const _BulletItem(
                        text: 'You can stop sharing at any time',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Start button
                ElevatedButton.icon(
                  onPressed: _isSharing ? null : _startSharing,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.share_location_rounded),
                  label: Text(_isSharing ? 'Starting...' : 'Start Sharing'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SakhiTheme.connected,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveSharingCard extends StatefulWidget {
  final int duration;
  final VoidCallback onStop;

  const _ActiveSharingCard({required this.duration, required this.onStop});

  @override
  State<_ActiveSharingCard> createState() => _ActiveSharingCardState();
}

class _ActiveSharingCardState extends State<_ActiveSharingCard> {
  late Timer _timer;
  late DateTime _expiresAt;

  @override
  void initState() {
    super.initState();
    _expiresAt = DateTime.now().add(Duration(minutes: widget.duration));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _expiresAt.difference(DateTime.now());
    final mins = remaining.inMinutes;
    final secs = remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: SakhiTheme.connected.withValues(alpha: 0.08),
        border: Border.all(
          color: SakhiTheme.connected.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.share_location_rounded,
            color: SakhiTheme.connected,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Location Sharing Active',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: SakhiTheme.connected,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${mins}m ${secs}s remaining',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Your contacts can see your location',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onStop,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop Sharing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SakhiTheme.danger,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;

  const _BulletItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: SakhiTheme.connected,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
