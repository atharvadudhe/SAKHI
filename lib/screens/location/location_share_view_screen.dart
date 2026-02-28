import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../config/theme.dart';
import '../../models/location_share_model.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

class LocationShareViewScreen extends StatefulWidget {
  final String shareId;
  final String senderName;
  final String senderPhone;

  const LocationShareViewScreen({
    super.key,
    required this.shareId,
    required this.senderName,
    required this.senderPhone,
  });

  @override
  State<LocationShareViewScreen> createState() => _LocationShareViewScreenState();
}

class _LocationShareViewScreenState extends State<LocationShareViewScreen> {
  Timer? _pollTimer;
  LatLng? _myLocation;

  @override
  void initState() {
    super.initState();
    _refreshMyLocation();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshMyLocation(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshMyLocation() async {
    final result = await LocationService.instance.getPosition();
    if (!mounted || !result.isSuccess || result.position == null) return;
    setState(() {
      _myLocation = LatLng(
        result.position!.latitude,
        result.position!.longitude,
      );
    });
  }

  Future<void> _callSender() async {
    final normalized = widget.senderPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (normalized.isEmpty) return;
    await launchUrlString('tel:$normalized');
  }

  Future<void> _openDirections(LatLng destination) async {
    final origin = _myLocation;
    final originQuery = origin == null
        ? ''
        : '&origin=${origin.latitude},${origin.longitude}';
    final url =
        'https://www.google.com/maps/dir/?api=1$originQuery&destination=${destination.latitude},${destination.longitude}&travelmode=walking';
    await launchUrlString(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('${widget.senderName} - Live Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded),
            onPressed: _callSender,
          ),
        ],
      ),
      body: StreamBuilder<LocationShareModel?>(
        stream: FirestoreService.instance.locationShareStream(widget.shareId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final share = snapshot.data;
          if (share == null) {
            return const Center(child: Text('Location share not found.'));
          }

          final hasExpired = share.expiresAt != null &&
              DateTime.now().isAfter(share.expiresAt!);
          if (!share.isActive || hasExpired) {
            return const Center(
              child: Text('This live-location session has ended.'),
            );
          }

          final senderLatLng = LatLng(
            share.location.latitude,
            share.location.longitude,
          );
          final markers = <Marker>{
            Marker(
              markerId: const MarkerId('sender'),
              position: senderLatLng,
              infoWindow: InfoWindow(title: widget.senderName),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            ),
          };
          if (_myLocation != null) {
            markers.add(
              Marker(
                markerId: const MarkerId('me'),
                position: _myLocation!,
                infoWindow: const InfoWindow(title: 'Your Location'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: senderLatLng,
                    zoom: 14,
                  ),
                  markers: markers,
                  myLocationButtonEnabled: true,
                  myLocationEnabled: _myLocation != null,
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                color: Colors.white,
                child: Column(
                  children: [
                    Text(
                      'Live location refreshes every 30 seconds.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => _openDirections(senderLatLng),
                        icon: const Icon(Icons.directions_rounded),
                        label: const Text('Get Directions'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SakhiTheme.connected,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
