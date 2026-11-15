import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marapass_mapa/domain/navigation.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/data/routing_repository.dart';
import 'package:marapass_mapa/application/navigation_session.dart';
import 'package:marapass_mapa/voice/drive_command.dart';

Map<String, dynamic> fixture() => jsonDecode(
  File('test/fixtures/route_sao_luis_barreirinhas.json').readAsStringSync(),
) as Map<String, dynamic>;
RoadRoute road() => RoadRoute(
  points: const [
    GeoPoint(-2.53, -44.30),
    GeoPoint(-2.53, -44.29),
    GeoPoint(-2.52, -44.29),
  ],
  steps: const [
    RoadStep(
      instruction: 'Siga',
      road: 'A',
      type: 'depart',
      modifier: 'straight',
      startMeters: 0,
      distance: 1112,
      duration: 100,
      point: GeoPoint(-2.53, -44.30),
    ),
    RoadStep(
      instruction: 'Vire à esquerda',
      road: 'B',
      type: 'turn',
      modifier: 'left',
      startMeters: 1110,
      distance: 1112,
      duration: 100,
      point: GeoPoint(-2.53, -44.29),
    ),
    RoadStep(
      instruction: 'Chegue ao destino',
      road: 'B',
      type: 'arrive',
      modifier: '',
      startMeters: 2220,
      distance: 0,
      duration: 0,
      point: GeoPoint(-2.52, -44.29),
    ),
  ],
  distance: 2224,
  duration: 200,
  summary: 'A, B',
  originSnap: 0,
  destinationSnap: 0,
);

