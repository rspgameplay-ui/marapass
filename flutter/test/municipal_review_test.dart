import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marapass_mapa/application/map_state.dart';
import 'package:marapass_mapa/data/tourism_repository.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/presentation/municipal_visit_guide.dart';
import 'package:marapass_mapa/presentation/map_screen.dart';
import 'package:marapass_mapa/recording/recording_screen.dart';

void main() {
  test('catálogo e painel preservam os mesmos registros e corrigem lagoas', () {
    final asset = File('assets/data/places.json').readAsStringSync();
    expect(File('admin/data/places.json').readAsStringSync(), asset);
    final places = (jsonDecode(asset) as List)
        .map((p) => TourismPlace.fromJson(p))
        .toList();
    // 51 desde 09/11: inclui a Praia de Travosa.
    expect(places.where((p) => p.city == 'Santo Amaro do Maranhão').length, 51);
    expect(places.where((p) => p.city == 'Primeira Cruz').length, 6);
    for (final id in ['osm:node:5201075226', 'osm:node:5176384366']) {
      final place = places.firstWhere((p) => p.id == id);
      expect(place.category, PlaceCategory.nature);
      expect(place.needsVisitPlanning, isTrue);
      expect(place.sourceUrl, startsWith('https://'));
    }
  });
  for (final city in ['Santo Amaro do Maranhão', 'Primeira Cruz']) {
    testWidgets('guia de $city filtra o mapa e cabe em celular', (
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
        ..engine(MapEngine.essential)
        ..query('busca anterior');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            mapStateProvider.overrideWith((ref) => map),
          ],
          child: MaterialApp(
            home: Scaffold(body: MunicipalVisitGuide(city: city)),
          ),
        ),
      );
      await tester.tap(find.text('Guia de $city'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(city == 'Primeira Cruz' ? 'Lagoa da Areia' : 'Betânia'),
        100,
      );
      expect(
        find.text(city == 'Primeira Cruz' ? 'Lagoa da Areia' : 'Betânia'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Explorar locais deste município'),
        250,
      );
      await tester.tap(find.text('Explorar locais deste município'));
      await tester.pumpAndSettle();
      expect(map.state.city, city);
      expect(map.state.query, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ficha natural mantém planejamento e não oferece Waze direto', (
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
        child: MaterialApp(
          home: Scaffold(
            body: PlaceDetails(
              place: repo.seed.firstWhere((p) => p.id == 'osm:node:5201075226'),
              onFocus: () {},
              onNavigate: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Planejar visita'), findsOneWidget);
    expect(find.text('Abrir Waze'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('gravador apresenta controles com texto ampliado no celular', (
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
    final map = MapCoordinator(repo)..engine(MapEngine.essential);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          mapStateProvider.overrideWith((ref) => map),
        ],
        child: const MaterialApp(home: RecordingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Iniciar gravação'), 200);
    expect(find.text('Iniciar gravação'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
