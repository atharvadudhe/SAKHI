import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/walking_request_model.dart';
import '../../services/firestore_service.dart';
import '../../services/walking_request_service.dart';
import '../live_tracking_screen.dart';

/// Shows that a volunteer has accepted the user's request
/// Waits for volunteer to confirm arrival before starting the session
class VolunteerAcceptedScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String volunteerId;
  final String volunteerName;

  const VolunteerAcceptedScreen({
    super.key,
    required this.requestId,
    required this.volunteerId,
    required this.volunteerName,
  });

  @override
  ConsumerState<VolunteerAcceptedScreen> createState() =>
      _VolunteerAcceptedScreenState();
}

class _VolunteerAcceptedScreenState
    extends ConsumerState<VolunteerAcceptedScreen> {
  final _firestore = FirestoreService.instance;
  Timer? _animTimer;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    // Animate dots
    _animTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4;
        });
      }
    });
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }

  String get _dots => '.' * _dotCount + ' ' * (3 - _dotCount);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WalkingRequestModel?>(
      stream: _firestore.streamUserRequestStatus(widget.requestId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Volunteer Accepted')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: SakhiTheme.danger,
                  ),
                  const SizedBox(height: 16),
                  Text('Error: ${snap.error}'),
                ],
              ),
            ),
          );
        }

        final req = snap.data;
        if (req == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Volunteer Accepted')),
            body: const Center(child: Text('Request not found')),
          );
        }

        // If volunteer arrived and user confirmed journey started, navigate to live tracking
        if (req.volunteerConfirmedArrival && req.userConfirmedAt != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => LiveTrackingScreen(
                  userId: req.requesterId,
                  volunteerId: widget.volunteerId,
                ),
              ),
            );
          });
        }

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated checkmark
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: SakhiTheme.safe.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 60,
                        color: SakhiTheme.safe,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Volunteer name
                    Text(
                      widget.volunteerName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Status text
                    Text(
                      'has accepted your request!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Waiting for arrival status
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: SakhiTheme.searching.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: SakhiTheme.searching.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    SakhiTheme.searching,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'On the way to you',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Volunteer is traveling to your location$_dots',
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Tips
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'While you wait',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Stay in a well-lit, public area\n'
                            '• Keep your phone charged\n'
                            '• Share this screen with trusted contacts',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
