import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/mvp/data/content.dart';
import 'package:marapass_mapa/mvp/data/trip.dart';

import 'mvp_flow_test.dart' show boot, tapIt;

void main() {
  final d = DateTime(2027, 1, 10);

  group('regras da rota', () {
    test('lê o horário de funcionamento, inclusive até a meia-noite', () {
      expect(openingHours(Content.item('mangue')), (11 * 60, 23 * 60));
      expect(openingHours(Content.item('conchas')), (16 * 60, 24 * 60));
      expect(openingHours(Content.item('vila')), isNull);
    });

    test('avisa horário sobreposto e fora do funcionamento', () {
      final t = Trip(id: 't', name: 'x', start: d, end: d, stops: [
        TripStop(id: 'a', day: d, itemId: 'lagoas', startMin: 8 * 60, stayMin: 180),
        TripStop(id: 'b', day: d, itemId: 'mangue', startMin: 10 * 60, stayMin: 60),
      ]);
      final c = tripConflicts(t, d);
      expect(c['b']!.join(), contains('sobreposto'));
      expect(c['b']!.join(), contains('funcionamento'));
      expect(c.containsKey('a'), isFalse);
    });

    test('custo separa hospedagem por noite, passeios por pessoa e alimentação', () {
      final t = Trip(id: 't', name: 'x', start: d, end: DateTime(2027, 1, 12), people: 2, extras: {'vila'}, stops: [
        TripStop(id: 'a', day: d, itemId: 'lagoas', startMin: 480, stayMin: 120),
      ]);
      final c = tripCost(t);
      expect(c[0].cents, 32000 * 2); // 2 noites
      expect(c[1].cents, 12000 * 2); // 2 pessoas
      expect(c[3].cents, 7000 * 2 * 3); // 3 dias
    });

    test('reservar tudo: hospedagem pelo período e passeio pelo turno da chegada', () {
      final t = Trip(id: 't', name: 'x', start: d, end: DateTime(2027, 1, 12), people: 3, extras: {'vila'}, stops: [
        TripStop(id: 'a', day: d, itemId: 'lagoas', startMin: 14 * 60, stayMin: 120),
        TripStop(id: 'b', day: d, itemId: 'mangue', startMin: 19 * 60, stayMin: 60),
        TripStop(id: 'c', day: d, pause: 'almoco', startMin: 12 * 60, stayMin: 60),
      ]);
      final r = tripRequests(t);
      expect(r.map((e) => e.item.id), ['vila', 'lagoas']);
      expect(r[0].period, '2 noites · Quarto Standard');
      expect(r[1].period, 'Tarde');
      expect(r.every((e) => e.people == 3), isTrue);
    });

    test('rota salva volta igual do JSON', () {
      final t = Trip(id: 't', name: 'Lençóis', start: d, end: d, people: 3, extras: {'vila'}, stops: [
        TripStop(id: 'p', day: d, pause: 'almoco', startMin: 720, stayMin: 90),
      ]);
      final back = Trip.fromJson(t.toJson());
      expect(back.name, 'Lençóis');
      expect(back.people, 3);
      expect(back.stops.single.label, 'Almoço');
      expect(back.extras, {'vila'});
    });
  });

  testWidgets('monta, vê o resumo com custo e salva a rota no passaporte', (tester) async {
    await boot(tester);
    await tapIt(tester, find.byKey(const Key('qa-rota')));
    await tapIt(tester, find.byKey(const Key('route-new')));
    await tapIt(tester, find.byKey(const Key('route-next'))); // Quando
    await tester.enterText(find.byKey(const Key('route-search')), 'lagoas');
    await tester.pumpAndSettle();
    await tapIt(tester, find.byKey(const Key('route-add-lagoas')));
    await tapIt(tester, find.byKey(const Key('route-next'))); // Onde
    await tapIt(tester, find.byKey(const Key('route-pause-almoco')));
    await tapIt(tester, find.byKey(const Key('route-next'))); // Horários
    await tapIt(tester, find.byKey(const Key('route-next'))); // Extras
    expect(find.byKey(const Key('route-summary')), findsOneWidget);
    expect(find.text('Almoço'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('route-cost')), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Custo estimado'), findsOneWidget);
    await tapIt(tester, find.byKey(const Key('route-save')));
    await tester.enterText(find.byKey(const Key('route-name')), 'Lençóis em família');
    await tapIt(tester, find.byKey(const Key('route-name-ok')));
    Navigator.of(tester.element(find.byKey(const Key('route-summary')))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Lençóis em família'), findsOneWidget);
  });
}
