import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_service.dart';
import '../services/walking_request_service.dart';
import '../screens/user_request_listener.dart';

/// Simple screen where a user can broadcast a walking request.
///
/// Replaces the old volunteer listing logic after switching to a
/// broadcast-based architecture.
class FindVolunteerScreen extends StatefulWidget {
  const FindVolunteerScreen({super.key});

  @override
  State<FindVolunteerScreen> createState() => _FindVolunteerScreenState();
}

class _FindVolunteerScreenState extends State<FindVolunteerScreen> {
  final _firestore = FirestoreService.instance;

  LatLng? _userLocation;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permission denied';
          _isLoading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error obtaining location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _requestBuddy() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to continue')));
      return;
    }

    if (_userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not available')));
      return;
    }

    final exists = await _firestore.hasActiveBroadcastRequest(currentUser.uid);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already have a pending request')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final profile = await _firestore.getUser(currentUser.uid);
      if (profile == null) throw Exception('Profile data missing');

      final requestId = await _firestore.createBroadcastRequest(
        requesterId: profile.uid,
        requesterName: profile.name,
        requesterLocation:
            GeoPoint(_userLocation!.latitude, _userLocation!.longitude),
        destinationLocation:
            GeoPoint(_userLocation!.latitude, _userLocation!.longitude),
        destinationName: 'Current location',
      );

      Navigator.pop(context); // dismiss loader
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UserRequestListener(requestId: requestId),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error sending request: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔥 ACTIVE SCREEN: FindVolunteerScreen');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Walking Buddy'),
        backgroundColor: Colors.pink.shade400,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _initLocation();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Broadcast a request and a nearby volunteer will be notified.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _requestBuddy,
              child: const Text('Request Walking Buddy'),
            ),
          ],
        ),
      ),
    );
  }
}
