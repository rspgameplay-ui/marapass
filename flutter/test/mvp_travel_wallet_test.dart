import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/mvp/data/content.dart';
import 'package:marapass_mapa/mvp/data/store.dart';
import 'package:marapass_mapa/mvp/theme/tokens.dart';
import 'package:marapass_mapa/mvp/ui/checkin.dart';
import 'package:marapass_mapa/mvp/ui/coupons.dart';
import 'package:marapass_mapa/mvp/ui/itinerary.dart';
import 'package:marapass_mapa/mvp/ui/map_tab.dart' show itemPoint;
import 'package:marapass_mapa/mvp/ui/nav_screen.dart' show maneuverIcon;
import 'package:marapass_mapa/mvp/ui/scan.dart';
import 'package:marapass_mapa/mvp/ui/stay.dart';
import 'package:marapass_mapa/domain/navigation.dart';
import 'package:marapass_mapa/domain/tourism.dart';

Widget _wrap(Widget child, AppStore store) => ProviderScope(
  overrides: [appStoreProvider.overrideWith((ref) => store)],
  child: MaterialApp(theme: mvpTheme(), home: child),
);

void main() {
  test('QR: placa vira check-in, oferta vira cupom e o resto é recusado', () {
    final it = Content.items.first;
    expect((parseScan(plateCode(it)) as PlateScan).item.id, it.id);
    expect((parseScan('marapass:plate:${plateCode(it)}') as PlateScan).item.id, it.id);
    expect((parseScan('marapass:offer:c1') as OfferScan).cupom.id, 'c1');
    expect(parseScan('https://exemplo.com'), isNull);
    expect(parseScan('MP-XXXXXX'), isNull);
  });

  test('roteiros usam itens reais, na mesma cidade, com um destaque', () {
    for (final p in dayPlans) {
      expect(p.stops.length, greaterThanOrEqualTo(3));
      expect(p.stops.where((s) => s.anchor).length, 1);
      for (final s in p.stops) {
        expect(Content.item(s.itemId), isNotNull, reason: s.itemId);
        expect(s.item.cidade, p.city);
        if (s.backupId != null) expect(Content.item(s.backupId!), isNotNull);
      }
    }
  });

  test('posição dos itens no mapa usa a coordenada real (Lagoa Azul)', () {
    final it = Content.item('lagoas')!;
    expect(itemPoint(it).lat, itemPoint(it).lat);
    expect(itemPoint(it).distanceKm(const GeoPoint(-2.6630536, -42.8602811)), lessThan(.01));
  });

  test('valor estimado dos cupons é sempre positivo', () {
    for (final c in Content.allCupons) {
      expect(couponValueCents(c), greaterThan(0), reason: c.id);
    }
  });

  test('ícone de manobra cobre curvas, rotatória, balsa e chegada', () {
    RoadStep st(String type, String mod, {String mode = 'driving'}) => RoadStep(
      instruction: '',
      road: '',
      type: type,
      modifier: mod,
      startMeters: 0,
      distance: 0,
      duration: 0,
      point: const GeoPoint(0, 0),
      mode: mode,
    );
    expect(maneuverIcon(st('turn', 'left')), Icons.turn_left_rounded);
    expect(maneuverIcon(st('roundabout', 'right')), Icons.roundabout_right_rounded);
    expect(maneuverIcon(st('arrive', '')), Icons.sports_score_rounded);
    expect(maneuverIcon(st('notification', '', mode: 'ferry')), Icons.directions_boat_rounded);
  });

  testWidgets('disponibilidade da hospedagem mostra tarifas e total', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = AppStore.memory();
    await tester.pumpWidget(_wrap(StayAvailabilityScreen(item: Content.item('vila')!), store));
    await tester.pumpAndSettle();
    expect(find.text('Quartos disponíveis'), findsOneWidget);
    expect(find.byKey(const Key('stay-room-0')), findsOneWidget);
    expect(find.text('Cancelamento grátis até 48 h'), findsWidgets);
    expect(find.byKey(const Key('stay-total')), findsOneWidget);
  });

  testWidgets('roteiro do dia lista paradas com plano B', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const ItineraryScreen(), AppStore.memory()));
    await tester.pumpAndSettle();
    expect(find.text(dayPlans.first.title), findsOneWidget);
    expect(find.textContaining('Plano B'), findsWidgets);
    await tester.tap(find.byKey(const Key('itinerary-city-1')));
    await tester.pumpAndSettle();
    expect(find.text(dayPlans[1].title), findsOneWidget);
  });

  testWidgets('carteira mostra economia, ativos e pontos', (tester) async {
    final store = AppStore.memory();
    await tester.pumpWidget(_wrap(Scaffold(body: WalletSummary(store: store)), store));
    expect(find.text('Benefícios MaraPass'), findsOneWidget);
    expect(find.byKey(const Key('wallet-saved')), findsOneWidget);
  });

  testWidgets('leitor sem câmera oferece digitação e simulação', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    ScanScreen.useCamera = false;
    await tester.pumpWidget(_wrap(const ScanScreen(), AppStore.memory()));
    await tester.pumpAndSettle();
    expect(find.text('Escanear QR Code do Local'), findsOneWidget);
    expect(find.byKey(const Key('scan-torch')), findsOneWidget);
    expect(find.byKey(const Key('scan-switch')), findsOneWidget);
    expect(find.byKey(const Key('scan-manual')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('scan-close'))).height, greaterThanOrEqualTo(48));
  });

  test('cores do tema continuam as do protótipo', () {
    expect(MP.navy, const Color(0xff0b3a66));
  });
}
