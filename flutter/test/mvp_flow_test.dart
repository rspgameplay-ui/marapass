import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/mvp/auth/auth.dart';
import 'package:marapass_mapa/mvp/data/content.dart';
import 'package:marapass_mapa/mvp/data/demo_repository.dart';
import 'package:marapass_mapa/mvp/data/models.dart';
import 'package:marapass_mapa/mvp/data/store.dart';
import 'package:marapass_mapa/mvp/data/supabase_repository.dart';
import 'package:marapass_mapa/mvp/providers.dart';
import 'package:marapass_mapa/mvp/ui/app.dart';
import 'package:marapass_mapa/mvp/ui/checkin.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(AppStore, DemoAuthGateway)> boot(
  WidgetTester tester, {
  bool onboarded = true,
}) async {
  SharedPreferences.setMockInitialValues({
    if (onboarded) 'mvp_onboarded_v1': true,
  });
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final store = AppStore.memory();
  final auth = DemoAuthGateway();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mvpRepositoryProvider.overrideWithValue(DemoMvpRepository()),
        authGatewayProvider.overrideWithValue(auth),
        appStoreProvider.overrideWith((ref) => store),
      ],
      child: const MvpApp(splash: Duration.zero),
    ),
  );
  await tester.pumpAndSettle();
  return (store, auth);
}

