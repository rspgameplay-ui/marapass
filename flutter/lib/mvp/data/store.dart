import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content.dart';

/// Estado local do aparelho para a versão de demonstração: favoritos,
/// preferências, cupons, reservas, check-ins, pedidos e a área do parceiro.
/// Transações com itens do Supabase usam o repositório real; este estado
/// cobre o catálogo editorial e funciona sem rede.
class LocalCoupon {
  LocalCoupon({
    required this.id,
    required this.cupomId,
    required this.code,
    required this.issuedAt,
    this.usedAt,
  });
  final String id;
  final String cupomId;
  final String code;
  final DateTime issuedAt;
  DateTime? usedAt;
  Cupom? get cupom => Content.cupom(cupomId);
  bool get used => usedAt != null;
  bool get expired =>
      !used && (cupom?.validade.isBefore(DateTime.now()) ?? false);
  bool get active => !used && !expired;
  Map<String, dynamic> toJson() => {
    'id': id,
    'c': cupomId,
    'k': code,
    'i': issuedAt.toIso8601String(),
    'u': usedAt?.toIso8601String(),
  };
  static LocalCoupon fromJson(Map<String, dynamic> j) => LocalCoupon(
    id: j['id'] as String,
    cupomId: j['c'] as String,
    code: j['k'] as String,
    issuedAt: DateTime.parse(j['i'] as String),
    usedAt: j['u'] == null ? null : DateTime.parse(j['u'] as String),
  );
}

enum ResStatus {
  solicitada('Aguardando confirmação'),
  confirmada('Confirmada'),
  recusada('Não confirmada'),
  cancelada('Cancelada'),
  concluida('Concluída');

  const ResStatus(this.label);
  final String label;
}

class LocalReservation {
  LocalReservation({
    required this.id,
    required this.itemId,
    required this.date,
    required this.period,
    required this.people,
    required this.status,
    required this.history,
    this.cupomId,
    this.customer = 'Você',
  });
  final String id;
  final String itemId;
  DateTime date;
  String period; // Manhã | Tarde
  int people;
  ResStatus status;
  final List<String> history;
  String? cupomId;
  String customer;
  Item? get item => Content.item(itemId);
  Map<String, dynamic> toJson() => {
    'id': id,
    'it': itemId,
    'd': date.toIso8601String(),
    'p': period,
    'n': people,
    's': status.name,
    'h': history,
    'c': cupomId,
    'cu': customer,
  };
  static LocalReservation fromJson(Map<String, dynamic> j) => LocalReservation(
    id: j['id'] as String,
    itemId: j['it'] as String,
    date: DateTime.parse(j['d'] as String),
    period: j['p'] as String,
    people: j['n'] as int,
    status: ResStatus.values.byName(j['s'] as String),
    history: (j['h'] as List).cast<String>(),
    cupomId: j['c'] as String?,
    customer: (j['cu'] as String?) ?? 'Você',
  );
}

class Checkin {
  Checkin({
    required this.itemId,
    required this.polo,
    required this.cidade,
    required this.at,
    this.rating = 0,
  });
  final String itemId;
  final String polo;
  final String cidade;
  final DateTime at;
  int rating;
  Map<String, dynamic> toJson() => {
    'i': itemId,
    'p': polo,
    'c': cidade,
    'a': at.toIso8601String(),
    'r': rating,
  };
  static Checkin fromJson(Map<String, dynamic> j) => Checkin(
    itemId: j['i'] as String,
    polo: j['p'] as String,
    cidade: j['c'] as String,
    at: DateTime.parse(j['a'] as String),
    rating: j['r'] as int,
  );
}

class Ticket {
  Ticket({
    required this.id,
    required this.kind,
    required this.subject,
    required this.body,
    required this.at,
    this.status = 'Aberta',
    List<String>? replies,
  }) : replies = replies ?? [];
  final String id;
  final String kind; // Suporte | Sugestão | Avaliação | Reserva | Artesanato | Fotografia | Transfer
  final String subject;
  final String body;
  final DateTime at;
  String status;
  final List<String> replies;
  Map<String, dynamic> toJson() => {
    'id': id,
    'k': kind,
    's': subject,
    'b': body,
    'a': at.toIso8601String(),
    'st': status,
    'r': replies,
  };
  static Ticket fromJson(Map<String, dynamic> j) => Ticket(
    id: j['id'] as String,
    kind: j['k'] as String,
    subject: j['s'] as String,
    body: j['b'] as String,
    at: DateTime.parse(j['a'] as String),
    status: j['st'] as String,
    replies: (j['r'] as List).cast<String>(),
  );
}

