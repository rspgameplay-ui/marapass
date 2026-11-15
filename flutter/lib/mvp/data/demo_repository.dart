import 'models.dart';
import 'repository.dart';

/// Repositório em memória: usado nos testes e no modo demonstração
/// (`--dart-define=MVP_DEMO=true` ou quando o Supabase não está configurado).
/// Os dados são fictícios e marcados como demonstração na interface.
class DemoMvpRepository implements MvpRepository {
  DemoMvpRepository({this.failNext = false, this.latency = Duration.zero});

  /// Faz a próxima chamada de escrita falhar (testes de erro).
  bool failNext;
  final Duration latency;

  final _reservations = <Reservation>[];
  final _coupons = <CouponInstance>[];
  final _entitlements = <PassportEntitlement>[];
  final _issuedKeys = <String, String>{};
  final _reservationKeys = <String, String>{};
  final _orderKeys = <String, String>{};
  String? displayName;
  int issueCalls = 0;
  int reservationCalls = 0;

  static const _est = Establishment(
    id: 'e1',
    name: 'Lençóis Experience (demonstração)',
    city: 'Barreirinhas',
    category: 'passeios',
  );

  static final _experiences = [
    const Experience(
      id: 'x1',
      establishmentId: 'e1',
      title: 'Passeio às Lagoas Clássicas',
      description: 'Travessia pelas dunas até a Lagoa Azul e a Lagoa Bonita, com tempo para banho.',
      category: 'passeios',
      priceFromCents: 18000,
      durationMinutes: 300,
      capacity: 12,
      establishment: _est,
    ),
    const Experience(
      id: 'x2',
      establishmentId: 'e1',
      title: 'Rio Preguiças e Vassouras',
      description:
          'Descida de barco pelo Rio Preguiças até os Pequenos Lençóis.',
      category: 'passeios',
      priceFromCents: 22000,
      durationMinutes: 420,
      capacity: 10,
      establishment: _est,
    ),
    const Experience(
      id: 'x3',
      establishmentId: 'e1',
      title: 'Pôr do sol nas dunas',
      description: 'Final de tarde com vista aberta para o campo de dunas.',
      category: 'passeios',
      priceFromCents: 9000,
      durationMinutes: 150,
      capacity: 8,
      establishment: _est,
    ),
  ];

  static final _offers = [
    Offer(
      id: 'o1',
      establishmentId: 'e1',
      title: 'Desconto no passeio de dunas (demonstração)',
      description: 'Oferta de demonstração para testar o fluxo de cupom.',
      discountType: 'percentage',
      discountValue: 20,
      perUserLimit: 1,
      establishment: _est,
    ),
    Offer(
      id: 'o2',
      establishmentId: 'e1',
      title: 'Água de coco de cortesia (demonstração)',
      description: 'Cortesia na primeira compra.',
      discountType: 'fixed_amount',
      discountValue: 8,
      perUserLimit: 1,
      establishment: _est,
    ),
  ];

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  void _maybeFail() {
    if (failNext) {
      failNext = false;
      throw const MvpException(
        'Sem conexão. Confira a internet e tente de novo.',
      );
    }
  }

  @override
  Future<List<Experience>> experiences({
    String? query,
    String? category,
  }) async {
    await _wait();
    return _experiences.where((e) {
      final q = (query ?? '').toLowerCase().trim();
      return (q.isEmpty || e.title.toLowerCase().contains(q)) &&
          (category == null || category.isEmpty || e.category == category);
    }).toList();
  }

  @override
  Future<List<Slot>> slots(String experienceId) async {
    await _wait();
    final base = DateTime.now();
    return [
      for (var d = 1; d <= 5; d++)
        for (final h in [8, 14])
          Slot(
            id: 's-$experienceId-$d-$h',
            experienceId: experienceId,
            startsAt: DateTime(base.year, base.month, base.day + d, h),
            capacity: 8,
          ),
    ];
  }

  @override
  Future<List<Offer>> offers({String? query}) async {
    await _wait();
    final q = (query ?? '').toLowerCase().trim();
    return _offers
        .where((o) => q.isEmpty || o.title.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<List<Establishment>> establishments({String? query}) async => [_est];

  @override
  Future<String> requestReservation({
    required String slotId,
    required int participants,
    required String requestKey,
  }) async {
    await _wait();
    reservationCalls++;
    _maybeFail();
    final existing = _reservationKeys[requestKey];
    if (existing != null) return existing;
    final id = 'r${_reservations.length + 1}';
    final xid = slotId.split('-')[1];
    _reservations.add(
      Reservation(
        id: id,
        experienceId: xid,
        scheduledAt: DateTime.now().add(const Duration(days: 2)),
        participants: participants,
        status: 'pending',
        experienceTitle: _experiences.firstWhere((e) => e.id == xid).title,
      ),
    );
    _reservationKeys[requestKey] = id;
    return id;
  }

  @override
  Future<List<Reservation>> myReservations() async => List.of(_reservations);

  @override
  Future<String> issueCoupon({
    required String offerId,
    required String idempotencyKey,
    String? reservationId,
  }) async {
    await _wait();
    issueCalls++;
    _maybeFail();
    final existing = _issuedKeys[idempotencyKey];
    if (existing != null) return existing;
    final offer = _offers.firstWhere((o) => o.id == offerId);
    final id = 'c${_coupons.length + 1}';
    _coupons.add(
      CouponInstance(
        id: id,
        offerId: offerId,
        status: 'issued',
        title: offer.title,
        displayCode:
            'DEMO-${(7000 + _coupons.length).toRadixString(16).toUpperCase()}',
        discountType: offer.discountType,
        discountValue: offer.discountValue,
        issuedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      ),
    );
    _issuedKeys[idempotencyKey] = id;
    return id;
  }

  @override
  Future<List<CouponInstance>> myCoupons() async => List.of(_coupons);

  @override
  Future<List<PassportProduct>> passportProducts() async => const [
    PassportProduct(
      id: 'p1',
      name: 'Passaporte MaraPass (demonstração)',
      priceCents: 4900,
      description: 'Benefícios em parceiros da região durante a sua estadia.',
      durationDays: 7,
      benefitsExplanation: 'Descontos e cortesias em parceiros aprovados.',
    ),
  ];

  @override
  Future<List<PassportEntitlement>> myEntitlements() async =>
      List.of(_entitlements);

  @override
  Future<String> prepareOrder({
    required String productId,
    required String requestKey,
  }) async {
    await _wait();
    _maybeFail();
    return _orderKeys.putIfAbsent(
      requestKey,
      () => 'order-${_orderKeys.length + 1}',
    );
  }

  @override
  Future<void> activatePassport(String entitlementId) async {}

  @override
  Future<Profile?> myProfile() async =>
      Profile(id: 'demo', displayName: displayName);

  @override
  Future<void> updateDisplayName(String name) async {
    displayName = name.trim();
  }

  @override
  Future<void> deleteMyAccount() async {}
}
