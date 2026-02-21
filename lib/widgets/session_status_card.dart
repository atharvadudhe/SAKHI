import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../config/theme.dart';

class SessionStatusCard extends StatelessWidget {
  final SessionModel? session;

  const SessionStatusCard({super.key, this.session});

  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return _buildSafeCard(context);
    }

    return switch (session!.status) {
      SessionStatus.searching => _buildSearchingCard(context),
      SessionStatus.active => _buildActiveCard(context),
      SessionStatus.sosTriggered => _buildSOSCard(context),
      SessionStatus.ended => _buildSafeCard(context),
    };
  }

  Widget _buildSafeCard(BuildContext context) {
    return _StatusCard(
      color: SakhiTheme.safe,
      icon: Icons.check_circle_rounded,
      title: 'You are Safe',
      subtitle: 'No active safety sessions',
    );
  }

  Widget _buildSearchingCard(BuildContext context) {
    return _StatusCard(
      color: SakhiTheme.searching,
      icon: Icons.search_rounded,
      title: 'Searching...',
      subtitle: 'Looking for a nearby volunteer buddy',
      showProgress: true,
    );
  }

  Widget _buildActiveCard(BuildContext context) {
    final remaining = session!.remaining;
    final mins = remaining.inMinutes;
    final secs = remaining.inSeconds % 60;

    return _StatusCard(
      color: SakhiTheme.connected,
      icon: Icons.link_rounded,
      title: 'Connected',
      subtitle: session!.volunteerName != null
          ? 'Buddy: ${session!.volunteerName} • ${mins}m ${secs}s left'
          : 'Monitoring active • ${mins}m ${secs}s left',
    );
  }

  Widget _buildSOSCard(BuildContext context) {
    return _StatusCard(
      color: SakhiTheme.danger,
      icon: Icons.warning_rounded,
      title: 'SOS ACTIVE',
      subtitle: 'Emergency alert sent • Help is on the way',
      showPulse: true,
    );
  }
}

class _StatusCard extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool showProgress;
  final bool showPulse;

  const _StatusCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showProgress = false,
    this.showPulse = false,
  });

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.showPulse || widget.showProgress) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glowOpacity = widget.showPulse
            ? 0.2 + _controller.value * 0.3
            : 0.1;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: widget.color.withValues(alpha: 0.08),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: glowOpacity),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.15),
                ),
                child: Icon(widget.icon, color: widget.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showProgress)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: widget.color,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
