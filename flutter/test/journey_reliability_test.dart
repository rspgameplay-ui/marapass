
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marapass_mapa/application/navigation_session.dart';
import 'package:marapass_mapa/data/routing_repository.dart';
import 'package:marapass_mapa/domain/navigation.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/navigation/traveler_marker.dart';

import 'helpers.dart' show road;

void main() {
  testWidgets('mixed demo completes land-water-land offline without GPS', (
    tester,
  ) async {
    var requests = 0;
    final repo = RoutingRepository(
      client: MockClient((_) async {
        requests++;
        throw const FormatException('offline');
      }),
    );
    final n = NavigationSession(repo);
    await tester.runAsync(() => n.loadMixedSimulation(autoStart: false));
    n.startSimulation(mixed: true);
    expect(n.active, isTrue);
    expect(n.travelMode, TravelMode.land);
    await tester.pump(const Duration(seconds: 18));
    expect(n.travelMode, TravelMode.nautical);
    await tester.pump(const Duration(seconds: 18));
    expect(n.travelMode, TravelMode.land);
    await tester.pump(const Duration(seconds: 18));
    expect(n.phase, NavigationPhase.arrived);
    expect(requests, 0);
    expect(n.message, contains('Nenhum deslocamento real'));
    n.dispose();
    repo.client.close();
  });
  test(
    'ferry segment never asks car router to recalculate over water',
    () async {
      var requests = 0;
      final repo = RoutingRepository(
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 500);
        }),
      );
      final r = road();
      final ferry = RoadRoute(
        points: r.points,
        steps: [
          RoadStep(
            instruction: 'Balsa',
            road: '',
            type: 'depart',
            modifier: '',
            startMeters: 0,
            distance: r.distance,
            duration: r.duration,
            point: r.points.first,
            mode: 'ferry',
          ),
        ],
        distance: r.distance,
        duration: r.duration,
        summary: 'Travessia',
        originSnap: 0,
        destinationSnap: 0,
      );
      final n = NavigationSession(repo)
        ..routes = [ferry]
        ..origin = ferry.points.first
        ..destination = ferry.points.last
        ..phase = NavigationPhase.navigating;
      for (var i = 0; i < 5; i++) {
        n.ingest(
          const GeoPoint(-2.532, -44.299),
          accuracyMeters: 8,
          timestamp: DateTime.now(),
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(n.travelMode, TravelMode.nautical);
      expect(requests, 0);
      expect(n.route, same(ferry));
      n.dispose();
      repo.client.close();
    },
  );
  test('weak fix freezes progress, expands accuracy and recovers without losing route', () {
    final n = NavigationSession(RoutingRepository())
      ..routes = [road()]
      ..phase = NavigationPhase.navigating;
    n.ingest(
      const GeoPoint(-2.53, -44.299),
      accuracyMeters: 8,
      timestamp: DateTime.now(),
      speed: 3,
      course: 359,
    );
    final meters = n.meters, r = n.route;
    n.ingest(
      const GeoPoint(-2.52, -44.29),
      accuracyMeters: 200,
      timestamp: DateTime.now(),
    );
    expect(n.lowSignal, isTrue);
    expect(n.accuracy, 200);
    expect(n.meters, meters);
    expect(n.route, same(r));
    n.ingest(
      const GeoPoint(-2.53, -44.298),
      accuracyMeters: 8,
      timestamp: DateTime.now(),
      speed: 3,
      course: 1,
    );
    expect(n.lowSignal, isFalse);
    expect(n.meters, greaterThan(meters));
    expect(headingDelta(0, n.heading).abs(), lessThan(2));
    final heading = n.heading;
    n.setCompassHeading(180);
    expect(n.heading, heading);
    n.ingest(
      const GeoPoint(-2.53, -44.298),
      accuracyMeters: 8,
      timestamp: DateTime.now(),
      speed: 0,
    );
    n.setCompassHeading(90);
    expect(headingDelta(heading, n.heading), greaterThan(0));
    n.dispose();
    n.repository.client.close();
  });
  testWidgets('marker transition, reduced motion and screen reader state', (
    tester,
  ) async {
    Widget marker(TravelMode mode, {bool weak = false, bool reduced = false}) =>
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: TravelerMarker(mode: mode, heading: 90, imprecise: weak),
          ),
        );
    await tester.pumpWidget(marker(TravelMode.land));
    expect(
      find.bySemanticsLabel('Você está aqui, seguindo para leste'),
      findsOneWidget,
    );
    await tester.pumpWidget(marker(TravelMode.nautical, weak: true));
    await tester.pump(const Duration(milliseconds: 125));
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is TravelerPainter,
      ),
      findsNWidgets(2),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.bySemanticsLabel(
        'Você está aqui, seguindo para leste, Localização imprecisa',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(marker(TravelMode.nautical, reduced: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
