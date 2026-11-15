import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/islands/nautical_connections.dart';
import 'package:marapass_mapa/islands/nautical_screen.dart';

Future<NauticalCatalog> fixtureCatalog() async => NauticalCatalog.fromJson(
  jsonDecode(File('assets/data/nautical_connections.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  test(
    'travessia mantém geometria da fonte e separa documentação de operação',
    () {
      final j = jsonDecode(
        File('assets/data/nautical_connections.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final catalog = NauticalCatalog.fromJson(j);
      expect(catalog.routes, hasLength(1));
      final route = catalog.routes.single;
      expect(route.id, 'antaq:300044');
      expect(route.points, hasLength(18));
      expect(route.points.first.lat, -2.831645);
      expect(route.points.first.lng, -41.83015);
      expect(route.points.last.lat, -2.767181);
      expect(route.points.last.lng, -41.846466);
      expect(route.canStartVesselNavigation, isFalse);
      expect(j['routes'][0]['operationallyVerified'], isFalse);
      expect(j['routes'][0]['geometryUse'], 'planning_only');
      expect(route.islandIds, ['geonames:3403422']);
      // Carrapatal must never inherit Canárias' line or a nearest-port guess.
      expect(
        catalog.routes.where(
          (r) => r.islandIds.contains('osm:relation:10270258'),
        ),
        isEmpty,
      );
      expect(route.documentedMinutes, 20);
      expect(j['archiveSha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
    },
  );

  testWidgets('Carrapatal mostra pendência sem oferecer início de navegação', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: NauticalScreen(
            islandId: 'osm:relation:10270258',
            loadCatalog: fixtureCatalog,
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('ocorrência de 2014'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('ocorrência de 2014'), findsOneWidget);
    expect(find.text('Ver traçado de referência'), findsNothing);
    expect(find.text('Iniciar navegação'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Canárias expõe traçado com tempo documental e confirmação pendente',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: NauticalScreen(
              islandId: 'geonames:3403422',
              loadCatalog: fixtureCatalog,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Tatus ↔ Canárias'), findsOneWidget);
      expect(
        find.textContaining('não é previsão de chegada atual'),
        findsOneWidget,
      );
      expect(find.text('Ver traçado de referência'), findsOneWidget);
      expect(find.text('Iniciar navegação'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
