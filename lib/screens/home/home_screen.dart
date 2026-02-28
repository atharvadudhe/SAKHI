import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/session_model.dart';
import '../../models/location_share_alert_model.dart';
import '../../providers/providers.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/sakhi_brand_logo.dart';
import '../../models/broadcast_model.dart';
import '../../services/hardware_trigger_service.dart';
import '../../services/evidence_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;
  DateTime? _lastNotificationsSeenAt;
  String? _seenForUid;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    // Wire hardware-trigger SOS to the same SOS handler used by the button
    HardwareTriggerService.instance.onSOSTriggered = () {
      if (mounted) {
        _triggerSOS(sendBroadcast: false);
        _showHardwareSOSConfirmation();
      }
    };
  }

  @override
  void dispose() {
    _fadeController.dispose();
    HardwareTriggerService.instance.onSOSTriggered = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _mainBody());
  }

  String _notificationsSeenKey(String uid) => 'notifications_seen_at_$uid';

  Future<void> _loadNotificationsSeen(String uid) async {
    if (_seenForUid == uid) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notificationsSeenKey(uid));
    DateTime? seenAt;
    if (raw != null) {
      seenAt = DateTime.tryParse(raw);
    }
    if (!mounted) return;
    setState(() {
      _seenForUid = uid;
      _lastNotificationsSeenAt = seenAt;
    });
  }

  Future<void> _markNotificationsSeen(String uid) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notificationsSeenKey(uid), now.toIso8601String());
    if (!mounted) return;
    setState(() {
      _seenForUid = uid;
      _lastNotificationsSeenAt = now;
    });
  }

  Future<void> _openNotifications() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid != null) {
      await _markNotificationsSeen(uid);
    }
    if (!mounted) return;
    context.push('/notifications');
  }

  Future<void> _startSession() async {
    if (!mounted) return;
    context.push('/walking-buddy/search-destination');
  }

  String _formatCooldown(Duration d) {
    final total = d.inSeconds;
    final m = total ~/ 60;
    final s = total % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Future<void> _cancelActiveSos() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await FirestoreService.instance.cancelActiveSosBroadcast(uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS cancelled'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _triggerSOS({bool sendBroadcast = true}) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to use SOS'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (sendBroadcast) {
      final active = await FirestoreService.instance.getActiveSosBroadcastForUser(
        uid,
      );
      if (active != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS is already active. Hold ✕ to cancel it first.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final cooldown = await FirestoreService.instance.getSosCooldownRemaining(
        uid,
      );
      if (cooldown != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please wait ${_formatCooldown(cooldown)} before triggering SOS again.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    // 1. Trigger SOS on active session if exists
    final session = ref.read(activeSessionProvider).value;
    if (session != null) {
      ref
          .read(sessionControllerProvider.notifier)
          .triggerSOS(session.sessionId);

      // Start covert evidence recording — await and handle errors.
      try {
        final started = await EvidenceService.instance.startCovertRecording(
          session.sessionId,
        );
        if (!started && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Covert recording could not start. Check microphone permissions.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        debugPrint('Covert recording failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Covert recording failed to start.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    // 2. Also send an SOS broadcast to nearby volunteers
    bool broadcastSent = !sendBroadcast;
    try {
      if (sendBroadcast) {
        final position = await LocationService.instance.getCurrentPosition();
        if (position != null) {
          final user = ref.read(currentUserProvider).value;
          await FirestoreService.instance.sendBroadcast(
            uid: uid,
            message: 'SOS! Emergency help needed immediately!',
            alertType: 'need_help',
            location: GeoPoint(position.latitude, position.longitude),
            userName: user?.name,
          );
          broadcastSent = true;
        }
      }
    } catch (e) {
      final msg = e.toString();
      if (mounted && msg.contains('sos_already_active')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS is already active. Hold ✕ to cancel it first.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (mounted && msg.contains('sos_cooldown:')) {
        final raw = msg.split('sos_cooldown:').last;
        final sec = int.tryParse(raw) ?? 0;
        final d = Duration(seconds: sec.clamp(0, 3600));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please wait ${_formatCooldown(d)} before triggering SOS again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      debugPrint('SOS broadcast failed: $e');
    }

    if (!mounted) return;

    if (!broadcastSent && session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send SOS. Check your connection.'),
          backgroundColor: SakhiTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show SOS confirmation
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
        title: const Text('SOS Activated'),
        content: Text(
          session != null
              ? 'Emergency alert has been sent to your contacts and nearby volunteers.'
              : 'Emergency broadcast sent to nearby volunteers.',
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

  // ── Hardware SOS confirmation (triggered from volume buttons) ──

  void _showHardwareSOSConfirmation() {
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
        title: const Text('Hardware SOS Activated'),
        content: const Text(
          'Rapid volume-button presses detected.\n'
          'An emergency broadcast has been sent to nearby volunteers '
          'and your live location is being shared.',
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

  // ── Fake Call Bottom Sheet ──

  void _showFakeCallBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Schedule Fake Call',
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose a delay — the fake incoming call will appear after '
                  'the selected time.',
                  style: TextStyle(
                    color: Theme.of(
                      ctx,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                _FakeCallDelayTile(
                  label: '5 seconds',
                  icon: Icons.timer_rounded,
                  onTap: () {
                    Navigator.pop(ctx);
                    _scheduleFakeCall(const Duration(seconds: 5));
                  },
                ),
                _FakeCallDelayTile(
                  label: '15 seconds',
                  icon: Icons.timer_rounded,
                  onTap: () {
                    Navigator.pop(ctx);
                    _scheduleFakeCall(const Duration(seconds: 15));
                  },
                ),
                _FakeCallDelayTile(
                  label: '1 minute',
                  icon: Icons.timer_rounded,
                  onTap: () {
                    Navigator.pop(ctx);
                    _scheduleFakeCall(const Duration(minutes: 1));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scheduleFakeCall(Duration delay) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Fake call scheduled in ${delay.inSeconds >= 60 ? '${delay.inMinutes} minute' : '${delay.inSeconds} seconds'}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Future.delayed(delay, () {
      if (!mounted) return;
      context.push(
        '/fake-call',
        extra: {'callerName': 'Mom', 'callerLabel': 'Mobile'},
      );
    });
  }

  Widget _mainBody() {
    final sessionAsync = ref.watch(activeSessionProvider);
    final broadcastsAsync = ref.watch(broadcastsFeedProvider);
    final activeSharesAsync = ref.watch(activeLocationSharesProvider);
    final heartbeatStateAsync = ref.watch(internalHeartbeatStateProvider);
    final activeSosAsync = ref.watch(activeSosBroadcastProvider);
    final incomingLocationAlertsAsync = ref.watch(
      incomingLocationShareAlertsProvider,
    );
    final currentUid = ref.watch(authStateProvider).value?.uid;
    if (currentUid != null && _seenForUid != currentUid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadNotificationsSeen(currentUid);
      });
    }
    final activeSos = activeSosAsync.value;
    final heartbeatState = heartbeatStateAsync.value;
    final hasActiveHeartbeat =
        heartbeatState != null &&
        heartbeatState.isMonitoring &&
        heartbeatState.expiresAt != null &&
        DateTime.now().isBefore(heartbeatState.expiresAt!);
    final heartbeatExpiresAt =
        hasActiveHeartbeat ? heartbeatState.expiresAt : null;
    final activeShare = activeSharesAsync.value?.isNotEmpty == true
        ? activeSharesAsync.value!.first
        : null;
    final shareId = activeShare?['id'] as String?;
    final expiresRaw = activeShare?['expiresAt'];
    final shareExpiresAt = expiresRaw is Timestamp
        ? expiresRaw.toDate()
        : (expiresRaw as DateTime?);
    final resolvedShareExpiresAt = shareExpiresAt ?? DateTime.now();
    final hasActiveShare = shareId != null &&
        shareExpiresAt != null &&
        !((activeShare?['isActive'] as bool?) == false) &&
        DateTime.now().isBefore(shareExpiresAt);
    final latestMySos = (broadcastsAsync.value ?? const <BroadcastModel>[])
        .where((b) => b.uid == (currentUid ?? '') && b.alertType == 'need_help')
        .fold<BroadcastModel?>(null, (prev, b) {
      if (prev == null) return b;
      final prevTs = prev.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final curTs = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return curTs.isAfter(prevTs) ? b : prev;
    });
    final cooldownRemaining = () {
      if (latestMySos?.timestamp == null) return null;
      final elapsed = DateTime.now().difference(latestMySos!.timestamp!);
      const max = Duration(minutes: 1);
      if (elapsed >= max) return null;
      return max - elapsed;
    }();
    final cooldownUntil = cooldownRemaining == null
        ? null
        : DateTime.now().add(cooldownRemaining);
    final activeIncomingLocationCount =
        (incomingLocationAlertsAsync.value ?? const <LocationShareAlertModel>[])
            .where((a) => a.isActive && !a.isExpired)
            .where((a) {
              final seen = _lastNotificationsSeenAt;
              final createdAt = a.createdAt;
              if (seen == null || createdAt == null) return true;
              return createdAt.isAfter(seen);
            })
            .length;
    final pendingBroadcastCount =
        (broadcastsAsync.value ?? const <BroadcastModel>[])
            .where((b) => b.alertType != 'need_help' || b.isActive)
            .where((b) {
              final seen = _lastNotificationsSeenAt;
              final ts = b.timestamp;
              if (seen == null || ts == null) return true;
              return ts.isAfter(seen);
            })
            .length;
    final notificationCount = activeIncomingLocationCount + pendingBroadcastCount;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SafeArea(
        child: Stack(
          children: [
            // Main content
            CustomScrollView(
              slivers: [
                // ── App Bar ──
                SliverAppBar(
                  floating: true,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  surfaceTintColor: Colors.transparent,
                  title: Row(
                    children: [
                      const SakhiBrandLogo(size: 40, framed: false),
                      const SizedBox(width: 10),
                      const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          fontSize: 20,
                          color: SakhiTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_outlined),
                          if (notificationCount > 0)
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: SakhiTheme.danger,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  notificationCount > 99
                                      ? '99+'
                                      : '$notificationCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      onPressed: _openNotifications,
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_outline_rounded),
                      onPressed: () {
                        context.push('/profile');
                      },
                    ),
                  ],
                ),

                // ── Body ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Primary Action ──
                      _PrimaryCTA(
                        session: sessionAsync.value,
                        onStart: _startSession,
                        onViewSession: () => context.push('/session'),
                      ),
                      const SizedBox(height: 12),
                      incomingLocationAlertsAsync.when(
                        data: (alerts) {
                          final activeAlerts = alerts
                              .where((a) => a.isActive && !a.isExpired)
                              .toList();
                          if (activeAlerts.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return _IncomingLocationAlerts(alerts: activeAlerts);
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 10),
                      broadcastsAsync.when(
                        data: (broadcasts) {
                          final sosAlerts = broadcasts
                              .where(
                                (b) =>
                                    b.alertType == 'need_help' &&
                                    b.isActive &&
                                    b.uid != (currentUid ?? ''),
                              )
                              .take(3)
                              .toList();
                          if (sosAlerts.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return _IncomingSosAlerts(alerts: sosAlerts);
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),

                      // ── Quick Actions Grid ──
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _QuickActionCard(
                            icon: Icons.location_on_rounded,
                            title: 'Share Location',
                            subtitle: 'Time-bound sharing',
                            color: SakhiTheme.connected,
                            onTap: () => context.push('/location-sharing'),
                          ),
                          _QuickActionCard(
                            icon: Icons.campaign_rounded,
                            title: 'Community Alert',
                            subtitle: 'Broadcast nearby',
                            color: SakhiTheme.searching,
                            onTap: () => context.push('/broadcast'),
                          ),
                          _QuickActionCard(
                            icon: Icons.volunteer_activism_rounded,
                            title: 'Volunteer Mode',
                            subtitle: 'Help others',
                            color: SakhiTheme.safe,
                            onTap: () => context.push('/volunteer'),
                          ),
                          _QuickActionCard(
                            icon: Icons.contacts_rounded,
                            title: 'Emergency\nContacts',
                            subtitle: 'Manage contacts',
                            color: SakhiTheme.danger,
                            onTap: () => context.push('/emergency-contacts'),
                          ),
                          _QuickActionCard(
                            icon: Icons.phone_callback_rounded,
                            title: 'Fake Call',
                            subtitle: 'De-escalation tool',
                            color: SakhiTheme.primaryDark,
                            onTap: _showFakeCallBottomSheet,
                          ),
                          _QuickActionCard(
                            icon: Icons.directions_walk_rounded,
                            title: 'Walk With Me',
                            subtitle: 'Virtual companion',
                            color: SakhiTheme.connected,
                            onTap: () =>
                                context.push('/virtual-companion-setup'),
                          ),
                          _QuickActionCard(
                            icon: Icons.favorite_rounded,
                            title: 'Internal\nHeartbeat',
                            subtitle: 'Timed check-ins',
                            color: Colors.pink.shade600,
                            onTap: () => context.push('/internal-heartbeat'),
                          ),
                          _QuickActionCard(
                            icon: Icons.masks_rounded,
                            title: 'Camouflage\nMode',
                            subtitle: 'Disguise app icon',
                            color: const Color(0xFF7B1FA2),
                            onTap: () => context.push('/camouflage'),
                          ),
                        ],
                      ),
                    ]),
                  ),
                ),
              ],
            ),

            // ── Floating SOS Button ──
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 84,
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: hasActiveShare
                            ? _LiveShareFloatingButton(
                                expiresAt: resolvedShareExpiresAt,
                                onTap: () => context.push('/location-sharing'),
                              )
                            : const SizedBox(width: 72, height: 72),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SOSButton(
                          onTriggered: () => _triggerSOS(),
                          onCancelTriggered: _cancelActiveSos,
                          isActive: activeSos != null,
                          cooldownUntil: cooldownUntil,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: hasActiveHeartbeat
                            ? _InternalHeartbeatFloatingButton(
                                expiresAt: heartbeatExpiresAt!,
                                onTap: () => context.push('/internal-heartbeat'),
                              )
                            : const SizedBox(width: 72, height: 72),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Primary Call-to-Action ──
class _PrimaryCTA extends StatelessWidget {
  final SessionModel? session;
  final VoidCallback onStart;
  final VoidCallback onViewSession;

  const _PrimaryCTA({
    this.session,
    required this.onStart,
    required this.onViewSession,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveSession =
        session != null && (session!.isActive || session!.isSearching);

    return Material(
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      shadowColor: SakhiTheme.primary.withValues(alpha: 0.3),
      child: InkWell(
        onTap: hasActiveSession ? onViewSession : onStart,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: hasActiveSession
                  ? [
                      SakhiTheme.connected,
                      SakhiTheme.connected.withValues(alpha: 0.8),
                    ]
                  : [SakhiTheme.primary, SakhiTheme.primaryDark],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                child: Icon(
                  hasActiveSession
                      ? Icons.visibility_rounded
                      : Icons.shield_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasActiveSession
                          ? 'View Active Session'
                          : 'Start Safety Session',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasActiveSession
                          ? 'Tap to see your active monitoring'
                          : 'Get a volunteer buddy for your journey',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quick Action Card ──
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).cardTheme.color ?? Colors.white,
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: color.withValues(alpha: 0.1),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color:
                        Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: 0.8) ??
                        Colors.black54,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncomingLocationAlerts extends StatelessWidget {
  final List<LocationShareAlertModel> alerts;

  const _IncomingLocationAlerts({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: SakhiTheme.connected.withValues(alpha: 0.08),
        border: Border.all(
          color: SakhiTheme.connected.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.share_location_rounded,
                color: SakhiTheme.connected,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Live Location Alerts',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...alerts.take(3).map((alert) => _IncomingAlertCard(alert: alert)),
        ],
      ),
    );
  }
}

class _IncomingAlertCard extends StatelessWidget {
  final LocationShareAlertModel alert;

  const _IncomingAlertCard({required this.alert});

  Future<void> _call(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (normalized.isEmpty) return;
    await launchUrlString('tel:$normalized');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${alert.senderName} shared live location',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push(
                        '/location-sharing/view',
                        extra: {
                          'shareId': alert.shareId,
                          'senderName': alert.senderName,
                          'senderPhone': alert.senderPhone,
                        },
                      );
                    },
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('View'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _call(alert.senderPhone),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SakhiTheme.danger,
                      foregroundColor: Colors.white,
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

class _IncomingSosAlerts extends StatelessWidget {
  final List<BroadcastModel> alerts;

  const _IncomingSosAlerts({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: SakhiTheme.danger.withValues(alpha: 0.08),
        border: Border.all(color: SakhiTheme.danger.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: SakhiTheme.danger,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'SOS Alerts',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...alerts.map((alert) => _IncomingSosAlertCard(alert: alert)),
        ],
      ),
    );
  }
}

class _IncomingSosAlertCard extends StatelessWidget {
  final BroadcastModel alert;

  const _IncomingSosAlertCard({required this.alert});

  Future<void> _callSender(BuildContext context) async {
    final sender = await FirestoreService.instance.getUser(alert.uid);
    final phone = (sender?.phone ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find sender phone number'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    await launchUrlString('tel:$phone');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${alert.userName ?? 'User'} sent an SOS alert',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push(
                        '/broadcast/sos-view',
                        extra: {
                          'senderUid': alert.uid,
                          'senderName': alert.userName ?? 'User',
                          'lat': alert.location.latitude,
                          'lng': alert.location.longitude,
                        },
                      );
                    },
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('View'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _callSender(context),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SakhiTheme.danger,
                      foregroundColor: Colors.white,
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

// ── Fake-call delay option tile ──
class _FakeCallDelayTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _FakeCallDelayTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: SakhiTheme.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

class _LiveShareFloatingButton extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback onTap;

  const _LiveShareFloatingButton({
    required this.expiresAt,
    required this.onTap,
  });

  @override
  State<_LiveShareFloatingButton> createState() => _LiveShareFloatingButtonState();
}

class _LiveShareFloatingButtonState extends State<_LiveShareFloatingButton> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.expiresAt.difference(DateTime.now());
    final sec = remaining.inSeconds.clamp(0, 3599);
    final mm = (sec ~/ 60).toString().padLeft(2, '0');
    final ss = (sec % 60).toString().padLeft(2, '0');

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE7F8F5),
          border: Border.all(
            color: SakhiTheme.connected.withValues(alpha: 0.65),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: SakhiTheme.connected.withValues(alpha: 0.20),
              blurRadius: 10,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_on_rounded,
              color: SakhiTheme.connected,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              '$mm:$ss',
              style: const TextStyle(
                color: SakhiTheme.connected,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InternalHeartbeatFloatingButton extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback onTap;

  const _InternalHeartbeatFloatingButton({
    required this.expiresAt,
    required this.onTap,
  });

  @override
  State<_InternalHeartbeatFloatingButton> createState() =>
      _InternalHeartbeatFloatingButtonState();
}

class _InternalHeartbeatFloatingButtonState
    extends State<_InternalHeartbeatFloatingButton> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.expiresAt.difference(DateTime.now());
    final sec = remaining.inSeconds.clamp(0, 3599);
    final mm = (sec ~/ 60).toString().padLeft(2, '0');
    final ss = (sec % 60).toString().padLeft(2, '0');

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFEEF0),
          border: Border.all(
            color: SakhiTheme.danger.withValues(alpha: 0.45),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: SakhiTheme.danger.withValues(alpha: 0.15),
              blurRadius: 10,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_rounded, color: SakhiTheme.danger, size: 24),
            const SizedBox(height: 2),
            Text(
              '$mm:$ss',
              style: const TextStyle(
                color: SakhiTheme.danger,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
