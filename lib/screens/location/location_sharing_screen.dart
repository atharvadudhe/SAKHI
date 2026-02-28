import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/theme.dart';
import '../../models/emergency_contact.dart';
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
  final Set<String> _selectedContactIds = <String>{};

  final _durations = [15, 30, 60, 120];

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startSharing(List<EmergencyContact> contacts) async {
    final selectedContacts = contacts.where((c) {
      final key = c.id.isNotEmpty ? c.id : c.phone;
      return _selectedContactIds.contains(key);
    }).toList();
    if (selectedContacts.isEmpty) {
      _showError('Select at least one emergency contact to share with.');
      return;
    }

    setState(() => _isSharing = true);

    try {
      final result = await LocationService.instance.getPosition();
      if (!mounted) return;

      if (!result.isSuccess) {
        setState(() => _isSharing = false);

        switch (result.failure!) {
          case LocationFailure.permissionDenied:
            _showError('Location permission denied. Please grant permission and try again.');
            return;
          case LocationFailure.permissionPermanentlyDenied:
            _showOpenSettingsDialog();
            return;
          case LocationFailure.serviceDisabled:
            _showError('Location services (GPS) are turned off. Please enable GPS and try again.');
            return;
          case LocationFailure.timeout:
            _showError('Could not get a GPS fix. Make sure you are outdoors or near a window, then try again.');
            return;
          case LocationFailure.unknown:
            _showError('An unexpected location error occurred. Please try again.');
            return;
        }
      }

      final position = result.position!;

      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null) throw Exception('Not logged in');

      // Defensive cleanup: ensure any stale active shares are closed first.
      await FirestoreService.instance.stopAllActiveLocationShares(uid);

      final user = ref.read(currentUserProvider).value;
      final userName = user?.name ?? 'Unknown';
      final senderPhone = (user?.phone.trim().isNotEmpty ?? false)
          ? user!.phone
          : '';

      final recipientUsers = await FirestoreService.instance.getUsersByPhones(
        selectedContacts.map((c) => c.phone).toList(),
      );
      final recipientUids = recipientUsers
          .map((u) => u.uid)
          .where((id) => id != uid)
          .toSet()
          .toList();
      final recipientPhones = recipientUsers
          .where((u) => u.uid != uid)
          .map((u) => u.phone)
          .toList();

      if (recipientUids.isEmpty) {
        setState(() => _isSharing = false);
        _showError(
          'Selected contacts are not registered on SAKHI yet.',
        );
        return;
      }

      final shareId = await FirestoreService.instance.createLocationShare(
        uid: uid,
        userName: userName,
        senderPhone: senderPhone,
        recipientUids: recipientUids,
        recipientPhones: recipientPhones,
        location: GeoPoint(position.latitude, position.longitude),
        durationMinutes: _selectedDuration,
      );
      if (!mounted) return;
      ref.invalidate(activeLocationSharesProvider);
      final expiresAt = DateTime.now().add(Duration(minutes: _selectedDuration));

      // Start updating location on the share
      LocationService.instance.stopLocationUpdates();
      LocationService.instance.startLocationUpdates(
        onUpdate: (pos) {
          if (DateTime.now().isAfter(expiresAt)) {
            FirestoreService.instance.stopLocationShare(shareId);
            LocationService.instance.stopLocationUpdates();
            return;
          }
          if (shareId.isNotEmpty) {
            FirestoreService.instance.updateLocationShare(
              shareId,
              GeoPoint(pos.latitude, pos.longitude),
            );
            // Also update user location
            FirestoreService.instance.updateUserLocation(
              uid,
              GeoPoint(pos.latitude, pos.longitude),
            );
          }
        },
        intervalSeconds: 30,
      );
      // Keep sharing alive even if this screen is closed.
      Timer(Duration(minutes: _selectedDuration), () async {
        await FirestoreService.instance.stopLocationShare(shareId);
        LocationService.instance.stopLocationUpdates();
      });

      if (mounted) {
        final unmatchedCount = selectedContacts.length - recipientUids.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              unmatchedCount > 0
                  ? 'Sharing started with $recipientUids.length contact(s). '
                      '$unmatchedCount not on SAKHI.'
                  : 'Location sharing started with $recipientUids.length contact(s)!',
            ),
            backgroundColor: SakhiTheme.safe,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSharing = false);
        _showError('Could not start sharing: $e');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: SakhiTheme.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showOpenSettingsDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Location permission is permanently denied. '
          'Please open app settings and enable location access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopSharing(String? shareId) async {
    final uid = ref.read(authStateProvider).value?.uid;
    try {
      LocationService.instance.stopLocationUpdates();

      if (shareId != null && shareId.isNotEmpty) {
        await FirestoreService.instance.stopLocationShare(shareId);
      }
      if (uid != null) {
        await FirestoreService.instance.stopAllActiveLocationShares(uid);
        final stillActive =
            await FirestoreService.instance.getActiveLocationShares(uid);
        if (stillActive.isNotEmpty) {
          throw Exception(
            'Location sharing is still active. Please try again.',
          );
        }
      }

      if (mounted) {
        ref.invalidate(activeLocationSharesProvider);
        setState(() {
          _isSharing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location sharing stopped'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Could not stop sharing: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(emergencyContactsProvider);
    final activeSharesAsync = ref.watch(activeLocationSharesProvider);
    final activeShare = activeSharesAsync.value?.isNotEmpty == true
        ? activeSharesAsync.value!.first
        : null;
    final activeShareId = activeShare?['id'] as String?;
    final activeExpiresAtRaw = activeShare?['expiresAt'];
    final activeExpiresAt = activeExpiresAtRaw is Timestamp
        ? activeExpiresAtRaw.toDate()
        : (activeExpiresAtRaw as DateTime?);
    final resolvedExpiresAt = activeExpiresAt ?? DateTime.now();
    final hasActiveShare =
        activeShare != null &&
        activeExpiresAt != null &&
        !((activeShare['isActive'] as bool?) == false) &&
        DateTime.now().isBefore(activeExpiresAt);
    final sharedWithCount =
        (activeShare?['recipientUids'] as List<dynamic>? ?? []).length;

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

              if (hasActiveShare) ...[
                // Active sharing UI
                _ActiveSharingCard(
                  expiresAt: resolvedExpiresAt,
                  sharedWithCount: sharedWithCount,
                  onStop: () => _stopSharing(activeShareId),
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

                const Text(
                  'Select Contacts',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 12),
                contactsAsync.when(
                  data: (contacts) {
                    if (contacts.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.orange.withValues(alpha: 0.08),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'No emergency contacts found. Add contacts first.',
                        ),
                      );
                    }

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: contacts.map((contact) {
                          final key =
                              contact.id.isNotEmpty ? contact.id : contact.phone;
                          final selected = _selectedContactIds.contains(key);
                          return CheckboxListTile(
                            value: selected,
                            title: Text(contact.name),
                            subtitle: Text(contact.phone),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            onChanged: (value) {
                              setState(() {
                                if (value ?? false) {
                                  _selectedContactIds.add(key);
                                } else {
                                  _selectedContactIds.remove(key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: SakhiTheme.danger.withValues(alpha: 0.08),
                    ),
                    child: const Text('Could not load contacts.'),
                  ),
                ),
                const SizedBox(height: 24),

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
                        text: 'Location refreshes every 30 seconds',
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
                  onPressed: _isSharing || hasActiveShare
                      ? null
                      : () => _startSharing(contactsAsync.value ?? const []),
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
  final DateTime expiresAt;
  final int sharedWithCount;
  final VoidCallback onStop;

  const _ActiveSharingCard({
    required this.expiresAt,
    required this.sharedWithCount,
    required this.onStop,
  });

  @override
  State<_ActiveSharingCard> createState() => _ActiveSharingCardState();
}

class _ActiveSharingCardState extends State<_ActiveSharingCard> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
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
    final remaining = widget.expiresAt.difference(DateTime.now());
    final totalSeconds = remaining.inSeconds.clamp(0, 999999);
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;

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
            'Shared with ${widget.sharedWithCount} contact(s)',
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
