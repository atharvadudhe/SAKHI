import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/theme.dart';
import '../../models/session_model.dart';
import '../../providers/providers.dart';
import '../../services/location_service.dart';

class VolunteerDashboardScreen extends ConsumerStatefulWidget {
  const VolunteerDashboardScreen({super.key});

  @override
  ConsumerState<VolunteerDashboardScreen> createState() =>
      _VolunteerDashboardScreenState();
}

class _VolunteerDashboardScreenState
    extends ConsumerState<VolunteerDashboardScreen> {
  final Set<String> _dismissedIds = {};
  // ignore: unused_field
  GoogleMapController? _mapController;
  LatLng? _myPosition;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() => _myPosition = LatLng(pos.latitude, pos.longitude));
    }
  }

  Set<Marker> _buildMarkers(List<SessionModel> sessions) {
    final markers = <Marker>{};

    if (_myPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('me'),
          position: _myPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'You'),
        ),
      );
    }

    for (final s in sessions) {
      if (s.userLocation != null) {
        markers.add(
          Marker(
            markerId: MarkerId(s.sessionId),
            position: LatLng(
              s.userLocation!.latitude,
              s.userLocation!.longitude,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              s.isSOS ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: s.isSOS ? 'SOS Alert' : 'Help Needed',
              snippet: '${s.timeLimit}min session',
            ),
          ),
        );
      }
    }

    return markers;
  }

  String _distanceLabel(SessionModel session) {
    if (_myPosition == null || session.userLocation == null) return '';
    final km = LocationService.instance.distanceBetween(
      _myPosition!.latitude,
      _myPosition!.longitude,
      session.userLocation!.latitude,
      session.userLocation!.longitude,
    );
    if (km < 1) return '${(km * 1000).round()}m away';
    return '${km.toStringAsFixed(1)}km away';
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(searchingSessionsProvider);
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Volunteer Dashboard'),
        actions: [
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
                            : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Switch(
                      value: isAvailable,
                      activeColor: SakhiTheme.safe,
                      onChanged: (val) {
                        if (user != null) {
                          ref
                              .read(sessionControllerProvider.notifier)
                              .toggleAvailability(user.uid, val);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Could not load sessions.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          data: (allSessions) {
            final sessions = allSessions
                .where((s) => !_dismissedIds.contains(s.sessionId))
                .toList();

            return Column(
              children: [
                // Mini Map
                SizedBox(
                  height: 200,
                  child: _myPosition == null
                      ? Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _myPosition!,
                            zoom: 14,
                          ),
                          markers: _buildMarkers(sessions),
                          myLocationEnabled: false,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                          onMapCreated: (c) => _mapController = c,
                        ),
                ),

                // Stats Bar
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: SakhiTheme.safe.withValues(alpha: 0.08),
                    border: Border(
                      bottom: BorderSide(
                        color: SakhiTheme.safe.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_rounded,
                          color: SakhiTheme.safe, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        '${sessions.length} nearby request${sessions.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: SakhiTheme.safe,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Request List
                Expanded(
                  child: sessions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.volunteer_activism_rounded,
                                size: 64,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.15),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No active requests',
                                style:
                                    theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Check back soon \u2014 someone may need your help.',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            final session = sessions[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SessionRequestCard(
                                session: session,
                                distanceLabel: _distanceLabel(session),
                                onAccept: () {
                                  ref
                                      .read(sessionControllerProvider.notifier)
                                      .acceptSession(session.sessionId);
                                },
                                onDecline: () {
                                  setState(() {
                                    _dismissedIds.add(session.sessionId);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Request declined'),
                                      behavior: SnackBarBehavior.floating,
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SessionRequestCard extends StatelessWidget {
  final SessionModel session;
  final String distanceLabel;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _SessionRequestCard({
    required this.session,
    required this.distanceLabel,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(session.startTime);
    final theme = Theme.of(context);
    final isSOS = session.isSOS;
    final accentColor = isSOS ? SakhiTheme.danger : SakhiTheme.searching;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: accentColor.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    isSOS ? Icons.warning_rounded : Icons.person_rounded,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSOS
                            ? 'SOS \u2014 Immediate help!'
                            : 'Safety buddy needed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isSOS ? SakhiTheme.danger : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${elapsed.inMinutes}m ago \u2022 ${session.timeLimit}min session'
                        '${distanceLabel.isNotEmpty ? ' \u2022 $distanceLabel' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isSOS ? 'SOS' : 'NEW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
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
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: BorderSide(
                        color:
                            theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(isSOS ? 'Respond' : 'Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isSOS ? SakhiTheme.danger : SakhiTheme.safe,
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
