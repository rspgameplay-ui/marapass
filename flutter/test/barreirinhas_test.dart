import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marapass_mapa/application/map_state.dart';
import 'package:marapass_mapa/data/tourism_repository.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/pilot/barreirinhas.dart';

void main() {
  test('identificador Google é opaco, preservado e não inventado', () {
    expect(validGooglePlaceId('ChIJ_example_12345'), isTrue);
    expect(validGooglePlaceId('https://maps.google.com/x'), isFalse);
    expect(validGooglePlaceId('<script>alert(1)</script>'), isFalse);
    final p = TourismPlace.fromJson({
      'id': 'test',
      'name': 'Lugar',
      'city': 'Barreirinhas',
      'cat': 'nature',
      'lat': -2.7,
      'lng': -42.8,
      'googlePlaceId': 'ChIJ_example_12345',
    });
    expect(p.toJson()['googlePlaceId'], 'ChIJ_example_12345');
    expect(p.hasCoupon, isFalse);
  });
  testWidgets(
    'piloto filtra catálogo real e preserva orientação de acesso em tela pequena',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
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
      final map = MapCoordinator(repo);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            mapStateProvider.overrideWith((ref) => map),
          ],
          child: const MaterialApp(home: BarreirinhasPilot()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Seleção inicial: 9 locais'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextField));
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Lagoa Bonita');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      final card = find.descendant(
        of: find.byType(Card),
        matching: find.text('Lagoa Bonita'),
      );
      await tester.scrollUntilVisible(
        card,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.textContaining('transporte credenciado'), findsOneWidget);
      expect(find.text('Planejar trajeto no MaraPass'), findsNothing);
      expect(find.text('Consultar informações no Google'), findsOneWidget);
      Navigator.of(tester.element(find.text('Consultar informações no Google')))
          .pop();
      await tester.pumpAndSettle();
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
