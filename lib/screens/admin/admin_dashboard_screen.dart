import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../models/session_model.dart';

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
// Tab 1 — God-Mode Map
// ─────────────────────────────────────────────────────
class _GodModeMapTab extends ConsumerWidget {
  final void Function(GoogleMapController) onMapCreated;

  const _GodModeMapTab({required this.onMapCreated});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final sessionsAsync = ref.watch(allActiveSessionsProvider);
    final broadcastsAsync = ref.watch(broadcastsFeedProvider);
    final theme = Theme.of(context);

    final users = usersAsync.value ?? [];
    final sessions = sessionsAsync.value ?? [];
    final broadcasts = broadcastsAsync.value ?? [];

    final markers = <Marker>{};

    // Active users with location
    for (final u in users) {
      if (u.currentLocation != null) {
        final isVol = u.role == UserRole.volunteer;
        markers.add(
          Marker(
            markerId: MarkerId('user_${u.uid}'),
            position: LatLng(
              u.currentLocation!.latitude,
              u.currentLocation!.longitude,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isVol ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(
              title: u.name,
              snippet: isVol ? 'Volunteer' : 'User',
            ),
          ),
        );
      }
    }

    // Active SOS sessions
    for (final s in sessions) {
      if (s.userLocation != null && s.isSOS) {
        markers.add(
          Marker(
            markerId: MarkerId('sos_${s.sessionId}'),
            position: LatLng(
              s.userLocation!.latitude,
              s.userLocation!.longitude,
            ),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'SOS Active'),
          ),
        );
      }
    }

    // Broadcasts
    for (final b in broadcasts) {
      markers.add(
        Marker(
          markerId: MarkerId('bcast_${b.id}'),
          position: LatLng(b.location.latitude, b.location.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueYellow),
          infoWindow: InfoWindow(
            title: b.alertLabel,
            snippet: b.message,
          ),
        ),
      );
    }

    // Stats bar
    final activeVolunteers =
        users.where((u) => u.role == UserRole.volunteer && u.isAvailable).length;
    final sosSessions = sessions.where((s) => s.isSOS).length;

    return Column(
      children: [
        // Stats ribbon
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          child: Row(
            children: [
              _StatChip(
                label: '${users.length} Users',
                color: SakhiTheme.connected,
              ),
              const SizedBox(width: 16),
              _StatChip(
                label: '$activeVolunteers Volunteers online',
                color: SakhiTheme.safe,
              ),
              const SizedBox(width: 16),
              _StatChip(
                label: '${sessions.length} Active sessions',
                color: SakhiTheme.searching,
              ),
              const SizedBox(width: 16),
              _StatChip(
                label: '$sosSessions SOS',
                color: SakhiTheme.danger,
              ),
              const SizedBox(width: 16),
              _StatChip(
                label: '${broadcasts.length} Broadcasts',
                color: SakhiTheme.searching,
              ),
            ],
          ),
        ),
        // Map
        Expanded(
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(20.5937, 78.9629), // Center of India
              zoom: 5,
            ),
            markers: markers,
            myLocationEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            onMapCreated: onMapCreated,
          ),
        ),
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
