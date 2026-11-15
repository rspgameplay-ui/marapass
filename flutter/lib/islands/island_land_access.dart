import '../domain/tourism.dart';

/// Roadside point linked to an island by a documented crossing.
class IslandLandAccess {
  IslandLandAccess.fromJson(Map<String, dynamic> json)
    : destination = TourismPlace.fromJson({
        ...json,
        'cat': 'transport',
        'description': json['note'],
        'sourceUrl': json['accessSource'],
        'dataSource': 'OpenStreetMap • ODbL',
        'referenceLocation': false,
      }),
      crossingSource = json['crossingSource'] as String;

  final TourismPlace destination;
  final String crossingSource;
}

IslandLandAccess? closestIslandAccess(
  Iterable<IslandLandAccess> accesses,
  GeoPoint? origin, {
  bool Function(GeoPoint)? accepts,
}) {
  IslandLandAccess? closest;
  double? closestDistance;
  for (final access in accesses) {
    final point = access.destination.point;
    if (accepts != null && !accepts(point)) continue;
    if (origin == null) return access;
    final distance = origin.distanceKm(point);
    if (closestDistance == null || distance < closestDistance) {
      closest = access;
      closestDistance = distance;
    }
  }
  return closest;
}
