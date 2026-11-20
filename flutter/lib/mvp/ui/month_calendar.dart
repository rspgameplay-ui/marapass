import 'package:flutter/material.dart';

import '../theme/tokens.dart';

const _monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

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
              tooltip: 'Mês anterior',
              onPressed: canBack ? () => setState(() => _month = DateTime(_month.year, _month.month - 1)) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              key: const Key('cal-next'),
              tooltip: 'Próximo mês',
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Row(
          children: [
            for (final (k, l) in const ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'].indexed)
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
            label: '$n de ${_monthNames[d.month - 1]}${dot ? ', com evento' : ''}',
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
