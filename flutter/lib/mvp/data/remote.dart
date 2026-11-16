import 'dart:typed_data';

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

  /// Pedido para virar parceiro (aprovado pela equipe MaraPass).
  Future<Map<String, dynamic>> requestPartner({
    required String business,
    required String cadastur,
    required String city,
    required String phone,
  }) => _g(
    () async => _row(
      await _c.rpc(
        'mvp_request_partner',
        params: {'p_business': business, 'p_cadastur': cadastur, 'p_city': city, 'p_phone': phone},
      ),
    ),
  );

  Future<Map<String, dynamic>?> myPartnerRequest() => _g(
    () async => await _c.from('mvp_partner_requests').select().eq('user_id', userId!).maybeSingle(),
  );

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

  /// Check-in validado no servidor: token da placa ('placa') ou GPS
  /// dentro do raio do local ('gps' e 'codigo').
  Future<Map<String, dynamic>> checkIn(
    String itemKey,
    String polo,
    String cidade, {
    required String method,
    String? token,
    double? lat,
    double? lng,
  }) => _g(
    () async => _row(
      await _c.rpc(
        'mvp_checkin',
        params: {'p_item_key': itemKey, 'p_polo': polo, 'p_cidade': cidade, 'p_method': method, 'p_token': token, 'p_lat': lat, 'p_lng': lng},
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

  // ---------- Ofertas do parceiro
  Future<List<Map<String, dynamic>>> offers() => _g(
    () async => List<Map<String, dynamic>>.from(
      await _c
          .from('mvp_partner_offers')
          .select()
          .order('created_at', ascending: false),
    ),
  );

  Future<List<Map<String, dynamic>>> offerStats() => _g(
    () async => List<Map<String, dynamic>>.from(
      await _c.rpc('mvp_offer_stats') as List,
    ),
  );

  Future<Map<String, dynamic>> createOffer({
    required String title,
    required String benefit,
    required String rules,
    required int limit,
    required DateTime until,
    String category = 'passeio',
  }) => _g(
    () async => _row(
      await _c.rpc(
        'mvp_create_offer',
        params: {
          'p_title': title,
          'p_benefit': benefit,
          'p_rules': rules,
          'p_limit': limit,
          'p_until': _date(until),
          'p_category': category,
        },
      ),
    ),
  );

  Future<Map<String, dynamic>> setOfferStatus(
    String id,
    String status, {
    String? reason,
  }) => _g(
    () async => _row(
      await _c.rpc(
        'mvp_set_offer_status',
        params: {'p_id': id, 'p_status': status, 'p_reason': reason},
      ),
    ),
  );

  /// Envia a foto da oferta para o bucket (pasta do próprio usuário) e grava
  /// o endereço na oferta. Devolve a oferta atualizada.
  Future<Map<String, dynamic>> uploadOfferImage(String offerId, Uint8List bytes, String mime) => _g(() async {
    final ext = mime == 'image/png' ? 'png' : (mime == 'image/webp' ? 'webp' : 'jpg');
    final path = '$userId/oferta-$offerId-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _c.storage.from('marapass-assets').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: true),
    );
    final url = _c.storage.from('marapass-assets').getPublicUrl(path);
    return _row(await _c.rpc('mvp_set_offer_image', params: {'p_id': offerId, 'p_url': url}));
  });

  Future<Map<String, dynamic>> activateOfferCoupon(String offerId) => _g(
    () async => _row(
      await _c.rpc(
        'mvp_activate_offer_coupon',
        params: {'p_offer_id': offerId},
      ),
    ),
  );

  // ---------- Atendimento
  Future<List<Map<String, dynamic>>> myTickets() => _g(
    () async => List<Map<String, dynamic>>.from(
      await _c
          .from('mvp_tickets')
          .select()
          .eq('user_id', userId!)
          .order('created_at', ascending: false),
    ),
  );

  Future<Map<String, dynamic>> openTicket(
    String kind,
    String subject,
    String body,
  ) => _g(
    () async => _row(
      await _c.rpc(
        'mvp_open_ticket',
        params: {'p_kind': kind, 'p_subject': subject, 'p_body': body},
      ),
    ),
  );

  Future<Map<String, dynamic>> replyTicket(String id, String text) => _g(
    () async => _row(
      await _c.rpc('mvp_reply_ticket', params: {'p_id': id, 'p_text': text}),
    ),
  );

  /// Nome do perfil (tabela profiles, policy de atualização do próprio usuário).
  Future<void> updateName(String name) => _g(
    () async =>
        _c.from('profiles').update({'display_name': name}).eq('id', userId!),
  );

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
