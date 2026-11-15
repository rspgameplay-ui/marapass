import 'dart:math' as math;

import 'package:flutter/material.dart';

enum PlaceCategory {
  destination('Destinos', Icons.location_city_outlined, 0xff223449),
  services('Serviços úteis', Icons.local_gas_station_outlined, 0xff68768b),
  nature('Natureza', Icons.landscape_outlined, 0xff2b9353),
  culture('Cultura', Icons.account_balance_outlined, 0xff82634a),
  gastronomy('Gastronomia', Icons.restaurant_outlined, 0xffde514e),
  lodging('Hospedagem', Icons.bed_outlined, 0xff8564b5),
  tours('Passeios', Icons.explore_outlined, 0xff307ee9),
  events('Eventos', Icons.event_outlined, 0xffa55585),
  crafts('Artesanato', Icons.handyman_outlined, 0xffa87817),
  photography('Fotografia', Icons.camera_alt_outlined, 0xff6b7192),
  residential('Condomínios', Icons.apartment_outlined, 0xff68768b),
  transport('Transporte', Icons.directions_bus_outlined, 0xff527879);

  const PlaceCategory(this.label, this.icon, this.argb);
  final String label;
  final IconData icon;
  final int argb;
  Color get color => Color(argb);
  static PlaceCategory parse(String value) => switch (value) {
    'services' => services,
    'residential' => residential,
    'nature' => nature,
    'culture' => culture,
    'gastronomy' => gastronomy,
    'lodging' => lodging,
    'tours' => tours,
    'events' => events,
    'crafts' => crafts,
    'photography' => photography,
    'tourist_transport' => transport,
    'transport' => transport,
    _ => destination,
  };
}

class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat, lng;
  double distanceKm(GeoPoint other) {
    double rad(double v) => v * math.pi / 180;
    final a =
        math.pow(math.sin(rad(other.lat - lat) / 2), 2) +
        math.cos(rad(lat)) *
            math.cos(rad(other.lat)) *
            math.pow(math.sin(rad(other.lng - lng) / 2), 2);
    return 6371 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a.clamp(0, 1)));
  }
}

class GeoBounds {
  const GeoBounds(this.south, this.west, this.north, this.east);
  static const maranhao = GeoBounds(-10.3, -48.6, -1.0, -41.7);
  final double south, west, north, east;
  bool contains(GeoPoint p) =>
      p.lat >= south && p.lat <= north && p.lng >= west && p.lng <= east;
}