/// Oferta criada pelo parceiro (área do parceiro, demonstração).
class PartnerOffer {
  PartnerOffer({
    required this.id,
    required this.title,
    required this.benefit,
    required this.rules,
    required this.limit,
    required this.until,
    this.status = 'Em análise',
    this.used = 0,
    this.issued = 0,
    this.pauseReason,
  });
  final String id;
  String title;
  String benefit;
  String rules;
  int limit;
  DateTime until;
  String status; // Ativa | Em análise | Pausada | Encerrada
  int used;
  int issued;
  String? pauseReason;
  Map<String, dynamic> toJson() => {
    'id': id,
    't': title,
    'b': benefit,
    'r': rules,
    'l': limit,
    'u': until.toIso8601String(),
    's': status,
    'us': used,
    'is': issued,
    'pr': pauseReason,
  };
  static PartnerOffer fromJson(Map<String, dynamic> j) => PartnerOffer(
    id: j['id'] as String,
    title: j['t'] as String,
    benefit: j['b'] as String,
    rules: j['r'] as String,
    limit: j['l'] as int,
    until: DateTime.parse(j['u'] as String),
    status: j['s'] as String,
    used: j['us'] as int,
    issued: j['is'] as int,
    pauseReason: j['pr'] as String?,
  );
}

class Validation {
  Validation({
    required this.code,
    required this.title,
    required this.at,
    required this.amountCents,
    required this.ok,
    this.reason,
  });
  final String code;
  final String title;
  final DateTime at;
  final int amountCents;
  final bool ok;
  final String? reason;
  Map<String, dynamic> toJson() => {
    'k': code,
    't': title,
    'a': at.toIso8601String(),
    'v': amountCents,
    'o': ok,
    'r': reason,
  };
  static Validation fromJson(Map<String, dynamic> j) => Validation(
    code: j['k'] as String,
    title: j['t'] as String,
    at: DateTime.parse(j['a'] as String),
    amountCents: j['v'] as int,
    ok: j['o'] as bool,
    reason: j['r'] as String?,
  );
}

class AppStore extends ChangeNotifier {
  AppStore._(this._prefs);
  final SharedPreferences? _prefs;
  static const _key = 'mp_store_v2';
  final _rnd = Random();

  // Preferências
  bool bigText = false;
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
  bool fotoAlbum = false;

  // Parceiro (demonstração)
  final partnerOffers = <PartnerOffer>[];
  final validations = <Validation>[];

  static Future<AppStore> load() async {
    SharedPreferences? p;
    try {
      p = await SharedPreferences.getInstance();
    } catch (_) {}
    final s = AppStore._(p);
    s._restore();
    return s;
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
      offerAlerts = j['offerAlerts'] as bool? ?? true;
      highContrast = j['hc'] as bool? ?? false;
      name = j['name'] as String?;
      favorites.addAll(((j['fav'] as List?) ?? []).cast<String>());
      coupons.addAll(
        ((j['cup'] as List?) ?? []).map(
          (e) => LocalCoupon.fromJson(e as Map<String, dynamic>),
        ),
      );
      reservations.addAll(
        ((j['res'] as List?) ?? []).map(
          (e) => LocalReservation.fromJson(e as Map<String, dynamic>),
        ),
      );
      checkins.addAll(
        ((j['chk'] as List?) ?? []).map(
          (e) => Checkin.fromJson(e as Map<String, dynamic>),
        ),
      );
      savedEvents.addAll(((j['ev'] as List?) ?? []).cast<String>());
      readAvisos.addAll(((j['av'] as List?) ?? []).cast<String>());
      ((j['pk'] as Map?) ?? {}).forEach(
        (k, v) => packs['$k'] = (v as List).cast<int>().toSet(),
      );
      tickets.addAll(
        ((j['tk'] as List?) ?? []).map(
          (e) => Ticket.fromJson(e as Map<String, dynamic>),
        ),
      );
      invites = j['inv'] as int? ?? 0;
      fotoAlbum = j['fa'] as bool? ?? false;
      partnerOffers.addAll(
        ((j['po'] as List?) ?? []).map(
          (e) => PartnerOffer.fromJson(e as Map<String, dynamic>),
        ),
      );
      validations.addAll(
        ((j['va'] as List?) ?? []).map(
          (e) => Validation.fromJson(e as Map<String, dynamic>),
        ),
      );
      if (partnerOffers.isEmpty) _seedPartner();
    } catch (_) {
      _seedPartner();
    }
  }

  void _seedPartner() {
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
          'offerAlerts': offerAlerts,
          'hc': highContrast,
          'name': name,
          'fav': favorites.toList(),
          'cup': coupons.map((e) => e.toJson()).toList(),
          'res': reservations.map((e) => e.toJson()).toList(),
          'chk': checkins.map((e) => e.toJson()).toList(),
          'ev': savedEvents.toList(),
          'av': readAvisos.toList(),
          'pk': packs.map((k, v) => MapEntry(k, v.toList())),
          'tk': tickets.map((e) => e.toJson()).toList(),
          'inv': invites,
          'fa': fotoAlbum,
          'po': partnerOffers.map((e) => e.toJson()).toList(),
          'va': validations.map((e) => e.toJson()).toList(),
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
      if (c.cupomId == cupomId && !c.used) return c;
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
      coupons.where((c) => c.used).length * 20 +
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
  ];

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
