import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:marapass_mapa/location/location_service.dart';
import 'package:marapass_mapa/application/navigation_session.dart';
import 'package:marapass_mapa/data/routing_repository.dart';

import 'helpers.dart' show road;

Position fix({double accuracy = 8, bool stale = false}) => Position(
  longitude: -44.3,
  latitude: -2.53,
  timestamp: DateTime.now().subtract(Duration(seconds: stale ? 60 : 0)),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class FakeLocation implements LocationGateway {
  Object? failure;
  int cancelled = 0;
  final streams = <StreamController<Position>>[];
  @override
  Future<void> authorize() async {
    if (failure != null) throw failure!;
  }

  @override
  Stream<Position> updates() {
    final c = StreamController<Position>(
      onCancel: () {
        cancelled++;
      },
    );
    streams.add(c);
    return c.stream;
  }
}

void main() {
  test(
    'planejamento aceita uma origem aproximada antes do GPS preciso',
    () async {
      final gateway = FakeLocation();
      final session = NavigationSession(
        RoutingRepository(),
        locationService: LocationService(gateway: gateway),
      );
      addTearDown(session.repository.client.close);
      addTearDown(session.dispose);
      final planning = session.currentPosition(forNavigation: false);
      await Future<void>.delayed(Duration.zero);
      gateway.streams.single.add(fix(accuracy: 120));
      expect((await planning).accuracy, 120);
    },
  );

  test('aquisição aguarda precisão e cancela a leitura temporária', () async {
    final g = FakeLocation();
    final service = LocationService(gateway: g);
    final f = service.acquire(navigation: true);
    await Future<void>.delayed(Duration.zero);
    g.streams.single.add(fix(accuracy: 800));
    g.streams.single.add(fix(stale: true));
    var done = false;
    f.then((_) {
      done = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);
    g.streams.single.add(fix());
    expect((await f).accuracy, 8);
    expect(g.cancelled, 1);
  });
  test('recusa é específica e não inicia observação', () async {
    final g = FakeLocation()
      ..failure = const PermissionDeniedException('denied');
    await expectLater(
      LocationService(gateway: g).acquire(),
      throwsA(
        isA<LocationFailure>().having(
          (e) => e.problem,
          'motivo',
          LocationProblem.denied,
        ),
      ),
    );
    expect(g.streams, isEmpty);
  });
  test('timeout e imprecisão encerram leitura sem fingir GPS válido', () async {
    final g = FakeLocation();
    final s = LocationService(
      gateway: g,
      acquisitionTimeout: const Duration(milliseconds: 40),
    );
    final f = s.acquire(navigation: true);
    await Future<void>.delayed(Duration.zero);
    g.streams.single.add(fix(accuracy: 300));
    await expectLater(
      f,
      throwsA(
        isA<LocationFailure>().having(
          (e) => e.problem,
          'motivo',
          LocationProblem.imprecise,
        ),
      ),
    );
    expect(g.cancelled, 1);
    final g2 = FakeLocation();
    await expectLater(
      LocationService(
        gateway: g2,
        acquisitionTimeout: const Duration(milliseconds: 20),
      ).acquire(),
      throwsA(
        isA<LocationFailure>().having(
          (e) => e.problem,
          'motivo',
          LocationProblem.timeout,
        ),
      ),
    );
    expect(g2.cancelled, 1);
  });
  test('encerrar aquisição impede iniciar navegação posteriormente', () async {
    final g = FakeLocation();
    final n =
        NavigationSession(
            RoutingRepository(),
            locationService: LocationService(gateway: g),
            headingUpdates: () => const Stream<double>.empty(),
          )
          ..routes = [road()]
          ..origin = road().points.first
          ..destination = road().points.last
          ..phase = NavigationPhase.preview;
    final start = n.start();
    await Future<void>.delayed(Duration.zero);
    expect(n.starting, isTrue);
    n.startSimulation();
    expect(n.simulating, isFalse);
    await n.pause();
    await start;
    expect(n.active, isFalse);
    expect(g.cancelled, 1);
    n.dispose();
    n.repository.client.close();
  });
  test(
    'inicia com posição precisa e encerra se a permissão for revogada',
    () async {
      final g = FakeLocation();
      final n =
          NavigationSession(
              RoutingRepository(),
              locationService: LocationService(gateway: g),
              headingUpdates: () => const Stream<double>.empty(),
            )
            ..routes = [road()]
            ..origin = road().points.first
            ..destination = road().points.last
            ..phase = NavigationPhase.preview;
      final starting = n.start();
      await Future<void>.delayed(Duration.zero);
      g.streams.single.add(fix());
      await starting;
      expect(n.active, isTrue);
      expect(n.simulating, isFalse);
      expect(n.accuracy, 8);
      expect(g.streams.length, 2);
      g.streams.last.addError(const PermissionDeniedException('revoked'));
      await Future<void>.delayed(Duration.zero);
      expect(n.active, isFalse);
      expect(n.locationIssue?.problem, LocationProblem.denied);
      n.dispose();
      n.repository.client.close();
    },
  );
  test('posição antiga ou inválida não é utilizável', () {
    expect(usablePosition(fix(stale: true)), isFalse);
    expect(usablePosition(fix(accuracy: double.nan)), isFalse);
  });
}
