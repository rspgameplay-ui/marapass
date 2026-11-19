import '../domain/tourism.dart';
import '../domain/municipality.dart';

class MapCommand {
  const MapCommand({
    this.city,
    this.category,
    this.day,
    this.coupons = false,
    this.route = false,
    this.term = '',
    this.error,
  });
  final Municipality? city;
  final PlaceCategory? category;
  final DateTime? day;
  final bool coupons, route;
  final String term;
  final String? error;
  String get dateLabel => day == null
      ? ''
      : '${day!.day.toString().padLeft(2, '0')}/${day!.month.toString().padLeft(2, '0')}/${day!.year}';
  String get summary =>
      '${route ? 'Planejar rota' : 'Pesquisar'} • ${category?.label ?? (term.isEmpty ? 'Lugares' : term)}${city == null ? '' : ' • ${city!.name}'}${coupons ? ' • ofertas publicadas' : ''}${day == null ? '' : ' • $dateLabel'}';
}

MapCommand parseCommand(
  String text,
  List<Municipality> cities, {
  DateTime? now,
  bool requireCouponCity = true,
}) {
  final raw = normalize(text)
      .replaceAll(RegExp(r'[.,;?!–—-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final n = now ?? DateTime.now().toUtc().subtract(const Duration(hours: 3));
  final today = DateTime(n.year, n.month, n.day);
  // Long names claim their span before shorter municipality names inside them.
  final ordered = [...cities]
    ..sort((a, b) => b.name.length.compareTo(a.name.length));
  final spans = <(int, int)>[];
  final chosen = <String, Municipality>{};
  for (final city in ordered) {
    final pattern = RegExp(
      '(^|[^a-z])${RegExp.escape(normalize(city.name))}(\\b|\$)',
    );
    for (final hit in pattern.allMatches(raw)) {
      if (spans.any((s) => hit.start >= s.$1 && hit.end <= s.$2)) continue;
      chosen[city.id] = city;
      spans.add((hit.start, hit.end));
    }
  }
  final matches = chosen.values.toList();
  if (matches.length > 1) {
    return const MapCommand(
      error: 'Encontrei mais de um município. Escolha um destino por comando.',
    );
  }
  final city = matches.isEmpty ? null : matches.first;
  final route = RegExp(
    r'\b(rota|navegar|leva|leve|levar|tracar|trace|traca|navegue|vamos|a gente vai|nos vamos|bora|como chegar|quero conhecer|ir para)\b',
  ).hasMatch(raw);
  final coupons = RegExp(
    r'\b(cupom|cupons|desconto|descontos|oferta|ofertas)\b',
  ).hasMatch(raw);
  final category =
      RegExp(r'\b(restaurante|restaurantes|comer|gastronomia|lanchonete)\b')
          .hasMatch(raw)
      ? PlaceCategory.gastronomy
      : RegExp(r'\b(hotel|hoteis|pousada|hospedagem)\b').hasMatch(raw)
      ? PlaceCategory.lodging
      : RegExp(r'\b(condominio|condominios)\b').hasMatch(raw)
      ? PlaceCategory.residential
      : RegExp(r'\b(passeio|passeios|trilha|trilhas)\b').hasMatch(raw)
      ? PlaceCategory.tours
      : null;
  const months = [
    'janeiro',
    'fevereiro',
    'marco',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  const words = {
    'um': 1,
    'dois': 2,
    'tres': 3,
    'quatro': 4,
    'cinco': 5,
    'seis': 6,
    'sete': 7,
    'oito': 8,
    'nove': 9,
    'dez': 10,
    'onze': 11,
    'doze': 12,
    'treze': 13,
    'quatorze': 14,
    'catorze': 14,
    'quinze': 15,
    'dezesseis': 16,
    'dezessete': 17,
    'dezoito': 18,
    'dezenove': 19,
    'vinte': 20,
    'vinte e um': 21,
    'vinte e dois': 22,
    'vinte e tres': 23,
    'vinte e quatro': 24,
    'vinte e cinco': 25,
    'vinte e seis': 26,
    'vinte e sete': 27,
    'vinte e oito': 28,
    'vinte e nove': 29,
    'trinta': 30,
    'trinta e um': 31,
  };
  var dateText = raw;
  for (final w
      in words.keys.toList()..sort((a, b) => b.length.compareTo(a.length))) {
    dateText = dateText.replaceAll(
      RegExp('\\b$w(?=\\s+(?:de\\s+)?(?:${months.join('|')}))'),
      words[w].toString(),
    );
  }
  DateTime? day;
  String? dateMatch;
  int? d, m, y;
  bool explicit = false;
  final named = RegExp(
    r'\b(\d{1,2})\s+(?:de\s+)?(' +
        months.join('|') +
        r')(?:\s+(?:de\s+)?(20\d{2}))?\b',
  ).firstMatch(dateText);
  final numeric = RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{4}))?\b')
      .firstMatch(dateText);
  if (named != null) {
    d = int.parse(named[1]!);
    m = months.indexOf(named[2]!) + 1;
    y = int.tryParse(named[3] ?? '');
    explicit = y != null;
    dateMatch = named[0];
  } else if (numeric != null) {
    d = int.parse(numeric[1]!);
    m = int.parse(numeric[2]!);
    y = int.tryParse(numeric[3] ?? '');
    explicit = y != null;
    dateMatch = numeric[0];
  }
  if (d != null && m != null) {
    y ??= today.year;
    day = DateTime(y, m, d);
    if (day.month != m || day.day != d) {
      return const MapCommand(
        error: 'Data inválida. Confira o dia, mês e ano.',
      );
    }
    if (!explicit && day.isBefore(today)) day = DateTime(y + 1, m, d);
  } else if (raw.contains('amanha')) {
    day = today.add(const Duration(days: 1));
    dateMatch = 'amanha';
  } else if (raw.contains('hoje')) {
    day = today;
    dateMatch = 'hoje';
  } else if (RegExp(
    r'\b(dia|janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro)\b',
  ).hasMatch(raw)) {
    return const MapCommand(
      error: 'Não entendi a data. Diga, por exemplo, 20 de janeiro de 2027.',
    );
  }
  if (day != null &&
      (day.isBefore(today) || day.difference(today).inDays > 366)) {
    return const MapCommand(
      error: 'Escolha uma data entre hoje e os próximos 366 dias.',
    );
  }
  var term = dateText;
  if (city != null) term = term.replaceAll(normalize(city.name), '');
  if (dateMatch != null) term = term.replaceAll(dateMatch, '');
  term = term
      .replaceAll(
        RegExp(
          r'\b(localize|localizar|encontre|encontrar|buscar|busque|procure|pesquisar|mostre|mostrar|onde|fica|vamos|gente|vai|nos|bora|conhecer|como|chegar|gostaria|visitar|quis|dizer|somente|apenas|so|outra|outro|nao|quis|dizer|quero|preciso|restaurante|restaurantes|gastronomia|comer|hotel|hoteis|pousada|hospedagem|condominio|condominios|passeio|passeios|cupom|cupons|desconto|descontos|oferta|ofertas|rota|navegar|leva|leve|me|levar|tracar|trace|traca|navegue|defina|definir|trajeto|caminho|ir|pra|pro|para|aos|em|no|na|do|da|de|que|tem|com|dia|um|uma|o|a|os|as|ate)\b',
        ),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (requireCouponCity && coupons && city == null) {
    return const MapCommand(
      error: 'Diga o município para consultar as ofertas publicadas.',
    );
  }
  return MapCommand(
    city: city,
    category: category,
    day: day,
    coupons: coupons,
    route: route,
    term: term,
  );
}
