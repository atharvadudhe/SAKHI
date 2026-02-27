import 'package:flutter/material.dart';

import '../models/walking_request_model.dart';
import '../services/firestore_service.dart';
import '../services/walking_request_service.dart';
import 'live_tracking_screen.dart';

/// Listens to a single request document and navigates when accepted
class UserRequestListener extends StatefulWidget {
  final String requestId;
  const UserRequestListener({Key? key, required this.requestId}) : super(key: key);

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
          return Center(child: Text('Error: \\${snap.error}'));
        }
        final req = snap.data;
        if (req == null) {
          return const Center(child: Text('Request not found'));
        }
        if (req.status == WalkingRequestStatus.accepted && req.acceptedBy != null) {
          // navigate to live tracking screen
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final volunteer = await _firestore.getUser(req.acceptedBy!);
            if (volunteer != null) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => LiveTrackingScreen(
                    userId: req.requesterId,
                    volunteerId: volunteer.uid,
                  ),
                ),
              );
            }
          });
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Waiting for a volunteer to accept your request...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }
}
