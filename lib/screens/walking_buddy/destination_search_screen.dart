import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../config/theme.dart';
import '../../models/walking_buddy_models.dart';
import '../../models/place_suggestion.dart';
import '../../providers/walking_buddy_providers.dart';
import '../../services/places_service.dart';

/// Screen for searching and selecting a walking destination
class DestinationSearchScreen extends ConsumerStatefulWidget {
  const DestinationSearchScreen({super.key});

  @override
  ConsumerState<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState
    extends ConsumerState<DestinationSearchScreen> {
  late TextEditingController _searchController;

  // places autocomplete suggestions returned from the service
  List<PlaceSuggestion> _suggestions = [];

  // used to debounce typing so we don't hit the API on every keystroke
  Timer? _debounce;

  // unique token sent to Google with each session
  String _sessionToken = const Uuid().v4();

  // when the user taps a suggestion we show a small map preview
  LatLng? _mapCenter;
  final Completer<GoogleMapController> _mapController = Completer();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _selectDestination(DestinationModel destination) {
    // Save to recent destinations
    ref.read(addRecentDestinationProvider)(destination);

    // Update selected destination
    ref.read(selectedDestinationProvider.notifier).state = destination;

    // Navigate to location confirmation
    context.push('/walking-buddy/location-confirmation', extra: destination);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: SakhiTheme.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onSearchChanged() {
    final input = _searchController.text;
    // cancel previous timer
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (input.isEmpty) {
      setState(() {
        _suggestions.clear();
      });
      // start a fresh session if user begins typing again later
      _sessionToken = const Uuid().v4();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results =
            await PlacesService.fetchSuggestions(input, _sessionToken);
        if (mounted) {
          setState(() {
            _suggestions = results;
          });
        }
      } catch (e) {
        _showError('Search failed: $e');
      }
    });
  }

  Future<void> _onSuggestionTap(PlaceSuggestion suggestion) async {
    try {
      final latLng =
          await PlacesService.fetchPlaceLatLng(suggestion.placeId, _sessionToken);
      if (latLng != null) {
        setState(() {
          _mapCenter = latLng;
          _suggestions.clear();
          _searchController.text = suggestion.description;
        });

        if (_mapController.isCompleted) {
          final ctrl = await _mapController.future;
          ctrl.animateCamera(
              CameraUpdate.newLatLngZoom(latLng, 15));
        }

        // convert to destination model and immediately select
        final destination = DestinationModel(
          placeId: suggestion.placeId,
          name: suggestion.description,
          address: suggestion.description,
          latitude: latLng.latitude,
          longitude: latLng.longitude,
        );
        _selectDestination(destination);
        // once a place is selected, we won't reuse the old token
        _sessionToken = const Uuid().v4();
      } else {
        _showError('Could not determine location for this place');
      }
    } catch (e) {
      _showError('Failed to fetch place details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentDestinations = ref.watch(recentDestinationsProvider);
    // we are no longer using mock data; suggestions drive the list
    

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Destination'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search destination...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _suggestions.clear();
                            _mapCenter = null;
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),

          // optional map preview
          if (_mapCenter != null)
            SizedBox(
              height: 200,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _mapCenter!,
                  zoom: 15,
                ),
                onMapCreated: (ctrl) {
                  if (!_mapController.isCompleted) {
                    _mapController.complete(ctrl);
                  }
                },
                markers: {
                  Marker(
                    markerId: const MarkerId('selected'),
                    position: _mapCenter!,
                  )
                },
              ),
            ),

          // results area
          Expanded(
            child: _searchController.text.isEmpty
                ? _buildRecentList(recentDestinations)
                : _buildSuggestionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentList(List<DestinationModel> recentDestinations) {
    if (recentDestinations.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListView(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'Recent',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        ...recentDestinations.map(
          (destination) => _DestinationTile(
            destination: destination,
            onTap: () => _selectDestination(destination),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionsList() {
    if (_suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No results found',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _suggestions.length,
      itemBuilder: (ctx, index) {
        final sug = _suggestions[index];
        return ListTile(
          title: Text(sug.description),
          leading: const Icon(Icons.location_on, color: SakhiTheme.primary),
          onTap: () => _onSuggestionTap(sug),
        );
      },
    );
  }
}

/// Widget for individual destination tile
class _DestinationTile extends StatelessWidget {
  final DestinationModel destination;
  final VoidCallback onTap;

  const _DestinationTile({
    required this.destination,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.location_on, color: SakhiTheme.primary),
      title: Text(destination.name),
      subtitle: Text(destination.address ?? ''),
      trailing: const Icon(Icons.arrow_forward),
      onTap: onTap,
    );
  }
}
