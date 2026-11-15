import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marapass_mapa/main.dart';
import 'package:marapass_mapa/application/map_state.dart';
import 'package:marapass_mapa/data/tourism_repository.dart';
import 'package:marapass_mapa/data/catalog_workspace.dart';

void main() {
  testWidgets(
    'central cadastra um ponto, mantém rascunho e apresenta no mapa após ativar',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = TourismRepository(prefs, apiUrl: '', publishableKey: '');
      await tester.runAsync(() => repo.initialize());
      final coordinator = MapCoordinator(repo)..engine(MapEngine.essential);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            mapStateProvider.overrideWith((ref) => coordinator),
          ],
          child: const MaraPassApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mais opções'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Central de customização'));
      await tester.tap(find.text('Central de customização'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir painel compartilhado'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 740);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Área de trabalho deste aparelho'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Área de trabalho deste aparelho'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Abrir cadastros locais'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir cadastros locais'));
      await tester.pumpAndSettle();
      expect(find.text('Área de trabalho local'), findsOneWidget);
      await tester.tap(find.text('Novo cadastro'));
      await tester.pumpAndSettle();
      Future<void> fill(String label, String value) async {
        final finder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label,
        );
        await tester.scrollUntilVisible(
          finder,
          300,
          maxScrolls: 30,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.enterText(finder, value);
        await tester.pump();
      }

      await fill('Nome', 'Museu de teste');
      await fill('Município', 'São Luís');
      await fill('Latitude', '-2,53');
      await fill('Longitude', '-44,3');
      await tester.scrollUntilVisible(
        find.text('Salvar cadastro'),
        350,
        maxScrolls: 30,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar cadastro'));
      await tester.pumpAndSettle();
      expect(coordinator.entries.single.status, CatalogStatus.draft);
      expect(
        coordinator.state.places.any((p) => p.name == 'Museu de teste'),
        isFalse,
      );
      final search = find.widgetWithText(TextField, 'Pesquisar no catálogo');
      await tester.enterText(search, 'Museu de teste');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      final row = find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Museu de teste'),
      );
      await tester.scrollUntilVisible(
        row,
        250,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      final status = find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<CatalogStatus>,
      );
      await tester.scrollUntilVisible(
        status,
        350,
        maxScrolls: 30,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(status);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Visível no meu mapa').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Salvar cadastro'),
        350,
        maxScrolls: 30,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar cadastro'));
      await tester.pumpAndSettle();
      expect(
        coordinator.state.places.any((p) => p.name == 'Museu de teste'),
        isTrue,
      );
      expect(prefs.getString(CatalogWorkspace.key), contains('Museu de teste'));
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(320, 740);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
