import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/theme.dart';
import '../../models/broadcast_model.dart';
import '../../providers/providers.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

class BroadcastScreen extends ConsumerStatefulWidget {
  const BroadcastScreen({super.key});

  @override
  ConsumerState<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends ConsumerState<BroadcastScreen> {
  bool _isSending = false;
  bool _isLocating = true;
  String? _locationError;
  LatLng? _currentLatLng;
  GoogleMapController? _mapController;

  final _alertTypes = const [
    {
      'key': 'crime',
      'label': 'Crime',
      'icon': Icons.local_police_rounded,
      'color': SakhiTheme.danger,
    },
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
      'key': 'road_issue',
      'label': 'Road Issue',
      'icon': Icons.report_problem_rounded,
      'color': SakhiTheme.connected,
    },
    {
      'key': 'other',
      'label': 'Other',
      'icon': Icons.more_horiz_rounded,
      'color': SakhiTheme.primary,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    final result = await LocationService.instance.getPosition();
    if (!mounted) return;

    if (result.isSuccess && result.position != null) {
      final pos = result.position!;
      setState(() {
        _currentLatLng = LatLng(pos.latitude, pos.longitude);
        _isLocating = false;
      });
      return;
    }

    final message = switch (result.failure) {
      LocationFailure.permissionDenied =>
        'Location permission denied. Allow location to use the map.',
      LocationFailure.permissionPermanentlyDenied =>
        'Location permission permanently denied. Enable it from settings.',
      LocationFailure.serviceDisabled =>
        'Location service is disabled. Turn it on to load the map.',
      LocationFailure.timeout => 'Location request timed out. Please retry.',
      _ => 'Could not determine your location.',
    };

    setState(() {
      _locationError = message;
      _isLocating = false;
    });
  }

  List<BroadcastModel> _nearbyBroadcasts(List<BroadcastModel> all) {
    final current = _currentLatLng;
    if (current == null) return all;
    return all.where((b) {
      final distanceKm = LocationService.instance.distanceBetween(
        current.latitude,
        current.longitude,
        b.location.latitude,
        b.location.longitude,
      );
      return distanceKm <= 5.0;
    }).toList();
  }

  Color _alertColor(String type) {
    switch (type) {
      case 'crime':
        return SakhiTheme.danger;
      case 'suspicious_activity':
        return SakhiTheme.danger;
      case 'road_issue':
        return SakhiTheme.connected;
      case 'other':
        return SakhiTheme.primary;
      case 'unsafe_area':
      default:
        return SakhiTheme.searching;
    }
  }

  double _alertHue(String type) {
    switch (type) {
      case 'crime':
        return BitmapDescriptor.hueRed;
      case 'suspicious_activity':
        return BitmapDescriptor.hueOrange;
      case 'road_issue':
        return BitmapDescriptor.hueAzure;
      case 'other':
        return BitmapDescriptor.hueViolet;
      case 'unsafe_area':
      default:
        return BitmapDescriptor.hueYellow;
    }
  }

  Set<Marker> _buildMarkers(List<BroadcastModel> broadcasts) {
    final markers = <Marker>{};

    if (_currentLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('me'),
          position: _currentLatLng!,
          infoWindow: const InfoWindow(title: 'You'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    for (final b in broadcasts) {
      markers.add(
        Marker(
          markerId: MarkerId('broadcast_${b.id}'),
          position: LatLng(b.location.latitude, b.location.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(_alertHue(b.alertType)),
          infoWindow: InfoWindow(
            title: b.alertLabel,
            snippet: b.message.isEmpty ? 'Reported recently' : b.message,
          ),
        ),
      );
    }

    return markers;
  }

  Future<bool> _sendAlert({
    required String message,
    required String alertType,
  }) async {
    if (message.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a description'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    setState(() => _isSending = true);

    try {
      final positionResult = await LocationService.instance.getPosition();
      final position = positionResult.position;
      if (position == null) {
        throw Exception('Could not get your location');
      }

      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null) throw Exception('Not logged in');

      final user = ref.read(currentUserProvider).value;

      await FirestoreService.instance.sendBroadcast(
        uid: uid,
        message: message.trim(),
        alertType: alertType,
        location: GeoPoint(position.latitude, position.longitude),
        userName: user?.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert reported and pinned on map.'),
            backgroundColor: SakhiTheme.safe,
            behavior: SnackBarBehavior.floating,
          ),
        );
        final current = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentLatLng = current;
          _isSending = false;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(current, 15));
      }
      return true;
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
      return false;
    } finally {
      if (mounted && _isSending) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _openReportAlertSheet() async {
    String selectedType = 'unsafe_area';
    final messageController = TextEditingController();
    bool isSubmitting = false;
    bool showDescError = false;
    int shakeTick = 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, sheetSetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Report an Alert',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose incident type and add a short description.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Type',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _alertTypes.map((type) {
                          final isSelected = selectedType == type['key'];
                          final color = type['color'] as Color;
                          return ChoiceChip(
                            avatar: Icon(
                              type['icon'] as IconData,
                              size: 16,
                              color: isSelected ? Colors.white : color,
                            ),
                            label: Text(type['label'] as String),
                            selected: isSelected,
                            onSelected: (_) => sheetSetState(
                              () => selectedType = type['key'] as String,
                            ),
                            selectedColor: color,
                            backgroundColor: color.withValues(alpha: 0.1),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : color,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.transparent
                                  : color.withValues(alpha: 0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TweenAnimationBuilder<double>(
                        key: ValueKey(shakeTick),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 420),
                        builder: (context, t, child) {
                          final dx = math.sin(t * math.pi * 8) * (1 - t) * 10;
                          return Transform.translate(
                            offset: Offset(dx, 0),
                            child: child,
                          );
                        },
                        child: TextFormField(
                          controller: messageController,
                          maxLines: 4,
                          maxLength: 200,
                          onChanged: (_) {
                            if (showDescError) {
                              sheetSetState(() => showDescError = false);
                            }
                          },
                          decoration: InputDecoration(
                            hintText:
                                'Describe what you\'re seeing or experiencing...',
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: showDescError
                                    ? SakhiTheme.danger
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: showDescError
                                    ? SakhiTheme.danger
                                    : SakhiTheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (showDescError)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Description is required',
                            style: TextStyle(
                              color: SakhiTheme.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.of(sheetContext).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      if (messageController.text
                                          .trim()
                                          .isEmpty) {
                                        HapticFeedback.mediumImpact();
                                        sheetSetState(() {
                                          showDescError = true;
                                          shakeTick++;
                                        });
                                        return;
                                      }
                                      sheetSetState(() => isSubmitting = true);
                                      final ok = await _sendAlert(
                                        message: messageController.text,
                                        alertType: selectedType,
                                      );
                                      if (!mounted) return;
                                      sheetSetState(() => isSubmitting = false);
                                      if (ok && sheetContext.mounted) {
                                        Navigator.of(sheetContext).pop();
                                      }
                                    },
                              icon: isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: Text(isSubmitting ? 'Sending' : 'Submit'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _alertColor(selectedType),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // Avoid disposing immediately on pop; this prevents occasional bottom-sheet
    // teardown assertions on some Flutter versions.
  }

  @override
  Widget build(BuildContext context) {
    final broadcastsAsync = ref.watch(broadcastsFeedProvider);
    final allBroadcasts = broadcastsAsync.value ?? const <BroadcastModel>[];
    final markers = _buildMarkers(_nearbyBroadcasts(allBroadcasts));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Community Alert'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _isLocating
                  ? const Center(child: CircularProgressIndicator())
                  : _currentLatLng == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_off_rounded,
                              size: 44,
                              color: SakhiTheme.danger,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _locationError ?? 'Location unavailable',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: _loadCurrentLocation,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _currentLatLng!,
                        zoom: 14,
                      ),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      markers: markers,
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: SizedBox(
                  width: 190,
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _openReportAlertSheet,
                    icon: const Icon(Icons.flag_rounded),
                    label: const Text('Report Alert'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SakhiTheme.searching,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(190, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
