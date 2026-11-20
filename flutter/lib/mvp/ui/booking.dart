import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'month_calendar.dart';

import '../data/content.dart';
import '../data/models.dart' show formatBrl;
import '../data/remote.dart' show SlotDay;
import '../data/repository.dart';
import '../data/store.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'common.dart';
import 'explore.dart';
import 'login_screen.dart';
import 'support.dart';

/// Reserva em etapas curtas (protótipo aprovado): dia, período, pessoas e
/// cupom, com resumo do preço e barra fixa de confirmação. No MVP a reserva é
/// um pedido de disponibilidade: o parceiro confirma depois.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.item});
  final Item item;
  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  DateTime? _day;
  String? _period;
  int _people = 2;
  late bool _useCoupon = Content.cupom(widget.item.cupom) != null;
  bool _busy = false;

  /// Turnos do parceiro (vazio = horários padrão, sem limite cadastrado).
  List<SlotDay> _slots = const [];

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    final r = ref.read(appStoreProvider).remote;
    if (r == null) return;
    final n = DateTime.now();
    try {
      final list = await r.slotAvailability(widget.item.id, DateTime(n.year, n.month, n.day + 1), DateTime(n.year, n.month, n.day + 180));
      if (mounted) setState(() => _slots = list);
    } catch (_) {}
  }

  SlotDay? _slot(DateTime? d, String p) => d == null
      ? null
      : _slots.where((x) => x.period == p && x.day.year == d.year && x.day.month == d.month && x.day.day == d.day).firstOrNull;

  bool _dayOpen(DateTime d) => _slots.isEmpty || _slots.any((x) => x.available && x.day.year == d.year && x.day.month == d.month && x.day.day == d.day);

  /// Mesma chave em toda nova tentativa: o banco não duplica o pedido.
  final String _requestKey =
      '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(Object())}';


  Future<void> _submit() async {
    final ok = await requireLogin(
      context,
      ref,
      reason:
          'Entre para enviar o pedido de reserva. Você volta direto para cá.',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final store = ref.read(appStoreProvider);
    final cupom = Content.cupom(widget.item.cupom);
    final LocalReservation r;
    try {
      r = await store.requestReservationAsync(
        itemId: widget.item.id,
        date: _day!,
        period: _period!,
        people: _people,
        requestKey: _requestKey,
        cupomId: _useCoupon ? cupom?.id : null,
      );
    } on MvpException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMpSnack(context, e.message);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MpStatusScreen(
          title: 'Solicitação enviada',
          message: 'O parceiro vai confirmar a sua reserva. Você acompanha em Minhas reservas e recebe um aviso.',
          details: _ResSummary(res: r),
          primaryLabel: 'Ver minhas reservas',
          onPrimary: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const ReservationsScreen()),
          ),
          secondaryLabel: 'Voltar ao início',
          onSecondary: () {
            ref.read(shellTabProvider.notifier).go(0);
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    final cupom = Content.cupom(i.cupom);
    final unit = i.precoCents ?? 0;
    final discount = _useCoupon ? (cupom?.valorCents ?? 0) * _people : 0;
    final total = (unit * _people - discount).clamp(0, 1 << 31);
    final ready = _day != null && _period != null;

    Widget step(int n, String title, Widget child, {bool done = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: MP.sectionGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: done ? MP.green : MP.soft,
                    child: done
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 18,
                          )
                        : Text(
                            '$n',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: MP.ink,
                            ),
                          ),
                  ),
                  const SizedBox(width: MP.s3),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MP.s3),
              child,
            ],
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s6),
          children: [
            MpHeader('Reservar', subtitle: i.titulo),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  step(
                    1,
                    'Escolha o dia',
                    MpMonthCalendar(
                      start: _day,
                      onChanged: (d, _) => setState(() {
                        _day = d;
                        final cur = _period == null ? null : _slot(d, _period!);
                        if (cur != null && !cur.available) _period = null;
                      }),
                      isEnabled: (d) => d.difference(DateTime.now()).inDays < 180 && _dayOpen(d),
                      hasEvent: (d) => Content.byCat(Cat.evento).any((e) => e.data != null && e.data!.year == d.year && e.data!.month == d.month && e.data!.day == d.day),
                    ),
                    done: _day != null,
                  ),
                  step(
                    2,
                    'Escolha o horário',
                    Row(
                      children: [
                        for (final p in [
                          for (final (name, hours, icon) in const [
                            ('Manhã', '8h às 12h', Icons.wb_sunny_rounded),
                            ('Tarde', '14h às 18h', Icons.wb_twilight_rounded),
                          ])
                            if (_slots.isEmpty || _slot(_day, name) != null || _day == null)
                              (
                                name,
                                switch (_slot(_day, name)) {
                                  null => hours,
                                  final x when !x.open => 'Não funciona',
                                  final x => '${x.hours} · ${x.left == 0 ? 'esgotado' : '${x.left} vagas'}',
                                },
                                icon,
                              ),
                        ]) ...[
                          Expanded(
                            child: InkWell(
                              key: Key('period-${p.$1}'),
                              borderRadius: BorderRadius.circular(MP.rMedium),
                              onTap: (_slot(_day, p.$1)?.available ?? true) ? () => setState(() {
                                _period = p.$1;
                                final left = _slot(_day, p.$1)?.left;
                                if (left != null && _people > left) _people = left;
                              }) : null,
                              child: Container(
                                padding: const EdgeInsets.all(MP.s4),
                                decoration: BoxDecoration(
                                  color: _period == p.$1 ? MP.navy : MP.soft,
                                  borderRadius: BorderRadius.circular(
                                    MP.rMedium,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      p.$3,
                                      color: _period == p.$1
                                          ? MP.yellow
                                          : MP.navy,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      p.$1,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        color: _period == p.$1
                                            ? Colors.white
                                            : MP.ink,
                                      ),
                                    ),
                                    Text(
                                      p.$2,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _period == p.$1
                                            ? Colors.white70
                                            : MP.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (p.$1 == 'Manhã') const SizedBox(width: MP.s3),
                        ],
                      ],
                    ),
                    done: _period != null,
                  ),
                  step(
                    3,
                    'Quantas pessoas?',
                    Row(
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          size: 36,
                          color: MP.navy,
                        ),
                        const Spacer(),
                        MpStepper(
                          value: _people,
                          min: 1,
                          max: _slot(_day, _period ?? '')?.left.clamp(1, 12) ?? 12,
                          keyPrefix: 'people',
                          onChanged: (v) => setState(() => _people = v),
                        ),
                      ],
                    ),
                    done: true,
                  ),
                  if (cupom != null)
                    step(
                      4,
                      'Cupom',
                      SwitchListTile(
                        key: const Key('use-coupon'),
                        value: _useCoupon,
                        onChanged: (v) => setState(() => _useCoupon = v),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Usar ${cupom.beneficio}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        subtitle: Text(cupom.detalhe),
                      ),
                      done: _useCoupon,
                    ),
                  if (unit > 0)
                    MpCard(
                      color: MP.soft,
                      child: Column(
                        children: [
                          _line(
                            '${formatBrl(unit)} × $_people ${_people == 1 ? 'pessoa' : 'pessoas'}',
                            formatBrl(unit * _people),
                          ),
                          if (discount > 0)
                            _line(
                              'Desconto do cupom',
                              '- ${formatBrl(discount)}',
                              color: MP.success,
                            ),
                          const Divider(height: MP.s5),
                          _line('Total estimado', formatBrl(total), bold: true),
                          const SizedBox(height: MP.s2),
                          const Text(
                            'Nenhum pagamento é feito agora. O valor final é combinado com o parceiro.',
                            style: TextStyle(
                              color: MP.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s3, MP.pageH, MP.s3),
          decoration: const BoxDecoration(
            color: MP.page,
            border: Border(top: BorderSide(color: MP.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ready)
                Padding(
                  padding: const EdgeInsets.only(bottom: MP.s2),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available_rounded, color: MP.green, size: MP.iconSm),
                      const SizedBox(width: MP.s2),
                      Expanded(
                        child: Text(
                          '${_day!.day.toString().padLeft(2, '0')}/${_day!.month.toString().padLeft(2, '0')} · $_period · $_people ${_people == 1 ? 'pessoa' : 'pessoas'}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: MP.ink),
                        ),
                      ),
                      if (unit > 0)
                        Text(formatBrl(total), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: MP.ink)),
                    ],
                  ),
                ),
              MpCtaButton(
                key: const Key('booking-submit'),
                label: ready
                    ? 'Solicitar reserva'
                    : (_day == null ? 'Escolha o dia' : 'Escolha o horário'),
                busy: _busy,
                onPressed: ready ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String a, String b, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                a,
                style: TextStyle(
                  fontSize: bold ? 18 : 16,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  color: color ?? MP.ink,
                ),
              ),
            ),
            Text(
              b,
              style: TextStyle(
                fontSize: bold ? 20 : 16,
                fontWeight: FontWeight.w800,
                color: color ?? MP.ink,
              ),
            ),
          ],
        ),
      );
}

