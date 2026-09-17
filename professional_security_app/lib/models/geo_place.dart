/// One search result from GeocodingService.
class GeoPlace {
  final String displayName;
  final double latitude;
  final double longitude;

  const GeoPlace({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  factory GeoPlace.fromMap(Map<String, dynamic> map) {
    return GeoPlace(
      displayName: map['display_name'] as String,
      latitude: double.parse(map['lat'] as String),
      longitude: double.parse(map['lon'] as String),
    );
  }
}
