import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../models/session_model.dart';
import '../../models/live_location_model.dart';

import '../../providers/providers.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

/// Admin dashboard — web-only.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedTab = 0;
  // ignore: unused_field
  GoogleMapController? _mapController;

  static const _tabs = [
    _NavItem(icon: Icons.map_rounded, label: 'Map'),
    _NavItem(icon: Icons.warning_rounded, label: 'Live Alerts'),
    _NavItem(icon: Icons.people_rounded, label: 'Users'),
  ];

  @override
  Widget build(BuildContext context) {
    // Security: web-only + admin role
    if (!kIsWeb) {
      return const Scaffold(
        body: Center(
          child: Text('Admin panel is only available on the web platform.'),
        ),
      );
    }

    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null || currentUser.role != UserRole.admin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                'Unauthorized Access',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('You do not have admin privileges.'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => AuthService.instance.signOut(),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          // ── Side Navigation ──
          Container(
            width: 220,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Brand header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SakhiTheme.primary.withValues(alpha: 0.1),
                        ),
                        child: const Icon(Icons.shield_rounded,
                            color: SakhiTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'SAKHI Admin',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: SakhiTheme.primary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Nav items
                ..._tabs.asMap().entries.map((entry) {
                  final i = entry.key;
                  final tab = entry.value;
                  final selected = _selectedTab == i;
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: Material(
                      color: selected
                          ? SakhiTheme.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selectedTab = i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                tab.icon,
                                size: 20,
                                color: selected
                                    ? SakhiTheme.primary
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                tab.label,
                                style: TextStyle(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? SakhiTheme.primary
                                      : theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                // Sign-out
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: () => AuthService.instance.signOut(),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Main Content ──
          Expanded(
            child: switch (_selectedTab) {
              0 => _GodModeMapTab(
                  onMapCreated: (c) => _mapController = c,
                ),
              1 => const _LiveAlertsTab(),
              2 => const _UserManagementTab(),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Nav Item Data
// ─────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ─────────────────────────────────────────────────────
// Tab 1 — God-Mode Live Map
// ─────────────────────────────────────────────────────
class _GodModeMapTab extends ConsumerStatefulWidget {
  final void Function(GoogleMapController) onMapCreated;

  const _GodModeMapTab({required this.onMapCreated});

  @override
  ConsumerState<_GodModeMapTab> createState() => _GodModeMapTabState();
}

class _GodModeMapTabState extends ConsumerState<_GodModeMapTab> {
  /// Currently selected marker for the detail panel.
  LiveLocationModel? _selectedTracker;
  final _timeFormat = DateFormat('hh:mm:ss a');

  // ── Marker builder ──

  Set<Marker> _buildMarkers(
    List<LiveLocationModel> trackers,
    List<SessionModel> sessions,
  ) {
    final markers = <Marker>{};

    // 1. Live trackers from the liveLocations collection
    for (final t in trackers) {
      // Determine colour based on tracking reason + role
      double hue;
      switch (t.trackingReason) {
        case TrackingReason.sos:
          hue = BitmapDescriptor.hueRed; // 🔴 SOS
        case TrackingReason.volunteerDuty:
          hue = BitmapDescriptor.hueGreen; // 🟢 Active volunteer
        case TrackingReason.session:
          hue = t.role == 'volunteer'
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueAzure; // 🔵 Regular user session
      }

      markers.add(
        Marker(
          markerId: MarkerId('live_${t.uid}'),
          position: LatLng(t.latitude, t.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: t.userName,
            snippet: _snippetFor(t),
          ),
          onTap: () => setState(() => _selectedTracker = t),
        ),
      );
    }

    // 2. SOS sessions that may not (yet) have a liveLocations entry
    final trackedUids = trackers.map((t) => t.uid).toSet();
    for (final s in sessions) {
      if (s.isSOS && s.userLocation != null && !trackedUids.contains(s.createdBy)) {
        markers.add(
          Marker(
            markerId: MarkerId('sos_session_${s.sessionId}'),
            position: LatLng(
              s.userLocation!.latitude,
              s.userLocation!.longitude,
            ),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: 'SOS (session)',
              snippet: 'Session ${s.sessionId.substring(0, 8)}',
            ),
          ),
        );
      }
    }

    return markers;
  }

  String _snippetFor(LiveLocationModel t) {
    final roleLbl = t.role == 'volunteer' ? 'Volunteer' : 'User';
    final reasonLbl = switch (t.trackingReason) {
      TrackingReason.sos => '• SOS',
      TrackingReason.volunteerDuty => '• On Duty',
      TrackingReason.session => '• Session',
    };
    return '$roleLbl $reasonLbl • ${t.timeSinceUpdate}';
  }

  // ── Info Detail Panel ──

  Widget _buildInfoPanel(ThemeData theme) {
    final t = _selectedTracker;
    if (t == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        child: Row(
          children: [
            Icon(Icons.touch_app_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 10),
            Text(
              'Tap a marker on the map to see details',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    Color markerColor;
    String reasonLabel;
    switch (t.trackingReason) {
      case TrackingReason.sos:
        markerColor = SakhiTheme.danger;
        reasonLabel = 'SOS';
      case TrackingReason.volunteerDuty:
        markerColor = SakhiTheme.safe;
        reasonLabel = 'Volunteer Duty';
      case TrackingReason.session:
        markerColor = SakhiTheme.connected;
        reasonLabel = 'Safety Session';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Row(
        children: [
          // ── Avatar ──
          CircleAvatar(
            radius: 20,
            backgroundColor: markerColor.withValues(alpha: 0.15),
            child: Text(
              t.userName.isNotEmpty ? t.userName[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: markerColor,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // ── Name + role ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t.role == 'volunteer' ? 'Volunteer' : 'User'} • $reasonLabel',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // ── Reason badge ──
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: markerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: markerColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              reasonLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: markerColor,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // ── Battery ──
          if (t.batteryLevel != null) ...[
            Icon(
              t.batteryLevel! > 20
                  ? Icons.battery_std_rounded
                  : Icons.battery_alert_rounded,
              size: 18,
              color: t.batteryLevel! > 20 ? SakhiTheme.safe : SakhiTheme.danger,
            ),
            const SizedBox(width: 4),
            Text(
              '${t.batteryLevel}%',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 16),
          ],

          // ── Last update ──
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _timeFormat.format(t.lastUpdatedAt),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                t.timeSinceUpdate,
                style: TextStyle(
                  fontSize: 11,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),

          // ── Close button ──
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => setState(() => _selectedTracker = null),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final liveAsync = ref.watch(activeLiveLocationsProvider);
    final sessionsAsync = ref.watch(allActiveSessionsProvider);
    final usersAsync = ref.watch(allUsersProvider);
    final theme = Theme.of(context);

    final trackers = liveAsync.value ?? [];
    final sessions = sessionsAsync.value ?? [];
    final users = usersAsync.value ?? [];
    final markers = _buildMarkers(trackers, sessions);

    // Stats
    final sosCount =
        trackers.where((t) => t.trackingReason == TrackingReason.sos).length +
            sessions.where((s) => s.isSOS).length;
    final volunteerCount =
        trackers.where((t) => t.role == 'volunteer').length;
    final sessionUserCount =
        trackers.where((t) => t.role == 'user').length;
    final totalUsers = users.length;

    return Column(
      children: [
        // ── Stats ribbon ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          child: Row(
            children: [
              _StatChip(
                label: '$totalUsers Registered',
                color: SakhiTheme.connected,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: '$volunteerCount Volunteers live',
                color: SakhiTheme.safe,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: '$sessionUserCount Users tracking',
                color: SakhiTheme.connected,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: '$sosCount SOS',
                color: SakhiTheme.danger,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: '${markers.length} Markers',
                color: SakhiTheme.searching,
              ),
              const Spacer(),
              // Legend
              _LegendDot(color: SakhiTheme.danger, label: 'SOS'),
              const SizedBox(width: 10),
              _LegendDot(color: SakhiTheme.safe, label: 'Volunteer'),
              const SizedBox(width: 10),
              _LegendDot(color: SakhiTheme.connected, label: 'User'),
            ],
          ),
        ),

        // ── Map ──
        Expanded(
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(20.5937, 78.9629), // Centre of India
              zoom: 5,
            ),
            markers: markers,
            myLocationEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            onMapCreated: widget.onMapCreated,
          ),
        ),

        // ── Info Detail Panel ──
        _buildInfoPanel(theme),
      ],
    );
  }
}

// ── Legend dot for the stats ribbon ──
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Tab 2 — Live Alerts
// ─────────────────────────────────────────────────────
class _LiveAlertsTab extends ConsumerWidget {
  const _LiveAlertsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(allActiveSessionsProvider);
    final broadcastsAsync = ref.watch(broadcastsFeedProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live Alerts',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // ── Active Sessions Table ──
          Text('Active Sessions',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Expanded(
            flex: 1,
            child: sessionsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (sessions) {
                if (sessions.isEmpty) {
                  return Center(
                    child: Text(
                      'No active sessions.',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5)),
                    ),
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      theme.colorScheme.surfaceContainerHighest,
                    ),
                    columns: const [
                      DataColumn(label: Text('Session ID')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Created By')),
                      DataColumn(label: Text('Volunteer')),
                      DataColumn(label: Text('Duration')),
                      DataColumn(label: Text('Elapsed')),
                    ],
                    rows: sessions.map((s) {
                      Color statusColor;
                      switch (s.status) {
                        case SessionStatus.sosTriggered:
                          statusColor = SakhiTheme.danger;
                        case SessionStatus.active:
                          statusColor = SakhiTheme.safe;
                        case SessionStatus.searching:
                          statusColor = SakhiTheme.searching;
                        default:
                          statusColor = theme.colorScheme.onSurface;
                      }
                      return DataRow(cells: [
                        DataCell(Text(
                          s.sessionId.substring(0, 8),
                          style: theme.textTheme.bodySmall,
                        )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            s.status.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        )),
                        DataCell(Text(s.createdBy.substring(0, 8))),
                        DataCell(
                            Text(s.volunteerName ?? '—')),
                        DataCell(Text('${s.timeLimit}min')),
                        DataCell(Text('${s.elapsed.inMinutes}min')),
                      ]);
                    }).toList(),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ── Broadcasts Table ──
          Text('Community Broadcasts',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Expanded(
            flex: 1,
            child: broadcastsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (broadcasts) {
                if (broadcasts.isEmpty) {
                  return Center(
                    child: Text(
                      'No broadcasts.',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5)),
                    ),
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      theme.colorScheme.surfaceContainerHighest,
                    ),
                    columns: const [
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Message')),
                      DataColumn(label: Text('By')),
                      DataColumn(label: Text('Time')),
                    ],
                    rows: broadcasts.map((b) {
                      return DataRow(cells: [
                        DataCell(Text(b.alertLabel)),
                        DataCell(SizedBox(
                          width: 300,
                          child: Text(
                            b.message,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                        DataCell(Text(b.userName ?? b.uid.substring(0, 8))),
                        DataCell(Text(b.timeAgo)),
                      ]);
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Tab 3 — User Management
// ─────────────────────────────────────────────────────
class _UserManagementTab extends ConsumerWidget {
  const _UserManagementTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('User Management',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: usersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading users: $e'),
              data: (users) {
                if (users.isEmpty) {
                  return const Center(child: Text('No registered users.'));
                }
                return SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      theme.colorScheme.surfaceContainerHighest,
                    ),
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Phone')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Available')),
                      DataColumn(label: Text('Verified')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: users.map((u) {
                      Color roleColor;
                      switch (u.role) {
                        case UserRole.admin:
                          roleColor = SakhiTheme.primary;
                        case UserRole.volunteer:
                          roleColor = SakhiTheme.safe;
                        case UserRole.user:
                          roleColor = SakhiTheme.connected;
                      }
                      return DataRow(cells: [
                        DataCell(Text(u.name)),
                        DataCell(Text(
                            u.phone.isNotEmpty ? u.phone : '—')),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            u.role.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: roleColor,
                            ),
                          ),
                        )),
                        DataCell(Icon(
                          u.isAvailable
                              ? Icons.check_circle_rounded
                              : Icons.remove_circle_outline_rounded,
                          size: 18,
                          color: u.isAvailable
                              ? SakhiTheme.safe
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                        )),
                        DataCell(Icon(
                          u.verifiedStatus
                              ? Icons.verified_rounded
                              : Icons.cancel_outlined,
                          size: 18,
                          color: u.verifiedStatus
                              ? SakhiTheme.safe
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                        )),
                        DataCell(
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 18),
                            onSelected: (role) {
                              FirestoreService.instance
                                  .updateUserRole(u.uid, role);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'user',
                                child: Text('Set User'),
                              ),
                              const PopupMenuItem(
                                value: 'volunteer',
                                child: Text('Set Volunteer'),
                              ),
                              const PopupMenuItem(
                                value: 'admin',
                                child: Text('Set Admin'),
                              ),
                            ],
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
