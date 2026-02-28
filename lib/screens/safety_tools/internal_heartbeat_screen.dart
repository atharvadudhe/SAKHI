import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../config/theme.dart';
import '../../models/emergency_contact.dart';
import '../../providers/providers.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

/// Internal heartbeat monitor:
/// user must periodically tap "I'm Safe" before timer expires.
/// If they miss a heartbeat, SOS is auto-triggered.
class InternalHeartbeatScreen extends ConsumerStatefulWidget {
  const InternalHeartbeatScreen({super.key});

  @override
  ConsumerState<InternalHeartbeatScreen> createState() =>
      _InternalHeartbeatScreenState();
}

class _InternalHeartbeatScreenState
    extends ConsumerState<InternalHeartbeatScreen> {
  static const List<int> _intervalOptionsMin = [3, 5, 10, 15];

  Timer? _countdownTimer;
  int _selectedMinutes = 3;
  int _remainingSeconds = 3 * 60;
  bool _isMonitoring = false;
  bool _isTriggeringSOS = false;
  bool _sosTriggered = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _selectedMinutes * 60;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startMonitoring() {
    _countdownTimer?.cancel();
    setState(() {
      _isMonitoring = true;
      _sosTriggered = false;
      _remainingSeconds = _selectedMinutes * 60;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isMonitoring || _isTriggeringSOS) return;
      setState(() {
        _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        _handleHeartbeatMissed();
      }
    });
  }

  void _stopMonitoring() {
    _countdownTimer?.cancel();
    setState(() {
      _isMonitoring = false;
      _remainingSeconds = _selectedMinutes * 60;
    });
  }

  void _checkIn() {
    if (!_isMonitoring || _isTriggeringSOS) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _remainingSeconds = _selectedMinutes * 60;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Heartbeat received. Timer restarted.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleHeartbeatMissed() async {
    if (_isTriggeringSOS) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _isTriggeringSOS = true;
      _isMonitoring = false;
    });

    try {
      final auth = ref.read(authStateProvider).value;
      if (auth == null) return;

      final uid = auth.uid;
      final contacts =
          await FirestoreService.instance.getEmergencyContacts(uid);

      final activeSession = ref.read(activeSessionProvider).value;
      if (activeSession != null) {
        await ref
            .read(sessionControllerProvider.notifier)
            .triggerSOS(activeSession.sessionId);
      }

      final pos = await LocationService.instance.getCurrentPosition();
      GeoPoint? geo;
      if (pos != null) {
        geo = GeoPoint(pos.latitude, pos.longitude);
        final user = ref.read(currentUserProvider).value;
        await FirestoreService.instance.sendBroadcast(
          uid: uid,
          message:
              'SOS! Internal heartbeat missed. Immediate assistance needed.',
          alertType: 'need_help',
          location: geo,
          userName: user?.name,
        );
      }

      await _notifyContactsViaSms(contacts: contacts, location: geo);

      if (!mounted) return;
      setState(() => _sosTriggered = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No heartbeat detected. SOS has been triggered for your emergency flow.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SakhiTheme.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isTriggeringSOS = false);
      }
    }
  }

  Future<void> _notifyContactsViaSms({
    required List<EmergencyContact> contacts,
    GeoPoint? location,
  }) async {
    if (contacts.isEmpty) return;
    if (kIsWeb) return;

    final recipients = contacts
        .map((c) => c.phone.trim())
        .where((p) => p.isNotEmpty)
        .join(',');
    if (recipients.isEmpty) return;

    final locationText = location == null
        ? 'Location unavailable'
        : 'https://maps.google.com/?q=${location.latitude},${location.longitude}';
    final body = Uri.encodeComponent(
      'SAKHI SOS: Heartbeat missed. Please check on me immediately. '
      'My location: $locationText',
    );

    final smsUri = 'sms:$recipients?body=$body';
    await launchUrlString(smsUri);
  }

  Future<bool> _onBackPressed() async {
    if (!_isMonitoring) return true;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop Heartbeat Monitor?'),
        content: const Text(
          'Leaving now will stop the heartbeat timer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop & Exit'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      _stopMonitoring();
      return true;
    }
    return false;
  }

  String get _formattedTime {
    final secs = _remainingSeconds.clamp(0, 99999);
    final min = (secs ~/ 60).toString().padLeft(2, '0');
    final sec = (secs % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contactsAsync = ref.watch(emergencyContactsProvider);

    return PopScope(
      canPop: !_isMonitoring,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final allowed = await _onBackPressed();
        if (allowed && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Internal Heartbeat'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SakhiTheme.connected.withValues(alpha: 0.08),
                    border: Border.all(
                      color: SakhiTheme.connected.withValues(alpha: 0.25),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.favorite_rounded, color: SakhiTheme.connected),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap "I\'m Safe" before the timer expires. '
                          'If you miss a heartbeat, SOS is triggered automatically.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                contactsAsync.when(
                  data: (contacts) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: contacts.isEmpty
                          ? SakhiTheme.danger.withValues(alpha: 0.08)
                          : SakhiTheme.safe.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      contacts.isEmpty
                          ? 'No emergency contacts found. Add contacts first for best protection.'
                          : '${contacts.length} emergency contact${contacts.length == 1 ? '' : 's'} connected for SOS.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),
                Text(
                  'Heartbeat Interval',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _intervalOptionsMin.map((m) {
                    final selected = _selectedMinutes == m;
                    return ChoiceChip(
                      label: Text('$m min'),
                      selected: selected,
                      onSelected: _isMonitoring
                          ? null
                          : (_) => setState(() {
                                _selectedMinutes = m;
                                _remainingSeconds = m * 60;
                              }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Center(
                  child: _buildHeartbeatButton(theme),
                ),
                const SizedBox(height: 20),
                if (_isMonitoring) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isTriggeringSOS ? null : _stopMonitoring,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stop Heartbeat'),
                  ),
                ],
                if (_sosTriggered) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/home'),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Back to Home'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeartbeatButton(ThemeData theme) {
    final total = _selectedMinutes * 60;
    final progress = total == 0 ? 0.0 : (_remainingSeconds.clamp(0, total) / total);
    final accent = _sosTriggered
        ? SakhiTheme.danger
        : (_isMonitoring ? SakhiTheme.safe : SakhiTheme.primary);

    final label = _sosTriggered
        ? 'SOS Triggered'
        : _isMonitoring
            ? "Tap: I'm Safe"
            : 'Tap to Start';

    final onTap = _isTriggeringSOS || _sosTriggered
        ? null
        : (_isMonitoring ? _checkIn : _startMonitoring);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              accent.withValues(alpha: 0.92),
              accent.withValues(alpha: 0.76),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 28,
              spreadRadius: 3,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 232,
              height: 232,
              child: CircularProgressIndicator(
                value: _sosTriggered ? 1 : progress,
                strokeWidth: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.20),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_rounded,
                  size: 44,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  _formattedTime,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
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
