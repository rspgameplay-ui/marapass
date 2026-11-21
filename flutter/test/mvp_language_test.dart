import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/mvp/data/store.dart';

import 'mvp_flow_test.dart' show boot;

void main() {
  testWidgets('trocar para inglês traduz a barra de abas e volta ao português', (
    tester,
  ) async {
    final (store, _) = await boot(tester);
    expect(find.text('Início'), findsWidgets);
    expect(find.text('Passaporte'), findsWidgets);

    store.setLanguage('en');
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Passport'), findsWidgets);
    expect(find.text('Início'), findsNothing);

    store.setLanguage('pt');
    await tester.pumpAndSettle();
    expect(find.text('Início'), findsWidgets);
  });

  testWidgets('em inglês, tela inicial e Defina sua Rota aparecem traduzidas', (tester) async {
    final (store, _) = await boot(tester);
    store.setLanguage('en');
    await tester.pumpAndSettle();
    expect(find.text('Plan your Route'), findsWidgets);
    expect(find.text('Lodging'), findsWidgets);
    expect(find.text('My passport'), findsWidgets);
    expect(find.text('Defina sua Rota'), findsNothing);
    await tester.tap(find.byKey(const Key('qa-rota')));
    await tester.pumpAndSettle();
    expect(find.text('New route'), findsOneWidget);
    store.setLanguage('pt');
    await tester.pumpAndSettle();
  });

  test('idioma inválido volta para português', () {
    final store = AppStore.memory();
    store.setLanguage('fr');
    expect(store.language, 'pt');
  });
}
