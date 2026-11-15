import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marapass_mapa/application/map_state.dart';
import 'package:marapass_mapa/application/navigation_session.dart';
import 'package:marapass_mapa/data/beach_visit.dart';
import 'package:marapass_mapa/data/routing_repository.dart';
import 'package:marapass_mapa/data/tourism_repository.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/presentation/beach_visit_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const ponta = TourismPlace(
  id: pontaAreiaId,
  name: "Praia da Ponta d'Areia",
  city: 'São Luís',
  point: GeoPoint(-2.4969085, -44.3086571),
  category: PlaceCategory.nature,
  description: '',
  tags: 'marapass:beach',
);
const origin = GeoPoint(-2.53, -44.30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a previsão usa o horário de São Luís e expira no fim da tabela',
    () async {
      final forecast = (await SaoLuisTideForecast.load())!;
      final time = DateTime.parse('2026-11-15T08:00:00-03:00');
      final value = forecast.at(time)!;
      expect(value.height, inInclusiveRange(0, 8));
      expect(value.next.time.isAfter(time), isTrue);
      expect(saoLuisLocalTime(time).hour, 8);
      expect(forecast.at(DateTime.utc(2027, 1, 3)), isNull);
    },
  );

  test(
    'a balneabilidade diferencia os pontos e fica indisponível após sete dias',
    () {
      final [ramp, seawall, square] = beachAccesses(ponta);
      final sampled = DateTime.utc(2026, 11, 15, 11);
      expect(recentBathingResult(ramp, sampled), 'Próprio');
      expect(recentBathingResult(seawall, sampled), 'Próprio');
      expect(recentBathingResult(square, sampled), 'Impróprio');
      expect(recentBathingResult(ramp, DateTime.utc(2026, 11, 16, 3)), isNull);
      expect(ramp.verified, isFalse);
      expect(
        compassDirection(visitBearing(origin, const GeoPoint(-2.52, -44.30))),
        'N',
      );
    },
  );

  for (final failure in [null, 'offline', 'no-route']) {
    testWidgets(
      'Ponta d’Areia: ${failure ?? 'carregando e rota por acesso aproximado'}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = TourismRepository(prefs, apiUrl: '', publishableKey: '')
          ..seed = [ponta];
        final map = MapCoordinator(repo)..setLocation(origin);
        final response = Completer<http.Response>();
        final fixture = File('test/fixtures/route_sao_luis_barreirinhas.json')
            .readAsStringSync();
        final routing = RoutingRepository(
          client: MockClient((request) => response.future),
        );
        addTearDown(routing.client.close);
        GeoPoint? target;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              repositoryProvider.overrideWithValue(repo),
              mapStateProvider.overrideWith((ref) => map),
              routingRepositoryProvider.overrideWithValue(routing),
            ],
            child: MaterialApp(
              home: BeachVisitScreen(
                beach: ponta,
                onNavigate: (plan, arrival, profile) {
                  expect(arrival, same(plan.route.points.last));
                  expect(profile, RoutingProfile.driving);
                  target = arrival;
                },
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Calculando rota até o acesso…'), findsOneWidget);
        expect(find.text('Orientação até o acesso'), findsOneWidget);
        if (failure == 'offline') {
          response.completeError(http.ClientException('disconnected'));
        } else if (failure == 'no-route') {
          response.complete(http.Response('{"code":"NoRoute"}', 400));
        } else {
          response.complete(http.Response(fixture, 200));
        }
        await tester.pumpAndSettle();
        if (failure == null) {
          expect(find.text('Iniciar navegação'), findsOneWidget);
          await tester.tap(find.text('Iniciar navegação'));
          expect(target, isNotNull);
          expect(target, isNot(same(ponta.point)));
          await tester.dragFrom(const Offset(25, 730), const Offset(0, -530));
          await tester.pumpAndSettle();
          expect(find.text('Não verificado').hitTestable(), findsOneWidget);
          await tester.tap(find.text('Não verificado'));
          await tester.pumpAndSettle();
          expect(find.textContaining('a entrada para a praia'), findsOneWidget);
        } else {
          expect(
            find.text(
              failure == 'offline'
                  ? 'Conexão indisponível'
                  : 'Rota indisponível para este acesso',
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining('em linha reta (aproximada)'),
            findsOneWidget,
          );
          await tester.tap(find.text('Orientação até o acesso'));
          await tester.pumpAndSettle();
          expect(find.text('Atualizar localização'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }

  test('praia com acesso confirmado usa a entrada do catálogo', () {
    const beach = TourismPlace(
      id: 'praia-verificada',
      name: 'Praia de teste',
      city: 'São Luís',
      point: origin,
      category: PlaceCategory.nature,
      description: '',
      tags: 'marapass:beach',
      referenceLocation: false,
    );
    final access = beachAccesses(beach).single;
    expect(access.verified, isTrue);
    expect(access.point, same(origin));
  });

  test('rota baixada é reutilizada apenas perto de sua origem', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fixture = File('test/fixtures/route_sao_luis_barreirinhas.json')
        .readAsStringSync();
    final route = RoutingRepository(
      client: MockClient((request) async => http.Response(fixture, 200)),
    );
    addTearDown(route.client.close);
    final store = DownloadedVisitRoutes(prefs);
    final (plan, index) = await calculateVisitRoute(
      route,
      origin,
      beachAccesses(ponta).first,
      RoutingProfile.driving,
    );
    expect(await store.save('access-driving', plan, index), isTrue);
    expect(store.load('access-driving', origin)?.downloaded, isTrue);
    expect(store.load('access-driving', const GeoPoint(-2.52, -44.30)), isNull);
    expect(store.load('access-walking', origin), isNull);
  });
}
