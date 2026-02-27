import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';

/// Setup screen that lets users configure a "Walk With Me" virtual-companion
/// session by entering a destination and selecting a time limit.
class VirtualCompanionSetupScreen extends ConsumerStatefulWidget {
  const VirtualCompanionSetupScreen({super.key});

  @override
  ConsumerState<VirtualCompanionSetupScreen> createState() =>
      _VirtualCompanionSetupScreenState();
}

class _VirtualCompanionSetupScreenState
    extends ConsumerState<VirtualCompanionSetupScreen> {
  final _destinationController = TextEditingController();
  int _selectedMinutes = 30;

  static const _durationOptions = [15, 30, 45, 60, 90];

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  void _startCompanion() {
    final destination = _destinationController.text.trim();
    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your destination'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    context.push('/active-companion', extra: {
      'destination': destination,
      'durationMinutes': _selectedMinutes,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Walk With Me'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header illustration ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    SakhiTheme.connected.withValues(alpha: 0.1),
                    SakhiTheme.primary.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.directions_walk_rounded,
                    size: 64,
                    color: SakhiTheme.connected,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Virtual Companion',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set a timer for your journey. If you don\'t confirm '
                    'arrival, an automatic SOS will be sent to your emergency '
                    'contacts and nearby volunteers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Destination input ──
            Text(
              'Where are you headed?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(
                hintText: 'e.g., Home, Office, Friend\'s place',
                prefixIcon: Icon(Icons.place_rounded),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 28),

            // ── Duration selector ──
            Text(
              'How long will it take?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _durationOptions.map((min) {
                final selected = min == _selectedMinutes;
                return ChoiceChip(
                  label: Text('$min min'),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedMinutes = min),
                  selectedColor:
                      SakhiTheme.primary.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: selected ? SakhiTheme.primary : null,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  side: BorderSide(
                    color: selected
                        ? SakhiTheme.primary
                        : theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 36),

            // ── Start button ──
            ElevatedButton.icon(
              onPressed: _startCompanion,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Walk'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SakhiTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // ── Info note ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: SakhiTheme.searching.withValues(alpha: 0.08),
                border: Border.all(
                  color: SakhiTheme.searching.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: SakhiTheme.searching,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your live location will be tracked during the session '
                      'and shared only if SOS is triggered.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface
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
    );
  }
}
