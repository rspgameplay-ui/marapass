import 'tourism.dart';

class Municipality {
  const Municipality({
    required this.id,
    required this.name,
    required this.point,
    required this.bounds,
    required this.region,
    required this.intermediateRegion,
    required this.mappedPlaces,
    required this.areaKm2,
  });
  final String id, name, region, intermediateRegion;
  final GeoPoint point;
  final GeoBounds bounds;
  final int mappedPlaces;
  final double areaKm2;
  factory Municipality.fromJson(Map<String, dynamic> j) {
    final b = j['bounds'] as List;
    return Municipality(
      id: j['id'] as String,
      name: j['name'] as String,
      point: GeoPoint(
        (j['lat'] as num).toDouble(),
        (j['lng'] as num).toDouble(),
      ),
      bounds: GeoBounds(
        (b[0] as num).toDouble(),
        (b[1] as num).toDouble(),
        (b[2] as num).toDouble(),
        (b[3] as num).toDouble(),
      ),
      region: j['region'] as String,
      intermediateRegion: j['intermediateRegion'] as String,
      mappedPlaces: j['mappedPlaces'] as int,
      areaKm2: (j['areaKm2'] as num).toDouble(),
    );
  }
}
