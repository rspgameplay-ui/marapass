import '../i18n.dart';
import 'content.dart';

class LocalCoupon {
  LocalCoupon({
    required this.id,
    required this.cupomId,
    required this.code,
    required this.issuedAt,
    this.usedAt,
    this.sale,
    this.stage,
  });
  final String id;
  final String cupomId;
  final String code;
  final DateTime issuedAt;
  DateTime? usedAt;
  final Map<String, dynamic>? sale;
  final String? stage;
  bool get closed => stage == 'cancelled' || stage == 'declined';
  Cupom? get cupom {
    final terms = sale;
    if (terms == null) return Content.cupom(cupomId);
    return Cupom(
      id: cupomId,
      itemId: '',
      parceiro: terms['title'] as String,
      cat: Content.cupom(cupomId)?.cat ?? Cat.passeio,
      beneficio: terms['benefit'] as String,
      detalhe: terms['rules'] as String,
      validade: DateTime.parse(terms['expires'] as String),
      valorCents: terms['discount_cents'] as int,
    );
  }

  bool get used => usedAt != null;
  bool get expired =>
      !used && (cupom?.validade.isBefore(DateTime.now()) ?? false);
  bool get active => !used && !expired && !closed;
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
  solicitada('Pendente'),
  confirmada('Confirmada'),
  recusada('Não confirmada'),
  cancelada('Cancelada'),
  concluida('Utilizada');

  const ResStatus(this._label);
  final String _label;
  String get label => tr(_label);
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
    this.remoteId,
  });
  final String itemId;
  final String polo;
  final String cidade;
  final DateTime at;
  int rating;
  final String? remoteId;
  Map<String, dynamic> toJson() => {
    'id': remoteId,
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
    remoteId: j['id'] as String?,
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
    this.remoteId,
  }) : replies = replies ?? [];
  final String id;
  final String? remoteId;
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
    this.imageUrl,
    this.saleTerms,
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
  String? imageUrl;
  final Map<String, dynamic>? saleTerms;
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
