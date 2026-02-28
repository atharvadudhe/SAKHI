import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../services/internal_heartbeat_service.dart';

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
  String _formattedTime(int remainingSeconds) {
    final secs = remainingSeconds.clamp(0, 99999);
    final min = (secs ~/ 60).toString().padLeft(2, '0');
    final sec = (secs % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contactsAsync = ref.watch(emergencyContactsProvider);
    final heartbeatStateAsync = ref.watch(internalHeartbeatStateProvider);
    final service = ref.watch(internalHeartbeatServiceProvider);
    final hb = heartbeatStateAsync.value ?? service.current;
    final isMonitoring = hb.isMonitoring;
    final isTriggeringSOS = hb.isTriggeringSos;
    final sosTriggered = hb.sosTriggered;
    final selectedMinutes = hb.intervalMinutes;
    final remainingSeconds = hb.remainingSeconds;

    return Scaffold(
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
                          'If you miss a heartbeat, SOS is triggered automatically.\n'
                          'You can leave this screen while monitoring stays active.',
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
                  children: InternalHeartbeatService.intervalOptionsMin.map((m) {
                    final selected = selectedMinutes == m;
                    return ChoiceChip(
                      label: Text('$m min'),
                      selected: selected,
                      onSelected: isMonitoring
                          ? null
                          : (_) => service.setIntervalMinutes(m),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Center(
                  child: _buildHeartbeatButton(
                    theme,
                    service: service,
                    isMonitoring: isMonitoring,
                    isTriggeringSOS: isTriggeringSOS,
                    sosTriggered: sosTriggered,
                    selectedMinutes: selectedMinutes,
                    remainingSeconds: remainingSeconds,
                  ),
                ),
                const SizedBox(height: 20),
                if (isMonitoring) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: isTriggeringSOS ? null : () => service.stopMonitoring(),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stop Heartbeat'),
                  ),
                ],
                if (sosTriggered) ...[
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
    );
  }

  Widget _buildHeartbeatButton(
    ThemeData theme, {
    required InternalHeartbeatService service,
    required bool isMonitoring,
    required bool isTriggeringSOS,
    required bool sosTriggered,
    required int selectedMinutes,
    required int remainingSeconds,
  }) {
    final total = selectedMinutes * 60;
    final progress = total == 0 ? 0.0 : (remainingSeconds.clamp(0, total) / total);
    final accent = sosTriggered
        ? SakhiTheme.danger
        : (isMonitoring ? SakhiTheme.safe : SakhiTheme.primary);

    final label = sosTriggered
        ? 'SOS Triggered'
        : isMonitoring
            ? "Tap: I'm Safe"
            : 'Tap to Start';

    final onTap = isTriggeringSOS || sosTriggered
        ? null
        : (isMonitoring
            ? () async {
                HapticFeedback.mediumImpact();
                await service.checkIn();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Heartbeat received. Timer restarted.'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            : () => service.startMonitoring());

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
                value: sosTriggered ? 1 : progress,
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
                  _formattedTime(remainingSeconds),
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
