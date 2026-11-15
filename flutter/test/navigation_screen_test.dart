import 'dart:io';

import 'package:marapass_mapa/journey/journey_controller.dart';
import 'package:marapass_mapa/domain/tourism.dart';

import 'package:geolocator/geolocator.dart';
import 'package:marapass_mapa/location/location_service.dart';

import 'location_service_test.dart' show FakeLocation;
import 'navigation_test.dart' show road;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:marapass_mapa/navigation/traveler_marker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marapass_mapa/application/map_state.dart';
import 'package:marapass_mapa/application/navigation_session.dart';
import 'package:marapass_mapa/data/routing_repository.dart';
import 'package:marapass_mapa/data/tourism_repository.dart';
import 'package:marapass_mapa/presentation/navigation_screen.dart';

void main() {
  testWidgets('lagoa de referência não dispara rota de carro com autoPlan', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = TourismRepository(
      await SharedPreferences.getInstance(),
      apiUrl: '',
      publishableKey: '',
    );
    await tester.runAsync(repo.initialize);
    var requests = 0;
    final routing = RoutingRepository(
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 500);
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          routingRepositoryProvider.overrideWithValue(routing),
        ],
        child: MaterialApp(
          home: NavigationScreen(
            destination: repo.seed.firstWhere(
              (p) => p.id == 'osm:node:5201075226',
            ),
            autoPlan: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Planejar visita'), findsOneWidget);
    expect(find.text('Calcular rota de carro'), findsNothing);
    expect(requests, 0);
    expect(find.text('Guia de Santo Amaro do Maranhão'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    routing.client.close();
  });

  testWidgets('suspensão transitória não cancela a espera pelo GPS', (
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
    final gateway = FakeLocation()
      ..failure = const PermissionDeniedException('denied');
    final routing = RoutingRepository();
    addTearDown(routing.client.close);
    final plan = road();
    final navigation =
        NavigationSession(
            routing,
            locationService: LocationService(gateway: gateway),
          )
          ..routes = [plan]
          ..origin = plan.points.first
          ..destination = plan.points.last
          ..phase = NavigationPhase.preview;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          mapStateProvider.overrideWith((ref) => map),
          navigationProvider.overrideWith((ref) => navigation),
        ],
        child: MaterialApp(
          home: NavigationScreen(
            destination: repo.seed.firstWhere((p) => p.name == 'Barreirinhas'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    gateway.failure = null;
    await tester.ensureVisible(find.text('Iniciar com meu GPS'));
    await tester.tap(find.text('Iniciar com meu GPS'));
    await tester.pump();
    expect(navigation.starting, isTrue);
    final observer =
        tester.state(find.byType(NavigationScreen)) as WidgetsBindingObserver;
    observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await tester.pump();
    expect(navigation.starting, isTrue);
    expect(gateway.cancelled, 0);
    expect(find.text('Obtendo GPS…'), findsOneWidget);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(gateway.cancelled, 1);
  });

  testWidgets(
    'planejador calcula rota interna e mantém layout compacto com texto ampliado',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final repo = TourismRepository(
        await SharedPreferences.getInstance(),
        apiUrl: '',
        publishableKey: '',
      );
      await tester.runAsync(repo.initialize);
      final map = MapCoordinator(repo)..engine(MapEngine.essential);
      final data = File('test/fixtures/route_sao_luis_barreirinhas.json')
          .readAsStringSync();
      final routing = RoutingRepository(
        client: MockClient((_) async => http.Response(data, 200)),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            mapStateProvider.overrideWith((ref) => map),
            routingRepositoryProvider.overrideWithValue(routing),
            navigationProvider.overrideWith(
              (ref) => NavigationSession(
                routing,
                locationService: LocationService(
                  gateway: FakeLocation()
                    ..failure = const PermissionDeniedException('denied'),
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: NavigationScreen(
              destination: repo.seed.firstWhere(
                (p) => p.name == 'Barreirinhas',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Localização indisponível'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'São Luís');
      await tester.pumpAndSettle();
      await tester.tap(find.text('São Luís').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calcular rota de carro'));
      await tester.pumpAndSettle();
      expect(find.text('255 km'), findsOneWidget);
      expect(find.text('Iniciar com meu GPS'), findsOneWidget);
      expect(find.textContaining('Chegada estimada às'), findsOneWidget);
      await tester.tap(find.byTooltip('Ver instruções'));
      await tester.pumpAndSettle();
      expect(find.text('Instruções do percurso'), findsOneWidget);
      Navigator.of(tester.element(find.text('Instruções do percurso'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Personalizar descobertas').first);
      await tester.pumpAndSettle();
      expect(find.text('Sua viagem, do seu jeito'), findsOneWidget);
      for (final label in [
        'Natureza',
        'Passeios',
        'Gastronomia',
        'Artesanato',
      ]) {
        await tester.tap(find.widgetWithText(FilterChip, label));
      }
      await tester.ensureVisible(find.text('Aplicar preferências'));
      await tester.tap(find.text('Aplicar preferências'));
      await tester.pumpAndSettle();
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(NavigationScreen)),
      );
      expect(scope.read(journeyProvider).preferences.interests, {
        PlaceCategory.culture,
      });
      await tester.ensureVisible(find.text('Descobertas no caminho'));
      await tester.tap(find.text('Descobertas no caminho'));
      await tester.pumpAndSettle();
      expect(find.text('Seu caminho, suas descobertas'), findsOneWidget);
      expect(find.textContaining('lugares nesta seleção'), findsOneWidget);
      await tester.tap(find.text('Cupons'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nenhum cupom publicado e confirmado nesta seleção.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Fechar descobertas'));
      await tester.pumpAndSettle();
      final navigation = scope.read(navigationProvider);
      await tester.ensureVisible(find.text('Simular percurso sem GPS'));
      await tester.tap(find.text('Simular percurso sem GPS'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(navigation.active, isTrue);
      expect(find.byTooltip('Reportar ocorrência nesta sessão'), findsNothing);
      final mapController = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      expect(
        normalizeHeading(mapController.camera.rotation),
        closeTo(normalizeHeading(-navigation.cameraBearing!), .01),
      );
      expect(
        tester.widget<TravelerMarker>(find.byType(TravelerMarker)).heading,
        0,
      );
      navigation.setFollow(false);
      await tester.pump();
      await tester.tap(find.text('Voltar à rota'));
      await tester.pump();
      expect(navigation.follow, isTrue);
      await tester.ensureVisible(find.text('Encerrar'));
      await tester.tap(find.text('Encerrar'));
      await tester.pumpAndSettle();
      expect(navigation.active, isFalse);
      await tester.ensureVisible(find.text('Iniciar com meu GPS'));
      await tester.tap(find.text('Iniciar com meu GPS'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Localização não autorizada.'),
        findsOneWidget,
      );
      expect(find.text('Como liberar a localização'), findsOneWidget);
      await tester.tap(find.text('Como liberar a localização'));
      await tester.pumpAndSettle();
      expect(find.text('Copiar link do mapa'), findsOneWidget);
      Navigator.of(tester.element(find.text('Copiar link do mapa'))).pop();
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(320, 740);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      routing.client.close();
    },
  );
}