class _ResSummary extends StatelessWidget {
  const _ResSummary({required this.res});
  final LocalReservation res;
  @override
  Widget build(BuildContext context) => MpCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          res.item?.titulo ?? 'Passeio',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: MP.s2),
        MpInfoRow(Icons.event_rounded, fmtLong(res.date)),
        MpInfoRow(Icons.schedule_rounded, res.period),
        MpInfoRow(
          Icons.groups_rounded,
          '${res.people} ${res.people == 1 ? 'pessoa' : 'pessoas'}',
        ),
        const SizedBox(height: MP.s2),
        _StatusBadge(res.status),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.s);
  final ResStatus s;
  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (s) {
      ResStatus.confirmada => (MP.success, MP.successBg),
      ResStatus.solicitada => (MP.warning, MP.warningBg),
      ResStatus.concluida => (MP.info, MP.infoBg),
      _ => (MP.textSecondary, MP.soft),
    };
    return MpBadge(s.label, fg: fg, bg: bg);
  }
}

/// Central de reservas do turista.
class ReservationsScreen extends ConsumerWidget {
  const ReservationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(appStoreProvider).myReservations;
    final active = list
        .where(
          (r) =>
              r.status == ResStatus.solicitada ||
              r.status == ResStatus.confirmada,
        )
        .toList();
    final past = list.where((r) => !active.contains(r)).toList();
    return Scaffold(
      body: SafeArea(
        child: list.isEmpty
            ? Column(
                children: [
                  const MpHeader('Minhas reservas'),
                  Expanded(
                    child: MpEmpty(
                      icon: Icons.event_note_rounded,
                      title: 'Nenhuma reserva ainda',
                      message: 'Escolha um passeio e toque em Reservar. O parceiro confirma e você acompanha aqui.',
                      actionLabel: 'Ver passeios',
                      onAction: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const ExploreScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: MP.s8),
                children: [
                  const MpHeader(
                    'Minhas reservas',
                    subtitle: 'Acompanhe, mude ou cancele.',
                  ),
                  if (active.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                        MP.pageH,
                        0,
                        MP.pageH,
                        MP.s2,
                      ),
                      child: MpSectionTitle('Próximas'),
                    ),
                  for (final r in active) _ResTile(res: r),
                  if (past.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                        MP.pageH,
                        MP.s4,
                        MP.pageH,
                        MP.s2,
                      ),
                      child: MpSectionTitle('Histórico'),
                    ),
                  for (final r in past) _ResTile(res: r),
                ],
              ),
      ),
    );
  }
}