void main() {
  test('Marapés reconhece pedidos naturais e exige confirmação explícita', () {
    expect(driveDestination('Marapés, mude o destino para Atins!'), 'atins');
    expect(
      driveDestination('Oi, Marapés, me leve até Barreirinhas.'),
      'barreirinhas',
    );
    expect(driveDestination('Troque a rota para Barreirinhas'), isNull);
    expect(confirmsDriveDestination('Sim!'), isTrue);
    expect(confirmsDriveDestination('Sim, mas espere'), isFalse);
    expect(cancelsDriveDestination('Mantenha a rota'), isTrue);
  });

  test(
    'mudança de destino mantém rota na falha e usa a posição atual no sucesso',
    () async {
      final calls = <Uri>[];
      final repository = RoutingRepository(
        client: MockClient((request) async {
          calls.add(request.url);
          return calls.length == 1
              ? http.Response('{"code":"NoRoute"}', 400)
              : http.Response(jsonEncode(fixture()), 200);
        }),
      );
      final oldRoute = road();
      const user = GeoPoint(-2.53, -44.299);
      const target = GeoPoint(-2.75, -42.83);
      final n = NavigationSession(repository)
        ..routes = [oldRoute]
        ..phase = NavigationPhase.navigating
        ..origin = oldRoute.points.first
        ..destination = oldRoute.points.last
        ..location = user;
      addTearDown(repository.client.close);
      addTearDown(n.dispose);
      expect(await n.changeDestination(target, roadOnly: false), isFalse);
      expect(calls, isEmpty);
      n.lastFix = DateTime.now();
      expect(await n.changeDestination(target, roadOnly: false), isFalse);
      expect(n.route, same(oldRoute));
      expect(await n.changeDestination(target, roadOnly: false), isTrue);
      expect(n.destination, same(target));
      expect(n.active, isTrue);
      expect(calls.last.pathSegments.last, '-44.299,-2.53;-42.83,-2.75');
    },
  );

  testWidgets('simulação recalcula da posição atual e continua na nova rota', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    Uri? requestUrl;
    final repository = RoutingRepository(
      client: MockClient((request) {
        requestUrl = request.url;
        return response.future;
      }),
    );
    final oldRoute = road();
    final n = NavigationSession(repository)
      ..routes = [oldRoute]
      ..destination = oldRoute.points.last
      ..phase = NavigationPhase.preview;
    addTearDown(repository.client.close);
    n.startSimulation();
    try {
      await tester.pump(const Duration(milliseconds: 800));
      final current = n.location!;
      expect(current.lng, greaterThan(oldRoute.points.first.lng));
      const target = GeoPoint(-2.75, -42.83);
      final change = n.changeDestination(target, roadOnly: false);
      await tester.pump(const Duration(seconds: 2));
      expect(n.route, same(oldRoute));
      expect(n.location, same(current));
      expect(
        requestUrl!.pathSegments.last,
        '${current.lng},${current.lat};-42.83,-2.75',
      );
      response.complete(http.Response(jsonEncode(fixture()), 200));
      await tester.pump();
      expect(await change, isTrue);
      expect(n.origin, same(current));
      expect(n.destination, same(target));
      final newRoute = n.route;
      expect(newRoute, isNot(same(oldRoute)));
      await tester.pump(const Duration(milliseconds: 800));
      expect(n.simulating, isTrue);
      expect(n.active, isTrue);
      expect(n.route, same(newRoute));
      expect(n.meters, greaterThan(0));
      expect(n.lastFix, isNull);
    } finally {
      n.dispose();
    }
  });

  test('rumo da câmera segue o trecho atual, inclusive na curva', () {
    final route = road();
    expect(route.bearingAt(0), closeTo(90, 0.01));
    expect(route.bearingAt(route.cumulative[1]), closeTo(0, 0.01));
    expect(route.bearingAt(route.geometryLength), closeTo(0, 0.01));
  });

  test('tempo restante acompanha a duração das etapas da rota', () {
    final json = fixture();
    final raw = (json['routes'] as List).first;
    final steps = (raw['legs'] as List).first['steps'] as List;
    for (final step in steps) {
      step['duration'] = 0;
    }
    steps.first['duration'] = 90;
    steps[1]['duration'] = 10;
    raw['duration'] = 100;
    final route = RoadRoute.fromOsrm(json, 0);
    final firstTurn = route.steps[1].startMeters;
    expect(firstTurn, greaterThan(0));
    expect(route.remainingDuration(0), 100);
    expect(route.remainingDuration(firstTurn / 2), closeTo(55, .001));
    expect(route.remainingDuration(firstTurn), closeTo(10, .001));
    expect(route.remainingDuration(route.geometryLength), 0);
  });

  test('falha ao planejar nova origem descarta a rota anterior', () async {
    final repository = RoutingRepository(
      client: MockClient((_) async => http.Response('{"code":"NoRoute"}', 400)),
    );
    final oldRoute = road();
    final n = NavigationSession(repository)
      ..routes = [oldRoute]
      ..origin = oldRoute.points.first
      ..destination = oldRoute.points.last
      ..phase = NavigationPhase.preview;
    addTearDown(n.dispose);
    addTearDown(repository.client.close);
    await n.calculate(const GeoPoint(-2.57, -44.30), oldRoute.points.last);
    expect(n.route, isNull);
    expect(n.phase, NavigationPhase.idle);
    expect(n.message, contains('ligação rodoviária'));
  });

  test(
    'novo cálculo aguarda o intervalo e usa os pontos solicitados',
    () async {
      final origins = <String>[];
      final repository = RoutingRepository(
        client: MockClient((request) async {
          origins.add(request.url.pathSegments.last.split(';').first);
          return http.Response(jsonEncode(fixture()), 200);
        }),
      );
      addTearDown(repository.client.close);
      const target = GeoPoint(-2.75, -42.83);
      await repository.routes(const GeoPoint(-2.53, -44.30), target);
      await repository.routes(const GeoPoint(-2.54, -44.31), target);
      expect(origins, ['-44.3,-2.53', '-44.31,-2.54']);
    },
  );

  test('geometria real São Luís–Barreirinhas tem manobras ordenadas e alternativas rodoviárias', () {
    final json = fixture();
    final route = RoadRoute.fromOsrm(json, 0);
    expect((json['routes'] as List).length, 2);
    expect(route.distance, greaterThan(250000));
    expect(route.points.length, greaterThan(100));
    expect(route.steps.length, 38);
    expect(route.steps.last.type, 'arrive');
    expect(route.steps.last.startMeters, closeTo(route.geometryLength, 1));
    for (var i = 1; i < route.steps.length; i++) {
      expect(
        route.steps[i].startMeters,
        greaterThanOrEqualTo(route.steps[i - 1].startMeters),
      );
    }
    expect(route.destinationSnap, lessThan(10));
  });
  test('projeção acompanha segmentos e mede desvio sem avançar em cruzamento distante', () {
    final r = road();
    final p = projectOnRoute(const GeoPoint(-2.53, -44.295), r);
    expect(p.meters, closeTo(555, 5));
    expect(p.distanceToRoad, lessThan(1));
    final off = projectOnRoute(const GeoPoint(-2.528, -44.295), r);
    expect(off.distanceToRoad, greaterThan(200));
    final restricted = projectOnRoute(r.points.last, r, maximum: 500);
    expect(restricted.meters, lessThan(1500));
  });
  test('GPS impreciso ou antigo não avança; chegada exige posição precisa e duas leituras', () {
    final n = NavigationSession(RoutingRepository());
    n.routes = [road()];
    n.phase = NavigationPhase.navigating;
    n.origin = n.route!.points.first;
    n.destination = n.route!.points.last;
    n.ingest(
      const GeoPoint(-2.53, -44.299),
      accuracyMeters: 100,
      timestamp: DateTime.now(),
    );
    expect(n.meters, 0);
    expect(n.lowSignal, isTrue);
    n.ingest(
      const GeoPoint(-2.53, -44.299),
      accuracyMeters: 10,
      timestamp: DateTime.now().subtract(const Duration(seconds: 30)),
    );
    expect(n.meters, 0);
    n.ingest(
      const GeoPoint(-2.53, -44.299),
      accuracyMeters: 10,
      timestamp: DateTime.now(),
    );
    expect(n.meters, greaterThan(90));
    for (final lng in [-44.296, -44.293, -44.29]) {
      n.ingest(
        GeoPoint(-2.53, lng),
        accuracyMeters: 8,
        timestamp: DateTime.now(),
      );
    }
    for (final lat in [-2.527, -2.524, -2.521, -2.52]) {
      n.ingest(
        GeoPoint(lat, -44.29),
        accuracyMeters: 8,
        timestamp: DateTime.now(),
      );
    }
    expect(n.phase, NavigationPhase.navigating);
    n.ingest(
      const GeoPoint(-2.52, -44.29),
      accuracyMeters: 8,
      timestamp: DateTime.now(),
    );
    expect(n.phase, NavigationPhase.arrived);
    n.dispose();
    n.repository.client.close();
  });
  test('API pede passos e geometria, limita encaixe em via e não inventa rota quando indisponível', () async {
    final repo = RoutingRepository(
      client: MockClient((request) async {
        expect(request.url.queryParameters['steps'], 'true');
        expect(request.url.queryParameters['radiuses'], '500;500');
        return http.Response(jsonEncode(fixture()), 200);
      }),
    );
    final r = await repo.routes(
      const GeoPoint(-2.53, -44.3),
      const GeoPoint(-2.75, -42.83),
    );
    expect(r.length, 2);
    final missing = RoutingRepository(
      client: MockClient(
        (_) async => http.Response('{"code":"NoSegment"}', 400),
      ),
    );
    await expectLater(
      missing.routes(
        const GeoPoint(-2.53, -44.3),
        const GeoPoint(-2.75, -42.83),
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('500 m'),
        ),
      ),
    );
    repo.client.close();
    missing.client.close();
  });
  test('desvio exige duas posições diferentes e falha de recálculo respeita intervalo sem inventar geometria', () async {
    var calls = 0;
    Uri? reroute;
    final repository = RoutingRepository(
      client: MockClient((request) async {
        calls++;
        reroute = request.url;
        return http.Response('{"code":"NoRoute"}', 400);
      }),
    );
    final n = NavigationSession(repository)
      ..routes = [road()]
      ..phase = NavigationPhase.navigating;
    n.origin = n.route!.points.first;
    n.destination = n.route!.points.last;
    final first = DateTime.now().subtract(const Duration(seconds: 1));
    const firstPoint = GeoPoint(-2.532, -44.299);
    for (var i = 0; i < 2; i++) {
      n.ingest(firstPoint, accuracyMeters: 8, timestamp: first);
    }
    expect(calls, 0);
    n.ingest(
      const GeoPoint(-2.5321, -44.298),
      accuracyMeters: 8,
      timestamp: first.add(const Duration(milliseconds: 700)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    expect(reroute?.pathSegments.last, '-44.298,-2.5321;-44.29,-2.52');
    expect(n.message, contains('ligação rodoviária'));
    expect(n.deviated, isTrue);
    expect(n.meters, 0);
    for (var i = 0; i < 6; i++) {
      n.ingest(
        const GeoPoint(-2.532, -44.299),
        accuracyMeters: 8,
        timestamp: DateTime.now(),
      );
    }
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    n.dispose();
    repository.client.close();
  });
  test('encerrar durante cálculo descarta resposta tardia', () async {
    final pending = Completer<http.Response>();
    final repository = RoutingRepository(
      client: MockClient((_) => pending.future),
    );
    final n = NavigationSession(repository);
    final calculation = n.calculate(
      const GeoPoint(-2.53, -44.3),
      const GeoPoint(-2.75, -42.83),
    );
    expect(n.phase, NavigationPhase.calculating);
    await n.pause();
    pending.complete(http.Response(jsonEncode(fixture()), 200));
    await calculation;
    expect(n.routes, isEmpty);
    expect(n.phase, NavigationPhase.idle);
    n.dispose();
    repository.client.close();
  });
  test('instruções em português distinguem retorno, rotatória e balsa', () {
    expect(
      maneuverInstruction({
        'name': 'BR-135',
        'maneuver': {'type': 'roundabout', 'exit': 2},
      }),
      contains('saída 2'),
    );
    expect(
      maneuverInstruction({
        'name': '',
        'maneuver': {'type': 'turn', 'modifier': 'uturn'},
      }),
      'Faça o retorno',
    );
    expect(
      maneuverInstruction({
        'name': '',
        'mode': 'ferry',
        'maneuver': {'type': 'notification'},
      }),
      contains('balsa'),
    );
  });
}
