import 'models.dart';

/// Erro já traduzido para o turista: explica a causa e indica o que fazer.
class MvpException implements Exception {
  const MvpException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Contrato de dados do app. A implementação real fala com o Supabase;
/// a de demonstração e a dos testes ficam em memória.
abstract class MvpRepository {
  Future<List<Experience>> experiences({String? query, String? category});
  Future<List<Slot>> slots(String experienceId);
  Future<List<Offer>> offers({String? query});
  Future<List<Establishment>> establishments({String? query});

  /// Retorna o id da reserva. `requestKey` torna a chamada idempotente.
  Future<String> requestReservation({
    required String slotId,
    required int participants,
    required String requestKey,
  });
  Future<List<Reservation>> myReservations();

  /// Retorna o id do cupom emitido. `idempotencyKey` evita emissão duplicada.
  Future<String> issueCoupon({
    required String offerId,
    required String idempotencyKey,
    String? reservationId,
  });
  Future<List<CouponInstance>> myCoupons();

  Future<List<PassportProduct>> passportProducts();
  Future<List<PassportEntitlement>> myEntitlements();
  Future<String> prepareOrder({
    required String productId,
    required String requestKey,
  });
  Future<void> activatePassport(String entitlementId);

  Future<Profile?> myProfile();
  Future<void> updateDisplayName(String name);
  Future<void> deleteMyAccount();
}
