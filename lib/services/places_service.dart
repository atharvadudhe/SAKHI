import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/place_suggestion.dart';

/// Lightweight wrapper around the Google Places HTTP API. The SDKs do not
/// include an autocomplete widget for Flutter, so we hit the REST endpoints
/// directly.  The API key is read from [AppConstants.googleMapsApiKey]
/// (injected at build time via dart-define or other secure mechanism).
class PlacesService {
  PlacesService._();

  static const _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  /// Fetches autocomplete suggestions for [input].
  ///
  /// [sessionToken] should be a unique string per session (e.g. UUID) and
  /// ideally persisted while the user is typing. See Google docs for usage
  /// with billing.
  static Future<List<PlaceSuggestion>> fetchSuggestions(
    String input, String sessionToken) async {
  final apiKey = AppConstants.googleMapsApiKey;
  if (apiKey.isEmpty) {
    throw Exception('Google Maps API key not provided');
  }

  final uri = Uri.parse('$_baseUrl/autocomplete/json').replace(
    queryParameters: {
      'input': input,
      'key': apiKey,
      'sessiontoken': sessionToken,
      'components': 'country:in',
    },
  );

  print("==== AUTOCOMPLETE REQUEST ====");
  print("URI: $uri");

  final resp = await http.get(uri);

  print("STATUS CODE: ${resp.statusCode}");
  print("RESPONSE BODY: ${resp.body}");
  print("==============================");

  if (resp.statusCode != 200) {
    throw Exception(
        'Places autocomplete request failed with code ${resp.statusCode}');
  }

  final data = json.decode(resp.body) as Map<String, dynamic>;
  final status = data['status'] as String?;

  if (status != 'OK') {
    if (status == 'ZERO_RESULTS') return [];
    throw Exception(
        'Places API error: $status - ${data['error_message']}');
  }

  final List suggestionsJson = data['predictions'] as List;
  return suggestionsJson
      .map((item) =>
          PlaceSuggestion.fromJson(item as Map<String, dynamic>))
      .toList();
}

  /// Retrieves the latitude/longitude of a place given its [placeId].
  ///
  /// Returns null if the API call succeeds but the geometry is missing for
  /// some reason.
  static Future<LatLng?> fetchPlaceLatLng(
      String placeId, String sessionToken) async {
    final apiKey = AppConstants.googleMapsApiKey;
    if (apiKey.isEmpty) {
      throw Exception('Google Maps API key not provided');
    }

    final uri = Uri.parse('$_baseUrl/details/json').replace(
      queryParameters: {
        'place_id': placeId,
        'key': apiKey,
        'sessiontoken': sessionToken,
        'fields': 'geometry/location',
      },
    );

    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Places details request failed with code ${resp.statusCode}');
    }

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final status = data['status'] as String?;
    if (status != 'OK') {
      throw Exception('Places details API error: $status');
    }

    final location = (data['result'] as Map?)?['geometry']
        as Map<String, dynamic>?;
    if (location == null) return null;
    final lat = (location['location'] as Map)['lat'] as num;
    final lng = (location['location'] as Map)['lng'] as num;
    return LatLng(lat.toDouble(), lng.toDouble());
  }
}
