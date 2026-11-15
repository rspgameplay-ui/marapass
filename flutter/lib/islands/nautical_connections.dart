import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/tourism.dart';

/// Published connections are planning references, never a vessel routing graph.
class NauticalConnection {
  NauticalConnection.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['name'] as String,
      islandIds = (j['islandIds'] as List).cast<String>(),
      points = [
        for (final p in j['geometry']['coordinates'] as List)
          GeoPoint((p[1] as num).toDouble(), (p[0] as num).toDouble()),
      ],
      endpointNames = [
        for (final e in j['endpoints'] as List) e['name'] as String,
      ],
      authorizationUrl = j['authorizationUrl'] as String,
      serviceNote = j['serviceNote'] as String,
      durationNote = j['durationNote'] as String,
      documentedMinutes = j['durationMinutesInAuthorization'] as int;
  final String id, name, authorizationUrl, serviceNote, durationNote;
  final int documentedMinutes;
  final List<String> islandIds, endpointNames;
  final List<GeoPoint> points;
  // A documented line alone does not establish navigability, current service,
  // passenger access, depth, tide windows, or authorization of a particular boat.
  bool get canStartVesselNavigation => false;
}

class NauticalCatalog {
  NauticalCatalog.fromJson(Map<String, dynamic> j)
    : sourceUrl = j['sourceUrl'] as String,
      sourceEdition = j['sourceEdition'] as String,
      routes = [
        for (final r in j['routes'] as List)
          NauticalConnection.fromJson(Map<String, dynamic>.from(r as Map)),
      ];
  final String sourceUrl, sourceEdition;
  final List<NauticalConnection> routes;
  static Future<NauticalCatalog> load() async => NauticalCatalog.fromJson(
    jsonDecode(
      await rootBundle.loadString('assets/data/nautical_connections.json'),
    ) as Map<String, dynamic>,
  );
}
