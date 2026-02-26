import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

/// Active countdown screen for the Virtual Companion / "Walk With Me" feature.
///
/// Shows a live countdown. The user can press "I've Arrived Safely" to end the
/// session, or if the timer reaches 00:00, an automatic SOS is triggered —
/// pinging emergency contacts, creating a broadcast and pushing live location.
class ActiveCompanionScreen extends ConsumerStatefulWidget {
  final String destination;
  final int durationMinutes;

  const ActiveCompanionScreen({
    super.key,
    required this.destination,
    required this.durationMinutes,
  });

  @override
  ConsumerState<ActiveCompanionScreen> createState() =>
      _ActiveCompanionScreenState();
}

class _ActiveCompanionScreenState extends ConsumerState<ActiveCompanionScreen> {
  late int _remainingSeconds;
  Timer? _countdownTimer;
  bool _arrivedSafely = false;
  bool _sosTriggered = false;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.durationMinutes * 60;
    _initSession();
  }

  // ── Session initialisation ──

  Future<void> _initSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Acquire current location
      final position = await LocationService.instance.getCurrentPosition();
      GeoPoint? currentLocation;
      if (position != null) {
        currentLocation = GeoPoint(position.latitude, position.longitude);
      }

      // Create session via the shared Firestore helper
      final session = await FirestoreService.instance.createSession(
        userId: user.uid,
        timeLimitMinutes: widget.durationMinutes,
        currentLocation: currentLocation,
      );
      _sessionId = session.sessionId;

      // Persist virtual-companion metadata on the session document
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(session.sessionId)
          .update({
        'isVirtualCompanionActive': true,
        'estimatedArrivalTime': Timestamp.fromDate(
          DateTime.now().add(Duration(minutes: widget.durationMinutes)),
        ),
        'destinationName': widget.destination,
      });

      // Begin location tracking for the session
      LocationService.instance.startLocationUpdates(
        onUpdate: (pos) {
          final geoPoint = GeoPoint(pos.latitude, pos.longitude);
          FirestoreService.instance.updateSessionLocation(
            session.sessionId,
            geoPoint,
          );
          FirestoreService.instance.writeLocationUpdate(
            sessionId: session.sessionId,
            uid: user.uid,
            geoPoint: geoPoint,
          );
        },
      );
    } catch (e) {
      debugPrint('Failed to create companion session: $e');
    }

    // Start the visible countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        _autoTriggerSOS();
      }
    });
  }

  // ── User-driven safe arrival ──

  Future<void> _markArrived() async {
    _countdownTimer?.cancel();
    LocationService.instance.stopLocationUpdates();
    HapticFeedback.mediumImpact();
    setState(() => _arrivedSafely = true);

    if (_sessionId != null) {
      try {
        await FirestoreService.instance.endSession(_sessionId!);
      } catch (e) {
        debugPrint('Failed to end companion session: $e');
      }
    }
  }

  // ── Automatic (or manual) SOS ──

  Future<void> _autoTriggerSOS() async {
    if (_arrivedSafely || _sosTriggered) return;
    HapticFeedback.heavyImpact();
    setState(() => _sosTriggered = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Mark the session as SOS-triggered
      if (_sessionId != null) {
        await FirestoreService.instance.triggerSOS(_sessionId!);
      }

      // 2. Send an SOS broadcast to nearby volunteers
      final position = await LocationService.instance.getCurrentPosition();
      if (position != null) {
        final geoPoint = GeoPoint(position.latitude, position.longitude);
        final userModel = ref.read(currentUserProvider).value;
        await FirestoreService.instance.sendBroadcast(
          uid: user.uid,
          message:
              'SOS! Virtual companion timer expired. '
              'Heading to: ${widget.destination}. Immediate help needed!',
          alertType: 'need_help',
          location: geoPoint,
          userName: userModel?.name,
        );
      }

      debugPrint('[VirtualCompanion] Auto-SOS triggered');
    } catch (e) {
      debugPrint('[VirtualCompanion] Failed to trigger SOS: $e');
    }
  }

  // ── Helpers ──

  String get _formattedTime {
    final absSeconds = _remainingSeconds.abs().clamp(0, 99999);
    final min = (absSeconds ~/ 60).toString().padLeft(2, '0');
    final sec = (absSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  double get _progress {
    final total = widget.durationMinutes * 60;
    return (_remainingSeconds.clamp(0, total)) / total;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Dynamic colours based on session state
    Color timerColor;
    String statusText;
    IconData statusIcon;

    if (_arrivedSafely) {
      timerColor = SakhiTheme.safe;
      statusText = 'You arrived safely!';
      statusIcon = Icons.check_circle_rounded;
    } else if (_sosTriggered) {
      timerColor = SakhiTheme.danger;
      statusText = 'SOS has been sent!';
      statusIcon = Icons.warning_rounded;
    } else if (_remainingSeconds <= 60) {
      timerColor = SakhiTheme.danger;
      statusText = 'Almost out of time!';
      statusIcon = Icons.timer_off_rounded;
    } else if (_remainingSeconds <= widget.durationMinutes * 60 * 0.25) {
      timerColor = SakhiTheme.searching;
      statusText = 'Hurry up!';
      statusIcon = Icons.timer_rounded;
    } else {
      timerColor = SakhiTheme.connected;
      statusText = 'Walking to ${widget.destination}';
      statusIcon = Icons.directions_walk_rounded;
    }

    return PopScope(
      canPop: _arrivedSafely || _sosTriggered,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Press "I\'ve Arrived Safely" to end the session',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Walk With Me'),
          automaticallyImplyLeading: _arrivedSafely || _sosTriggered,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),

                // Status icon + label
                Icon(statusIcon, size: 48, color: timerColor),
                const SizedBox(height: 12),
                Text(
                  statusText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: timerColor,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Countdown ring ──
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CircularProgressIndicator(
                          value: _arrivedSafely ? 1.0 : _progress,
                          strokeWidth: 10,
                          backgroundColor:
                              timerColor.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(timerColor),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _arrivedSafely ? '✓' : _formattedTime,
                            style: TextStyle(
                              fontSize: _arrivedSafely ? 64 : 48,
                              fontWeight: FontWeight.bold,
                              color: timerColor,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          if (!_arrivedSafely && !_sosTriggered)
                            Text(
                              'remaining',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Destination chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place_rounded, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.destination,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Action buttons ──
                if (!_arrivedSafely && !_sosTriggered) ...[
                  ElevatedButton.icon(
                    onPressed: _markArrived,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text("I've Arrived Safely"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SakhiTheme.safe,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _autoTriggerSOS,
                    icon: const Icon(Icons.sos_rounded),
                    label: const Text('Trigger SOS Now'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SakhiTheme.danger,
                      side: const BorderSide(color: SakhiTheme.danger),
                    ),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Home'),
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
