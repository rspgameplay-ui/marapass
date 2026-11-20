import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content.dart';
import 'models.dart' show formatBrl;
import 'remote.dart';
import 'repository.dart' show MvpException;

export 'store_models.dart';
import 'store_models.dart';
import 'trip.dart';

/// Estado local do aparelho para a versão de demonstração: favoritos,
/// preferências, cupons, reservas, check-ins, pedidos e a área do parceiro.
/// Transações com itens do Supabase usam o repositório real; este estado
/// cobre o catálogo editorial e funciona sem rede.
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs);
  final SharedPreferences? _prefs;
  static const _key = 'mp_store_v2';
  final _rnd = Random();

  // Preferências
  bool bigText = false;
  String language = 'pt';
  bool offerAlerts = true;
  bool highContrast = false;
  String? name;

  // Turista
  final favorites = <String>{};
  final coupons = <LocalCoupon>[];
  final reservations = <LocalReservation>[];
  final checkins = <Checkin>[];
  final savedEvents = <String>{};
  final readAvisos = <String>{};
  final packs = <String, Set<int>>{};
  final tickets = <Ticket>[];
  int invites = 0;
  int routesDone = 0;

  /// Rotas montadas em "Defina sua Rota" (ficam no aparelho).
  final trips = <Trip>[];

  Future<void> saveTrip(Trip t) async {
    trips.removeWhere((x) => x.id == t.id);
    trips.insert(0, t);
    await _save();
  }

  Future<void> deleteTrip(String id) async {
    trips.removeWhere((x) => x.id == id);
    await _save();
  }

  bool fotoAlbum = false;

  // Parceiro (demonstração)
  final partnerOffers = <PartnerOffer>[];
  final validations = <Validation>[];

  /// Supabase (funções mvp_*). Nulo nos testes e no modo demonstração.
  MvpRemote? remote;
  bool syncing = false;
  final commercialPoints = <Map<String, dynamic>>[];
  String? _account;
  int _syncGeneration = 0;
  void changeAccount() {
    if (remote == null || _account == remote!.userId) return;
    ++_syncGeneration;
    _account = remote!.userId;
    syncing = false;
    coupons.clear();
    commercialPoints.clear();
    validations.clear();
    partnerOffers.clear();
    reservations.clear();
    checkins.clear();
    tickets.clear();
    Content.extraCupons.clear();
    isPartnerMember = false;
    notifyListeners();
  }

  bool isPartnerMember = false;

  /// Com login real, cupons, reservas e check-ins vivem no banco.
  bool get online => remote?.signedIn ?? false;

  static Future<AppStore> load({MvpRemote? remote}) async {
    SharedPreferences? p;
    try {
      p = await SharedPreferences.getInstance();
    } catch (_) {}
    final s = AppStore._(p)..remote = remote;
    s._restore();
    s.changeAccount();
    return s;
  }

  // ---------- Sincronização com o Supabase
  static DateTime _dt(Object? v) => DateTime.parse('$v').toLocal();

  LocalCoupon _couponFrom(Map<String, dynamic> r) => LocalCoupon(
    id: '${r['id']}',
    cupomId: '${r['cupom_key']}',
    code: '${r['code']}',
    issuedAt: _dt(r['issued_at']),
    stage: r['sale_stage'] as String?,
    sale: r['sale'] as Map<String, dynamic>?,
    usedAt: r['used_at'] == null ? null : _dt(r['used_at']),
  );

  LocalReservation _resFrom(Map<String, dynamic> r) => LocalReservation(
    id: '${r['id']}',
    itemId: '${r['item_key']}',
    date: DateTime.parse('${r['day']}'),
    period: '${r['period']}',
    people: (r['people'] as num).toInt(),
    status: ResStatus.values.firstWhere(
      (s) => s.name == r['status'],
      orElse: () => ResStatus.solicitada,
    ),
    history: [for (final h in (r['history'] as List? ?? const [])) '$h'],
    cupomId: r['cupom_key'] as String?,
    customer: r['user_id'] == remote?.userId
        ? 'Você'
        : ((r['customer_name'] as String?)?.trim().isNotEmpty ?? false
              ? r['customer_name'] as String
              : 'Turista'),
  );

  /// Traz do banco os dados da conta. Chamado no login e ao abrir a área do parceiro.
  Future<void> syncFromServer() async {
    final r = remote;
    changeAccount();
    if (r == null || syncing) return;
    if (!r.signedIn) {
      try {
        final offers = await r.publicSales();
        if (!r.signedIn) {
          _setPublicOffers(offers);
          notifyListeners();
        }
      } catch (_) {}
      return;
    }
    final generation = _syncGeneration;
    final account = r.userId;
    syncing = true;
    try {
      final results = await Future.wait([
        r.myCoupons(),
        r.reservations(),
        r.myCheckins(),
        r.isPartner(),
        r.couponPoints(),
      ]);
      if (generation != _syncGeneration || r.userId != account) return;
      commercialPoints
        ..clear()
        ..addAll(results[4] as List<Map<String, dynamic>>);
      isPartnerMember = results[3] as bool;
      coupons
        ..clear()
        ..addAll((results[0] as List<Map<String, dynamic>>).map(_couponFrom));
      reservations
        ..clear()
        ..addAll((results[1] as List<Map<String, dynamic>>).map(_resFrom));
      checkins
        ..clear()
        ..addAll(
          (results[2] as List<Map<String, dynamic>>).map(
            (c) => Checkin(
              itemId: '${c['item_key']}',
              polo: '${c['polo']}',
              cidade: '${c['cidade']}',
              at: _dt(c['created_at']),
              rating: (c['rating'] as num?)?.toInt() ?? 0,
              remoteId: '${c['id']}',
            ),
          ),
        );
      await _syncExtras(r);
    } catch (_) {
      // sem rede: mantém o que está no aparelho
    } finally {
      if (generation == _syncGeneration) {
        syncing = false;
        await _save();
      }
    }
  }

  Future<LocalCoupon> activateCouponAsync(String cupomId) async {
    if (remote != null && (!online || !cupomId.startsWith('po:'))) {
      throw const MvpException(
        'Para emitir, entre na sua conta e escolha uma oferta comercial aprovada.',
      );
    }
    if (!online) return activateCoupon(cupomId);
    final c = _couponFrom(
      cupomId.startsWith('po:')
          ? await remote!.activateOfferCoupon(cupomId.substring(3))
          : await remote!.activateCoupon(cupomId),
    );
    coupons
      ..removeWhere((e) => e.id == c.id)
      ..insert(0, c);
    await _save();
    return c;
  }

  Future<LocalReservation> requestReservationAsync({
    required String itemId,
    required DateTime date,
    required String period,
    required int people,
    required String requestKey,
    String? cupomId,
  }) async {
    if (!online) {
      return requestReservation(
        itemId: itemId,
        date: date,
        period: period,
        people: people,
        cupomId: cupomId,
      );
    }
    final row = await remote!.requestReservation(
      itemKey: itemId,
      itemTitle: Content.item(itemId)?.titulo ?? itemId,
      day: date,
      period: period,
      people: people,
      requestKey: requestKey,
      cupomKey: cupomId,
      customerName: name,
    );
    final r = _resFrom(row);
    reservations
      ..removeWhere((e) => e.id == r.id)
      ..add(r);
    await _save();
    return r;
  }

  Future<void> _applyRes(Map<String, dynamic> row) async {
    final r = _resFrom(row);
    final i = reservations.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      reservations[i] = r;
    } else {
      reservations.add(r);
    }
    await _save();
  }

  Future<void> rescheduleAsync(String id, DateTime date, String period) async =>
      online
      ? _applyRes(
          await remote!.updateReservation(
            id,
            'reschedule',
            day: date,
            period: period,
          ),
        )
      : reschedule(id, date, period);

  Future<void> changePeopleAsync(String id, int people) async => online
      ? _applyRes(await remote!.updateReservation(id, 'people', people: people))
      : changePeople(id, people);

  Future<void> cancelReservationAsync(String id, String reason) async => online
      ? _applyRes(await remote!.updateReservation(id, 'cancel', reason: reason))
      : cancelReservation(id, reason);

  Future<void> decideReservationAsync(String id, bool accept) async {
    if (!online) return decideReservation(id, accept);
    await _applyRes(await remote!.decideReservation(id, accept));
  }

  /// [method]: 'placa' (com [token]), 'gps' ou 'codigo' (com [lat]/[lng]).
  /// Sem conta, registra só no aparelho.
  Future<Checkin> checkInAsync(
    Item item, {
    String method = 'gps',
    String? token,
    double? lat,
    double? lng,
  }) async {
    if (!online) return checkIn(item);
    final row = await remote!.checkIn(
      item.id,
      item.polo,
      item.cidade,
      method: method,
      token: token,
      lat: lat,
      lng: lng,
    );
    final c = Checkin(
      itemId: item.id,
      polo: item.polo,
      cidade: item.cidade,
      at: _dt(row['created_at']),
      rating: (row['rating'] as num?)?.toInt() ?? 0,
      remoteId: '${row['id']}',
    );
    checkins
      ..removeWhere((e) => e.remoteId == c.remoteId)
      ..insert(0, c);
    await _save();
    return c;
  }

  Future<void> rateAsync(Checkin c, int stars) async {
    rate(c, stars);
    if (online && c.remoteId != null) {
      try {
        await remote!.rateCheckin(c.remoteId!, stars);
      } catch (_) {}
    }
  }

  /// Área do parceiro com dados reais: entra como parceiro de demonstração.
  /// Confere no servidor se a conta é de parceiro aprovado. Sem conta, a
  /// área do parceiro abre em modo de demonstração (dados do aparelho).
  Future<bool> enterPartnerArea() async {
    if (!online) return true;
    try {
      isPartnerMember = await remote!.isPartner();
      if (isPartnerMember) {
        reservations.removeWhere((r) => r.id == 'pr1' || r.id == 'pr2');
        await syncFromServer();
      }
    } catch (_) {}
    notifyListeners();
    return isPartnerMember;
  }

  // ---------- Ofertas, atendimento e perfil no banco
  static const _cats = {
    'passeio': Cat.passeio,
    'gastronomia': Cat.gastronomia,
    'hospedagem': Cat.hospedagem,
    'cultura': Cat.cultura,
    'natureza': Cat.natureza,
    'evento': Cat.evento,
    'artesanato': Cat.artesanato,
    'fotografia': Cat.fotografia,
    'transporte': Cat.transporte,
  };

  PartnerOffer _offerFrom(
    Map<String, dynamic> o,
    Map<String, (int, int)> stats,
  ) {
    final st = stats['${o['id']}'] ?? (0, 0);
    return PartnerOffer(
      id: '${o['id']}',
      title: '${o['title']}',
      benefit: '${o['benefit']}',
      rules: '${o['rules'] ?? ''}',
      limit: (o['issue_limit'] as num).toInt(),
      until: DateTime.parse('${o['valid_until']}'),
      status: '${o['status']}',
      issued: st.$1,
      used: st.$2,
      pauseReason: o['pause_reason'] as String?,
      imageUrl: o['image_url'] as String?,
      saleTerms: o['sale_terms'] as Map<String, dynamic>?,
    );
  }

  Ticket _ticketFrom(Map<String, dynamic> t) => Ticket(
    id: '${t['protocol']}',
    remoteId: '${t['id']}',
    kind: '${t['kind']}',
    subject: '${t['subject']}',
    body: '${t['body']}',
    at: _dt(t['created_at']),
    status: '${t['status']}',
    replies: [for (final x in (t['replies'] as List? ?? const [])) '$x'],
  );

  void _setPublicOffers(List<Map<String, dynamic>> offers) {
    // Ofertas aprovadas aparecem para os turistas como cupons.
    Content.extraCupons
      ..clear()
      ..addAll([
        for (final o in offers.where(
          (o) =>
              o['status'] == 'Ativa' &&
              o['sale_approved'] == true &&
              o['sale_terms'] != null,
        ))
          Cupom(
            id: 'po:${o['id']}',
            itemId: '',
            parceiro: '${o['title']}',
            cat: _cats[o['category']] ?? Cat.passeio,
            beneficio: '${o['benefit']}',
            detalhe:
                '${o['rules'] ?? ''} · Valor com desconto: ${formatBrl(o['sale_terms']['due'] as int)}',
            valorCents: o['sale_terms']['discount_cents'] as int,
            foto: o['image_url'] as String?,
            validade: DateTime.parse('${o['valid_until']}')
                .add(const Duration(hours: 23, minutes: 59)),
          ),
      ]);
  }

  Future<void> _syncExtras(MvpRemote r) async {
    final account = r.userId;
    final offers = await r.offers();
    if (account != r.userId) return;
    _setPublicOffers(offers);
    if (isPartnerMember) {
      final stats = {
        for (final s in await r.offerStats())
          '${s['offer_id']}': (
            (s['issued'] as num).toInt(),
            (s['used'] as num).toInt(),
          ),
      };
      if (account != r.userId) return;
      partnerOffers
        ..clear()
        ..addAll(
          offers
              .where((o) => o['created_by'] == account)
              .map((o) => _offerFrom(o, stats)),
        );
    }
    final ownTickets = await r.myTickets();
    if (account != r.userId) return;
    tickets
      ..clear()
      ..addAll(ownTickets.map(_ticketFrom));
  }

  Future<PartnerOffer> createOfferAsync({
    required String title,
    required String benefit,
    required String rules,
    required int limit,
    required DateTime until,
    String category = 'passeio',
  }) async {
    if (!online) {
      return createOffer(
        title: title,
        benefit: benefit,
        rules: rules,
        limit: limit,
        until: until,
      );
    }
    final o = _offerFrom(
      await remote!.createOffer(
        title: title,
        benefit: benefit,
        rules: rules,
        limit: limit,
        until: until,
        category: category,
      ),
      const {},
    );
    partnerOffers.insert(0, o);
    await _save();
    return o;
  }

  /// Ativa (aprova), pausa com motivo ou encerra uma oferta.
  /// Foto da oferta (só com conta de parceiro, pelo servidor).
  Future<void> setOfferImageAsync(String id, Uint8List bytes, String mime) async {
    if (!online) throw const MvpException('Entre na conta de parceiro para enviar fotos.');
    final row = await remote!.uploadOfferImage(id, bytes, mime);
    final i = partnerOffers.indexWhere((e) => e.id == id);
    if (i >= 0) partnerOffers[i].imageUrl = row['image_url'] as String?;
    await _syncExtras(remote!);
    notifyListeners();
  }

  Future<void> setOfferStatusAsync(
    String id,
    String status, {
    String? reason,
  }) async {
    if (!online) {
      status == 'Pausada' ? pauseOffer(id, reason ?? '') : resumeOffer(id);
      return;
    }
    final row = await remote!.setOfferStatus(id, status, reason: reason);
    final i = partnerOffers.indexWhere((e) => e.id == id);
    final old = i >= 0 ? partnerOffers[i] : null;
    final o = _offerFrom(row, {id: (old?.issued ?? 0, old?.used ?? 0)});
    if (i >= 0) partnerOffers[i] = o;
    await _syncExtras(remote!);
    await _save();
  }

  Future<Ticket> openTicketAsync({
    required String kind,
    required String subject,
    required String body,
  }) async {
    if (!online) return openTicket(kind: kind, subject: subject, body: body);
    final Ticket t;
    try {
      t = _ticketFrom(await remote!.openTicket(kind, subject, body));
    } catch (_) {
      // sem rede: guarda no aparelho para não perder a mensagem
      return openTicket(kind: kind, subject: subject, body: body);
    }
    tickets.insert(0, t);
    await _save();
    return t;
  }

  Future<void> replyAsync(String ticketId, String text) async {
    final t = tickets.firstWhere((e) => e.id == ticketId);
    if (!online || t.remoteId == null) return reply(ticketId, text);
    final row = await remote!.replyTicket(t.remoteId!, text);
    final i = tickets.indexWhere((e) => e.id == ticketId);
    tickets[i] = _ticketFrom(row);
    await _save();
  }

  Future<(bool, String)> validateCodeAsync(String raw, int amountCents) async {
    if (!online) return validateCode(raw, amountCents);
    final code = raw.trim().toUpperCase();
    final res = await remote!.validateCoupon(
      code,
      amountCents > 0 ? amountCents : null,
    );
    final ok = res['ok'] == true;
    final cupom = Content.cupom(res['cupom_key'] as String?);
    final reason = res['reason'] as String?;
    validations.insert(
      0,
      Validation(
        code: code,
        title: cupom?.parceiro ?? (ok ? 'Cupom' : 'Código não encontrado'),
        at: DateTime.now(),
        amountCents: amountCents,
        ok: ok,
        reason: switch (reason) {
          'used' => 'Já utilizado',
          'not_found' => 'Código inválido',
          _ => null,
        },
      ),
    );
    await _save();
    unawaited(syncFromServer());
    if (ok) return (true, '${cupom?.beneficio ?? 'Benefício'} aplicado.');
    return (
      false,
      reason == 'used'
          ? 'Este cupom já foi utilizado e não vale de novo.'
          : 'Código não encontrado. Confira as letras com o turista.',
    );
  }

  /// Para testes: estado vazio sem persistência.
  @visibleForTesting
  factory AppStore.memory() => AppStore._(null).._seedPartner();

  void _restore() {
    final raw = _prefs?.getString(_key);
    if (raw == null) {
      _seedPartner();
      return;
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      bigText = j['bigText'] as bool? ?? false;
      language = j['lang'] == 'en' ? 'en' : 'pt';
      offerAlerts = j['offerAlerts'] as bool? ?? true;
      highContrast = j['hc'] as bool? ?? false;
      name = j['name'] as String?;
      favorites.addAll(((j['fav'] as List?) ?? []).cast<String>());
      coupons.addAll(
        ((remote == null ? j['cup'] as List? : null) ?? []).map(
          (e) => LocalCoupon.fromJson(e as Map<String, dynamic>),
        ),
      );
      reservations.addAll(
        ((remote == null ? j['res'] as List? : null) ?? []).map(
          (e) => LocalReservation.fromJson(e as Map<String, dynamic>),
        ),
      );
      checkins.addAll(
        ((remote == null ? j['chk'] as List? : null) ?? []).map(
          (e) => Checkin.fromJson(e as Map<String, dynamic>),
        ),
      );
      savedEvents.addAll(((j['ev'] as List?) ?? []).cast<String>());
      readAvisos.addAll(((j['av'] as List?) ?? []).cast<String>());
      ((j['pk'] as Map?) ?? {}).forEach(
        (k, v) => packs['$k'] = (v as List).cast<int>().toSet(),
      );
      tickets.addAll(
        ((remote == null ? j['tk'] as List? : null) ?? []).map(
          (e) => Ticket.fromJson(e as Map<String, dynamic>),
        ),
      );
      invites = j['inv'] as int? ?? 0;
      routesDone = j['rt'] as int? ?? 0;
      trips
        ..clear()
        ..addAll([for (final t in (j['trips'] as List? ?? const [])) Trip.fromJson(t as Map<String, dynamic>)]);
      fotoAlbum = j['fa'] as bool? ?? false;
      partnerOffers.addAll(
        ((remote == null ? j['po'] as List? : null) ?? []).map(
          (e) => PartnerOffer.fromJson(e as Map<String, dynamic>),
        ),
      );
      validations.addAll(
        ((remote == null ? j['va'] as List? : null) ?? []).map(
          (e) => Validation.fromJson(e as Map<String, dynamic>),
        ),
      );
      if (partnerOffers.isEmpty) _seedPartner();
    } catch (_) {
      _seedPartner();
    }
  }

  void _seedPartner() {
    if (remote != null) return;
    partnerOffers
      ..clear()
      ..addAll([
        PartnerOffer(
          id: 'po1',
          title: 'Desconto no passeio às lagoas',
          benefit: r'R$ 50 de desconto',
          rules: 'Por pessoa, em passeios regulares.',
          limit: 200,
          until: DateTime(2027, 1, 31),
          status: 'Ativa',
          issued: 86,
          used: 41,
        ),
        PartnerOffer(
          id: 'po2',
          title: 'Kitesurf: aula experimental',
          benefit: r'R$ 40 de desconto',
          rules: 'Na primeira aula.',
          limit: 50,
          until: DateTime(2027, 2, 28),
          status: 'Pausada',
          issued: 12,
          used: 5,
          pauseReason: 'Vento fraco na temporada',
        ),
      ]);
    reservations.addAll([
      LocalReservation(
        id: 'pr1',
        itemId: 'lagoas',
        date: DateTime.now().add(const Duration(days: 1)),
        period: 'Manhã',
        people: 4,
        status: ResStatus.solicitada,
        history: ['Pedido recebido'],
        customer: 'Maria S.',
      ),
      LocalReservation(
        id: 'pr2',
        itemId: 'lagoas',
        date: DateTime.now().add(const Duration(days: 2)),
        period: 'Tarde',
        people: 2,
        status: ResStatus.confirmada,
        history: ['Pedido recebido', 'Confirmada pelo parceiro'],
        customer: 'João P.',
      ),
    ]);
  }

  Future<void> _save() async {
    notifyListeners();
    final p = _prefs;
    if (p == null) return;
    try {
      await p.setString(
        _key,
        jsonEncode({
          'bigText': bigText,
          'lang': language,
          'offerAlerts': offerAlerts,
          'hc': highContrast,
          'name': name,
          'fav': favorites.toList(),
          'cup': remote != null ? [] : coupons.map((e) => e.toJson()).toList(),
          'res': remote != null
              ? []
              : reservations.map((e) => e.toJson()).toList(),
          'chk': remote != null ? [] : checkins.map((e) => e.toJson()).toList(),
          'ev': savedEvents.toList(),
          'av': readAvisos.toList(),
          'pk': packs.map((k, v) => MapEntry(k, v.toList())),
          'tk': remote != null ? [] : tickets.map((e) => e.toJson()).toList(),
          'inv': invites,
          'rt': routesDone,
          'trips': [for (final t in trips) t.toJson()],
          'fa': fotoAlbum,
          'po': remote != null
              ? []
              : partnerOffers.map((e) => e.toJson()).toList(),
          'va': remote != null
              ? []
              : validations.map((e) => e.toJson()).toList(),
        }),
      );
    } catch (_) {}
  }

  String _id(String p) =>
      '$p${DateTime.now().microsecondsSinceEpoch}${_rnd.nextInt(999)}';
  String _code() {
    const a = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return 'MP-${List.generate(4, (_) => a[_rnd.nextInt(a.length)]).join()}';
  }

  // ---------- Preferências
  void setBigText(bool v) {
    bigText = v;
    _save();
  }

  void setLanguage(String v) {
    language = v == 'en' ? 'en' : 'pt';
    _save();
  }

  void setOfferAlerts(bool v) {
    offerAlerts = v;
    _save();
  }

  void setHighContrast(bool v) {
    highContrast = v;
    _save();
  }

  void setName(String v) {
    name = v.trim().isEmpty ? null : v.trim();
    _save();
    if (online && name != null) {
      unawaited(remote!.updateName(name!).catchError((_) {}));
    }
  }

  // ---------- Favoritos
  bool isFav(String id) => favorites.contains(id);
  void toggleFav(String id) {
    favorites.contains(id) ? favorites.remove(id) : favorites.add(id);
    _save();
  }

  // ---------- Cupons (idempotente por cupom: um ativo por pessoa)
  LocalCoupon? activeCouponFor(String cupomId) {
    for (final c in coupons) {
      if (c.cupomId == cupomId && c.active) return c;
    }
    return null;
  }

  LocalCoupon activateCoupon(String cupomId) {
    final existing = activeCouponFor(cupomId);
    if (existing != null) return existing;
    final c = LocalCoupon(
      id: _id('lc'),
      cupomId: cupomId,
      code: _code(),
      issuedAt: DateTime.now(),
    );
    coupons.insert(0, c);
    _save();
    return c;
  }

  void markCouponUsed(String id) {
    for (final c in coupons) {
      if (c.id == id && c.usedAt == null) c.usedAt = DateTime.now();
    }
    _save();
  }

  // ---------- Reservas
  List<LocalReservation> get myReservations =>
      reservations.where((r) => r.customer == 'Você').toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  LocalReservation requestReservation({
    required String itemId,
    required DateTime date,
    required String period,
    required int people,
    String? cupomId,
  }) {
    final r = LocalReservation(
      id: _id('r'),
      itemId: itemId,
      date: date,
      period: period,
      people: people,
      status: ResStatus.solicitada,
      history: ['Pedido enviado em ${_fmt(DateTime.now())}'],
      cupomId: cupomId,
    );
    reservations.add(r);
    _save();
    return r;
  }

  void reschedule(String id, DateTime date, String period) {
    final r = reservations.firstWhere((e) => e.id == id);
    r
      ..date = date
      ..period = period
      ..status = ResStatus.solicitada
      ..history.add('Novo dia pedido: ${_fmt(date)} ($period)');
    _save();
  }

  void changePeople(String id, int people) {
    final r = reservations.firstWhere((e) => e.id == id);
    r
      ..people = people
      ..history.add('Participantes alterados para $people');
    _save();
  }

  void cancelReservation(String id, String reason) {
    final r = reservations.firstWhere((e) => e.id == id);
    r
      ..status = ResStatus.cancelada
      ..history.add('Cancelada: $reason');
    _save();
  }

  void decideReservation(String id, bool accept) {
    final r = reservations.firstWhere((e) => e.id == id);
    r
      ..status = accept ? ResStatus.confirmada : ResStatus.recusada
      ..history.add(
        accept ? 'Confirmada pelo parceiro' : 'Recusada pelo parceiro',
      );
    _save();
  }

  // ---------- Check-in, pontos e selos
  Checkin checkIn(Item item) {
    final c = Checkin(
      itemId: item.id,
      polo: item.polo,
      cidade: item.cidade,
      at: DateTime.now(),
    );
    checkins.insert(0, c);
    _save();
    return c;
  }

  void rate(Checkin c, int stars) {
    c.rating = stars;
    _save();
  }

  bool alreadyCheckedIn(String itemId) {
    final today = DateTime.now();
    return checkins.any(
      (c) =>
          c.itemId == itemId &&
          c.at.year == today.year &&
          c.at.month == today.month &&
          c.at.day == today.day,
    );
  }

  Set<String> get stampedPolos => {for (final c in checkins) c.polo};
  Set<String> get stampedCities => {for (final c in checkins) c.cidade};

  /// Saldo = soma das movimentações (regra 6 da especificação).
  int get points =>
      checkins.length * 50 +
      coupons.where((c) => c.used && c.sale == null).length * 20 +
      commercialPoints.fold<int>(0, (n, e) => n + (e['points'] as int)) +
      stampedPolos.length * 100;

  (String, int, String?, int?) get level {
    var cur = Content.niveis.first;
    (String, int)? next;
    for (final l in Content.niveis) {
      if (points >= l.$2) {
        cur = l;
      } else {
        next ??= l;
      }
    }
    return (cur.$1, cur.$2, next?.$1, next?.$2);
  }

  List<(IconData, String, bool)> get achievements => [
    (Icons.flag_rounded, 'Primeiro check-in', checkins.isNotEmpty),
    (
      Icons.local_activity_rounded,
      'Primeiro cupom usado',
      coupons.any((c) => c.used),
    ),
    (Icons.map_rounded, 'Três polos visitados', stampedPolos.length >= 3),
    (
      Icons.event_available_rounded,
      'Primeira reserva',
      myReservations.isNotEmpty,
    ),
    (Icons.favorite_rounded, 'Cinco favoritos', favorites.length >= 5),
    (Icons.group_add_rounded, 'Convidou um amigo', invites > 0),
    (Icons.explore_rounded, 'Dez visitas registradas', checkins.length >= 10),
    (
      Icons.location_city_rounded,
      'Cinco cidades carimbadas',
      stampedCities.length >= 5,
    ),
    (
      Icons.workspace_premium_rounded,
      'Sete polos visitados',
      stampedPolos.length >= 7,
    ),
    (
      Icons.star_rounded,
      'Primeira avaliação',
      checkins.any((c) => c.rating > 0),
    ),
  ];

  /// Missões em andamento: (ícone, texto, progresso atual, meta). Só as que
  /// ainda não foram concluídas, da mais próxima de fechar para a mais longe.
  List<(IconData, String, int, int)> get missions {
    final all = <(IconData, String, int, int)>[
      (Icons.flag_rounded, 'Registre sua 1ª visita', checkins.length, 1),
      (Icons.explore_rounded, 'Registre 10 visitas', checkins.length, 10),
      (Icons.map_rounded, 'Visite 3 polos diferentes', stampedPolos.length, 3),
      (
        Icons.location_city_rounded,
        'Carimbe 5 cidades',
        stampedCities.length,
        5,
      ),
      (
        Icons.local_activity_rounded,
        'Use um cupom em um parceiro',
        coupons.where((c) => c.used).length,
        1,
      ),
      (Icons.group_add_rounded, 'Convide um amigo', invites, 1),
    ];
    final open = all.where((m) => m.$3 < m.$4).toList()
      ..sort((a, b) => (b.$3 / b.$4).compareTo(a.$3 / a.$4));
    return open.take(3).toList();
  }

  // ---------- Eventos, artesanato, pacote
  bool isSaved(String id) => savedEvents.contains(id);
  void toggleSaved(String id) {
    savedEvents.contains(id) ? savedEvents.remove(id) : savedEvents.add(id);
    _save();
  }

  Set<int> pack(String itemId) => packs[itemId] ?? <int>{};
  void togglePack(String itemId, int i) {
    final s = packs.putIfAbsent(itemId, () => <int>{});
    s.contains(i) ? s.remove(i) : s.add(i);
    _save();
  }

  void markAvisoRead(String id) {
    readAvisos.add(id);
    _save();
  }

  int get unreadAvisos =>
      Content.avisos.where((a) => !readAvisos.contains(a.id)).length;

  // ---------- Atendimento
  Ticket openTicket({
    required String kind,
    required String subject,
    required String body,
  }) {
    final t = Ticket(
      id: 'P${100000 + _rnd.nextInt(899999)}',
      kind: kind,
      subject: subject,
      body: body,
      at: DateTime.now(),
    );
    tickets.insert(0, t);
    _save();
    return t;
  }

  void reply(String ticketId, String text) {
    tickets.firstWhere((t) => t.id == ticketId).replies.add(text);
    _save();
  }

  /// Rotas traçadas no mapa (métrica do perfil).
  void addRoute() {
    routesDone++;
    _save();
  }

  void invite() {
    invites++;
    _save();
  }

  void setFotoAlbum(bool v) {
    fotoAlbum = v;
    _save();
  }

  // ---------- Parceiro
  PartnerOffer createOffer({
    required String title,
    required String benefit,
    required String rules,
    required int limit,
    required DateTime until,
  }) {
    final o = PartnerOffer(
      id: _id('po'),
      title: title,
      benefit: benefit,
      rules: rules,
      limit: limit,
      until: until,
    );
    partnerOffers.insert(0, o);
    _save();
    return o;
  }

  void pauseOffer(String id, String reason) {
    final o = partnerOffers.firstWhere((e) => e.id == id);
    o
      ..status = 'Pausada'
      ..pauseReason = reason;
    _save();
  }

  void resumeOffer(String id) {
    final o = partnerOffers.firstWhere((e) => e.id == id);
    o
      ..status = 'Ativa'
      ..pauseReason = null;
    _save();
  }

  /// Validação de uso único: o mesmo código nunca é aceito duas vezes.
  (bool, String) validateCode(String raw, int amountCents) {
    final code = raw.trim().toUpperCase();
    LocalCoupon? found;
    for (final c in coupons) {
      if (c.code == code) found = c;
    }
    if (found == null) {
      final v = Validation(
        code: code,
        title: 'Código não encontrado',
        at: DateTime.now(),
        amountCents: amountCents,
        ok: false,
        reason: 'Código inválido',
      );
      validations.insert(0, v);
      _save();
      return (false, 'Código não encontrado. Confira as letras com o turista.');
    }
    if (found.used) {
      validations.insert(
        0,
        Validation(
          code: code,
          title: found.cupom?.parceiro ?? 'Cupom',
          at: DateTime.now(),
          amountCents: amountCents,
          ok: false,
          reason: 'Já utilizado',
        ),
      );
      _save();
      return (false, 'Este cupom já foi utilizado e não vale de novo.');
    }
    if (found.expired) {
      validations.insert(
        0,
        Validation(
          code: code,
          title: found.cupom?.parceiro ?? 'Cupom',
          at: DateTime.now(),
          amountCents: amountCents,
          ok: false,
          reason: 'Expirado',
        ),
      );
      _save();
      return (
        false,
        'Este cupom venceu. Oriente o turista a procurar uma oferta válida.',
      );
    }
    found.usedAt = DateTime.now();
    validations.insert(
      0,
      Validation(
        code: code,
        title: found.cupom?.parceiro ?? 'Cupom',
        at: DateTime.now(),
        amountCents: amountCents,
        ok: true,
      ),
    );
    _save();
    return (true, '${found.cupom?.beneficio ?? 'Benefício'} aplicado.');
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

final appStoreProvider = ChangeNotifierProvider<AppStore>(
  (ref) => throw UnimplementedError('appStoreProvider precisa de override'),
);
