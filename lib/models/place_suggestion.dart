/// Model used for Google Places Autocomplete suggestions.
class PlaceSuggestion {
  final String description;
  final String placeId;

  PlaceSuggestion({required this.description, required this.placeId});

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) =>
      PlaceSuggestion(
        description: json['description'] as String,
        placeId: json['place_id'] as String,
      );
}
