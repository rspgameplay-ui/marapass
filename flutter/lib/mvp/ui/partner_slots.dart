import 'package:flutter/material.dart';
import '../i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content.dart';
import '../data/repository.dart' show MvpException;
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';

const _dows = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

/// Horários e vagas: o parceiro define, para cada item seu, os turnos Manhã e
/// Tarde, a faixa de horário, os dias da semana e o limite de pessoas por dia.
/// O banco recusa reservas acima do limite.
class PartnerSlotsScreen extends ConsumerStatefulWidget {
  const PartnerSlotsScreen({super.key});
  @override
  ConsumerState<PartnerSlotsScreen> createState() => _PartnerSlotsState();
}

class _SlotForm {
  _SlotForm(this.item, this.period, Map<String, dynamic>? row)
    : hours = TextEditingController(text: '${row?['hours'] ?? (period == 'Manhã' ? '8h às 12h' : '14h às 18h')}'),
      capacity = (row?['capacity'] as num?)?.toInt() ?? 10,
      weekdays = {for (final d in (row?['weekdays'] as List? ?? const [1, 2, 3, 4, 5, 6, 7])) (d as num).toInt()},
      active = row?['active'] as bool? ?? row != null,
      saved = row != null;
  final String item, period;
  final TextEditingController hours;
  int capacity;
  final Set<int> weekdays;
  bool active, saved;
}

class _PartnerSlotsState extends ConsumerState<PartnerSlotsScreen> {
  List<_SlotForm>? _forms;
  String? _error;
  String? _saving;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = ref.read(appStoreProvider).remote;
    if (r == null || !r.signedIn) {
      setState(() => _error = 'Entre com a conta de parceiro para editar horários e vagas.');
      return;
    }
    try {
      final (keys, rows) = await r.mySlots();
      Map<String, dynamic>? row(String k, String p) => rows.where((x) => x['item_key'] == k && x['period'] == p).firstOrNull;
      setState(() => _forms = [for (final k in keys) for (final p in const ['Manhã', 'Tarde']) _SlotForm(k, p, row(k, p))]);
    } on MvpException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _save(_SlotForm f) async {
    setState(() => _saving = '${f.item}|${f.period}');
    try {
      await ref.read(appStoreProvider).remote!.setSlot(
        itemKey: f.item,
        period: f.period,
        hours: f.hours.text,
        capacity: f.capacity,
        weekdays: f.weekdays.toList()..sort(),
        active: f.active,
      );
      f.saved = true;
      if (mounted) showMpSnack(context, '${f.period} salvo.');
    } on MvpException catch (e) {
      if (mounted) showMpSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final forms = _forms;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            MpHeader(tr('Horários e vagas'), subtitle: tr('O turista só consegue reservar dentro do que você definir aqui.')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) MpNotice(_error!),
                  if (forms == null && _error == null) const Center(child: CircularProgressIndicator()),
                  if (forms != null && forms.isEmpty)
                    MpNotice(tr('Nenhum item ligado à sua conta ainda. A equipe MaraPass faz essa ligação ao aprovar o seu cadastro.')),
                  for (final f in forms ?? const <_SlotForm>[]) ...[
                    if (f.period == 'Manhã') ...[
                      const SizedBox(height: MP.s3),
                      Text(Content.item(f.item)?.titulo ?? f.item, style: Theme.of(context).textTheme.titleLarge),
                    ],
                    const SizedBox(height: MP.s2),
                    MpCard(
                      key: Key('slot-${f.item}-${f.period}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: f.active,
                            onChanged: (v) => setState(() => f.active = v),
                            title: Text(f.period, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                            subtitle: Text(f.active ? tr('Aceita reservas') : tr('Fechado')),
                          ),
                          TextField(controller: f.hours, decoration: InputDecoration(labelText: tr('Horário (ex.: 8h às 12h)'))),
                          const SizedBox(height: MP.s3),
                          Row(children: [
                            Expanded(child: Text(tr('Vagas por dia (pessoas)'), style: TextStyle(fontWeight: FontWeight.w700))),
                            MpStepper(value: f.capacity, min: 1, max: 500, keyPrefix: 'slot-cap', onChanged: (v) => setState(() => f.capacity = v)),
                          ]),
                          const SizedBox(height: MP.s2),
                          Wrap(spacing: 6, children: [
                            for (var d = 1; d <= 7; d++)
                              FilterChip(
                                label: Text(_dows[d - 1]),
                                selected: f.weekdays.contains(d),
                                onSelected: (v) => setState(() => v ? f.weekdays.add(d) : f.weekdays.remove(d)),
                              ),
                          ]),
                          const SizedBox(height: MP.s3),
                          FilledButton(
                            onPressed: _saving != null ? null : () => _save(f),
                            child: Text(_saving == '${f.item}|${f.period}' ? tr('Salvando…') : (f.saved ? tr('Salvar alterações') : 'Ativar ${f.period.toLowerCase()}')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
