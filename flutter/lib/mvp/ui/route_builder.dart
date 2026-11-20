import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content.dart';
import '../data/models.dart' show formatBrl;
import '../data/repository.dart' show MvpException;
import '../data/store.dart';
import '../data/trip.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'itinerary.dart' show DayPlan, DayStop, itineraryRequestProvider;
import 'login_screen.dart' show requireLogin;
import 'month_calendar.dart';
import 'shell.dart' show Tabs;

/// Lista das rotas salvas, com o botão para montar uma nova.
class MyRoutesScreen extends ConsumerWidget {
  const MyRoutesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('route-new'),
        onPressed: () => push<void>(context, const RouteBuilderScreen()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova rota'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            const MpHeader('Defina sua Rota', subtitle: 'Monte seu passeio do seu jeito.'),
            if (store.trips.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: MP.pageH),
                child: MpNotice('Você ainda não montou nenhuma rota. Escolha as datas, os lugares e os horários; o app só dá dicas.'),
              ),
            for (final t in store.trips)
              Padding(
                padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s3),
                child: MpListTile(
                  icon: Icons.route_rounded,
                  title: t.name,
                  subtitle: '${_dm(t.start)} a ${_dm(t.end)} · ${t.stops.length} paradas',
                  tint: MP.tintGreen,
                  onTap: () => push<void>(context, RouteBuilderScreen(trip: t)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _dm(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
const _wd = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
String _dayLabel(DateTime d) => '${_wd[d.weekday - 1]}, ${_dm(d)}';

/// "Defina sua Rota": Quando, Onde, Horários e Extras, e o resumo final com
/// linha do tempo, conflitos e custo estimado. O app não monta o roteiro.
class RouteBuilderScreen extends ConsumerStatefulWidget {
  const RouteBuilderScreen({super.key, this.trip});
  final Trip? trip;
  @override
  ConsumerState<RouteBuilderScreen> createState() => _RouteBuilderScreenState();
}

class _RouteBuilderScreenState extends ConsumerState<RouteBuilderScreen> {
  late final Trip _t = widget.trip == null ? _blank() : Trip.fromJson(widget.trip!.toJson());
  late int _step = widget.trip == null ? 0 : 4;
  late DateTime _day = _t.start;
  String _q = '';
  bool _busy = false;

  static Trip _blank() {
    final n = DateTime.now();
    final d = DateTime(n.year, n.month, n.day + 1);
    return Trip(id: 'r${n.microsecondsSinceEpoch}', name: 'Minha rota', start: d, end: d);
  }

  bool get _hasDates => true;

  void _set(VoidCallback f) => setState(f);

  void _addItem(Item i) => _set(() {
    final last = _t.stopsOn(_day).lastOrNull;
    final drive = driveMinutes(last?.item, i) ?? 0;
    final start = last == null ? 8 * 60 : ((last.endMin + drive + 14) ~/ 15) * 15;
    _t.stops.add(TripStop(id: 's${DateTime.now().microsecondsSinceEpoch}', day: _day, itemId: i.id, startMin: start, stayMin: i.cat == Cat.gastronomia ? 90 : 120));
  });

  void _addPause(String kind) => _set(() {
    final last = _t.stopsOn(_day).lastOrNull;
    final start = kind == 'almoco' ? 12 * 60 : (last == null ? 10 * 60 : ((last.endMin + 14) ~/ 15) * 15);
    _t.stops.add(TripStop(id: 's${DateTime.now().microsecondsSinceEpoch}', day: _day, pause: kind, startMin: start, stayMin: kind == 'almoco' ? 90 : 30));
  });

  /// Reordenar mantém os horários em sequência: cada parada começa depois
  /// da anterior mais o deslocamento.
  void _reorder(int from, int to) => _set(() {
    final list = _t.stopsOn(_day);
    final first = list.first.startMin;
    list.insert(to, list.removeAt(from));
    list.first.startMin = first;
    for (var k = 1; k < list.length; k++) {
      final drive = driveMinutes(list[k - 1].item, list[k].item) ?? 0;
      list[k].startMin = ((list[k - 1].endMin + drive + 14) ~/ 15) * 15;
    }
  });

  Future<void> _save() async {
    final name = await _askName();
    if (name == null || !mounted) return;
    _t.name = name;
    await ref.read(appStoreProvider).saveTrip(_t);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rota salva em Meu passaporte.')));
  }

  Future<String?> _askName() {
    final c = TextEditingController(text: _t.name);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nome da rota'),
        content: TextField(key: const Key('route-name'), controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(key: const Key('route-name-ok'), onPressed: () => Navigator.pop(ctx, c.text.trim().isEmpty ? 'Minha rota' : c.text.trim()), child: const Text('Salvar')),
        ],
      ),
    );
  }

  /// Envia um pedido de reserva por item. Sem pagamento: cada parceiro
  /// confirma a disponibilidade e combina o valor.
  Future<void> _reserveAll() async {
    final reqs = tripRequests(_t);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reservar tudo'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final r in reqs) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• ${r.item.titulo}: ${_dm(r.day)}, ${r.period}')),
          const SizedBox(height: MP.s2),
          const Text('Cada parceiro confirma a vaga e combina o pagamento com você. Nada é cobrado no app.', style: TextStyle(fontSize: 13, color: MP.textSecondary)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(key: const Key('route-reserve-ok'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar pedidos')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final ok = await requireLogin(context, ref, reason: 'Entre para enviar os pedidos de reserva. Você volta direto para cá.');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final store = ref.read(appStoreProvider);
    final failed = <String>[];
    for (final r in reqs) {
      try {
        await store.requestReservationAsync(
          itemId: r.item.id,
          date: r.day,
          period: r.period,
          people: r.people,
          requestKey: '${_t.id}-${r.item.id}-${r.day.toIso8601String()}',
        );
      } on MvpException catch (e) {
        failed.add('${r.item.titulo}: ${e.message}');
      }
    }
    await store.saveTrip(_t);
    if (!mounted) return;
    setState(() => _busy = false);
    showMpSnack(
      context,
      failed.isEmpty
          ? '${reqs.length} pedidos enviados. Acompanhe em Minhas reservas.'
          : 'Não foi possível enviar: ${failed.join('; ')}',
    );
  }

  String _shareText() {
    final b = StringBuffer('${_t.name} · MaraPass\n');
    for (final d in _t.days) {
      final list = _t.stopsOn(d);
      if (list.isEmpty) continue;
      b.writeln('\n${_dayLabel(d)}');
      for (final s in list) {
        b.writeln('${hhmm(s.startMin)} – ${hhmm(s.endMin)}  ${s.label}${s.item == null ? '' : ' (${s.item!.cidade})'}');
      }
    }
    return b.toString();
  }

  Future<void> _share() async {
    await Clipboard.setData(ClipboardData(text: _shareText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Roteiro copiado. Cole no WhatsApp ou onde quiser.')));
  }

  void _showOnMap(DateTime d) {
    final list = _t.stopsOn(d).where((s) => s.item?.lat != null).toList();
    if (list.isEmpty) return;
    ref.read(itineraryRequestProvider.notifier).state = DayPlan(
      city: list.first.item!.cidade,
      title: _t.name,
      lens: _dayLabel(d),
      rest: '',
      tip: '',
      stops: [for (final s in list) DayStop(time: hhmm(s.startMin), slot: '', itemId: s.itemId!, why: '')],
    );
    ref.read(shellTabProvider.notifier).go(Tabs.mapa);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appStoreProvider);
    const titles = ['Quando', 'Onde', 'Horários', 'Extras', 'Sua rota'];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            MpHeader('Defina sua Rota', subtitle: '${_step < 4 ? 'Passo ${_step + 1} de 4 · ' : ''}${titles[_step]}'),
            if (_step < 4)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
                child: Row(children: [
                  for (var k = 0; k < 4; k++)
                    Expanded(child: Container(height: 5, margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(color: k <= _step ? MP.green : MP.borderSubtle, borderRadius: BorderRadius.circular(3)))),
                ]),
              ),
            if (_step >= 1 && _step <= 2 && _t.days.length > 1) _dayChips(),
            Expanded(child: [_when, _where, _times, _extras, _summary][_step]()),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _dayChips() => SizedBox(
    height: 56,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s2, MP.pageH, 0),
      children: [
        for (final d in _t.days)
          Padding(
            padding: const EdgeInsets.only(right: MP.s2),
            child: ChoiceChip(label: Text(_dayLabel(d)), selected: sameDay(d, _day), onSelected: (_) => _set(() => _day = d)),
          ),
      ],
    ),
  );

  Widget _bottomBar() {
    if (_step == 4) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s2, MP.pageH, MP.s3),
        child: Row(children: [
          Expanded(child: OutlinedButton.icon(key: const Key('route-share'), onPressed: _share, icon: const Icon(Icons.ios_share_rounded), label: const Text('Compartilhar'))),
          const SizedBox(width: MP.s2),
          Expanded(child: FilledButton.icon(key: const Key('route-save'), onPressed: _save, icon: const Icon(Icons.bookmark_add_rounded), label: const Text('Salvar rota'))),
        ]).withReserve(
          tripRequests(_t).isEmpty
              ? null
              : FilledButton.icon(
                  key: const Key('route-reserve'),
                  onPressed: _busy ? null : _reserveAll,
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text(_busy ? 'Enviando…' : 'Reservar tudo (${tripRequests(_t).length})'),
                  style: FilledButton.styleFrom(backgroundColor: MP.green, minimumSize: const Size(0, 52)),
                ),
        ),
      );
    }
    final ok = _step != 1 || _t.stops.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s2, MP.pageH, MP.s3),
      child: Row(children: [
        if (_step > 0) ...[
          Expanded(child: OutlinedButton(onPressed: () => _set(() => _step--), child: const Text('Voltar'))),
          const SizedBox(width: MP.s2),
        ],
        Expanded(
          flex: 2,
          child: FilledButton(
            key: const Key('route-next'),
            onPressed: ok && _hasDates ? () => _set(() => _step++) : null,
            child: Text(_step == 3 ? 'Ver minha rota' : (ok ? 'Continuar' : 'Adicione um lugar')),
          ),
        ),
      ]),
    );
  }

  // ---------- 1. Quando
  Widget _when() => ListView(
    padding: const EdgeInsets.all(MP.pageH),
    children: [
      const Text('Toque no dia de ida e depois no de volta. Para um dia só, toque duas vezes no mesmo dia ou siga em frente.', style: TextStyle(fontSize: 15, color: MP.textSecondary)),
      const SizedBox(height: MP.s3),
      MpMonthCalendar(
        start: _t.start,
        end: sameDay(_t.start, _t.end) ? null : _t.end,
        range: true,
        allowToday: true,
        hasEvent: (d) => _eventsOn(d).isNotEmpty,
        onChanged: (s, e) => _set(() {
          if (s == null) return;
          _t.start = s;
          _t.end = e ?? s;
          _t.stops.removeWhere((x) => x.day.isBefore(_t.start) || x.day.isAfter(_t.end));
          _day = _t.start;
        }),
      ),
      const SizedBox(height: MP.s3),
      for (final e in _t.days.expand(_eventsOn)) _tip(Icons.event_rounded, 'Evento nesta data: ${e.titulo} (${_dm(e.data!)})'),
      const SizedBox(height: MP.s3),
      Row(children: [
        const Expanded(child: Text('Pessoas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
        IconButton(onPressed: _t.people > 1 ? () => _set(() => _t.people--) : null, icon: const Icon(Icons.remove_circle_outline_rounded)),
        Text('${_t.people}', key: const Key('route-people'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        IconButton(onPressed: () => _set(() => _t.people++), icon: const Icon(Icons.add_circle_outline_rounded)),
      ]),
    ],
  );

  List<Item> _eventsOn(DateTime d) => Content.byCat(Cat.evento).where((e) => e.data != null && sameDay(e.data!, d)).toList();

  // ---------- 2. Onde
  Widget _where() {
    final day = _t.stopsOn(_day);
    final q = _q.toLowerCase();
    final options = Content.items
        .where((i) => i.cat != Cat.hospedagem && i.cat != Cat.transporte && i.cat != Cat.evento)
        .where((i) => q.isEmpty || '${i.titulo} ${i.cidade}'.toLowerCase().contains(q))
        .take(30)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(MP.pageH),
      children: [
        Row(children: [
          Expanded(child: Text('Sua ordem em ${_dayLabel(_day)}', style: Theme.of(context).textTheme.titleMedium)),
          TextButton.icon(onPressed: () => _showOnMap(_day), icon: const Icon(Icons.map_rounded), label: const Text('Mapa')),
        ]),
        if (day.isEmpty) const MpNotice('Adicione lugares da lista abaixo. Depois arraste para mudar a ordem.'),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: _reorder,
          children: [
            for (final (k, s) in day.indexed)
              ListTile(
                key: ValueKey(s.id),
                contentPadding: EdgeInsets.zero,
                leading: ReorderableDragStartListener(index: k, child: const Icon(Icons.drag_indicator_rounded)),
                title: Text(s.label),
                subtitle: Text(s.item?.cidade ?? 'Parada'),
                trailing: IconButton(tooltip: 'Remover', onPressed: () => _set(() => _t.stops.remove(s)), icon: const Icon(Icons.close_rounded)),
              ),
          ],
        ),
        const SizedBox(height: MP.s4),
        TextField(
          key: const Key('route-search'),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar lugar ou cidade'),
          onChanged: (v) => _set(() => _q = v),
        ),
        const SizedBox(height: MP.s2),
        for (final i in options)
          ListTile(
            key: Key('route-add-${i.id}'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(i.cat.icon, color: i.cat.tint.fg),
            title: Text(i.titulo),
            subtitle: Text([i.cidade, if (i.cupom != null) 'cupom disponível'].join(' · ')),
            trailing: day.any((s) => s.itemId == i.id) ? const Icon(Icons.check_circle_rounded, color: MP.green) : const Icon(Icons.add_circle_outline_rounded),
            onTap: day.any((s) => s.itemId == i.id) ? null : () => _addItem(i),
          ),
      ],
    );
  }

  // ---------- 3. Horários
  Widget _times() {
    final day = _t.stopsOn(_day);
    final issues = tripConflicts(_t, _day);
    return ListView(
      padding: const EdgeInsets.all(MP.pageH),
      children: [
        for (final (k, s) in day.indexed) ...[
          if (k > 0 && driveMinutes(day[k - 1].item, s.item) != null)
            _tip(Icons.directions_car_rounded, 'Distância até o próximo ponto: ${driveMinutes(day[k - 1].item, s.item)} min'),
          MpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: MP.s2),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('route-time-$k'),
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: s.startMin ~/ 60, minute: s.startMin % 60));
                      if (t != null) _set(() => s.startMin = t.hour * 60 + t.minute);
                    },
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text('Chegada ${hhmm(s.startMin)}'),
                  ),
                ),
                const SizedBox(width: MP.s2),
                DropdownButton<int>(
                  value: s.stayMin,
                  items: [for (final m in const [30, 60, 90, 120, 180, 240, 360]) DropdownMenuItem(value: m, child: Text(m < 60 ? '$m min' : '${m ~/ 60}h${m % 60 == 0 ? '' : '30'}'))],
                  onChanged: (v) => _set(() => s.stayMin = v ?? s.stayMin),
                ),
              ]),
              if (_hint(s) case final h?) _tip(Icons.tips_and_updates_rounded, h),
              for (final n in issues[s.id] ?? const <String>[]) _warn(n),
            ]),
          ),
          const SizedBox(height: MP.s2),
        ],
        const SizedBox(height: MP.s2),
        Wrap(spacing: MP.s2, children: [
          for (final e in pauseKinds.entries)
            ActionChip(key: Key('route-pause-${e.key}'), avatar: const Icon(Icons.add_rounded, size: 18), label: Text(e.value), onPressed: () => _addPause(e.key)),
        ]),
      ],
    );
  }

  String? _hint(TripStop s) {
    final i = s.item;
    if (i == null) return null;
    if (i.cupom != null && Content.cupom(i.cupom) != null) return 'Cupom disponível aqui: ${Content.cupom(i.cupom)!.beneficio}';
    if (i.cat == Cat.natureza || i.cat == Cat.passeio) return 'Melhor horário: manhã, antes do sol forte.';
    if (i.horario != null) return 'Funciona: ${i.horario}';
    return null;
  }

  // ---------- 4. Extras
  Widget _extras() {
    Widget group(String title, List<Item> items) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: MP.s3),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      for (final i in items)
        CheckboxListTile(
          key: Key('route-extra-${i.id}'),
          contentPadding: EdgeInsets.zero,
          value: _t.extras.contains(i.id),
          onChanged: (v) => _set(() => v == true ? _t.extras.add(i.id) : _t.extras.remove(i.id)),
          title: Text(i.titulo),
          subtitle: Text([i.cidade, if (i.precoCents != null) '${formatBrl(i.precoCents!)}${i.cat == Cat.hospedagem ? ' por noite' : ' por pessoa'}'].join(' · ')),
        ),
    ]);
    final cities = {for (final s in _t.stops) if (s.item != null) s.item!.cidade};
    List<Item> near(Cat c) => Content.byCat(c).where((i) => cities.isEmpty || cities.contains(i.cidade)).toList();
    final events = _t.days.expand(_eventsOn).toList();
    return ListView(
      padding: const EdgeInsets.all(MP.pageH),
      children: [
        const Text('Inclua reservas e eventos do período. Eles entram no custo estimado.', style: TextStyle(fontSize: 15, color: MP.textSecondary)),
        group('Hospedagem', near(Cat.hospedagem)),
        group('Passeios', near(Cat.passeio).where((i) => !_t.stops.any((s) => s.itemId == i.id)).toList()),
        if (events.isNotEmpty) group('Eventos no período', events) else ...[
          const SizedBox(height: MP.s3),
          const MpNotice('Nenhum evento cadastrado nessas datas.'),
        ],
      ],
    );
  }

  // ---------- Resumo: linha do tempo e custo
  Widget _summary() {
    final cost = tripCost(_t);
    final total = cost.fold<int>(0, (n, c) => n + c.cents - c.discountCents);
    return ListView(
      key: const Key('route-summary'),
      padding: const EdgeInsets.all(MP.pageH),
      children: [
        for (final d in _t.days) ...[
          Row(children: [
            Expanded(child: Text(_dayLabel(d), style: Theme.of(context).textTheme.titleLarge)),
            if (_t.stopsOn(d).any((s) => s.item?.lat != null))
              TextButton.icon(onPressed: () => _showOnMap(d), icon: const Icon(Icons.map_rounded), label: const Text('Ver no mapa')),
            IconButton(tooltip: 'Editar', onPressed: () => _set(() { _day = d; _step = 1; }), icon: const Icon(Icons.edit_rounded)),
          ]),
          if (_t.stopsOn(d).isEmpty) const Text('Dia livre.', style: TextStyle(color: MP.textSecondary)),
          for (final s in _t.stopsOn(d)) _timelineRow(s, tripConflicts(_t, d)[s.id]),
          const SizedBox(height: MP.s4),
        ],
        MpCard(
          key: const Key('route-cost'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Custo estimado', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: MP.s2),
            for (final c in cost) ...[
              _costRow(c.label, formatBrl(c.cents)),
              if (c.discountCents > 0) _costRow('Cupons em ${c.label.split(' ').first.toLowerCase()}', '− ${formatBrl(c.discountCents)}', color: MP.green),
            ],
            const Divider(),
            _costRow('Total do grupo (${_t.people} ${_t.people == 1 ? 'pessoa' : 'pessoas'})', formatBrl(total), bold: true),
            _costRow('Por pessoa', formatBrl((total / _t.people).round())),
            const SizedBox(height: MP.s2),
            const Text('Valores aproximados. Alimentação estimada em R\$ 70 por pessoa por dia.', style: TextStyle(fontSize: 13, color: MP.textSecondary)),
          ]),
        ),
      ],
    );
  }

  Widget _timelineRow(TripStop s, List<String>? issues) => IntrinsicHeight(
    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(width: 56, child: Text(hhmm(s.startMin), style: const TextStyle(fontWeight: FontWeight.w800, color: MP.textSecondary))),
      Container(width: 4, margin: const EdgeInsets.symmetric(horizontal: MP.s2), decoration: BoxDecoration(color: s.item == null ? MP.yellow : MP.green, borderRadius: BorderRadius.circular(2))),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: MP.s3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text('${hhmm(s.startMin)} – ${hhmm(s.endMin)}${s.item == null ? '' : ' · ${s.item!.cidade}'}', style: const TextStyle(color: MP.textSecondary)),
            for (final n in issues ?? const <String>[]) _warn(n),
          ]),
        ),
      ),
    ]),
  );

  Widget _costRow(String l, String v, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Expanded(child: Text(l, style: TextStyle(fontSize: 15, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color))),
      Text(v, style: TextStyle(fontSize: 15, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color)),
    ]),
  );

  Widget _tip(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: MP.s2),
    child: Row(children: [
      Icon(icon, size: 18, color: MP.textSecondary),
      const SizedBox(width: MP.s2),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: MP.textSecondary))),
    ]),
  );

  Widget _warn(String text) => Padding(
    padding: const EdgeInsets.only(top: MP.s2),
    child: Row(children: [
      const Icon(Icons.warning_amber_rounded, size: 18, color: MP.error),
      const SizedBox(width: MP.s2),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: MP.error, fontWeight: FontWeight.w600))),
    ]),
  );
}

extension on Row {
  /// Coloca o botão "Reservar tudo" acima de Compartilhar e Salvar.
  Widget withReserve(Widget? reserve) => reserve == null
      ? this
      : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [reserve, const SizedBox(height: MP.s2), this]);
}
