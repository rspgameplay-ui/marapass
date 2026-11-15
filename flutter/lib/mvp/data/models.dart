/// Modelos do MVP, alinhados às tabelas reais do Supabase.
library;

DateTime? _dt(Object? v) =>
    v == null ? null : DateTime.tryParse('$v')?.toLocal();
int _int(Object? v, [int d = 0]) =>
    v is num ? v.toInt() : int.tryParse('$v') ?? d;

class Establishment {
  const Establishment({
    required this.id,
    required this.name,
    this.city,
    this.category,
    this.description,
  });
  final String id;
  final String name;
  final String? city;
  final String? category;
  final String? description;

  factory Establishment.fromJson(Map<String, dynamic> j) => Establishment(
    id: '${j['id']}',
    name: '${j['name'] ?? 'Parceiro'}',
    city: j['city'] as String?,
    category: j['category'] as String?,
    description: j['description'] as String?,
  );
}

class Experience {
  const Experience({
    required this.id,
    required this.establishmentId,
    required this.title,
    this.description,
    this.category,
    this.priceFromCents,
    this.durationMinutes,
    this.capacity,
    this.bookingRequired = true,
    this.establishment,
  });
  final String id;
  final String establishmentId;
  final String title;
  final String? description;
  final String? category;
  final int? priceFromCents;
  final int? durationMinutes;
  final int? capacity;
  final bool bookingRequired;
  final Establishment? establishment;

  factory Experience.fromJson(Map<String, dynamic> j) {
    final est = j['establishments'];
    return Experience(
      id: '${j['id']}',
      establishmentId: '${j['establishment_id']}',
      title: '${j['title'] ?? 'Experiência'}',
      description: j['description'] as String?,
      category: j['category'] as String?,
      priceFromCents: j['price_from_cents'] == null
          ? null
          : _int(j['price_from_cents']),
      durationMinutes: j['duration_minutes'] == null
          ? null
          : _int(j['duration_minutes']),
      capacity: j['capacity'] == null ? null : _int(j['capacity']),
      bookingRequired: j['booking_required'] != false,
      establishment: est is Map<String, dynamic>
          ? Establishment.fromJson({'id': j['establishment_id'], ...est})
          : null,
    );
  }
}

class Slot {
  const Slot({
    required this.id,
    required this.experienceId,
    required this.startsAt,
    this.endsAt,
    this.capacity = 0,
  });
  final String id;
  final String experienceId;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int capacity;

  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
    id: '${j['id']}',
    experienceId: '${j['experience_id']}',
    startsAt: _dt(j['starts_at']) ?? DateTime.now(),
    endsAt: _dt(j['ends_at']),
    capacity: _int(j['capacity']),
  );
}

class Offer {
  const Offer({
    required this.id,
    required this.establishmentId,
    required this.title,
    this.experienceId,
    this.description,
    this.discountType,
    this.discountValue,
    this.startsAt,
    this.endsAt,
    this.maxIssuances,
    this.perUserLimit,
    this.minimumPurchaseCents,
    this.maximumDiscountCents,
    this.useUntil,
    this.advanceBookingRequired = false,
    this.disclosureExtra,
    this.establishment,
  });
  final String id;
  final String establishmentId;
  final String? experienceId;
  final String title;
  final String? description;
  final String? discountType;
  final num? discountValue;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? maxIssuances;
  final int? perUserLimit;
  final int? minimumPurchaseCents;
  final int? maximumDiscountCents;
  final DateTime? useUntil;
  final bool advanceBookingRequired;
  final String? disclosureExtra;
  final Establishment? establishment;

  /// Rótulo do benefício sem inventar valores: usa só o que o servidor devolve.
  String get benefitLabel => describeDiscount(discountType, discountValue);

  factory Offer.fromJson(Map<String, dynamic> j) {
    final est = j['establishments'];
    return Offer(
      id: '${j['id']}',
      establishmentId: '${j['establishment_id']}',
      experienceId: j['experience_id'] as String?,
      title: '${j['title'] ?? 'Oferta'}',
      description: j['description'] as String?,
      discountType: j['discount_type'] as String?,
      discountValue: j['discount_value'] is num
          ? j['discount_value'] as num
          : num.tryParse('${j['discount_value']}'),
      startsAt: _dt(j['starts_at']),
      endsAt: _dt(j['ends_at']),
      maxIssuances: j['max_issuances'] == null
          ? null
          : _int(j['max_issuances']),
      perUserLimit: j['per_user_limit'] == null
          ? null
          : _int(j['per_user_limit']),
      minimumPurchaseCents: j['minimum_purchase_cents'] == null
          ? null
          : _int(j['minimum_purchase_cents']),
      maximumDiscountCents: j['maximum_discount_cents'] == null
          ? null
          : _int(j['maximum_discount_cents']),
      useUntil: _dt(j['use_until']),
      advanceBookingRequired: j['advance_booking_required'] == true,
      disclosureExtra: j['disclosure_extra'] as String?,
      establishment: est is Map<String, dynamic>
          ? Establishment.fromJson({'id': j['establishment_id'], ...est})
          : null,
    );
  }
}

