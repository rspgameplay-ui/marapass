import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'base tem 217 códigos únicos, pontos com município e fonte rastreável',
    () {
      final cities = jsonDecode(
        File('assets/data/municipalities.json').readAsStringSync(),
      ) as List;
      final places = jsonDecode(
        File('assets/data/places.json').readAsStringSync(),
      ) as List;
      final codes = cities.map((m) => m['id']).toSet();
      expect(cities.length, 217);
      expect(codes.length, 217);
      expect(places.where((p) => p['cat'] == 'destination').length, 217);
      expect(places.map((p) => p['id']).toSet().length, places.length);
      final osm = places
          .where((p) => (p['id'] as String).startsWith('osm:'))
          .toList();
      expect(osm.length, 3991);
      for (final p in places) {
        expect(codes.contains(p['municipalityId']), isTrue);
        expect(p['sourceUrl'], startsWith('https://'));
      }
      for (final p in osm) {
        expect(p['isPartner'], isFalse);
        expect(p['dataSource'], contains('OpenStreetMap'));
        expect(p['checkedAt'], isIn(['2026-10-30', '2026-11-05', '2026-11-08', '2026-11-09']));
      }
      expect(osm.map((p) => p['municipalityId']).toSet().length, 146);
    },
  );
}
