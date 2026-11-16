import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'repository.dart';

/// Implementação real. Toda regra de negócio (vagas, limites, idempotência,
/// elegibilidade) é decidida no servidor pelas RPCs; o app só chama e traduz erros.
class SupabaseMvpRepository implements MvpRepository {
  SupabaseMvpRepository(this._client);
  final SupabaseClient _client;

  String get _uid {
    final u = _client.auth.currentUser;
    if (u == null) {
      throw const MvpException('Entre na sua conta para continuar.');
    }
    return u.id;
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on MvpException {
      rethrow;
    } catch (e) {
      throw translateError(e);
    }
  }

  @override
  Future<List<Experience>> experiences({String? query, String? category}) =>
      _guard(() async {
        var q = _client
            .from('experiences')
            .select('*, establishments(name, city, category)')
            .eq('status', 'published');
        if (category != null && category.isNotEmpty) {
          q = q.eq('category', category);
        }
        if (query != null && query.trim().isNotEmpty) {
          q = q.ilike('title', '%${_escape(query)}%');
        }
        final rows = await q.order('created_at', ascending: false).limit(60);
        return rows.map(Experience.fromJson).toList();
      });

  @override
  Future<List<Slot>> slots(String experienceId) => _guard(() async {
    final rows = await _client
        .from('experience_slots')
        .select()
        .eq('experience_id', experienceId)
        .eq('is_open', true)
        .gt('starts_at', DateTime.now().toUtc().toIso8601String())
        .order('starts_at')
        .limit(40);
    return rows.map(Slot.fromJson).toList();
  });

  @override
  Future<List<Offer>> offers({String? query}) => _guard(() async {
    var q = _client
        .from('offers')
        .select('*, establishments(name, city, category)');
    if (query != null && query.trim().isNotEmpty) {
      q = q.ilike('title', '%${_escape(query)}%');
    }
    final rows = await q.order('created_at', ascending: false).limit(60);
    return rows.map(Offer.fromJson).toList();
  });

  @override
  Future<List<Establishment>> establishments({String? query}) =>
      _guard(() async {
        var q = _client.from('establishments').select();
        if (query != null && query.trim().isNotEmpty) {
          q = q.ilike('name', '%${_escape(query)}%');
        }
        final rows = await q.order('name').limit(60);
        return rows.map(Establishment.fromJson).toList();
      });

  @override
  Future<String> requestReservation({
    required String slotId,
    required int participants,
    required String requestKey,
  }) => _guard(() async {
    final r = await _client.rpc(
      'request_reservation',
      params: {
        'p_user_id': _uid,
        'p_slot_id': slotId,
        'p_participants': participants,
        'p_request_key': requestKey,
      },
    );
    return _idOf(r);
  });

  @override
  Future<List<Reservation>> myReservations() => _guard(() async {
    final rows = await _client
        .from('reservations')
        .select('*, experiences(title)')
        .eq('user_id', _uid)
        .order('scheduled_at', ascending: false)
        .limit(60);
    return rows.map(Reservation.fromJson).toList();
  });

  @override
  Future<String> issueCoupon({
    required String offerId,
    required String idempotencyKey,
    String? reservationId,
  }) => _guard(() async {
    final r = await _client.rpc(
      'issue_coupon',
      params: {
        'p_user_id': _uid,
        'p_offer_id': offerId,
        'p_idempotency_key': idempotencyKey,
        'p_reservation_id': ?reservationId,
      },
    );
    return _idOf(r);
  });

  @override
  Future<List<CouponInstance>> myCoupons() => _guard(() async {
    final rows = await _client
        .from('coupon_instances')
        .select()
        .eq('beneficiary_user_id', _uid)
        .order('issued_at', ascending: false)
        .limit(100);
    return rows.map(CouponInstance.fromJson).toList();
  });

  @override
  Future<List<PassportProduct>> passportProducts() => _guard(() async {
    final rows = await _client
        .from('passport_products')
        .select()
        .eq('is_published', true)
        .order('price_cents');
    return rows.map(PassportProduct.fromJson).toList();
  });

