import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marapass_mapa/data/tourism_repository.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/application/map_state.dart';
import 'package:marapass_mapa/maps/native_maps.dart';
import 'package:marapass_mapa/terrain/elevation_data.dart';
import 'package:marapass_mapa/terrain/terrain_widgets.dart';
import 'package:marapass_mapa/presentation/map_screen.dart';

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
  testWidgets('ficha topográfica e mapa regional cabem em tela pequena', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    final repo = TourismRepository(
      await SharedPreferences.getInstance(),
      apiUrl: '',
      publishableKey: '',
    );
    await tester.runAsync(repo.initialize);
    final map = MapCoordinator(repo)
      ..engine(MapEngine.terrain)
      ..focus(const GeoPoint(-5.1, -45.1), 6);
    final place = repo.seed.firstWhere((p) => p.id == 'santo-amaro');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          mapStateProvider.overrideWith((ref) => map),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ListView(children: [PlaceElevation(place: place)]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Altitude estimada:'), findsOneWidget);
    await tester.tap(find.textContaining('Altitude estimada:'));
    await tester.pumpAndSettle();
    expect(find.textContaining('resolução da grade'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey('terrain-preview'),
        child: MaterialApp(
          home: Scaffold(
            body: MapCanvas(
              state: map.state,
              boundary: repo.boundary!,
              reference: repo.roads,
              terrainManifest: repo.terrainManifest,
              onFeature: (_) {},
              onViewport: (_, __) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Relevo regional'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    map.dispose();
  });
  testWidgets('seletor oferece relevo sem perder consulta de lugares', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = TourismRepository(
      await SharedPreferences.getInstance(),
      apiUrl: '',
      publishableKey: '',
    );
    await tester.runAsync(repo.initialize);
    final map = MapCoordinator(repo)..engine(MapEngine.essential);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          mapStateProvider.overrideWith((ref) => map),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Escolher mapa'));
    await tester.tap(find.text('Escolher mapa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relevo e altitude'));
    await tester.pumpAndSettle();
    expect(map.state.engine, MapEngine.terrain);
    expect(find.text('Relevo regional'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
