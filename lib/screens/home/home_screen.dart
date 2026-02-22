import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/session_model.dart';
import '../../providers/providers.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/session_status_card.dart';

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
  }

  @override
  void dispose() {
    _tipTimer.cancel();
    _fadeController.dispose();
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
    // 1. Trigger SOS on active session if exists
    final session = ref.read(activeSessionProvider).value;
    if (session != null) {
      ref
          .read(sessionControllerProvider.notifier)
          .triggerSOS(session.sessionId);
    }

    // 2. Also send an SOS broadcast to nearby volunteers
    final uid = ref.read(authStateProvider).value?.uid;
    bool broadcastSent = false;
    if (uid != null) {
      try {
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

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final sessionAsync = ref.watch(activeSessionProvider);

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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Greeting
                        userAsync.when(
                          data: (user) => Text(
                            'Hi, ${user?.name ?? 'there'}! 👋',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          loading: () => const SizedBox(height: 28),
                          error: (_, _) => Text(
                            'Hi there! 👋',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stay safe, we\'re always with you.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Status Card ──
                        sessionAsync.when(
                          data: (session) =>
                              SessionStatusCard(session: session),
                          loading: () => const SessionStatusCard(),
                          error: (_, _) => const SessionStatusCard(),
                        ),
                        const SizedBox(height: 28),

                        // ── Primary Action ──
                        _PrimaryCTA(
                          session: sessionAsync.value,
                          onStart: _startSession,
                          onViewSession: () => context.push('/session'),
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
                          ],
                        ),
                        const SizedBox(height: 28),

                        // ── Safety Tips ──
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                SakhiTheme.primary.withValues(alpha: 0.05),
                                SakhiTheme.primary.withValues(alpha: 0.02),
                              ],
                            ),
                            border: Border.all(
                              color: SakhiTheme.primary.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                color: SakhiTheme.primary.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Safety Tip',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      child: Text(
                                        _safetyTips[_tipIndex],
                                        key: ValueKey<int>(_tipIndex),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
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
            ],
          ),
        ),
      ),
    );
  }
}
