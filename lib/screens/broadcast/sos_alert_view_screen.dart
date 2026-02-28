import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../config/theme.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

class SosAlertViewScreen extends StatefulWidget {
  final String senderUid;
  final String senderName;
  final double latitude;
  final double longitude;

  const SosAlertViewScreen({
    super.key,
    required this.senderUid,
    required this.senderName,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<SosAlertViewScreen> createState() => _SosAlertViewScreenState();
}

class _SosAlertViewScreenState extends State<SosAlertViewScreen> {
  Timer? _pollTimer;
  LatLng? _myLocation;
  String _senderPhone = '';

  @override
  void initState() {
    super.initState();
    _refreshMyLocation();
    _loadSenderPhone();
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

  Future<void> _loadSenderPhone() async {
    final user = await FirestoreService.instance.getUser(widget.senderUid);
    if (!mounted) return;
    setState(() => _senderPhone = user?.phone ?? '');
  }

  Future<void> _callSender() async {
    final normalized = _senderPhone.replaceAll(RegExp(r'[^\d+]'), '');
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
    final sosLatLng = LatLng(widget.latitude, widget.longitude);
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('sos'),
        position: sosLatLng,
        infoWindow: InfoWindow(title: '${widget.senderName} (SOS)'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
    if (_myLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('me'),
          position: _myLocation!,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('${widget.senderName} - SOS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded),
            onPressed: _senderPhone.trim().isEmpty ? null : _callSender,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: sosLatLng, zoom: 14),
              markers: markers,
              myLocationEnabled: _myLocation != null,
              myLocationButtonEnabled: true,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
            color: Colors.white,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () => _openDirections(sosLatLng),
                icon: const Icon(Icons.directions_rounded),
                label: const Text('Get Directions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SakhiTheme.connected,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
