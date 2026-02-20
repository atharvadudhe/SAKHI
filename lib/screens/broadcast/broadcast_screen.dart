import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../config/theme.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../providers/providers.dart';

class BroadcastScreen extends ConsumerStatefulWidget {
  const BroadcastScreen({super.key});

  @override
  ConsumerState<BroadcastScreen> createState() =>
      _BroadcastScreenState();
}

class _BroadcastScreenState
    extends ConsumerState<BroadcastScreen> {
  final _messageController = TextEditingController();
  String _selectedType = 'unsafe_area';
  bool _isSending = false;

  final _alertTypes = [
    {
      'key': 'unsafe_area',
      'label': 'Unsafe Area',
      'icon': Icons.warning_amber_rounded,
      'color': SakhiTheme.searching,
    },
    {
      'key': 'suspicious_activity',
      'label': 'Suspicious Activity',
      'icon': Icons.visibility_rounded,
      'color': SakhiTheme.danger,
    },
    {
      'key': 'need_help',
      'label': 'Need Help',
      'icon': Icons.sos_rounded,
      'color': SakhiTheme.primaryDark,
    },
    {
      'key': 'road_issue',
      'label': 'Road Issue',
      'icon': Icons.report_problem_rounded,
      'color': SakhiTheme.connected,
    },
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendAlert() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a description'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final position =
          await LocationService.instance.getCurrentPosition();
      if (position == null) {
        throw Exception('Could not get your location');
      }

      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null) throw Exception('Not logged in');

      await FirestoreService.instance.sendBroadcast(
        uid: uid,
        message: _messageController.text.trim(),
        alertType: _selectedType,
        location:
            GeoPoint(position.latitude, position.longitude),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert sent to nearby volunteers!'),
            backgroundColor: SakhiTheme.safe,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: SakhiTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Community Alert'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: SakhiTheme.searching.withValues(alpha: 0.08),
                  border: Border.all(
                    color:
                        SakhiTheme.searching.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.campaign_rounded,
                        color: SakhiTheme.searching, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Broadcast Safety Alert',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Alert will be sent to volunteers within 2km radius.',
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

              // Alert type selection
              const Text(
                'Alert Type',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _alertTypes.map((type) {
                  final isSelected =
                      _selectedType == type['key'];
                  final color = type['color'] as Color;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type['icon'] as IconData,
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : color,
                        ),
                        const SizedBox(width: 6),
                        Text(type['label'] as String),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) => setState(
                        () => _selectedType = type['key'] as String),
                    selectedColor: color,
                    backgroundColor: color.withValues(alpha: 0.08),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : color.withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // Description
              const Text(
                'Description',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText:
                      'Describe what you\'re seeing or experiencing...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Location info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on_rounded,
                        size: 20, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your current location will be shared',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: SakhiTheme.primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '2km radius',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SakhiTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Send button
              ElevatedButton.icon(
                onPressed: _isSending ? null : _sendAlert,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                    _isSending ? 'Sending...' : 'Send Alert'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SakhiTheme.searching,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