class Reservation {
  const Reservation({
    required this.id,
    required this.experienceId,
    required this.scheduledAt,
    required this.participants,
    required this.status,
    this.experienceTitle,
  });
  final String id;
  final String experienceId;
  final DateTime scheduledAt;
  final int participants;
  final String status;
  final String? experienceTitle;

  factory Reservation.fromJson(Map<String, dynamic> j) {
    final x = j['experiences'];
    return Reservation(
      id: '${j['id']}',
      experienceId: '${j['experience_id']}',
      scheduledAt: _dt(j['scheduled_at']) ?? DateTime.now(),
      participants: _int(j['participants'], 1),
      status: '${j['status'] ?? 'pending'}',
      experienceTitle: x is Map ? x['title'] as String? : null,
    );
  }
}

class CouponInstance {
  const CouponInstance({
    required this.id,
    required this.offerId,
    required this.status,
    required this.title,
    this.displayCode,
    this.discountType,
    this.discountValue,
    this.issuedAt,
    this.expiresAt,
    this.redeemedAt,
  });
  final String id;
  final String offerId;
  final String status;
  final String title;
  final String? displayCode;
  final String? discountType;
  final num? discountValue;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final DateTime? redeemedAt;

  bool get isRedeemed => redeemedAt != null || status == 'redeemed';
  bool get isExpired =>
      !isRedeemed &&
      (status == 'expired' ||
          (expiresAt != null && expiresAt!.isBefore(DateTime.now())));
  bool get isActive => !isRedeemed && !isExpired && status != 'cancelled';
  String get benefitLabel => describeDiscount(discountType, discountValue);

  factory CouponInstance.fromJson(Map<String, dynamic> j) => CouponInstance(
    id: '${j['id']}',
    offerId: '${j['offer_id']}',
    status: '${j['status'] ?? 'issued'}',
    title: '${j['offer_title_snapshot'] ?? 'Cupom'}',
    displayCode: j['display_code'] as String?,
    discountType: j['discount_type_snapshot'] as String?,
    discountValue: j['discount_value_snapshot'] is num
        ? j['discount_value_snapshot'] as num
        : num.tryParse('${j['discount_value_snapshot']}'),
    issuedAt: _dt(j['issued_at']),
    expiresAt: _dt(j['expires_at']),
    redeemedAt: _dt(j['redeemed_at']),
  );
}

class PassportProduct {
  const PassportProduct({
    required this.id,
    required this.name,
    required this.priceCents,
    this.description,
    this.durationDays,
    this.benefitsExplanation,
    this.legalTerms,
  });
  final String id;
  final String name;
  final int priceCents;
  final String? description;
  final int? durationDays;
  final String? benefitsExplanation;
  final String? legalTerms;

  factory PassportProduct.fromJson(Map<String, dynamic> j) => PassportProduct(
    id: '${j['id']}',
    name: '${j['name'] ?? 'Passaporte'}',
    priceCents: _int(j['price_cents']),
    description: j['description'] as String?,
    durationDays: j['duration_days'] == null ? null : _int(j['duration_days']),
    benefitsExplanation: j['included_benefits_explanation'] as String?,
    legalTerms: j['legal_terms'] as String?,
  );
}

class PassportEntitlement {
  const PassportEntitlement({
    required this.id,
    required this.productId,
    required this.status,
    this.validFrom,
    this.validUntil,
    this.activatedAt,
  });
  final String id;
  final String productId;
  final String status;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final DateTime? activatedAt;

  bool get isActivated => activatedAt != null || status == 'active';

  factory PassportEntitlement.fromJson(Map<String, dynamic> j) =>
      PassportEntitlement(
        id: '${j['id']}',
        productId: '${j['product_id']}',
        status: '${j['status'] ?? ''}',
        validFrom: _dt(j['valid_from']),
        validUntil: _dt(j['valid_until']),
        activatedAt: _dt(j['activated_at']),
      );
}

class Profile {
  const Profile({required this.id, this.displayName, this.phone});
  final String id;
  final String? displayName;
  final String? phone;
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: '${j['id']}',
    displayName: j['display_name'] as String?,
    phone: j['phone'] as String?,
  );
}

/// Rótulo de desconto sem inventar regras: percentuais e valores fixos
/// são formatados; qualquer outro tipo cai em "Benefício exclusivo".
String describeDiscount(String? type, num? value) {
  final t = (type ?? '').toLowerCase();
  if (value != null && t.contains('percent')) {
    final v = value == value.roundToDouble() ? value.toInt() : value;
    return '$v% de desconto';
  }
  if (value != null && (t.contains('fixed') || t.contains('amount'))) {
    return '${formatBrl((value * 100).round())} de desconto';
  }
  if (t.contains('buy_one') || t.contains('2x1')) return 'Leve 2, pague 1';
  return 'Benefício exclusivo';
}

String formatBrl(int cents) {
  final neg = cents < 0;
  final abs = cents.abs();
  final reais = (abs ~/ 100).toString();
  final buf = StringBuffer();
  for (var i = 0; i < reais.length; i++) {
    if (i > 0 && (reais.length - i) % 3 == 0) buf.write('.');
    buf.write(reais[i]);
  }
  final c = (abs % 100).toString().padLeft(2, '0');
  return '${neg ? '-' : ''}R\$ $buf,$c';
}

const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
const _months = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

String formatDay(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
String formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
}
