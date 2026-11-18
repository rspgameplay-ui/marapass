import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marapass_mapa/mvp/data/remote.dart';
import 'package:marapass_mapa/mvp/ui/coupon_commerce.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/mvp/data/coupon_commerce.dart';
import 'package:marapass_mapa/mvp/data/store.dart';

const testCode = 'MP-13A45C6789AB4DEF8D02123456789ABC';

class ReceiptBackend extends Fake implements MvpRemote {
  String state = 'issued';
  int confirmations = 0;
  String? channel;
  @override
  String get userId => 'tester';
  @override
  bool get signedIn => true;
  @override
  Future<List<Map<String, dynamic>>> statement(
    String scope, {
    String? code,
    Map<String, dynamic>? cursor,
    Map<String, dynamic> filters = const {},
  }) async => [
    {
      'id': 'test',
      'code': testCode,
      'state': state,
      'stage': state,
      'paid': state == 'converted' ? 9000 : 0,
      'fee': state == 'converted' ? 450 : 0,
      'points': state == 'converted' ? 90 : 0,
      'entries': [],
      'events': [],
      'sale': {
        'title': 'Diária de teste',
        'rules': 'Uma diária',
        'price': 10000,
        'discount_cents': 1000,
        'due': 9000,
        'payment': 'Pagar ao parceiro',
        'expires': '2099-01-01T03:00:00Z',
        'url': null,
      },
    },
  ];
  @override
  Future<void> reportPayment(String code) async {
    state = 'payment_reported';
  }

  @override
  Future<Map<String, dynamic>> confirmReceipt(
    String code,
    int amount,
    String source,
  ) async {
    confirmations++;
    channel = source;
    if (amount != 9000) return {'ok': false, 'reason': 'amount_mismatch'};
    state = 'converted';
    return {'ok': true};
  }
}

Future<ReceiptBackend> showReceipt(WidgetTester tester, String scope) async {
  final backend = ReceiptBackend();
  tester.view.physicalSize = const Size(820, 1900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appStoreProvider.overrideWith(
          (ref) => AppStore.memory()..remote = backend,
        ),
      ],
      child: MaterialApp(
        home: CouponReceipt(code: testCode, scope: scope, channel: 'whatsapp'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return backend;
}

void main() {
  testWidgets('turista informa o pagamento sem confirmar a venda', (
    tester,
  ) async {
    final backend = await showReceipt(tester, 'tourist');
    await tester.tap(find.text('Já paguei ao parceiro'));
    await tester.pumpAndSettle();
    expect(
      find.text('Aguardando o parceiro conferir o recebimento.'),
      findsOneWidget,
    );
    expect(backend.confirmations, 0);
  });
  testWidgets('link do parceiro exige conferência explícita do recebimento', (
    tester,
  ) async {
    final backend = await showReceipt(tester, 'partner');
    expect(backend.confirmations, 0);
    await tester.enterText(find.byType(TextField).first, '90,00');
    await tester.tap(find.text('Confirmo que recebi este valor'));
    await tester.pumpAndSettle();
    expect(backend.channel, 'whatsapp');
    expect(backend.confirmations, 1);
    expect(find.text('Convertido'), findsOneWidget);
    expect(find.textContaining('R\$ 4,50'), findsOneWidget);
  });

  test('reais e percentuais preservam centavos e rejeitam ambiguidade', () {
    expect(couponHundredths('90,00'), 9000);
    expect(couponHundredths(' 0.05 '), 5);
    expect(couponHundredths('10'), 1000);
    for (final raw in ['1,005', '-10', '1e2', '', '1.200,00']) {
      expect(couponHundredths(raw), isNull);
    }
  });
  test('painel e QR identificam o mesmo código emitido pelo servidor', () {
    const code = 'MP-13A45C6789AB4DEF8D02123456789ABC';
    expect(commercialCouponCode(code), code);
    expect(commercialCouponCode('marapass:cupom:${code.toLowerCase()}'), code);
    expect(commercialCouponCode('MP-TEST'), isNull);
    expect(commercialCouponCode('marapass:offer:po:123'), isNull);
  });
  test('a carteira exibe as condições congeladas de uma oferta retirada', () {
    final coupon = LocalCoupon(
      id: '1',
      cupomId: 'po:retirada',
      code: 'teste',
      issuedAt: DateTime(2026),
      sale: {
        'title': 'Diária de teste',
        'benefit': '10%',
        'rules': 'Uma diária',
        'discount_cents': 1000,
        'expires': '2099-01-01T03:00:00Z',
      },
    );
    expect(coupon.cupom!.parceiro, 'Diária de teste');
    expect(coupon.cupom!.valorCents, 1000);
    expect(coupon.active, isTrue);
  });
}
