import 'package:flutter/material.dart';

import '../models/walking_request_model.dart';
import '../services/firestore_service.dart';
import '../services/walking_request_service.dart';
import 'session/volunteer_accepted_screen.dart';

/// Listens to a single request document and navigates when accepted
class UserRequestListener extends StatefulWidget {
  final String requestId;
  const UserRequestListener({super.key, required this.requestId});

  @override
  _UserRequestListenerState createState() => _UserRequestListenerState();
}

class _UserRequestListenerState extends State<UserRequestListener> {
  final _firestore = FirestoreService.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WalkingRequestModel?>(
      stream: _firestore.streamUserRequestStatus(widget.requestId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final req = snap.data;
        if (req == null) {
          return const Center(child: Text('Request not found'));
        }
        
        // Volunteer accepted - show acceptance screen instead of immediately navigating
        if (req.status == WalkingRequestStatus.accepted &&
            req.acceptedBy != null &&
            req.acceptedAt != null) {
          // Get volunteer info
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final volunteer = await _firestore.getUser(req.acceptedBy!);
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => VolunteerAcceptedScreen(
                    requestId: widget.requestId,
                    volunteerId: req.acceptedBy!,
                    volunteerName: volunteer?.name ?? 'Volunteer',
                  ),
                ),
              );
            }
          });
        }
        
        // Still waiting for volunteer
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Waiting for a volunteer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Searching nearby volunteers to help you...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
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
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Stay safe while waiting',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Stay in a well-lit area\n'
                            '• Keep your phone charged\n'
                            '• Share this with trusted contacts',
                            style: TextStyle(
                              fontSize: 12,
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
