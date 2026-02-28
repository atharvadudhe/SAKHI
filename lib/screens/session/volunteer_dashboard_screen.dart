import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/theme.dart';
import '../../models/session_model.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../../providers/walking_buddy_providers.dart';
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
  double _maxRangeKm = 5.0;

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
              s.isSOS
                  ? BitmapDescriptor.hueRed
                  : s.isVirtualCompanionActive
                      ? BitmapDescriptor.hueAzure
                      : BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: s.isSOS ? 'SOS Alert' : 'Help Needed',
              snippet: s.timeLimit > 0 ? '${s.timeLimit}min session' : null,
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

  List<SessionModel> _filterByRange(List<SessionModel> sessions) {
    if (_myPosition == null) return sessions;
    return sessions.where((s) {
      final loc = s.userLocation;
      if (loc == null) return false;
      final km = LocationService.instance.distanceBetween(
        _myPosition!.latitude,
        _myPosition!.longitude,
        loc.latitude,
        loc.longitude,
      );
      return km <= _maxRangeKm;
    }).toList();
  }

  /// Accept an incoming walking-buddy request (converted to [SessionModel]).
  Future<void> _acceptWalkingBuddy(SessionModel session) async {
    final auth = ref.read(authStateProvider).value;
    final user = ref.read(currentUserProvider).value;
    if (auth == null || user == null) return;

    // calculate distance from volunteer to requester
    final distance = LocationService.instance.distanceBetween(
      _myPosition?.latitude ?? 0,
      _myPosition?.longitude ?? 0,
      session.userLocation?.latitude ?? 0,
      session.userLocation?.longitude ?? 0,
    );

    final controller = ref.read(walkingBuddyControllerProvider.notifier);
    final success = await controller.volunteerAcceptSession(
      sessionId: session.sessionId,
      volunteerId: auth.uid,
      volunteerName: user.name,
      volunteerPhone: user.phone,
      volunteerPhotoUrl: user.photoUrl,
      distanceFromUser: distance,
    );

    if (success && mounted) {
      // navigate to walking buddy active screen.
      // Google Maps navigation will be launched only after user confirmation.
      context.push('/walking-buddy/volunteer-active', extra: session.sessionId);
    }
  }

  /// Reject a walking-buddy request and dismiss it locally.
  Future<void> _rejectWalkingBuddy(SessionModel session) async {
    final auth = ref.read(authStateProvider).value;
    if (auth == null) return;

    final controller = ref.read(walkingBuddyControllerProvider.notifier);
    await controller.volunteerRejectSession(
      sessionId: session.sessionId,
      volunteerId: auth.uid,
      rejectionReason: null,
    );

    if (mounted) {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔥 ACTIVE SCREEN: VolunteerDashboardScreen');
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
                      activeThumbColor: SakhiTheme.safe,
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
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const SizedBox.shrink(),
          data: (user) {
            // ── KYC gate: block unverified volunteers ──
            if (user != null &&
                user.verificationStatus != VerificationStatus.verified) {
              return _buildKycLockedView(theme, user.verificationStatus);
            }
            return _buildDashboardContent(theme);
          },
        ),
      ),
    );
  }

  /// Locked screen shown when the volunteer has not completed KYC.
  Widget _buildKycLockedView(
    ThemeData theme,
    VerificationStatus status,
  ) {
    String title;
    String message;
    IconData icon;
    Color color;

    switch (status) {
      case VerificationStatus.pending:
        title = 'Verification Pending';
        message =
            'Your documents are being reviewed. You will be able to '
            'view active SOS requests once verified.';
        icon = Icons.hourglass_top_rounded;
        color = SakhiTheme.searching;
      case VerificationStatus.rejected:
        title = 'Verification Rejected';
        message =
            'Your KYC submission was rejected. Please re-submit '
            'valid documents to access the volunteer dashboard.';
        icon = Icons.block_rounded;
        color = SakhiTheme.danger;
      case VerificationStatus.unverified:
      case VerificationStatus.verified:
        title = 'Verification Required';
        message =
            'For the safety of our users, volunteers must complete '
            'identity verification before viewing exact locations.';
        icon = Icons.verified_user_rounded;
        color = SakhiTheme.primary;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            if (status != VerificationStatus.pending)
              ElevatedButton.icon(
                onPressed: () => context.push('/volunteer-verification'),
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: const Text('Complete Verification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SakhiTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(ThemeData theme) {
    final sessionsAsync = ref.watch(searchingSessionsProvider);

    return sessionsAsync.when(
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
            final filteredSessions = _filterByRange(sessions);

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
                          markers: _buildMarkers(filteredSessions),
                          myLocationEnabled: false,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                          onMapCreated: (c) => _mapController = c,
                        ),
                ),

                // Range selector
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: SakhiTheme.primary.withValues(alpha: 0.05),
                    border: Border(
                      bottom: BorderSide(
                        color: SakhiTheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Range: ${_maxRangeKm.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Slider(
                        value: _maxRangeKm,
                        min: 2,
                        max: 50,
                        divisions: 96,
                        label: '${_maxRangeKm.toStringAsFixed(1)} km',
                        onChanged: (v) => setState(() => _maxRangeKm = v),
                      ),
                    ],
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
                        '${filteredSessions.length} request${filteredSessions.length == 1 ? '' : 's'} within ${_maxRangeKm.toStringAsFixed(1)} km',
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
                  child: filteredSessions.isEmpty
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
                                'No requests in range',
                                style:
                                    theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try increasing your range above ${_maxRangeKm.toStringAsFixed(1)} km.',
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
                          itemCount: filteredSessions.length,
                          itemBuilder: (context, index) {
                            final session = filteredSessions[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SessionRequestCard(
                                session: session,
                                distanceLabel: _distanceLabel(session),
                                onAccept: () {
                                  if (session.isVirtualCompanionActive) {
                                    _acceptWalkingBuddy(session);
                                  } else {
                                    ref
                                        .read(sessionControllerProvider.notifier)
                                        .acceptSession(session.sessionId);
                                  }
                                },
                                onDecline: () {
                                  if (session.isVirtualCompanionActive) {
                                    _rejectWalkingBuddy(session);
                                  } else {
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
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
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
                            : (session.isVirtualCompanionActive
                                ? 'Walking buddy needed'
                                : 'Safety buddy needed'),
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
