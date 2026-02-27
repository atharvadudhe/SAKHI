import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math' as math;

import '../../config/theme.dart';
import '../../models/walking_buddy_models.dart';
import '../../providers/walking_buddy_providers.dart';
import '../../providers/providers.dart';

/// Screen for confirming and adjusting user location before creating a session
class LocationConfirmationScreen extends ConsumerStatefulWidget {
  final DestinationModel destination;

  const LocationConfirmationScreen({
    super.key,
    required this.destination,
  });

  @override
  ConsumerState<LocationConfirmationScreen> createState() =>
      _LocationConfirmationScreenState();
}

class _LocationConfirmationScreenState
    extends ConsumerState<LocationConfirmationScreen> {
  // use a Completer so that we never try to call methods on a controller
  // that has not been created yet. avoids late init errors.
  final Completer<GoogleMapController> _mapController = Completer();

  // location state is nullable until we obtain permission & a fix.
  LatLng? _userLocation;
  LatLng? _destinationLocation;

  // loading state for the confirm button
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  /// ask for permission, check services and fetch the current position.
  ///
  /// This method lives in the UI layer because we need to show feedback
  /// directly (snackbars/dialogs) when something goes wrong.  We don't
  /// rely on `late` anywhere; if permission is denied the location remains
  /// null and the spinner or error text is shown.
  Future<void> _initLocation() async {
    try {
      // make sure device GPS is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled. Please enable GPS.');
        return;
      }

      // request/check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showError('Location permission denied. Please grant permission.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showOpenSettingsDialog();
        return;
      }

      // finally get the position
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      if (mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
          _destinationLocation = LatLng(
            widget.destination.latitude,
            widget.destination.longitude,
          );
        });
      }
    } catch (e) {
      if (mounted) _showError('Failed to get location: $e');
    }
  }

  // removed: logic moved into _initLocation with permission handling

  // no longer storing markers in state; compute lazily based on current
  // locations. this makes marker updates simpler and ensures we don't try to
  // reference them before the location is ready.
  Set<Marker> get _markers {
    if (_userLocation == null || _destinationLocation == null) return {};
    return {
      Marker(
        markerId: const MarkerId('user'),
        position: _userLocation!,
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue,
        ),
        draggable: true,
        onDragEnd: (newPosition) {
          setState(() {
            _userLocation = newPosition;
          });
        },
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: _destinationLocation!,
        infoWindow: InfoWindow(title: widget.destination.name),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed,
        ),
      ),
    };
  }

  Future<void> _confirmAndCreateSession() async {
    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authStateProvider);
      final currentUser = ref.read(currentUserProvider).value;

      if (authState.value == null || currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Create GeoPoints from locations
      final userGeoPoint = GeoPoint(
          _userLocation!.latitude, _userLocation!.longitude);
      final destGeoPoint = GeoPoint(
        _destinationLocation!.latitude,
        _destinationLocation!.longitude,
      );

      // Calculate estimated duration (mock calculation)
      final distance = _calculateDistance(
        _userLocation!.latitude,
        _userLocation!.longitude,
        _destinationLocation!.latitude,
        _destinationLocation!.longitude,
      );
      final estimatedDuration = (distance / 1.4).clamp(5, 120).toDouble();

      // Create the walking session
      final controller = ref.read(walkingBuddyControllerProvider.notifier);
      final sessionId = await controller.createWalkingSession(
        userId: authState.value!.uid,
        userName: currentUser.name,
        userPhone: currentUser.phone,
        userPhotoUrl: currentUser.photoUrl,
        userLocation: userGeoPoint,
        destinationLocation: destGeoPoint,
        destinationName: widget.destination.name,
        destinationAddress: widget.destination.address,
        estimatedDuration: estimatedDuration,
      );

      if (sessionId != null && mounted) {
        // Save location to provider for later use
        ref.read(walkingBuddyUserLocationProvider.notifier).state = userGeoPoint;

        // Navigate to volunteer selection screen
        context.pushReplacement(
          '/walking-buddy/volunteer-selection',
          extra: sessionId,
        );
      } else {
        throw Exception('Failed to create session');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // use dart:math for accurate formulas
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  Widget _buildBottomSheet(BuildContext context) {
    // entire bottom sheet UI extracted for readability and to keep build
    // method focused on layout decisions. This widget is scrollable when
    // wrapped by Flexible in the parent.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag indicator
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Location info card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.my_location,
                        color: SakhiTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Location',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                            Text(
                              '${_userLocation!.latitude.toStringAsFixed(4)}, ${_userLocation!.longitude.toStringAsFixed(4)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: SakhiTheme.danger,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Destination',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                            Text(
                              widget.destination.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Drag the blue pin to adjust your location if needed',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          color: Colors.blue.shade700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _confirmAndCreateSession,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Find Walking Buddy'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // show a progress spinner while waiting on location or permission
    if (_userLocation == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Confirm Location'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // when we reach here we have both coordinates available
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Location'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // map occupies as much space as possible but will shrink if
            // bottom sheet grows
            Expanded(
  child: Stack(
    children: [
      GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _userLocation!,
          zoom: 15,
        ),

        onMapCreated: (controller) {
          if (!_mapController.isCompleted) {
            _mapController.complete(controller);
          }
        },

        // 🔥 This updates location when map moves
        onCameraMove: (cameraPosition) {
          setState(() {
            _userLocation = cameraPosition.target;
          });
        },

        markers: {
          if (_destinationLocation != null)
            Marker(
              markerId: const MarkerId('destination'),
              position: _destinationLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            ),
        },
      ),

      // 🔥 CENTER FIXED PIN (Uber Style)
      const Center(
        child: Icon(
          Icons.location_pin,
          size: 45,
          color: Colors.blue,
        ),
      ),
    ],
  ),
),
            // bottom sheet: flexible so it can scroll when space is low
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 0),
                child: _buildBottomSheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // controller is held by completer; GoogleMap disposes it automatically
    super.dispose();
  }

  // show a snackbar error message if something goes wrong
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: SakhiTheme.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showOpenSettingsDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Location permission is permanently denied. '
          'Please open app settings and enable location access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
