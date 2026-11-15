import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../domain/tourism.dart';
import '../domain/municipality.dart';
import '../maps/reference_roads.dart';
import 'published_catalog.dart';
import '../terrain/elevation_data.dart';
import '../islands/coastal_island.dart';
import '../islands/island_land_access.dart';

class CatalogResult {
  const CatalogResult(
    this.places, {
    this.error = false,
    this.truncated = false,
  });
  final List<TourismPlace> places;
  final bool error, truncated;
}

class TourismRepository {
  TourismRepository(
    this.preferences, {
    http.Client? client,
    this.apiUrl = AppConfig.supabaseUrl,
    this.publishableKey = AppConfig.publishableKey,
  }) : client = client ?? http.Client();
  final SharedPreferences preferences;
  final http.Client client;
  final String apiUrl, publishableKey;
  late List<TourismPlace> seed;
  late final publishedCatalog = PublishedCatalog(
    client,
    preferences,
    apiUrl,
    publishableKey,
  );
  List<CoastalIsland> coastalIslands = [];
  Map<String, List<IslandLandAccess>> islandAccesses = const {};
  List<TourismPlace> condominiums = [];
  List<TourismPlace> get basePlaces => {
    for (final p in seed) p.id: p,
    for (final p in condominiums) p.id: p,
    for (final i in coastalIslands) i.place.id: i.place,
  }.values.toList();
  List<Municipality> municipalities = [];
  Map<String, dynamic>? boundary;
  Map<String, dynamic>? municipalBoundaries;
  Map<String, dynamic>? sourceManifest;
  ReferenceRoadNetwork? roads;
  ElevationData? elevations;
  Map<String, dynamic>? terrainManifest;
  Future<void> initialize() async {
    publishedCatalog.restoreCache();
    final raw = jsonDecode(
      await rootBundle.loadString('assets/data/places.json'),
    ) as List;
    seed = raw
        .map((j) => TourismPlace.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    final residential = jsonDecode(
      await rootBundle.loadString('assets/data/condominiums.json'),
    );
    condominiums = (residential['places'] as List)
        .map((p) => TourismPlace.fromJson(Map<String, dynamic>.from(p)))
        .toList();
    final islands = jsonDecode(
      await rootBundle.loadString('assets/data/coastal_islands.json'),
    ) as Map<String, dynamic>;
    coastalIslands = (islands['islands'] as List)
        .map((j) => CoastalIsland.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    final accesses = jsonDecode(
      await rootBundle.loadString('assets/data/island_land_access.json'),
    ) as Map<String, dynamic>;
    islandAccesses = {
      for (final entry in accesses.entries)
        entry.key: [
          for (final access in entry.value as List)
            IslandLandAccess.fromJson(access as Map<String, dynamic>),
        ],
    };
    elevations = ElevationData(
      jsonDecode(await rootBundle.loadString('assets/data/elevations.json'))
          as Map<String, dynamic>,
    );
    terrainManifest = jsonDecode(
      await rootBundle.loadString('assets/data/terrain_manifest.json'),
    ) as Map<String, dynamic>;
    municipalities =
        (jsonDecode(
              await rootBundle.loadString('assets/data/municipalities.json'),
            ) as List)
            .map((j) => Municipality.fromJson(Map<String, dynamic>.from(j)))
            .toList();
    municipalBoundaries = jsonDecode(
      await rootBundle.loadString('assets/map/municipalities.geojson'),
    ) as Map<String, dynamic>;
    sourceManifest = jsonDecode(
      await rootBundle.loadString('assets/data/source_manifest.json'),
    ) as Map<String, dynamic>;
    boundary = jsonDecode(
      await rootBundle.loadString('assets/map/maranhao.geojson'),
    ) as Map<String, dynamic>;
    roads = ReferenceRoadNetwork(
      jsonDecode(await rootBundle.loadString('assets/map/roads_reference.json'))
          as Map<String, dynamic>,
      boundary!,
    );
  }

  List<TourismPlace> cachedPartners() {
    try {
      return (jsonDecode(preferences.getString('public_partners_v1') ?? '[]')
              as List)
          .map((j) => TourismPlace.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _get(
    String table,
    Map<String, String> params,
  ) async {
    final uri = Uri.parse('$apiUrl/rest/v1/$table')
        .replace(queryParameters: params);
    final r = await client
        .get(uri, headers: {'apikey': publishableKey})
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) {
      throw http.ClientException('Catálogo indisponível (${r.statusCode})');
    }
    return (jsonDecode(r.body) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<CatalogResult> fetchVisible(GeoBounds bounds) async {
    if (apiUrl.isEmpty || publishableKey.isEmpty) {
      return const CatalogResult([]);
    }
    try {
      final rows = await _get('establishments', {
        'select': 'id,name,description,category,city,latitude,longitude,street_address',
        'is_active': 'eq.true',
        'is_public': 'eq.true',
        'state_code': 'eq.MA',
        'and':
            '(latitude.gte.${bounds.south},latitude.lte.${bounds.north},longitude.gte.${bounds.west},longitude.lte.${bounds.east})',
        'order': 'id.asc',
        'limit': '501',
      });
      if (rows.isEmpty) {
        return const CatalogResult([]);
      }
      final visible = rows.take(500).toList();
      List<Map<String, dynamic>> offers = [];
      var offersFresh = true;
      var offersTruncated = false;
      try {
        for (var start = 0; start < visible.length; start += 100) {
          final ids = visible
              .skip(start)
              .take(100)
              .map((r) => r['id'])
              .join(',');
          final batch = await _get('offers', {
            'select': 'id,establishment_id,title,starts_at,ends_at',
            'establishment_id': 'in.($ids)',
            'is_published': 'eq.true',
            'order': 'id.asc',
            'limit': '1000',
          });
          offersTruncated = offersTruncated || batch.length >= 1000;
          offers.addAll(batch);
        }
      } catch (_) {
        offersFresh = false;
      }
      final now = DateTime.now();
      final active = <String, Map<String, dynamic>>{};
      for (final o in offers) {
        final start = DateTime.tryParse(o['starts_at'] as String? ?? '');
        final end = DateTime.tryParse(o['ends_at'] as String? ?? '');
        if ((o['starts_at'] != null && start == null) ||
            (o['ends_at'] != null && end == null) ||
            (o['id'] as String? ?? '').trim().isEmpty ||
            (o['title'] as String? ?? '').trim().isEmpty)
          continue;
        if ((start == null || !start.isAfter(now)) &&
            (end == null || end.isAfter(now))) {
          active.putIfAbsent(o['establishment_id'] as String, () => o);
        }
      }
      final places = visible.map((r) {
        final o = active[r['id']];
        return TourismPlace(
          id: r['id'] as String,
          name: r['name'] as String,
          city: r['city'] as String,
          point: GeoPoint(
            double.parse('${r['latitude']}'),
            double.parse('${r['longitude']}'),
          ),
          category: PlaceCategory.parse(r['category'] as String),
          description: r['description'] as String? ?? '',
          address: r['street_address'] as String?,
          isPartner: true,
          referenceLocation: false,
          offersFresh: offersFresh,
          offerTitle: o?['title'] as String?,
          offerId: o?['id'] as String?,
          offerStartsAt: DateTime.tryParse(o?['starts_at'] as String? ?? ''),
          offerEndsAt: DateTime.tryParse(o?['ends_at'] as String? ?? ''),
          offerCheckedAt: offersFresh ? now : null,
        );
      }).toList();
      // Só dados públicos próprios. Benefícios do cache nunca são tratados como vigentes.
      final cache = {
        for (final p in cachedPartners()) p.id: p,
        for (final p in places) p.id: p,
      };
      await preferences.setString(
        'public_partners_v1',
        jsonEncode(cache.values.take(1000).map((p) => p.toJson()).toList()),
      );
      return CatalogResult(
        places,
        truncated: rows.length > 500 || offersTruncated,
      );
    } catch (_) {
      return const CatalogResult([], error: true);
    }
  }
}
