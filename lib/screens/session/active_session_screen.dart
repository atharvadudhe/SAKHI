import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/theme.dart';
import '../../models/session_model.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../../services/firestore_service.dart';
import '../../widgets/sos_button.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  GoogleMapController? _mapController;
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    // Refresh timer for countdown display
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _endSession(String sessionId) {
    final userAsync = ref.read(currentUserProvider);

    // If user data is still loading, disable the action.
    if (userAsync.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading user data… please wait.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (userAsync.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load user data. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = userAsync.value;

    // If user has duress PINs configured, show PIN dialog instead.
    if (user != null && user.hasDuressPinSetup) {
      _showPinCancellationSheet(sessionId, user);
      return;
    }

    // Fallback: simple confirmation dialog (no PINs set).
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Session?'),
        content: const Text(
          'Are you sure you want to end this safety session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(sessionControllerProvider.notifier)
                  .endSession(sessionId);
              context.go('/home');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SakhiTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }

  /// Shows a PIN-entry bottom sheet for duress-aware session cancellation.
  void _showPinCancellationSheet(String sessionId, UserModel user) {
    final pinController = TextEditingController();
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 40,
                    color: SakhiTheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter PIN to cancel SOS',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter your cancellation PIN to end the session.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      errorText: errorText,
                      hintText: '• • • •',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final pin = pinController.text.trim();
                        if (pin.length != 4) {
                          setSheetState(
                            () => errorText = 'Enter a 4-digit PIN',
                          );
                          return;
                        }

                        if (pin == user.safePin) {
                          // ── SAFE PIN: genuinely cancel ──
                          Navigator.pop(ctx);
                          ref
                              .read(sessionControllerProvider.notifier)
                              .endSession(sessionId);
                          context.go('/home');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Session ended safely.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } else if (pin == user.duressPin) {
                          // ── DURESS PIN: fake-cancel ──
                          // Do NOT end the session. Escalate silently.
                          _handleDuressCancellation(sessionId, user.uid);
                          Navigator.pop(ctx);
                          context.go('/home');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Session cancelled.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } else {
                          setSheetState(() => errorText = 'Incorrect PIN');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SakhiTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Silently escalate: mark broadcasts as duress-active and trigger SOS
  /// on the session—but do NOT end it.
  Future<void> _handleDuressCancellation(
    String sessionId,
    String uid,
  ) async {
    try {
      // Escalate session to SOS if not already.
      await FirestoreService.instance.triggerSOS(sessionId);
      // Mark associated broadcasts as duress-active.
      await FirestoreService.instance.activateDuressOnBroadcasts(uid);
    } catch (_) {
      // Silent — the attacker must not see any failure UI.
    }
  }

  void _triggerSOS(String sessionId) {
    ref.read(sessionControllerProvider.notifier).triggerSOS(sessionId);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.warning_rounded,
          color: SakhiTheme.danger,
          size: 48,
        ),
        title: const Text('SOS Activated!'),
        content: const Text(
          'Emergency alert sent to your contacts and nearby volunteers. Help is on the way.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeSessionProvider);

    return Scaffold(
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 64,
                  color: SakhiTheme.danger.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Could not load session',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString().contains('failed-precondition')
                      ? 'The database is still setting up. '
                        'Please wait a minute and try again.'
                      : 'Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Go Home'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(activeSessionProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SakhiTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        data: (session) {
          if (session == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: SakhiTheme.safe,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No active session',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return _buildSessionView(session);
        },
      ),
    );
  }

  Widget _buildSessionView(SessionModel session) {
    final remainingMins = session.remaining.inMinutes;
    final remainingSecs = session.remaining.inSeconds % 60;
    final statusColor = switch (session.status) {
      SessionStatus.searching => SakhiTheme.searching,
      SessionStatus.active => SakhiTheme.safe,
      SessionStatus.sosTriggered => SakhiTheme.danger,
      SessionStatus.ended => Colors.grey,
    };

    return Stack(
      children: [
        // ── Map ──
        _buildMap(session),

        // ── Top info bar ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 12,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety Session',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        session.status == SessionStatus.searching
                            ? 'Looking for a volunteer...'
                            : session.volunteerName != null
                            ? 'Buddy: ${session.volunteerName}'
                            : 'Monitoring active',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        session.status == SessionStatus.searching
                            ? Icons.search
                            : session.status == SessionStatus.active
                            ? Icons.check_circle
                            : Icons.warning,
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        session.status.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Bottom panel ──
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Timer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_outlined, size: 20, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      '${remainingMins}m ${remainingSecs}s remaining',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Session info chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _InfoChip(
                      icon: Icons.access_time,
                      label: '${session.elapsed.inMinutes}m elapsed',
                    ),
                    const SizedBox(width: 12),
                    _InfoChip(
                      icon: Icons.update,
                      label: '${session.timeLimit}m total',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _endSession(session.sessionId),
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('End Session'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: SOSButton(
                        size: 56,
                        onTriggered: () => _triggerSOS(session.sessionId),
                        onCancelTriggered: () {},
                        isActive: false,
                        cooldownUntil: null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMap(SessionModel session) {
    // Use Google Maps if location available, else show placeholder
    final loc = session.userLocation;
    if (loc == null) {
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Acquiring location...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(loc.latitude, loc.longitude),
        zoom: 16,
      ),
      onMapCreated: (controller) => _mapController = controller,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: {
        Marker(
          markerId: const MarkerId('user'),
          position: LatLng(loc.latitude, loc.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        ),
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