class _ResTile extends StatelessWidget {
  const _ResTile({required this.res});
  final LocalReservation res;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s3),
    child: MpCard(
      onTap: () => push<void>(context, ReservationDetailScreen(id: res.id)),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: MpPhoto(
              photo: res.item?.foto,
              height: 72,
              radius: MP.rMedium,
              icon: Icons.event_rounded,
            ),
          ),
          const SizedBox(width: MP.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  res.item?.titulo ?? 'Passeio',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${fmtLong(res.date)} · ${res.period}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                _StatusBadge(res.status),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: MP.textMuted,
            size: 28,
          ),
        ],
      ),
    ),
  );
}

/// Detalhe da reserva: reagendar, participantes, cancelar com motivo,
/// conversa com o parceiro e histórico.
class ReservationDetailScreen extends ConsumerWidget {
  const ReservationDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final r = store.reservations.firstWhere((e) => e.id == id);
    final open =
        r.status == ResStatus.solicitada || r.status == ResStatus.confirmada;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            const MpHeader('Sua reserva'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ResSummary(res: r),
                  const SizedBox(height: MP.s4),
                  if (open) ...[
                    MpListTile(
                      key: const Key('res-reschedule'),
                      icon: Icons.edit_calendar_rounded,
                      title: 'Reagendar',
                      subtitle: 'Pedir outro dia ou horário',
                      onTap: () => _reschedule(context, store, r),
                    ),
                    const SizedBox(height: MP.s2),
                    MpListTile(
                      key: const Key('res-people'),
                      icon: Icons.groups_rounded,
                      title: 'Participantes',
                      subtitle:
                          '${r.people} ${r.people == 1 ? 'pessoa' : 'pessoas'}',
                      onTap: () => _people(context, store, r),
                    ),
                    const SizedBox(height: MP.s2),
                  ],
                  MpListTile(
                    icon: Icons.chat_rounded,
                    title: 'Conversar com o parceiro',
                    subtitle: 'Mensagens sobre esta reserva',
                    onTap: () => push<void>(
                      context,
                      ComposeScreen(
                        kind: 'Reserva',
                        subject: r.item?.titulo ?? 'Reserva',
                        hint: 'Escreva sua dúvida sobre a reserva',
                      ),
                    ),
                  ),
                  const SizedBox(height: MP.s4),
                  Text(
                    'Histórico',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: MP.s2),
                  for (final h in r.history.reversed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 10, color: MP.green),
                          const SizedBox(width: MP.s3),
                          Expanded(
                            child: Text(
                              h,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (open) ...[
                    const SizedBox(height: MP.s6),
                    TextButton(
                      key: const Key('res-cancel'),
                      onPressed: () => _cancel(context, store, r),
                      child: const Text(
                        'Cancelar reserva',
                        style: TextStyle(color: MP.error, fontSize: 17),
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

  Future<void> _reschedule(
    BuildContext context,
    AppStore store,
    LocalReservation r,
  ) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 90)),
      initialDate: r.date.isAfter(now)
          ? r.date
          : now.add(const Duration(days: 1)),
      helpText: 'Novo dia',
    );
    if (d == null || !context.mounted) return;
    final p = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final x in const ['Manhã', 'Tarde'])
              ListTile(
                minTileHeight: 64,
                leading: Icon(
                  x == 'Manhã'
                      ? Icons.wb_sunny_rounded
                      : Icons.wb_twilight_rounded,
                ),
                title: Text(
                  x,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(x),
              ),
          ],
        ),
      ),
    );
    if (p == null || !context.mounted) return;
    try {
      await store.rescheduleAsync(r.id, d, p);
      if (context.mounted) {
        showMpSnack(context, 'Pedido de novo dia enviado ao parceiro.');
      }
    } on MvpException catch (e) {
      if (context.mounted) showMpSnack(context, e.message);
    }
  }

  Future<void> _people(
    BuildContext context,
    AppStore store,
    LocalReservation r,
  ) async {
    var n = r.people;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Participantes'),
          content: MpStepper(
            value: n,
            min: 1,
            max: 12,
            keyPrefix: 'dlg-people',
            onChanged: (v) => set(() => n = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('dlg-people-save'),
              style: FilledButton.styleFrom(minimumSize: const Size(110, 52)),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && n != r.people) {
      try {
        await store.changePeopleAsync(r.id, n);
      } on MvpException catch (e) {
        if (context.mounted) showMpSnack(context, e.message);
      }
    }
  }

  Future<void> _cancel(
    BuildContext context,
    AppStore store,
    LocalReservation r,
  ) async {
    const reasons = [
      'Mudei meus planos',
      'Problema de saúde',
      'Clima ruim',
      'Encontrei outra opção',
      'Outro motivo',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s2),
              child: Text(
                'Por que você quer cancelar?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            for (final x in reasons)
              ListTile(
                minTileHeight: 60,
                title: Text(x, style: const TextStyle(fontSize: 17)),
                onTap: () => Navigator.of(context).pop(x),
              ),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar a reserva?'),
        content: const Text(
          'Grátis até 24 horas antes. O parceiro será avisado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Manter'),
          ),
          FilledButton(
            key: const Key('res-cancel-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: MP.error,
              minimumSize: const Size(120, 52),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (sure == true) {
      try {
        await store.cancelReservationAsync(r.id, reason);
        if (context.mounted) showMpSnack(context, 'Reserva cancelada.');
      } on MvpException catch (e) {
        if (context.mounted) showMpSnack(context, e.message);
      }
    }
  }
}
