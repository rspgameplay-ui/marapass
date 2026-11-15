import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/application/map_state.dart';
import 'package:marapass_mapa/journey/journey.dart';

import 'navigation_test.dart' show road;
import 'journey_test.dart' show poi;

void main() {
  final data = jsonDecode(
    File('assets/data/condominiums.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final places = (data['places'] as List)
      .map((j) => TourismPlace.fromJson(Map<String, dynamic>.from(j)))
      .toList();
  test('residential references are attributed, municipal, noncommercial and unique', () {
    expect(places.length, 448);
    expect(data['countsByMunicipality'].length, 8);
    expect(data['license'], 'ODbL-1.0');
    expect(places.map((p) => p.id).toSet().length, 448);
    for (final p in places) {
      expect(p.category, PlaceCategory.residential);
      expect(GeoBounds.maranhao.contains(p.point), isTrue);
      expect(p.municipalityId, startsWith('21'));
      expect(p.phone, isNull);
      expect(p.whatsapp, isNull);
      expect(p.hasCoupon, isFalse);
      expect(p.isPartner, isFalse);
      expect(p.sourceUrl, startsWith('https://www.openstreetmap.org/'));
    }
  });
  test(
    'optional layer is searchable and keeps saved properties accessible',
    () {
      expect(MapState(places: places).filtered, isEmpty);
      expect(
        MapState(
          places: places,
          category: PlaceCategory.residential,
        ).filtered.length,
        448,
      );
      final first = places.first;
      expect(
        MapState(places: places, query: first.name).filtered.map((p) => p.id),
        contains(first.id),
      );
      expect(
        MapState(
          places: places,
          savedOnly: true,
          saved: {first.id},
        ).filtered.map((p) => p.id),
        [first.id],
      );
      expect(
        MapState(
          places: places,
          category: PlaceCategory.residential,
          city: 'Barreirinhas',
        ).filtered.length,
        3,
      );
    },
  );
  test('private residential references do not become tourist discoveries', () {
    expect(
      JourneyIndex()
          .candidates(road(), [
            poi('Condomínio', category: PlaceCategory.residential),
            poi('Atrativo'),
          ])
          .map((c) => c.place.id),
      ['Atrativo'],
    );
  });
}