Future<void> login(WidgetTester tester) async {
  expect(find.byKey(const Key('login-email')), findsOneWidget);
  await tester.enterText(
    find.byKey(const Key('login-email')),
    'turista@email.com',
  );
  await tester.tap(find.byKey(const Key('login-submit')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('login-code')),
    DemoAuthGateway.demoCode,
  );
  await tester.tap(find.byKey(const Key('login-submit')));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      300,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

Future<void> tapIt(WidgetTester tester, Finder f) async {
  await reveal(tester, f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  group('regras', () {
    test('formatBrl usa vírgula e separador de milhar', () {
      expect(formatBrl(18000), 'R\$ 180,00');
      expect(formatBrl(123456789), 'R\$ 1.234.567,89');
    });

    test('erros técnicos viram mensagens que dizem o que fazer', () {
      expect(
        translateError(Exception('SocketException: Failed host lookup'))
            .message,
        contains('Sem conexão'),
      );
      expect(
        translateError(Exception('no seats left, capacity')).message,
        contains('vagas'),
      );
    });

    test('busca universal ignora acentos e acha por cidade e categoria', () {
      expect(Content.search('lencois').isNotEmpty, isTrue);
      expect(
        Content.search('barreirinhas').any((i) => i.id == 'mangue'),
        isTrue,
      );
      expect(
        Content.search('cuxa').any((i) => i.cat == Cat.gastronomia),
        isTrue,
      );
      expect(Content.search('zzzz'), isEmpty);
    });

    test('ativar cupom é idempotente e a validação é de uso único', () {
      final s = AppStore.memory();
      final a = s.activateCoupon('c1');
      final b = s.activateCoupon('c1');
      expect(a.id, b.id);
      expect(s.coupons.length, 1);
      expect(s.validateCode(a.code, 5000).$1, isTrue);
      final second = s.validateCode(a.code, 5000);
      expect(second.$1, isFalse);
      expect(second.$2, contains('já foi utilizado'));
      expect(s.validateCode('MP-NADA', 0).$1, isFalse);
      expect(s.activateCoupon('c1').id, isNot(a.id));
    });

    test('pontos: check-in 50, primeiro do polo 100, cupom usado 20', () {
      final s = AppStore.memory();
      s.checkIn(Content.item('lagoas')!);
      expect(s.points, 150);
      s.checkIn(Content.item('rio')!);
      expect(s.points, 200);
      final c = s.activateCoupon('c2');
      s.validateCode(c.code, 0);
      expect(s.points, 220);
      expect(s.level.$1, 'Viajante');
      expect(s.level.$3, 'Explorador');
    });

    test('placa MaraPass identifica o lugar', () {
      final it = Content.items.first;
      expect(itemByPlate(plateCode(it))?.id, it.id);
      expect(itemByPlate('MP-XXXXXX'), isNull);
    });
  });

  group('jornada do turista', () {
    testWidgets('visitante vê a Home com saudação e a navegação oficial', (
      tester,
    ) async {
      await boot(tester);
      expect(find.textContaining('viajante!'), findsOneWidget);
      expect(find.text('Para onde você quer ir?'), findsOneWidget);
      for (final l in [
        'Início',
        'Explorar',
        'Check-in',
        'Cupons',
        'Passaporte',
      ]) {
        expect(find.text(l), findsWidgets);
      }
    });

    testWidgets(
      'primeira abertura mostra a apresentação e permite entrar sem cadastro',
      (tester) async {
        await boot(tester, onboarded: false);
        expect(find.text('Mais que destinos, boas histórias.'), findsOneWidget);
        await tester.tap(find.byKey(const Key('onb-next')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('onb-next')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('onb-visitor')));
        await tester.pumpAndSettle();
        expect(find.text('Para onde você quer ir?'), findsOneWidget);
      },
    );

    testWidgets(
      'Explorar: busca encontra o passeio e mostra estado vazio claro',
      (tester) async {
        await boot(tester);
        await tester.tap(find.text('Explorar').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('explore-search')),
          'lagoas',
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.text('Passeio às Lagoas'), findsWidgets);
        await tester.enterText(find.byKey(const Key('explore-search')), 'zzzz');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.textContaining('Nada encontrado'), findsOneWidget);
      },
    );

    testWidgets(
      'ativar cupom pede login, retoma a oferta e mostra o QR ativo',
      (tester) async {
        final (store, auth) = await boot(tester);
        await tester.tap(find.text('Cupons').last);
        await tester.pumpAndSettle();
        await tapIt(tester, find.text('Pousada Vila Lençóis').first);
        await tapIt(tester, find.byKey(const Key('coupon-activate')));
        await login(tester);
        expect(auth.current, isNotNull);
        expect(find.text('Revisar ativação'), findsOneWidget);
        await tester.tap(find.byKey(const Key('review-accept')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('review-confirm')));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.text('Seu cupom'), findsOneWidget);
        expect(find.text('Ativo'), findsOneWidget);
        expect(store.coupons.single.cupomId, 'c3');
        await tester.tap(find.byKey(const Key('coupon-reveal')));
        await tester.pump();
        expect(find.text(store.coupons.single.code), findsOneWidget);
        await tester.pumpWidget(const SizedBox()); // encerra o relógio do QR
      },
    );

    testWidgets(
      'reserva: escolhe dia e horário, faz login e confirma o envio',
      (tester) async {
        final (store, _) = await boot(tester);
        await tapIt(tester, find.text('Passeio às Lagoas').first);
        await tapIt(tester, find.byKey(const Key('item-reserve')));
        final submit = find.byKey(const Key('booking-submit'));
        expect(
          tester
              .widget<FilledButton>(
                find.descendant(
                  of: submit,
                  matching: find.byType(FilledButton),
                ),
              )
              .onPressed,
          isNull,
        );
        await tapIt(tester, find.byKey(const Key('day-0')));
        await tapIt(tester, find.byKey(const Key('period-Manhã')));
        await tapIt(tester, find.byKey(const Key('people-plus')));
        await tester.tap(submit);
        await tester.pumpAndSettle();
        await login(tester);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.text('Solicitação enviada'), findsOneWidget);
        final mine = store.myReservations.single;
        expect(mine.people, 3);
        expect(mine.period, 'Manhã');
        expect(mine.status, ResStatus.solicitada);
      },
    );

    testWidgets('check-in pela placa: registra visita, dá pontos e selo', (
      tester,
    ) async {
      final (store, _) = await boot(tester);
      await tester.tap(find.text('Check-in').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkin-plate')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('plate-code')),
        plateCode(Content.items.first),
      );
      await tester.tap(find.byKey(const Key('plate-submit')));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
      expect(find.text('Visita registrada!'), findsOneWidget);
      expect(store.points, 150);
      await tapIt(tester, find.byKey(const Key('star-5')));
      expect(store.checkins.single.rating, 5);
    });

    testWidgets('perfil: letra grande vale para o app inteiro', (tester) async {
      final (store, _) = await boot(tester);
      await tester.tap(find.byKey(const Key('home-avatar')));
      await tester.pumpAndSettle();
      await tapIt(tester, find.byKey(const Key('big-text')));
      expect(store.bigText, isTrue);
      final ctx = tester.element(find.text('Letra grande'));
      expect(MediaQuery.textScalerOf(ctx).scale(10), greaterThan(11));
    });

    testWidgets('parceiro valida o código do turista uma única vez', (
      tester,
    ) async {
      final (store, _) = await boot(tester);
      final c = store.activateCoupon('c1');
      await tester.tap(find.byKey(const Key('home-avatar')));
      await tester.pumpAndSettle();
      await tapIt(tester, find.byKey(const Key('partner-area')));
      await tester.tap(find.byKey(const Key('p-validate')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('validate-code')), c.code);
      await tester.pumpAndSettle();
      await tapIt(tester, find.byKey(const Key('validate-submit')));
      await tester.tap(find.byKey(const Key('validate-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Validação concluída'), findsOneWidget);
      expect(store.coupons.single.used, isTrue);
    });
  });
}
