import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/terrain/elevation_data.dart';

void main() {
  TourismPlace point(double lat) => TourismPlace(
    id: 'sample',
    name: 'Local',
    city: 'Santo Amaro do Maranhão',
    description: '',
    category: PlaceCategory.nature,
    point: GeoPoint(lat, -43),
  );
  test('zero é altitude válida; posição editada invalida a amostra', () {
    final data = ElevationData({
      'queriedAt': '2026-11-05',
      'points': {
        'sample': {'lat': -2, 'lng': -43, 'meters': 0},
      },
    });
    expect(data.at(point(-2)), 0);
    expect(data.at(point(-2.0001)), isNull);
    expect(
      ElevationData({
        'queriedAt': '2026-11-05',
        'points': {
          'sample': {'lat': -2, 'lng': -43, 'meters': null},
        },
      }).at(point(-2)),
      isNull,
    );
  });
  test(
    'amostras cobrem a base pública e mantêm coordenadas e ausência de dados',
    () {
      final places = jsonDecode(
        File('assets/data/places.json').readAsStringSync(),
      ) as List;
      final j = jsonDecode(
        File('assets/data/elevations.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final points = j['points'] as Map;
      expect(points.length, places.length);
      expect(j['resolutionMeters'], 30);
      for (final p in places) {
        expect(p['isPartner'] ?? false, isFalse);
        final sample = points[p['id']] as Map;
        expect(sample['lat'], p['lat']);
        expect(sample['lng'], p['lng']);
        final v = sample['meters'];
        expect(
          v == null || (v is num && v.isFinite && v > -500 && v < 9000),
          isTrue,
        );
      }
      final manifest = jsonDecode(
        File('assets/data/terrain_manifest.json').readAsStringSync(),
      );
      expect(manifest['tileZoom'], 8);
      expect(manifest['pixelSpacingMetersApprox'], greaterThan(600));
      expect(File('assets/map/terrain_ma.png').lengthSync(), greaterThan(1000));
    },
  );
}
