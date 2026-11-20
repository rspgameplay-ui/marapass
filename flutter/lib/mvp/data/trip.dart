import 'dart:math' as math;

import 'content.dart';

/// Tipos de parada livre (sem lugar do catálogo).
const pauseKinds = {'almoco': 'Almoço', 'descanso': 'Descanso', 'abastecimento': 'Abastecimento'};

/// Um item da rota: um lugar do catálogo ou uma parada livre.
class TripStop {
  TripStop({required this.id, required this.day, this.itemId, this.pause, required this.startMin, required this.stayMin});

  final String id;
  DateTime day;
  final String? itemId;
  final String? pause;
  int startMin; // minutos desde 0h
  int stayMin;

  Item? get item => itemId == null ? null : Content.item(itemId!);
  String get label => item?.titulo ?? pauseKinds[pause] ?? 'Parada';
  int get endMin => startMin + stayMin;

  Map<String, dynamic> toJson() => {'id': id, 'day': day.toIso8601String(), 'item': itemId, 'pause': pause, 's': startMin, 'm': stayMin};
  static TripStop fromJson(Map<String, dynamic> j) => TripStop(
    id: '${j['id']}',
    day: DateTime.parse('${j['day']}'),
    itemId: j['item'] as String?,
    pause: j['pause'] as String?,
    startMin: (j['s'] as num).toInt(),
    stayMin: (j['m'] as num).toInt(),
  );
}

/// Rota montada pelo próprio turista ("Defina sua Rota").
class Trip {
  Trip({required this.id, required this.name, required this.start, required this.end, this.people = 2, List<TripStop>? stops, Set<String>? extras})
    : stops = stops ?? [],
      extras = extras ?? {};

  final String id;
  String name;
  DateTime start, end;
  int people;
  final List<TripStop> stops;

  /// Hospedagens, passeios e eventos que entram no custo e no carrinho.
  final Set<String> extras;

  List<DateTime> get days => [for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) d];
  int get nights => math.max(1, end.difference(start).inDays);

  List<TripStop> stopsOn(DateTime d) =>
      stops.where((s) => _same(s.day, d)).toList()..sort((a, b) => a.startMin.compareTo(b.startMin));

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'start': start.toIso8601String(), 'end': end.toIso8601String(),
    'people': people, 'stops': [for (final s in stops) s.toJson()], 'extras': extras.toList(),
  };
  static Trip fromJson(Map<String, dynamic> j) => Trip(
    id: '${j['id']}',
    name: '${j['name']}',
    start: DateTime.parse('${j['start']}'),
    end: DateTime.parse('${j['end']}'),
    people: (j['people'] as num?)?.toInt() ?? 2,
    stops: [for (final s in (j['stops'] as List? ?? const [])) TripStop.fromJson(s as Map<String, dynamic>)],
    extras: {for (final e in (j['extras'] as List? ?? const [])) '$e'},
  );
}

bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
bool sameDay(DateTime a, DateTime b) => _same(a, b);

String hhmm(int min) => '${(min ~/ 60).toString().padLeft(2, '0')}h${(min % 60).toString().padLeft(2, '0')}';

/// Minutos de carro entre dois lugares (linha reta × 1,3 a 45 km/h).
int? driveMinutes(Item? a, Item? b) {
  if (a?.lat == null || b?.lat == null || a?.lng == null || b?.lng == null) return null;
  const r = 6371.0;
  double rad(double x) => x * math.pi / 180;
  final dLat = rad(b!.lat! - a!.lat!), dLng = rad(b.lng! - a.lng!);
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(a.lat!)) * math.cos(rad(b.lat!)) * math.pow(math.sin(dLng / 2), 2);
  final km = 2 * r * math.asin(math.sqrt(h)) * 1.3;
  return (km / 45 * 60).round();
}

/// Abertura e fechamento lidos do texto "11h às 23h" (null se não der para ler).
(int, int)? openingHours(Item? i) {
  final m = RegExp(r'(\d{1,2})h(\d{2})?\s*(?:às|à|a|-)\s*(\d{1,2})h(\d{2})?').firstMatch(i?.horario ?? '');
  if (m == null) return null;
  final o = int.parse(m[1]!) * 60 + int.parse(m[2] ?? '0');
  var c = int.parse(m[3]!) * 60 + int.parse(m[4] ?? '0');
  if (c <= o) c += 24 * 60;
  return (o, c);
}

/// Avisos de conflito de um dia, por id de parada.
Map<String, List<String>> tripConflicts(Trip t, DateTime day) {
  final out = <String, List<String>>{};
  final list = t.stopsOn(day);
  for (var k = 0; k < list.length; k++) {
    final s = list[k];
    final notes = <String>[];
    if (k > 0) {
      final prev = list[k - 1];
      if (s.startMin < prev.endMin) {
        notes.add('Horário sobreposto com ${prev.label}.');
      } else {
        final drive = driveMinutes(prev.item, s.item);
        if (drive != null && prev.endMin + drive > s.startMin) {
          notes.add('O deslocamento leva cerca de $drive min e não fecha com o horário.');
        }
      }
    }
    final h = openingHours(s.item);
    if (h != null && (s.startMin < h.$1 || s.endMin > h.$2)) {
      notes.add('Fora do horário de funcionamento (${s.item!.horario}).');
    }
    if (notes.isNotEmpty) out[s.id] = notes;
  }
  return out;
}

/// Linha do custo estimado.
class CostLine {
  const CostLine(this.label, this.cents, {this.discountCents = 0});
  final String label;
  final int cents, discountCents;
}

/// Custo estimado: hospedagem por noite, passeios e eventos por pessoa,
/// alimentação estimada (R$ 70 por pessoa por dia) e cupons já descontados.
List<CostLine> tripCost(Trip t) {
  var stay = 0, stayOff = 0, tours = 0, toursOff = 0, events = 0, eventsOff = 0;
  final ids = {...t.extras, for (final s in t.stops) if (s.itemId != null) s.itemId!};
  for (final id in ids) {
    final i = Content.item(id);
    final p = i?.precoCents;
    if (i == null || p == null) continue;
    final off = Content.cupom(i.cupom)?.valorCents ?? 0;
    switch (i.cat) {
      case Cat.hospedagem:
        if (!t.extras.contains(id)) continue;
        stay += p * t.nights;
        stayOff += off;
      case Cat.evento:
        events += p * t.people;
        eventsOff += off;
      case Cat.gastronomia:
        continue; // entra na alimentação estimada
      default:
        tours += p * t.people;
        toursOff += off;
    }
  }
  return [
    CostLine('Hospedagem (${t.nights} ${t.nights == 1 ? 'noite' : 'noites'})', stay, discountCents: math.min(stay, stayOff)),
    CostLine('Passeios', tours, discountCents: math.min(tours, toursOff)),
    CostLine('Eventos', events, discountCents: math.min(events, eventsOff)),
    CostLine('Alimentação estimada', 7000 * t.people * t.days.length),
  ];
}
