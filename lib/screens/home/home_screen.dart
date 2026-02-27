import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/session_model.dart';
import '../../providers/providers.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/sos_button.dart';
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

  // ── Rotating Safety Tips ──
  static const _safetyTips = [
    'Start a safety session before travelling alone at night. A volunteer buddy can monitor your journey.',
    'Share your live location with trusted contacts when heading to an unfamiliar area.',
    'Save at least 3 emergency contacts so SOS alerts reach the right people instantly.',
    'Keep your phone charged above 20% when going out — your safety tools depend on it.',
    'Trust your instincts. If a place feels unsafe, broadcast a community alert to warn others.',
    'Walk in well-lit, populated areas whenever possible and stay aware of your surroundings.',
    'Use the volunteer mode to help others — safety is a community effort!',
    'Review your emergency contacts regularly to keep numbers up to date.',
  ];
  int _tipIndex = 0;
  late final Timer _tipTimer;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    // Rotate safety tip every 10 seconds
    _tipTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() => _tipIndex = (_tipIndex + 1) % _safetyTips.length);
      }
    });

    // Wire hardware-trigger SOS to the same SOS handler used by the button
    HardwareTriggerService.instance.onSOSTriggered = () {
      if (mounted) {
        _triggerSOS();
        _showHardwareSOSConfirmation();
      }
    };
  }

  @override
  void dispose() {
    _tipTimer.cancel();
    _fadeController.dispose();
    HardwareTriggerService.instance.onSOSTriggered = null;
    super.dispose();
  }

  Future<void> _startSession() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to start a session'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final controller = ref.read(sessionControllerProvider.notifier);
    final session = await controller.startSession();
    if (session != null && mounted) {
      context.push('/session');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start session. Check location permissions.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _triggerSOS() async {
    final position = await LocationService.instance.getCurrentPosition();
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
    final uid = ref.read(authStateProvider).value?.uid;
    bool broadcastSent = false;
    if (uid != null) {
      try {
        if (position != null) {
          final user = ref.read(currentUserProvider).value;
          await FirestoreService.instance.sendBroadcast(
            uid: uid,
            message: 'SOS! Emergency help needed immediately!',
            alertType: 'need_help',
            location: GeoPoint(position.latitude, position.longitude),
            userName: user?.name,
            phoneNumber: user?.phone,
          );
          broadcastSent = true;
        }
      } catch (e) {
        debugPrint('SOS broadcast failed: $e');
      }
    } else if (mounted) {
      // Not logged in - can't send SOS
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to use SOS'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
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

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final sessionAsync = ref.watch(activeSessionProvider);
    final broadcastsAsync = ref.watch(broadcastsFeedProvider);

    return Scaffold(
      body: FadeTransition(
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: SakhiTheme.primary.withValues(alpha: 0.1),
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            color: SakhiTheme.primary,
                            size: 20,
                          ),
                        ),
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
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () => context.push('/notifications'),
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── Primary Action (repurposed to open Walking Buddy) ──
                        _PrimaryCTA(
                          session: sessionAsync.value,
                          onStart: () =>
                              context.push('/walking-buddy/search-destination'),
                          onViewSession: () =>
                              context.push('/walking-buddy/search-destination'),
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
                              icon: Icons.masks_rounded,
                              title: 'Camouflage\nMode',
                              subtitle: 'Disguise app icon',
                              color: const Color(0xFF7B1FA2),
                              onTap: () => context.push('/camouflage'),
                            ),
                            // Walking Buddy moved to primary CTA above; removed duplicate here.
                          ],
                        ),
                        const SizedBox(height: 28),

                        // ── Nearby Alert Feed ──
                        Text(
                          'Nearby Alerts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        broadcastsAsync.when(
                          data: (broadcasts) {
                            if (broadcasts.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            // Show latest 3 alerts
                            // Separate SOS and normal alerts
                            final sosAlerts = broadcasts
                                .where((b) => b.alertType == 'need_help')
                                .toList();

                            final normalAlerts = broadcasts
                                .where((b) => b.alertType != 'need_help')
                                .toList();

                            // Sort SOS by latest first
                            sosAlerts.sort(
                              (a, b) => (b.timestamp ?? DateTime.now())
                                  .compareTo(a.timestamp ?? DateTime.now()),
                            );

                            // Combine → SOS first, then others
                            final ordered = [...sosAlerts, ...normalAlerts];

                            // Show top 5
                            final visible = ordered.take(5).toList();

                            return Column(
                              children: visible
                                  .map((b) => _AlertFeedCard(broadcast: b))
                                  .toList(),
                            );
                          },
                          loading: () => const SizedBox(
                            height: 48,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          error: (_, _) => const SizedBox.shrink(),
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
                child: Center(child: SOSButton(onTriggered: _triggerSOS)),
              ),
            ],
          ),
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

// ── Alert Feed Card ──
class _AlertFeedCard extends StatelessWidget {
  final BroadcastModel broadcast;

  const _AlertFeedCard({required this.broadcast});

  Color get _alertColor {
    switch (broadcast.alertType) {
      case 'need_help':
        return SakhiTheme.danger;
      case 'suspicious_activity':
        return SakhiTheme.searching;
      case 'road_issue':
        return SakhiTheme.connected;
      default:
        return SakhiTheme.searching;
    }
  }

  IconData get _alertIcon {
    switch (broadcast.alertType) {
      case 'need_help':
        return Icons.warning_rounded;
      case 'suspicious_activity':
        return Icons.visibility_rounded;
      case 'road_issue':
        return Icons.report_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri.parse('tel:$number');
    await launchUrl(uri);
  }

  Future<void> _openGoogleMaps(GeoPoint location) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${location.latitude},${location.longitude}',
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isSOS = broadcast.alertType == 'need_help';
    final isRecentSOS =
        isSOS &&
        broadcast.timestamp != null &&
        DateTime.now().difference(broadcast.timestamp!).inMinutes < 5;
    final phone = broadcast.phoneNumber;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color:
              Theme.of(context).cardTheme.color ??
              Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: isRecentSOS
                ? SakhiTheme.danger
                : _alertColor.withValues(alpha: 0.2),
            width: isRecentSOS ? 2 : 1,
          ),
          boxShadow: isRecentSOS
              ? [
                  BoxShadow(
                    color: SakhiTheme.danger.withValues(alpha: 0.35),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _alertColor.withValues(alpha: 0.1),
                  ),
                  child: Icon(_alertIcon, color: _alertColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        broadcast.alertLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: _alertColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        broadcast.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  broadcast.timeAgo,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),

            // 🔥 Show action buttons ONLY for SOS
            if (isSOS) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (phone != null && phone.isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _callNumber(phone),
                        icon: const Icon(Icons.call),
                        label: const Text('Call'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _alertColor,
                        ),
                      ),
                    ),
                  if (phone != null && phone.isNotEmpty)
                    const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openGoogleMaps(broadcast.location),
                      icon: const Icon(Icons.navigation),
                      label: const Text('Directions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _alertColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
