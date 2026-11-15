import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marapass_mapa/application/map_state.dart';
import 'package:marapass_mapa/application/navigation_session.dart';
import 'package:marapass_mapa/data/tourism_repository.dart';
import 'package:marapass_mapa/data/routing_repository.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/islands/coastal_island.dart';
import 'package:marapass_mapa/islands/island_directory.dart';
import 'package:marapass_mapa/islands/island_land_access.dart';
import 'package:marapass_mapa/journey/journey.dart';
import 'package:marapass_mapa/location/ahead_filter.dart';

import 'navigation_test.dart' show road;

import 'package:marapass_mapa/presentation/map_screen.dart';
import 'package:marapass_mapa/presentation/navigation_screen.dart';

Future<TourismRepository> repository(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final r = TourismRepository(
    await SharedPreferences.getInstance(),
    apiUrl: '',
    publishableKey: '',
  );
  await tester.runAsync(r.initialize);
  return r;
}

void main() {
  test('catálogo insular mantém origem, IDs únicos e não classifica empresas por nome', () {
    final j = jsonDecode(
      File('assets/data/coastal_islands.json').readAsStringSync(),
    );
    final islands = (j['islands'] as List)
        .map((x) => CoastalIsland.fromJson(x))
        .toList();
    expect(j['inventoryComplete'], isFalse);
    expect(islands.length, greaterThanOrEqualTo(30));
    expect(islands.map((i) => i.place.id).toSet().length, islands.length);
    for (final i in islands) {
      expect(i.place.isCoastalIsland, isTrue);
      expect(i.place.needsVisitPlanning, isTrue);
      expect(i.place.isPartner, isFalse);
      expect(i.place.hasCoupon, isFalse);
      expect(i.sources, isNotEmpty);
      for (final r in i.rings) {
        expect(r.length, greaterThan(3));
        expect(r.first.lat, r.last.lat);
        expect(r.first.lng, r.last.lng);
      }
    }
    final old =
        jsonDecode(File('assets/data/places.json').readAsStringSync()) as List;
    expect(
      TourismPlace.fromJson(
        old.firstWhere((p) => p['name'] == 'Hotel Ilha Costeira'),
      ).isCoastalIsland,
      isFalse,
    );
    final sao = islands.singleWhere(
      (i) => i.place.id == 'osm:relation:10037013',
    );
    expect(sao.matches('Ilha do Maranhão'), isTrue);
    expect(sao.matches('Upaon Acu'), isTrue);
  });
  testWidgets(
    'ilhas persistem em atualização sem perder cadastros e abrangem quatro municípios',
    (tester) async {
      final repo = await repository(tester);
      expect(repo.seed.length, greaterThanOrEqualTo(4217));
      expect(
        repo.basePlaces.map((p) => p.id).toSet().length,
        repo.basePlaces.length,
      );
      expect(
        repo.basePlaces
            .map((p) => p.id)
            .toSet()
            .containsAll(repo.seed.map((p) => p.id)),
        isTrue,
      );
      expect(repo.basePlaces.where((p) => p.id == 'ilha-lencois').length, 1);
      final m = MapCoordinator(repo)..islandsOnly(true);
      expect(m.state.filtered.length, repo.coastalIslands.length);
      await m.refresh();
      expect(m.state.filtered.length, repo.coastalIslands.length);
      m.query('Upaon Acu');
      expect(m.state.filtered.single.id, 'osm:relation:10037013');
      m.query('');
      m.setFilters(city: 'Raposa');
      expect(
        m.state.filtered.any((p) => p.id == 'osm:relation:10037013'),
        isTrue,
      );
      m.resetFilters();
      expect(m.state.islandsOnly, isFalse);
      m.dispose();
    },
  );
  testWidgets(
    'busca e seleção de Canárias funcionam em celular com texto ampliado',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = await repository(tester);
      TourismPlace? selected;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Builder(
              builder: (c) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    selected = await Navigator.push<TourismPlace>(
                      c,
                      MaterialPageRoute(
                        builder: (_) => const IslandDirectory(),
                      ),
                    );
                  },
                  child: const Text('Explorar'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Explorar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Canárias');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ilha das Canárias'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ilha das Canárias'));
      await tester.pumpAndSettle();
      expect(selected?.id, 'geonames:3403422');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('entrada Ilhas ativa mapa e permite remover filtro', (
    tester,
  ) async {
    final repo = await repository(tester);
    final m = MapCoordinator(repo)..engine(MapEngine.essential);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          mapStateProvider.overrideWith((ref) => m),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ilhas do litoral'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver ilhas no mapa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver ilhas no mapa'));
    await tester.pumpAndSettle();
    expect(m.state.islandsOnly, isTrue);
    expect(m.state.engine, MapEngine.streets);
    expect(m.state.filtered.length, repo.coastalIslands.length);
    await tester.tap(find.byTooltip('Mostrar todos os lugares'));
    await tester.pumpAndSettle();
    expect(m.state.islandsOnly, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('a direção e a rota usam o acesso da ilha em vez do seu marcador', () {
    const start = GeoPoint(-2.53, -44.295);
    final island = TourismPlace(
      id: 'ilha',
      name: 'Ilha de teste',
      city: 'São Luís',
      description: '',
      point: const GeoPoint(-2.53, -44.299),
      category: PlaceCategory.nature,
      tags: 'marapass:coastal_island',
    );
    IslandLandAccess access(String id, double lng) =>
        IslandLandAccess.fromJson({
          'id': id,
          'name': id,
          'city': 'São Luís',
          'lat': -2.53,
          'lng': lng,
          'accessSource': 'https://www.openstreetmap.org',
          'crossingSource': 'https://www.saoluis.ma.gov.br',
        });
    final passed = access('passado', -44.296);
    final upcoming = access('adiante', -44.290);
    expect(isAhead(start, island.point, 90), isFalse);
    expect(closestIslandAccess([passed, upcoming], start), passed);
    expect(
      closestIslandAccess(
        [passed, upcoming],
        start,
        accepts: (point) => isAhead(start, point, 90),
      ),
      upcoming,
    );
    final index = JourneyIndex();
    final route = road();
    expect(index.candidates(route, [island]), isEmpty);
    final candidates = index.candidates(
      route,
      [island],
      islandAccesses: {
        island.id: [passed, upcoming],
      },
    );
    final selected = recommendJourney(
      candidates,
      const JourneyPreferences(),
      progress: 700,
      traveling: true,
    ).single;
    expect(selected.islandAccess, upcoming);
    expect(selected.mapPlace.point.lng, upcoming.destination.point.lng);
    expect(
      recommendJourney(
        candidates,
        const JourneyPreferences(),
        progress: 1500,
        traveling: true,
      ),
      isEmpty,
    );
  });

  testWidgets('sem rumo, À frente aguarda e Todos próximos mostra as ilhas', (
    tester,
  ) async {
    final repo = await repository(tester);
    final map = MapCoordinator(repo)
      ..engine(MapEngine.essential)
      ..islandsOnly(true)
      ..setLocation(const GeoPoint(-2.72, -44.36));
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
    await tester.tap(find.text('Lugares'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aguardando o GPS identificar'), findsOneWidget);
    expect(find.text('Ilha Tauá-Mirim'), findsNothing);
    await tester.tap(find.text('Todos próximos'));
    await tester.pumpAndSettle();
    expect(find.text('Ilha Tauá-Mirim'), findsOneWidget);
    expect(find.text('Acesso por Porto do Coqueiro'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Tauá-Mirim oferece destino rodoviário no Coqueiro', (
    tester,
  ) async {
    final repo = await repository(tester);
    final island = repo.coastalIslands.singleWhere(
      (i) => i.place.name == 'Ilha Tauá-Mirim',
    );
    final access = repo.islandAccesses[island.place.id]!.single.destination;
    expect(access.point.lat, -2.7252595);
    expect(access.point.lng, -44.361824);
    expect(access.needsVisitPlanning, isFalse);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(home: NavigationScreen(destination: island.place)),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.text('Rota de carro até Porto do Coqueiro');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    final routes = tester.widgetList<NavigationScreen>(
      find.byType(NavigationScreen),
    );
    expect(routes.last.destination.id, access.id);
    expect(routes.last.roadOnly, isTrue);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ilha não dispara rota de carro com autoPlan', (tester) async {
    final repo = await repository(tester);
    var calls = 0;
    final r = RoutingRepository(
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 500);
      }),
    );
    final island = repo.coastalIslands.singleWhere(
      (i) => i.place.name == 'Ilha do Caju',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          routingRepositoryProvider.overrideWithValue(r),
        ],
        child: MaterialApp(
          home: NavigationScreen(destination: island.place, autoPlan: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Planejar visita'), findsOneWidget);
    expect(find.text('Calcular rota de carro'), findsNothing);
    expect(find.text('Visitar esta ilha'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    r.client.close();
  });
}
