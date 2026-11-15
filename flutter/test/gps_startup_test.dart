import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:geolocator/geolocator.dart';
import 'package:marapass_mapa/application/navigation_session.dart';
import 'package:marapass_mapa/data/routing_repository.dart';
import 'package:marapass_mapa/domain/navigation.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/location/location_service.dart';

import 'location_service_test.dart' show FakeLocation, fix;
import 'navigation_test.dart' show road, fixture;

class SingleFixGateway extends FakeLocation implements InitialLocationGateway {
  int initialReads = 0;
  @override
  Stream<Position> initialUpdates() {
    initialReads++;
    return Stream.value(fix());
  }
}

NavigationSession session(FakeLocation gateway, {RoadRoute? route}) {
  final r = route ?? road();
  return NavigationSession(
      RoutingRepository(),
      locationService: LocationService(gateway: gateway),
      headingUpdates: () => const Stream<double>.empty(),
    )
    ..routes = [r]
    ..origin = r.points.first
    ..destination = r.points.last
    ..phase = NavigationPhase.preview;
}

Future<void> turn() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test(
    'start from GPS away from preview keeps destination and opens one watch',
    () async {
      final g = SingleFixGateway();
      final calls = <Uri>[];
      final repo = RoutingRepository(
        client: MockClient((request) async {
          calls.add(request.url);
          return http.Response(jsonEncode(fixture()), 200);
        }),
      );
      final n = NavigationSession(
        repo,
        locationService: LocationService(gateway: g),
        headingUpdates: () => const Stream<double>.empty(),
      );
      addTearDown(repo.client.close);
      addTearDown(n.dispose);
      const target = GeoPoint(-2.75, -42.83);
      await n.calculate(const GeoPoint(-2.55, -44.31), target);
      await n.start();
      expect(n.active, isTrue);
      expect(n.destination, same(target));
      expect(n.origin!.lat, fix().latitude);
      expect(
        calls.last.pathSegments.last,
        '${fix().longitude},${fix().latitude};-42.83,-2.75',
      );
      expect(g.initialReads, 1);
      expect(g.streams, hasLength(1));
      await n.pause();
    },
  );

  test(
    'initial acquisition uses one-shot gateway without opening a watch',
    () async {
      final g = SingleFixGateway();
      await LocationService(gateway: g).acquire(navigation: true);
      expect(g.initialReads, 1);
      expect(g.streams, isEmpty);
    },
  );

  test(
    'ten starts, duplicate clicks, stable camera and complete watch cleanup',
    () async {
      final g = FakeLocation();
      final n = session(g);
      try {
        for (var i = 0; i < 10; i++) {
          final previous = g.streams.length;
          final starting = n.start();
          await n.start();
          await turn();
          expect(g.streams.length, previous + 1);
          g.streams.last.add(fix());
          await starting;
          expect(n.active, isTrue);
          expect(n.cameraReady, isFalse);
          expect(g.streams.length, previous + 2);
          final watch = g.streams.last;
          watch.add(fix());
          await turn();
          expect(n.cameraReady, isFalse);
          await Future<void>.delayed(const Duration(milliseconds: 1050));
          watch.add(fix());
          await turn();
          expect(n.cameraReady, isTrue);
          await n.pause();
          expect(n.active, isFalse);
          expect(n.cameraReady, isFalse);
          expect(g.cancelled, (i + 1) * 2);
          watch.add(fix());
          await turn();
          expect(n.active, isFalse);
        }
      } finally {
        n.dispose();
        n.repository.client.close();
        for (final c in g.streams) {
          await c.close();
        }
      }
    },
  );

  test('burst keeps newest fix; pause discards pending callback', () async {
    final g = FakeLocation();
    final n = session(g);
    try {
      final starting = n.start();
      await turn();
      g.streams.last.add(fix());
      await starting;
      var notifications = 0;
      n.addListener(() => notifications++);
      for (var i = 0; i < 1000; i++) {
        g.streams.last.add(fix());
      }
      await turn();
      expect(notifications, lessThanOrEqualTo(2));
      g.streams.last.add(fix());
      await n.pause();
      final paused = notifications;
      await Future<void>.delayed(const Duration(milliseconds: 550));
      expect(notifications, paused);
    } finally {
      n.dispose();
      n.repository.client.close();
    }
  });

  for (final error in [
    const PermissionDeniedException('denied'),
    const PositionUpdateException('unavailable'),
    TimeoutException('timeout'),
  ]) {
    test('startup failure preserves route: ${error.runtimeType}', () async {
      final g = FakeLocation()..failure = error;
      final n = session(g);
      final original = n.route;
      await n.start();
      expect(n.phase, NavigationPhase.preview);
      expect(n.route, same(original));
      expect(n.starting, isFalse);
      expect(n.cameraReady, isFalse);
      expect(g.streams, isEmpty);
      n.dispose();
      n.repository.client.close();
    });
  }

  test(
    'closed watch releases camera and returns to preserved preview',
    () async {
      final g = FakeLocation();
      final n = session(g);
      final starting = n.start();
      await turn();
      g.streams.last.add(fix());
      await starting;
      await g.streams.last.close();
      await turn();
      expect(n.phase, NavigationPhase.preview);
      expect(n.lowSignal, isTrue);
      expect(n.route, isNotNull);
      n.dispose();
      n.repository.client.close();
    },
  );

  test(
    'watch recovers after timeout and camera waits for fresh stable fixes',
    () async {
      final g = FakeLocation();
      final n = session(g);
      try {
        final starting = n.start();
        await turn();
        g.streams.last.add(fix());
        await starting;
        final watch = g.streams.last;
        watch.addError(TimeoutException('signal lost'));
        await turn();
        expect(n.active, isTrue);
        expect(n.lowSignal, isTrue);
        expect(n.cameraReady, isFalse);
        watch.add(fix());
        await turn();
        await Future<void>.delayed(const Duration(milliseconds: 1050));
        watch.add(fix());
        await turn();
        expect(n.lowSignal, isFalse);
        expect(n.cameraReady, isTrue);
      } finally {
        await n.pause();
        n.dispose();
        n.repository.client.close();
      }
    },
  );

  test('route revision never invalidates the ongoing GPS session', () async {
    final g = FakeLocation();
    final repo = RoutingRepository(
      client: MockClient((_) async => http.Response('{}', 503)),
    );
    final r = road();
    final n =
        NavigationSession(
            repo,
            locationService: LocationService(gateway: g),
            headingUpdates: () => const Stream<double>.empty(),
          )
          ..routes = [r]
          ..origin = r.points.first
          ..destination = r.points.last
          ..phase = NavigationPhase.preview;
    try {
      final starting = n.start();
      await turn();
      g.streams.last.add(fix());
      await starting;
      final first = n.lastFix;
      await n.calculate(r.points.first, r.points.last, recalculate: true);
      expect(n.active, isTrue);
      g.streams.last.add(fix());
      await turn();
      expect(n.lastFix!.isAfter(first!), isTrue);
      expect(g.streams.length, 2);
    } finally {
      await n.pause();
      n.dispose();
      repo.client.close();
    }
  });

  test('long route accepts initial GPS while camera remains gated', () async {
    final r = RoadRoute.fromOsrm(fixture(), 0);
    final g = FakeLocation();
    final n = session(g, route: r);
    // Fixture origin differs from the short-route fake, so inject its real start.
    final starting = n.start();
    await turn();
    final p = r.points.first;
    g.streams.last.add(
      Position(
        latitude: p.lat,
        longitude: p.lng,
        timestamp: DateTime.now(),
        accuracy: 8,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
    await starting;
    expect(n.active, isTrue);
    expect(n.cameraReady, isFalse);
    expect(n.route!.distance, greaterThan(250000));
    await n.pause();
    n.dispose();
    n.repository.client.close();
  });
}
