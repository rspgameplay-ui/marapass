import 'package:flutter/material.dart';
import '../i18n.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content.dart';
import '../data/store_models.dart' show ResStatus;
import '../data/trip.dart';
import '../data/store.dart' show appStoreProvider;
import '../theme/tokens.dart';

const _monthNamesPt = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

List<String> get _monthNames => appLang == 'en'
    ? const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
    : _monthNamesPt;

/// Feriados nacionais de data fixa (mês, dia).
const _feriados = {(1, 1), (4, 21), (5, 1), (9, 7), (10, 12), (11, 2), (11, 15), (11, 20), (12, 25)};

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

/// Grade mensal no modelo do Calendário da Apple, usada em Reservas,
/// Defina sua Rota e Eventos.
///
/// Toque simples escolhe um dia. Com [range] ligado, o primeiro toque marca a
/// ida e o segundo a volta. Dias passados ou recusados por [isEnabled] ficam
/// cinza e sem toque; [hasEvent] desenha um ponto embaixo do número.
/// Cada dia futuro tem a chave `day-N`, em que N é a distância a partir de
/// amanhã (day-0 = amanhã).
class MpMonthCalendar extends StatefulWidget {
  const MpMonthCalendar({
    super.key,
    required this.start,
    this.end,
    required this.onChanged,
    this.range = false,
    this.isEnabled,
    this.hasEvent,
    this.allowToday = false,
  });

  final DateTime? start, end;
  final void Function(DateTime? start, DateTime? end) onChanged;
  final bool range, allowToday;
  final bool Function(DateTime day)? isEnabled;
  final bool Function(DateTime day)? hasEvent;

  @override
  State<MpMonthCalendar> createState() => _MpMonthCalendarState();
}

class _MpMonthCalendarState extends State<MpMonthCalendar> {
  late DateTime _month = () {
    final n = DateTime.now();
    final ref = widget.start ?? (widget.allowToday ? n : DateTime(n.year, n.month, n.day + 1));
    return DateTime(ref.year, ref.month);
  }();

  bool _enabled(DateTime d, DateTime today) {
    if (d.isBefore(today) || (!widget.allowToday && d == today)) return false;
    return widget.isEnabled?.call(d) ?? true;
  }

  void _tap(DateTime d) {
    final s = widget.start, e = widget.end;
    if (!widget.range) return widget.onChanged(d, null);
    if (s == null || e != null || d.isBefore(s)) return widget.onChanged(d, null);
    if (d == s) return widget.onChanged(null, null);
    widget.onChanged(s, d);
  }

  @override
  Widget build(BuildContext context) {
    final today = _d(DateTime.now());
    final first = DateTime(_month.year, _month.month, 1);
    final lead = first.weekday - 1; // semana começa na segunda
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final canBack = _month.isAfter(DateTime(today.year, today.month));
    final s = widget.start == null ? null : _d(widget.start!);
    final e = widget.end == null ? null : _d(widget.end!);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_monthNames[_month.month - 1]} ${_month.year}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: const Key('cal-prev'),
              tooltip: tr('Mês anterior'),
              onPressed: canBack ? () => setState(() => _month = DateTime(_month.year, _month.month - 1)) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              key: const Key('cal-next'),
              tooltip: tr('Próximo mês'),
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Row(
          children: [
            for (final (k, l) in (appLang == 'en' ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S'] : const ['S', 'T', 'Q', 'Q', 'S', 'S', 'D']).indexed)
              Expanded(
                child: Center(
                  child: Text(l, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: k >= 5 ? MP.goldText : MP.textSecondary)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r * 7 - lead < days; r++)
          Row(
            children: [
              for (var k = 0; k < 7; k++)
                Expanded(child: _cell(r * 7 + k - lead + 1, days, today, s, e, k >= 5)),
            ],
          ),
      ],
    );
  }

  Widget _cell(int n, int days, DateTime today, DateTime? s, DateTime? e, bool weekend) {
    if (n < 1 || n > days) return const SizedBox(height: 46);
    final d = DateTime(_month.year, _month.month, n);
    final on = _enabled(d, today);
    final isEdge = d == s || d == e;
    final inRange = s != null && e != null && d.isAfter(s) && d.isBefore(e);
    final holiday = _feriados.contains((d.month, d.day));
    final dot = widget.hasEvent?.call(d) ?? false;
    final color = isEdge
        ? Colors.white
        : !on
            ? const Color(0xffb3bac4)
            : (weekend || holiday)
                ? MP.goldText
                : MP.ink;
    final offset = d.difference(today).inDays - 1;
    return SizedBox(
      height: 46,
      child: Container(
        color: inRange ? MP.tintBlue : null,
        child: Center(
          child: Semantics(
            button: on,
            selected: isEdge,
            label: appLang == 'en' ? '${_monthNames[d.month - 1]} $n${dot ? tr(', com evento') : ''}' : '$n de ${_monthNames[d.month - 1]}${dot ? tr(', com evento') : ''}',
            child: InkWell(
              key: offset >= 0 ? Key('day-$offset') : null,
              customBorder: const CircleBorder(),
              onTap: on ? () => _tap(d) : null,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEdge ? MP.navy : null,
                  border: d == today && !isEdge ? Border.all(color: MP.green, width: 2) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$n', style: TextStyle(fontSize: 15, fontWeight: d == today || isEdge ? FontWeight.w800 : FontWeight.w600, color: color)),
                    if (dot)
                      Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: isEdge ? Colors.white : MP.error)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resumo de um dia, como a agenda da Apple: eventos, reservas e pontos das
/// rotas salvas.
class DayAgenda extends ConsumerWidget {
  const DayAgenda({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    bool same(DateTime a) => a.year == day.year && a.month == day.month && a.day == day.day;
    final rows = <(IconData, Color, String, String)>[
      for (final e in Content.byCat(Cat.evento).where((e) => e.data != null && same(e.data!)))
        (Icons.event_rounded, MP.error, e.titulo, '${hhmm(e.data!.hour * 60 + e.data!.minute)} · ${e.cidade}'),
      for (final r in store.reservations.where((r) => same(r.date) && r.status != ResStatus.cancelada))
        (Icons.event_available_rounded, MP.navy, r.item?.titulo ?? 'Reserva', '${r.period} · ${r.status.label}'),
      for (final t in store.trips)
        for (final s in t.stopsOn(day)) (Icons.route_rounded, MP.green, s.label, '${hhmm(s.startMin)} · ${t.name}'),
    ];
    return Container(
      key: const Key('day-agenda'),
      margin: const EdgeInsets.only(top: MP.s3),
      padding: const EdgeInsets.all(MP.s3),
      decoration: BoxDecoration(color: MP.soft, borderRadius: BorderRadius.circular(MP.rMedium)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(appLang == 'en' ? '${_monthNames[day.month - 1]} ${day.day}' : '${day.day} de ${_monthNames[day.month - 1].toLowerCase()}', style: Theme.of(context).textTheme.titleMedium),
          if (rows.isEmpty)
            Padding(padding: EdgeInsets.only(top: 4), child: Text(tr('Nada marcado neste dia.'), style: TextStyle(color: MP.textSecondary))),
          for (final (icon, color, title, sub) in rows)
            Padding(
              padding: const EdgeInsets.only(top: MP.s2),
              child: Row(children: [
                Container(width: 4, height: 36, color: color),
                const SizedBox(width: MP.s2),
                Icon(icon, size: 20, color: color),
                const SizedBox(width: MP.s2),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(sub, style: const TextStyle(fontSize: 13, color: MP.textSecondary)),
                  ]),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}
