import '../domain/tourism.dart';

/// Immutable samples of public seed coordinates. An edited marker invalidates its sample.
class ElevationData {
  ElevationData(Map<String, dynamic> json)
    : points = Map<String, dynamic>.from(json['points'] as Map),
      queriedAt = json['queriedAt'] as String;
  final Map<String, dynamic> points;
  final String queriedAt;

  double? at(TourismPlace place) {
    final sample = points[place.id];
    if (sample is! Map) return null;
    final lat = sample['lat'], lng = sample['lng'], meters = sample['meters'];
    if (lat is! num || lng is! num || meters is! num || !meters.isFinite)
      return null;
    if ((lat - place.point.lat).abs() > 0.0000001 ||
        (lng - place.point.lng).abs() > 0.0000001)
      return null;
    return meters.toDouble();
  }
}
