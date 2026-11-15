import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/mvp/auth/auth.dart';
import 'package:marapass_mapa/mvp/data/demo_repository.dart';
import 'package:marapass_mapa/mvp/data/models.dart';
import 'package:marapass_mapa/mvp/data/supabase_repository.dart';
import 'package:marapass_mapa/mvp/providers.dart';
import 'package:marapass_mapa/mvp/ui/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(DemoMvpRepository, DemoAuthGateway)> boot(
  WidgetTester tester, {
  bool onboarded = true,
}) async {
  SharedPreferences.setMockInitialValues({
    if (onboarded) 'mvp_onboarded_v1': true,
  });
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final repo = DemoMvpRepository();
  final auth = DemoAuthGateway();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mvpRepositoryProvider.overrideWithValue(repo),
        authGatewayProvider.overrideWithValue(auth),
      ],
      child: const MvpApp(splash: Duration.zero),
    ),
  );
  await tester.pumpAndSettle();
  return (repo, auth);
}

Future<void> login(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('login-email')),
    'turista@email.com',
  );
  await tester.tap(find.byKey(const Key('login-submit')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('login-code')), '123456');
  await tester.tap(find.byKey(const Key('login-submit')));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder f) async {
  await reveal(tester, f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  group('formatação', () {
    test('formatBrl usa vírgula e separador de milhar', () {
      expect(formatBrl(0), 'R\$ 0,00');
      expect(formatBrl(18000), 'R\$ 180,00');
      expect(formatBrl(123456789), 'R\$ 1.234.567,89');
    });

    test('describeDiscount não inventa valores', () {
      expect(describeDiscount('percentage', 20), '20% de desconto');
      expect(describeDiscount('fixed_amount', 8), 'R\$ 8,00 de desconto');
      expect(describeDiscount('BUY_ONE_GET_ONE', null), 'Leve 2, pague 1');
      expect(describeDiscount(null, null), 'Benefício exclusivo');
    });

    test('cupom expirado e usado são distinguidos do ativo', () {
      final now = DateTime.now();
      CouponInstance c({
        String status = 'issued',
        DateTime? exp,
        DateTime? red,
      }) => CouponInstance(
        id: '1',
        offerId: 'o',
        status: status,
        title: 't',
        expiresAt: exp,
        redeemedAt: red,
      );
      expect(c(exp: now.add(const Duration(days: 1))).isActive, isTrue);
      expect(c(exp: now.subtract(const Duration(days: 1))).isExpired, isTrue);
      expect(c(red: now).isRedeemed, isTrue);
      expect(c(red: now).isActive, isFalse);
    });

    test('erros técnicos viram mensagens que dizem o que fazer', () {
      expect(
        translateError(Exception('SocketException: Failed host lookup'))
            .message,
        contains('Sem conexão'),
      );
      expect(
        translateError(Exception('no seats left, capacity exceeded')).message,
        contains('vagas'),
      );
      expect(
        translateError(Exception('algo estranho')).message,
        contains('Tente de novo'),
      );
    });
  });

  group('jornada do turista', () {
    testWidgets('visitante explora sem login e vê os passeios', (tester) async {
      await boot(tester);
      expect(find.text('Maranhão infinito.'), findsOneWidget);
      expect(find.text('Você está como visitante'), findsOneWidget);
      expect(find.text('Passeio às Lagoas Clássicas'), findsWidgets);
      // navegação inferior oficial
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

    testWidgets('primeira abertura passa pelo onboarding e permite visitante', (
      tester,
    ) async {
      await boot(tester, onboarded: false);
      expect(find.text('Descubra o Maranhão'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onb-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onb-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onb-visitor')));
      await tester.pumpAndSettle();
      expect(find.text('Maranhão infinito.'), findsOneWidget);
    });

    testWidgets(
      'busca na Explorar filtra e mostra estado vazio sem vermelho de erro',
      (tester) async {
        await boot(tester);
        await tester.tap(find.text('Explorar').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('explore-search')),
          'pôr do sol',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.text('Pôr do sol nas dunas'), findsOneWidget);
        expect(find.text('Rio Preguiças e Vassouras'), findsNothing);
        await tester.enterText(find.byKey(const Key('explore-search')), 'zzzz');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.textContaining('Nada encontrado'), findsOneWidget);
      },
    );

    testWidgets('ativar cupom pede login, retoma a oferta e emite uma vez', (
      tester,
    ) async {
      final (repo, auth) = await boot(tester);
      await tester.tap(find.text('Cupons').last);
      await tester.pumpAndSettle();
      expect(find.text('Entre para ver seus cupons'), findsOneWidget);

      await tester.tap(find.text('Explorar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ofertas'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Desconto no passeio de dunas'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('offer-activate')));

      // visitante é levado ao login
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      await login(tester);
      expect(auth.current, isNotNull);

      // login concluído: o fluxo segue para a revisão da MESMA oferta
      expect(find.text('Revisar ativação'), findsOneWidget);
      expect(find.text('20% de desconto'), findsWidgets);

      // sem aceitar as condições, o botão fica desabilitado
      final confirm = find.byKey(const Key('review-confirm'));
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(of: confirm, matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('review-accept')));
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(find.text('Seu cupom'), findsOneWidget);
      expect(find.text('Ativo'), findsOneWidget);
      expect(repo.issueCalls, 1);
      expect((await repo.myCoupons()).length, 1);
    });

    testWidgets(
      'falha de rede ao ativar não duplica: a nova tentativa usa a mesma chave',
      (tester) async {
        final (repo, auth) = await boot(tester);
        await auth.verifyCode('a@b.co', DemoAuthGateway.demoCode);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Explorar').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ofertas'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Água de coco'));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const Key('offer-activate')));
        await tester.tap(find.byKey(const Key('review-accept')));
        await tester.pumpAndSettle();

        repo.failNext = true;
        await tester.tap(find.byKey(const Key('review-confirm')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Sem conexão'), findsOneWidget);
        expect(find.text('Tentar de novo'), findsOneWidget);

        await tester.tap(find.byKey(const Key('review-confirm')));
        await tester.pumpAndSettle();
        expect(find.text('Seu cupom'), findsOneWidget);
        expect((await repo.myCoupons()).length, 1);
      },
    );

    testWidgets(
      'solicitar reserva: exige horário, pede login e confirma envio',
      (tester) async {
        final (repo, _) = await boot(tester);
        await tester.tap(find.text('Passeio às Lagoas Clássicas').first);
        await tester.pumpAndSettle();

        final submit = find.byKey(const Key('reserve-submit'));
        await reveal(tester, submit);
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
        expect(find.text('Escolha um horário'), findsOneWidget);

        final slot = find
            .byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith('slot-'),
            )
            .first;
        await tapVisible(tester, slot);
        await tapVisible(tester, find.byKey(const Key('people-plus')));
        expect(find.text('3'), findsOneWidget);

        await tapVisible(tester, submit);
        expect(find.byKey(const Key('login-email')), findsOneWidget);
        await login(tester);

        expect(find.text('Solicitação enviada'), findsOneWidget);
        expect(find.text('Aguardando confirmação'), findsOneWidget);
        expect(repo.reservationCalls, 1);
        expect((await repo.myReservations()).single.participants, 3);
      },
    );

    testWidgets('perfil: salvar nome, sair da conta', (tester) async {
      final (_, auth) = await boot(tester);
      await auth.verifyCode('maria@email.com', DemoAuthGateway.demoCode);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-avatar')));
      await tester.pumpAndSettle();
      expect(find.text('maria@email.com'), findsOneWidget);
      await tester.tap(find.byKey(const Key('edit-name')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('name-field')),
        'Maria Souza',
      );
      await tester.tap(find.byKey(const Key('name-save')));
      await tester.pumpAndSettle();
      expect(find.text('Maria Souza'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('sign-out')));
      expect(auth.current, isNull);
    });
  });
}
