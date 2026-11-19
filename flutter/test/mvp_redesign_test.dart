import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mvp_flow_test.dart' show boot, tapIt;

void main() {
  group('redesenho', () {
    testWidgets('passaporte mostra o bilhete e abre o leitor direto', (tester) async {
      await boot(tester);
      await tester.tap(find.text('Passaporte').last);
      await tester.pumpAndSettle();
      expect(find.text('Seus pontos'), findsOneWidget);
      expect(find.text('Visitas'), findsOneWidget);
      expect(find.text('Carimbos'), findsOneWidget);
      await tapIt(tester, find.byKey(const Key('pass-checkin')));
      expect(find.byKey(const Key('scan-screen')), findsOneWidget);
    });

    testWidgets('leitor oferece digitar código e "Estou no local"', (tester) async {
      await boot(tester);
      await tester.tap(find.byKey(const Key('qa-checkin')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scan-screen')), findsOneWidget);
      expect(find.byKey(const Key('scan-manual')), findsOneWidget);
      expect(find.byKey(const Key('checkin-here')), findsOneWidget);
    });

    testWidgets('reserva mostra o resumo no rodapé ao escolher dia e horário', (tester) async {
      await boot(tester);
      await tester.tap(find.byKey(const Key('home-search')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('explore-search')), 'lagoas');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passeio às Lagoas').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('item-reserve')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Manhã ·'), findsNothing);
      await tapIt(tester, find.byKey(const Key('day-0')));
      await tapIt(tester, find.byKey(const Key('period-Manhã')));
      expect(find.textContaining('Manhã ·'), findsOneWidget);
      expect(find.textContaining('2 pessoas'), findsWidgets);
    });
  });
}
