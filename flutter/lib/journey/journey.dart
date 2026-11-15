import 'dart:math' as math;

import '../domain/navigation.dart';
import '../domain/tourism.dart';
import '../islands/island_land_access.dart';

enum JourneyMode { interests, coupons, saved }

class JourneyPreferences {
  const JourneyPreferences({
    this.interests = const {
      PlaceCategory.nature,
      PlaceCategory.culture,
      PlaceCategory.tours,
      PlaceCategory.gastronomy,
      PlaceCategory.crafts,
    },
    this.corridorMeters = 2000,
    this.aheadMeters = 20000,
  });
  final Set<PlaceCategory> interests;
  final double corridorMeters, aheadMeters;
  static const corridorOptions = [500.0, 2000.0, 5000.0];
  static const aheadOptions = [5000.0, 20000.0, 50000.0];
  Map<String, dynamic> toJson() => {
    'interests': interests.map((c) => c.name).toList(),
    'corridor': corridorMeters,
    'ahead': aheadMeters,
  };
  factory JourneyPreferences.fromJson(Map<String, dynamic> json) {
    final interests = PlaceCategory.values
        .where(
          (c) =>
              c != PlaceCategory.destination &&
              c != PlaceCategory.residential &&
              (json['interests'] as List? ?? []).contains(c.name),
        )
        .toSet();
    return JourneyPreferences(
      interests: interests.isEmpty
          ? const JourneyPreferences().interests
          : interests,
      corridorMeters: corridorOptions.contains(json['corridor'])
          ? (json['corridor'] as num).toDouble()
          : 2000,
      aheadMeters: aheadOptions.contains(json['ahead'])
          ? (json['ahead'] as num).toDouble()
          : 20000,
    );
  }
}

GeoBounds journeyBounds(RoadRoute route) {
  var south = 90.0, north = -90.0, west = 180.0, east = -180.0;
  for (final p in route.points) {
    south = math.min(south, p.lat);
    north = math.max(north, p.lat);
    west = math.min(west, p.lng);
    east = math.max(east, p.lng);
  }
  // 5 km corridor, with a conservative longitude margin for Maranhão.
  return GeoBounds(south - .05, west - .052, north + .05, east + .052);
}

class JourneyCandidate {
  const JourneyCandidate(this.place, this.projection, {this.islandAccess});
  final TourismPlace place;
  final RouteProjection projection;
  final IslandLandAccess? islandAccess;
  GeoPoint get point => islandAccess?.destination.point ?? place.point;
  TourismPlace get mapPlace => islandAccess == null
      ? place
      : TourismPlace.fromJson({
          ...place.toJson(),
          'lat': point.lat,
          'lng': point.lng,
        });
  double ahead(double progress) => math.max(0, projection.meters - progress);
  String reason(Set<String> saved) => saved.contains(place.id)
      ? 'Você salvou este lugar'
      : place.hasCoupon
      ? 'Parceiro com oferta publicada'
      : 'Combina com seus interesses';
}

/// Projections are reused across GPS ticks and catalog refreshes. No location
/// history or inferred personal profile is kept.
class JourneyIndex {
  RoadRoute? _route;
  final _cache = <(String, String?), JourneyCandidate>{};
  List<JourneyCandidate> candidates(
    RoadRoute route,
    List<TourismPlace> places, {
    Map<String, List<IslandLandAccess>> islandAccesses = const {},
  }) {
    if (!identical(_route, route)) {
      _route = route;
      _cache.clear();
    }
    final bounds = journeyBounds(route);
    final result = <JourneyCandidate>[];
    final currentIds = <(String, String?)>{};
    for (final place in places) {
      if (place.category == PlaceCategory.destination ||
          place.category == PlaceCategory.residential) {
        continue;
      }
      final accesses = place.isCoastalIsland
          ? islandAccesses[place.id] ?? const <IslandLandAccess>[]
          : const <IslandLandAccess?>[null];
      for (final access in accesses) {
        final point = access?.destination.point ?? place.point;
        if (!bounds.contains(point)) continue;
        final id = (place.id, access?.destination.id);
        currentIds.add(id);
        final old = _cache[id];
        final projection =
            old != null &&
                old.point.lat == point.lat &&
                old.point.lng == point.lng
            ? old.projection
            : projectOnRoute(point, route);
        final entry = JourneyCandidate(place, projection, islandAccess: access);
        _cache[id] = entry;
        if (projection.distanceToRoad <= 5000) result.add(entry);
      }
    }
    _cache.removeWhere((id, _) => !currentIds.contains(id));
    return result;
  }
}

/// Keep nearby suggestions and represent the municipalities along a long trip.
/// The full list remains available in the discovery panel.
List<JourneyCandidate> journeyHighlights(
  List<JourneyCandidate> entries, {
  int limit = 24,
}) {
  final selected = <String, JourneyCandidate>{};
  final cities = <String>{};
  for (final e in entries.take(8)) {
    selected[e.place.id] = e;
    cities.add(e.place.city);
  }
  for (final e in entries) {
    if (selected.length >= limit) break;
    if (cities.add(e.place.city)) selected[e.place.id] = e;
  }
  for (final e in entries) {
    if (selected.length >= limit) break;
    selected[e.place.id] = e;
  }
  return selected.values.take(limit).toList();
}

List<JourneyCandidate> recommendJourney(
  List<JourneyCandidate> candidates,
  JourneyPreferences preferences, {
  double progress = 0,
  bool traveling = false,
  JourneyMode mode = JourneyMode.interests,
  Set<String> saved = const {},
  String? destinationId,
}) {
  final filtered = candidates
      .where(
        (e) =>
            e.place.id != destinationId &&
            (destinationId == null ||
                e.islandAccess?.destination.id != destinationId) &&
            preferences.interests.contains(e.place.category) &&
            e.projection.distanceToRoad <= preferences.corridorMeters &&
            (!traveling ||
                (e.projection.meters >= progress &&
                    e.ahead(progress) <= preferences.aheadMeters)) &&
            (mode != JourneyMode.coupons ||
                (e.place.isPartner && e.place.hasCoupon)) &&
            (mode != JourneyMode.saved || saved.contains(e.place.id)),
      )
      .toList();
  double score(JourneyCandidate e) =>
      e.ahead(progress) +
      e.projection.distanceToRoad * 2 -
      (saved.contains(e.place.id) ? 1500 : 0) -
      (e.place.hasCoupon ? 750 : 0);
  filtered.sort((a, b) {
    final order = score(a).compareTo(score(b));
    return order == 0 ? a.place.id.compareTo(b.place.id) : order;
  });
  final shown = <String>{};
  return filtered.where((entry) => shown.add(entry.place.id)).toList();
}