  @override
  Future<List<PassportEntitlement>> myEntitlements() => _guard(() async {
    final rows = await _client
        .from('passport_entitlements')
        .select()
        .eq('user_id', _uid)
        .order('purchased_at', ascending: false);
    return rows.map(PassportEntitlement.fromJson).toList();
  });

  @override
  Future<String> prepareOrder({
    required String productId,
    required String requestKey,
  }) => _guard(() async {
    final r = await _client.rpc(
      'mp_prepare_passport_order',
      params: {
        'p_user_id': _uid,
        'p_product_id': productId,
        'p_request_key': requestKey,
      },
    );
    return _idOf(r);
  });

  @override
  Future<void> activatePassport(String entitlementId) => _guard(() async {
    await _client.rpc(
      'mp_activate_passport',
      params: {'p_user_id': _uid, 'p_entitlement_id': entitlementId},
    );
  });

  @override
  Future<Profile?> myProfile() => _guard(() async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', _uid)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  });

  @override
  Future<void> updateDisplayName(String name) => _guard(() async {
    await _client.from('profiles').upsert({
      'id': _uid,
      'display_name': name.trim(),
    });
  });

  @override
  Future<void> deleteMyAccount() => _guard(() async {
    try {
      await _client.rpc('delete_my_account');
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202' || e.code == '42883') {
        throw const MvpException(
          'A exclusão automática ainda não está ativa. Escreva para o suporte e removemos seus dados.',
        );
      }
      rethrow;
    }
    await _client.auth.signOut();
  });
}

String _escape(String q) => q
    .trim()
    .replaceAll(RegExp(r'[%_,()\\]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ');

/// As RPCs podem devolver o id, uma linha ou uma lista de linhas.
String _idOf(Object? r) {
  if (r is String) return r;
  if (r is Map && r['id'] != null) return '${r['id']}';
  if (r is List && r.isNotEmpty) return _idOf(r.first);
  return '';
}

/// Converte falhas técnicas em mensagens que dizem o que aconteceu e o que fazer.
MvpException translateError(Object e) {
  final raw =
      (e is PostgrestException ? '${e.message} ${e.details ?? ''}' : '$e')
          .toLowerCase();
  if (e is AuthException) {
    if (raw.contains('expired') || raw.contains('invalid')) {
      return const MvpException(
        'Código inválido ou vencido. Peça um novo código.',
      );
    }
    if (raw.contains('rate') || raw.contains('seconds')) {
      return const MvpException(
        'Aguarde um instante antes de pedir outro código.',
      );
    }
    return const MvpException(
      'Não foi possível entrar. Confira o e-mail e tente de novo.',
    );
  }
  if (raw.contains('jwt') ||
      raw.contains('not authenticated') ||
      raw.contains('permission denied') ||
      (e is PostgrestException && e.code == '42501')) {
    return const MvpException(
      'Sua sessão expirou. Entre de novo para continuar.',
    );
  }
  if (raw.contains('capacity') ||
      raw.contains('full') ||
      raw.contains('no seats') ||
      raw.contains('vaga')) {
    return const MvpException(
      'Esse horário não tem mais vagas. Escolha outro.',
    );
  }
  if (raw.contains('issue limit')) {
    return const MvpException('Os cupons desta oferta esgotaram.');
  }
  if (raw.contains('limit') || raw.contains('already')) {
    return const MvpException('Você já atingiu o limite desta oferta.');
  }
  if (raw.contains('expired') ||
      raw.contains('ended') ||
      raw.contains('window')) {
    return const MvpException('Esta oferta já terminou.');
  }
  if (raw.contains('not published') ||
      raw.contains('unavailable') ||
      raw.contains('paused') ||
      raw.contains('not found')) {
    return const MvpException('Esta oferta não está mais disponível.');
  }
  if (e is TimeoutException ||
      raw.contains('socket') ||
      raw.contains('clientexception') ||
      raw.contains('failed host') ||
      raw.contains('network') ||
      raw.contains('connection')) {
    return const MvpException(
      'Sem conexão. Confira a internet e tente de novo.',
    );
  }
  return const MvpException(
    'Não foi possível concluir agora. Tente de novo em instantes.',
  );
}
