import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marapass_mapa/application/map_state.dart';
import 'package:marapass_mapa/data/tourism_repository.dart';
import 'package:marapass_mapa/domain/navigation.dart';
import 'package:marapass_mapa/journey/journey.dart';
import 'package:marapass_mapa/journey/journey_controller.dart';
import 'package:marapass_mapa/journey/journey_widgets.dart';

import 'journey_test.dart' show poi;

void main() {
  testWidgets(
    'detalhe usa a oferta do parceiro, salva o lugar e aponta sem alterar o percurso',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = TourismRepository(prefs, apiUrl: '', publishableKey: '')
        ..seed = [];
      final partner = poi('Parceiro de teste', coupon: true);
      final map = MapCoordinator(repo);
      final journey = JourneyController(repo)..partners = [partner];
      var focused = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            mapStateProvider.overrideWith((ref) => map),
            journeyProvider.overrideWith((ref) => journey),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showJourneyDetails(
                    context,
                    JourneyCandidate(
                      partner,
                      RouteProjection(500, 100, partner.point),
                    ),
                    onFocus: () => focused = true,
                  ),
                  child: const Text('Detalhes'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detalhes'));
      await tester.pumpAndSettle();
      expect(find.text('Oferta publicada'), findsOneWidget);
      expect(find.text('Recalcular rota para este local'), findsNothing);
      expect(
        find.textContaining('não emite nem reserva um cupom'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Salvar para visitar'));
      await tester.tap(find.text('Salvar para visitar'));
      await tester.pumpAndSettle();
      expect(map.state.saved.contains(partner.id), isTrue);
      expect(prefs.getStringList('saved_places'), contains(partner.id));
      await tester.ensureVisible(find.text('Ver ponto no mapa da rota'));
      await tester.tap(find.text('Ver ponto no mapa da rota'));
      await tester.pumpAndSettle();
      expect(focused, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'recalcular pela ficha permite tentar novamente e fecha ao trocar',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = TourismRepository(prefs, apiUrl: '', publishableKey: '')
        ..seed = [];
      final partner = poi('Boteco');
      final journey = JourneyController(repo)..partners = [partner];
      var result = Completer<bool>();
      var calls = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            journeyProvider.overrideWith((ref) => journey),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showJourneyDetails(
                    context,
                    JourneyCandidate(
                      partner,
                      RouteProjection(500, 62, partner.point),
                    ),
                    onFocus: () {},
                    onReroute: () {
                      calls++;
                      return result.future;
                    },
                  ),
                  child: const Text('Detalhes'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Detalhes'));
      await tester.pumpAndSettle();
      final action = find.text('Recalcular rota para este local');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pump();
      final progress = find.widgetWithText(
        FilledButton,
        'Calculando nova rota…',
      );
      expect(tester.widget<FilledButton>(progress).onPressed, isNull);
      expect(calls, 1);
      result.complete(false);
      await tester.pumpAndSettle();
      expect(find.textContaining('Não foi possível traçar'), findsOneWidget);
      result = Completer<bool>();
      await tester.ensureVisible(action);
      await tester.tap(action);
      result.complete(true);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(action, findsNothing);
      expect(find.text('Boteco'), findsNothing);
    },
  );
}
