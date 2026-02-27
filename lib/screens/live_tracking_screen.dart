import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../services/firestore_service.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String userId;
  final String volunteerId;

  const LiveTrackingScreen({
    super.key,
    required this.userId,
    required this.volunteerId,
  });

  @override
  _LiveTrackingScreenState createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final _firestore = FirestoreService.instance;
  StreamSubscription<UserModel?>? _userSub;
  StreamSubscription<UserModel?>? _volSub;
  StreamSubscription<Position>? _positionSub;
  UserModel? _user;
  UserModel? _volunteer;
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  String? _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;

    _userSub = _firestore.userStream(widget.userId).listen((u) {
      setState(() {
        _user = u;
      });
      _updateMarkers();
    });
    _volSub = _firestore.userStream(widget.volunteerId).listen((v) {
      setState(() {
        _volunteer = v;
      });
      _updateMarkers();
    });

    _startLocationUpdates();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _volSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  void _updateMarkers() {
    final markers = <Marker>{};
    if (_user?.liveLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: LatLng(
          _user!.liveLocation!.latitude,
          _user!.liveLocation!.longitude,
        ),
        infoWindow: const InfoWindow(title: 'You'),
      ));
    }
    if (_volunteer?.liveLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('volunteer'),
        position: LatLng(
          _volunteer!.liveLocation!.latitude,
          _volunteer!.liveLocation!.longitude,
        ),
        infoWindow: const InfoWindow(title: 'Volunteer'),
      ));
    }
    setState(() {
      _markers = markers;
    });
  }

  void _startLocationUpdates() {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      if (_myUid == null) return;
      // update whichever profile corresponds to this device
      if (_myUid == widget.userId || _myUid == widget.volunteerId) {
        _firestore.updateLiveLocation(
            _myUid!, GeoPoint(pos.latitude, pos.longitude));
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Tracking')),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(0, 0),
          zoom: 14,
        ),
        onMapCreated: (controller) {
          _mapController = controller;
        },
        markers: _markers,
      ),
    );
  }
}
