import 'package:supabase_flutter/supabase_flutter.dart';

import 'repository.dart';
import 'supabase_repository.dart' show translateError;

/// Acesso às funções `mvp_*` do Supabase (cupons, validação, reservas e
/// check-ins do app web). Regras de uso único, idempotência e permissão do
/// parceiro ficam no banco; aqui só chamamos e traduzimos os erros.
class MvpRemote {
  MvpRemote(this._c);
  final SupabaseClient _c;

  String? get userId => _c.auth.currentUser?.id;
  bool get signedIn =>
      userId != null && !(_c.auth.currentUser?.isAnonymous ?? false);

  Future<T> _g<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on MvpException {
      rethrow;
    } catch (e) {
      throw translateError(e);
    }
  }

  Map<String, dynamic> _row(Object? r) => r is List
      ? Map<String, dynamic>.from(r.first as Map)
      : Map<String, dynamic>.from(r! as Map);

  Future<Map<String, dynamic>> activateCoupon(String cupomKey) => _g(
    () async => _row(
      await _c.rpc('mvp_activate_coupon', params: {'p_cupom_key': cupomKey}),
    ),
  );

  Future<void> joinDemoPartner() => _g(() => _c.rpc('mvp_join_demo_partner'));

  Future<Map<String, dynamic>> validateCoupon(String code, int? amountCents) =>
      _g(
        () async => Map<String, dynamic>.from(
          await _c.rpc(
            'mvp_validate_coupon',
            params: {'p_code': code, 'p_amount_cents': amountCents},
          ) as Map,
        ),
      );

  Future<Map<String, dynamic>> requestReservation({
    required String itemKey,
    required String itemTitle,
    required DateTime day,
    required String period,
    required int people,
    required String requestKey,
    String? cupomKey,
    String? customerName,
  }) => _g(
    () async => _row(
      await _c.rpc(
        'mvp_request_reservation',
        params: {
          'p_item_key': itemKey,
          'p_item_title': itemTitle,
          'p_day': _date(day),
          'p_period': period,
          'p_people': people,
          'p_request_key': requestKey,
          'p_cupom_key': cupomKey,
          'p_customer_name': customerName,
        },
      ),
    ),
  );

  Future<Map<String, dynamic>> updateReservation(
    String id,
    String action, {
    DateTime? day,
    String? period,
    int? people,
    String? reason,
  }) => _g(
    () async => _row(
      await _c.rpc(
        'mvp_update_reservation',
        params: {
          'p_id': id,
          'p_action': action,
          'p_day': day == null ? null : _date(day),
          'p_period': period,
          'p_people': people,
          'p_reason': reason,
        },
      ),
    ),
  );

  Future<Map<String, dynamic>> decideReservation(String id, bool accept) => _g(
    () async => _row(
      await _c.rpc(
        'mvp_decide_reservation',
        params: {'p_id': id, 'p_accept': accept},
      ),
    ),
  );

  Future<Map<String, dynamic>> checkIn(
    String itemKey,
    String polo,
    String cidade,
  ) => _g(
    () async => _row(
      await _c.rpc(
        'mvp_checkin',
        params: {'p_item_key': itemKey, 'p_polo': polo, 'p_cidade': cidade},
      ),
    ),
  );

  Future<void> rateCheckin(String id, int rating) => _g(
    () => _c.rpc('mvp_rate_checkin', params: {'p_id': id, 'p_rating': rating}),
  );

  Future<List<Map<String, dynamic>>> myCoupons() => _g(
    () async => List<Map<String, dynamic>>.from(
      await _c
          .from('mvp_coupons')
          .select()
          .eq('user_id', userId!)
          .order('issued_at', ascending: false),
    ),
  );

  /// Para o parceiro, a policy devolve todas as reservas; para o turista, só as dele.
  Future<List<Map<String, dynamic>>> reservations() => _g(
    () async => List<Map<String, dynamic>>.from(
      await _c.from('mvp_reservations').select().order('day').limit(300),
    ),
  );

  Future<List<Map<String, dynamic>>> myCheckins() => _g(
    () async => List<Map<String, dynamic>>.from(
      await _c
          .from('mvp_checkins')
          .select()
          .eq('user_id', userId!)
          .order('created_at', ascending: false),
    ),
  );

  Future<bool> isPartner() =>
      _g(() async => (await _c.rpc('mvp_is_partner')) == true);

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