class TourismPlace {
  const TourismPlace({
    required this.id,
    required this.name,
    required this.city,
    required this.point,
    required this.category,
    required this.description,
    this.area,
    this.municipalityId,
    this.dataSource,
    this.checkedAt,
    this.address,
    this.website,
    this.hours,
    this.tags,
    this.searchAliases = const [],
    this.sourceUrl,
    this.googlePlaceId,
    this.photoUrl,
    this.phone,
    this.whatsapp,
    this.offerTitle,
    this.offerId,
    this.offerStartsAt,
    this.offerCheckedAt,
    this.offerEndsAt,
    this.offersFresh = false,
    this.isPartner = false,
    this.referenceLocation = true,
  });
  final String id, name, city, description;
  final GeoPoint point;
  final PlaceCategory category;
  final String? area,
      sourceUrl,
      photoUrl,
      phone,
      whatsapp,
      offerTitle,
      offerId,
      googlePlaceId;
  final String? address,
      website,
      hours,
      tags,
      municipalityId,
      dataSource,
      checkedAt;
  final DateTime? offerEndsAt, offerStartsAt, offerCheckedAt;
  final bool offersFresh, isPartner, referenceLocation;
  final List<String> searchAliases;
  bool get isBeach => tags?.split(';').contains('marapass:beach') ?? false;
  bool get isCoastalIsland =>
      tags?.split(';').contains('marapass:coastal_island') ?? false;
  bool get needsVisitPlanning =>
      isCoastalIsland ||
      (isBeach && referenceLocation) ||
      const {
        'osm:way:14436547',
        'osm:node:5024408266',
        'cabure',
        'lagoa-gaivota',
        'osm:node:5201075226',
        'osm:node:9977348717',
        'osm:way:594270795',
        'osm:way:594276706',
        'osm:relation:7458131',
        'osm:node:5201075303',
        'osm:node:5201075582',
        'osm:node:5176384366',
      }.contains(id);
  bool get hasCoupon => hasCouponAt(DateTime.now());
  bool hasCouponAt(DateTime now) =>
      isPartner &&
      offersFresh &&
      (offerId?.trim().isNotEmpty ?? false) &&
      (offerTitle?.trim().isNotEmpty ?? false) &&
      offerCheckedAt != null &&
      !offerCheckedAt!.isAfter(now) &&
      now.difference(offerCheckedAt!).inSeconds < 90 &&
      (offerStartsAt == null || !offerStartsAt!.isAfter(now)) &&
      (offerEndsAt == null || offerEndsAt!.isAfter(now));
  factory TourismPlace.fromJson(Map<String, dynamic> j) => TourismPlace(
    id: j['id'] as String,
    name: j['name'] as String,
    city: j['city'] as String,
    point: GeoPoint((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
    category: PlaceCategory.parse(j['cat'] as String),
    description: j['description'] as String? ?? '',
    area: j['area'] as String?,
    municipalityId: j['municipalityId'] as String?,
    dataSource: j['dataSource'] as String?,
    checkedAt: j['checkedAt'] as String?,
    address: j['address'] as String?,
    website: j['website'] as String?,
    hours: j['hours'] as String?,
    tags: j['tags'] as String?,
    searchAliases:
        (j['searchAliases'] as List?)?.whereType<String>().toList() ?? const [],
    sourceUrl: j['sourceUrl'] as String?,
    googlePlaceId: validGooglePlaceId(j['googlePlaceId'])
        ? j['googlePlaceId'] as String
        : null,
    photoUrl: j['photoUrl'] as String?,
    phone: j['phone'] as String?,
    whatsapp: j['whatsapp'] as String?,
    offerTitle: j['offerTitle'] as String?,
    offerId: j['offerId'] as String?,
    offerStartsAt: DateTime.tryParse(j['offerStartsAt'] as String? ?? ''),
    offerCheckedAt: DateTime.tryParse(j['offerCheckedAt'] as String? ?? ''),
    offerEndsAt: DateTime.tryParse(j['offerEndsAt'] as String? ?? ''),
    offersFresh: j['offersFresh'] == true,
    isPartner: j['isPartner'] == true,
    referenceLocation: j['referenceLocation'] != false,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'city': city,
    'lat': point.lat,
    'lng': point.lng,
    'cat': category == PlaceCategory.transport
        ? 'tourist_transport'
        : category.name,
    'description': description,
    'area': area,
    'municipalityId': municipalityId,
    'dataSource': dataSource,
    'checkedAt': checkedAt,
    'address': address,
    'website': website,
    'hours': hours,
    'tags': tags,
    'searchAliases': searchAliases,
    'sourceUrl': sourceUrl,
    'googlePlaceId': googlePlaceId,
    'photoUrl': photoUrl,
    'phone': phone,
    'whatsapp': whatsapp,
    'offerTitle': offerTitle,
    'offerId': offerId,
    'offerStartsAt': offerStartsAt?.toIso8601String(),
    'offerCheckedAt': offerCheckedAt?.toIso8601String(),
    'offerEndsAt': offerEndsAt?.toIso8601String(),
    'offersFresh': false,
    'isPartner': isPartner,
    'referenceLocation': referenceLocation,
  };
}

bool validGooglePlaceId(Object? value) =>
    value is String && RegExp(r'^[A-Za-z0-9_-]{8,255}$').hasMatch(value);

String normalize(String text) {
  const a = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const b = 'aaaaaeeeeiiiiooooouuuuc';
  var s = text.toLowerCase();
  for (var i = 0; i < a.length; i++) {
    s = s.replaceAll(a[i], b[i]);
  }
  return s;
}

class MapFeature {
  const MapFeature(this.id, this.point, this.places);
  final String id;
  final GeoPoint point;
  final List<TourismPlace> places;
  bool get isCluster => places.length > 1;
}

// Agrupa pela distância visual, inclusive entre células vizinhas e em zoom alto.
// Os pontos coincidentes continuam acessíveis pela lista do agrupamento.
List<MapFeature> clusterPlaces(
  List<TourismPlace> places,
  double zoom, {
  String? selectedId,
}) {
  final world = 256 * math.pow(2, zoom);
  final radius = zoom < 10
      ? 104.0
      : zoom < 14
      ? 92.0
      : zoom < 15
      ? 56.0
      : 38.0;
  final cells = <String, List<int>>{};
  final anchors = <({double x, double y})>[];
  final groups = <List<TourismPlace>>[];
  final entries = places.where((p) => p.id != selectedId).toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  for (final p in entries) {
    final sin = math.sin(p.point.lat * math.pi / 180).clamp(-.9999, .9999);
    final x = (p.point.lng + 180) / 360 * world;
    final y = (.5 - math.log((1 + sin) / (1 - sin)) / (4 * math.pi)) * world;
    final cx = (x / radius).floor(), cy = (y / radius).floor();
    int? nearest;
    var distance = radius * radius;
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final j in cells['${cx + dx}:${cy + dy}'] ?? <int>[]) {
          final px = x - anchors[j].x, py = y - anchors[j].y;
          final squared = px * px + py * py;
          if (squared < distance) {
            nearest = j;
            distance = squared;
          }
        }
      }
    }
    if (nearest == null) {
      cells.putIfAbsent('$cx:$cy', () => []).add(groups.length);
      anchors.add((x: x, y: y));
      groups.add([p]);
    } else {
      groups[nearest].add(p);
    }
  }
  return [
    for (final list in groups)
      MapFeature(
        list.length == 1 ? list.first.id : 'cluster:${list.first.id}',
        list.first.point,
        list,
      ),
    for (final p in places.where((p) => p.id == selectedId))
      MapFeature(p.id, p.point, [p]),
  ];
}
