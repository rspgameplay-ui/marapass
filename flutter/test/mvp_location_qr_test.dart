import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/mvp/data/content.dart';
import 'package:marapass_mapa/mvp/data/store.dart';
import 'package:marapass_mapa/mvp/theme/tokens.dart';
import 'package:marapass_mapa/mvp/ui/checkin.dart';
import 'package:marapass_mapa/mvp/ui/map_tab.dart' show itemPoint;
import 'package:marapass_mapa/mvp/ui/plates.dart';
import 'package:marapass_mapa/mvp/ui/scan.dart';

Future<void> _open(WidgetTester tester, Widget child, AppStore store) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [appStoreProvider.overrideWith((ref) => store)],
    child: MaterialApp(theme: mvpTheme(), home: child),
  ));
}

void main() {
  test('todos os itens com coordenada ficam dentro do Maranhão', () {
    for (final i in Content.items.where((i) => i.lat != null)) {
      expect(i.lat!, inInclusiveRange(-10.3, -1.0), reason: i.id);
      expect(i.lng!, inInclusiveRange(-48.8, -41.7), reason: i.id);
    }
    expect(Content.items.where((i) => i.lat != null).length, greaterThanOrEqualTo(30));
  });

  test('pontos exatos ficam no lugar; aproximados ganham afastamento curto', () {
    final juja = Content.item('juja')!;
    expect(juja.loc, Loc.exato);
    expect(itemPoint(juja).lat, juja.lat);
    final mangue = Content.item('mangue')!;
    final d = itemPoint(mangue).distanceKm(GeoPoint(mangue.lat!, mangue.lng!));
    expect(d, inInclusiveRange(.1, .5));
  });

  test('códigos de placa são únicos e o QR leva ao local certo', () {
    final codes = {for (final i in Content.items) plateCode(i)};
    expect(codes.length, Content.items.length);
    for (final i in Content.items) {
      expect((parseScan(plateQr(i)) as PlateScan).item.id, i.id);
    }
    expect((parseScan(offerQr('c2')) as OfferScan).cupom.id, 'c2');
  });

  testWidgets('check-in por GPS longe do local pede o QR da placa', (tester) async {
    final store = AppStore.memory();
    checkinLocate = () async => const GeoPoint(-2.5274, -44.3061); // São Luís
    await _open(tester, CheckinFlowScreen(item: Content.item('lagoas')!), store);
    await tester.tap(find.text('Permitir e continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Você ainda não está no local'), findsOneWidget);
    expect(store.checkins, isEmpty);
  });

  testWidgets('check-in por GPS no local registra a visita', (tester) async {
    final store = AppStore.memory();
    final it = Content.item('lagoas')!;
    checkinLocate = () async => GeoPoint(it.lat! + .002, it.lng!);
    await _open(tester, CheckinFlowScreen(item: it), store);
    await tester.tap(find.text('Permitir e continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Visita registrada!'), findsOneWidget);
    expect(store.checkins.single.itemId, 'lagoas');
  });

  testWidgets('sem GPS, oferece ler o QR', (tester) async {
    final store = AppStore.memory();
    checkinLocate = () async => throw Exception('negado');
    await _open(tester, CheckinFlowScreen(item: Content.item('centro')!), store);
    await tester.tap(find.text('Permitir e continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Não conseguimos sua localização'), findsOneWidget);
  });

  testWidgets('placa do local mostra QR, código e botão de baixar', (tester) async {
    final it = Content.item('juja')!;
    await _open(tester, PlatePreviewScreen(item: it), AppStore.memory());
    await tester.pumpAndSettle();
    expect(find.text(plateCode(it)), findsOneWidget);
    expect(find.byKey(const Key('plate-download')), findsOneWidget);
  });
}
