import 'package:flutter/material.dart';
import '../i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content.dart';
import '../data/models.dart' show formatBrl;
import '../data/repository.dart';
import '../data/store.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'booking.dart' show ReservationsScreen;
import 'common.dart';
import 'month_calendar.dart';
import 'login_screen.dart';

/// Ícone de cada comodidade comum.
IconData amenityIcon(String a) {
  final t = a.toLowerCase();
  if (t.contains('wi-fi')) return Icons.wifi_rounded;
  if (t.contains('café')) return Icons.free_breakfast_rounded;
  if (t.contains('piscina')) return Icons.pool_rounded;
  if (t.contains('praia') || t.contains('mar')) return Icons.beach_access_rounded;
  if (t.contains('bicicleta')) return Icons.pedal_bike_rounded;
  if (t.contains('estacionamento')) return Icons.local_parking_rounded;
  if (t.contains('ar-condicionado')) return Icons.ac_unit_rounded;
  if (t.contains('rede')) return Icons.deck_rounded;
  if (t.contains('cartão') || t.contains('pix')) return Icons.payments_rounded;
  if (t.contains('kids')) return Icons.child_care_rounded;
  if (t.contains('acessível')) return Icons.accessible_rounded;
  if (t.contains('música')) return Icons.music_note_rounded;
  if (t.contains('rio')) return Icons.water_rounded;
  if (t.contains('histórico')) return Icons.account_balance_rounded;
  return Icons.check_circle_outline_rounded;
}

/// Nota com estrelas e número de avaliações.
class RatingLine extends StatelessWidget {
  const RatingLine({super.key, required this.item, this.size = 15});
  final Item item;
  final double size;
  @override
  Widget build(BuildContext context) {
    if (item.nota == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: MP.yellow, size: size + 4),
        const SizedBox(width: 2),
        Text(item.nota!.toStringAsFixed(1).replaceAll('.', ','), style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: MP.ink)),
        if (item.avaliacoes != null)
          Text(' (${item.avaliacoes})', style: TextStyle(fontSize: size - 1, color: MP.textSecondary)),
      ],
    );
  }
}

/// Bloco de informações estruturadas de hospedagem e restaurantes: faixa de
/// preço, nota, diária, políticas e comodidades, no padrão das tarifas de hotel.
class StayFacts extends StatelessWidget {
  const StayFacts({super.key, required this.item, this.compact = false});
  final Item item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final stay = i.cat == Cat.hospedagem;
    final chips = <Widget>[
      if (i.cafeIncluso) const _Policy(Icons.free_breakfast_rounded, 'Café da manhã incluído', MP.green, MP.greenBg),
      if (stay)
        const _Policy(Icons.event_available_rounded, 'Cancelamento grátis até 24 h', MP.green, MP.greenBg),
      for (final a in i.comodidades.take(compact ? 3 : 8))
        if (!(i.cafeIncluso && a.toLowerCase().contains('café'))) _Policy(amenityIcon(a), a, MP.navy, MP.tintBlue),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: MP.s3,
          runSpacing: MP.s1,
          children: [
            RatingLine(item: i),
            Text(i.faixaLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: MP.green)),
            if (stay && i.precoCents != null)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: tr('a partir de ')),
                    TextSpan(text: formatBrl(i.precoCents!), style: const TextStyle(fontWeight: FontWeight.w800, color: MP.ink)),
                    const TextSpan(text: '/noite'),
                  ],
                ),
                style: const TextStyle(fontSize: 15, color: MP.textSecondary),
              ),
          ],
        ),
        if (i.horario != null && compact) ...[
          const SizedBox(height: MP.s1),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 16, color: MP.textSecondary),
              const SizedBox(width: MP.s1),
              Flexible(child: Text(i.horario!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: MP.textSecondary))),
            ],
          ),
        ],
        if (chips.isNotEmpty) ...[
          const SizedBox(height: MP.s2),
          Wrap(spacing: MP.s2, runSpacing: MP.s2, children: chips),
        ],
      ],
    );
  }
}

class _Policy extends StatelessWidget {
  const _Policy(this.icon, this.label, this.fg, this.bg);
  final IconData icon;
  final String label;
  final Color fg, bg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: MP.s2 + 2, vertical: 6),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(MP.rPill)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: fg),
        const SizedBox(width: 6),
        Flexible(
          child: Text(tr(label), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
        ),
      ],
    ),
  );
}

/// Oferta de quarto (tarifa) mostrada na disponibilidade.
class _Room {
  const _Room(this.name, this.perNight, this.breakfast, this.refundable, this.sleeps);
  final String name;
  final int perNight;
  final bool breakfast, refundable;
  final int sleeps;
}

/// Ver disponibilidade: datas e hóspedes, quartos com tarifa, café e
/// cancelamento claros, e pedido de reserva ao parceiro (sem pagamento no app).
class StayAvailabilityScreen extends ConsumerStatefulWidget {
  const StayAvailabilityScreen({super.key, required this.item});
  final Item item;
  @override
  ConsumerState<StayAvailabilityScreen> createState() => _StayState();
}

class _StayState extends ConsumerState<StayAvailabilityScreen> {
  late DateTimeRange _range = () {
    final t = DateTime.now();
    final start = DateTime(t.year, t.month, t.day).add(const Duration(days: 7));
    return DateTimeRange(start: start, end: start.add(const Duration(days: 2)));
  }();
  DateTime? _pickStart;
  int _guests = 2;
  int _room = 0;
  bool _busy = false;
  final String _requestKey = '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(Object())}';

  List<_Room> get _rooms {
    final base = widget.item.precoCents ?? 30000;
    return [
      _Room('Quarto Standard', base, widget.item.cafeIncluso, widget.item.cancelamentoGratis, 2),
      _Room('Quarto Superior com varanda', (base * 1.35).round(), true, widget.item.cancelamentoGratis, 3),
      _Room('Tarifa econômica', (base * .88).round(), false, false, 2),
    ];
  }

  int get _nights => _range.duration.inDays;

  Future<void> _request() async {
    final ok = await requireLogin(context, ref, reason: tr('Entre para enviar o pedido de reserva. Você volta direto para cá.'));
    if (!ok || !mounted) return;
    final room = _rooms[_room];
    setState(() => _busy = true);
    final LocalReservation r;
    try {
      r = await ref.read(appStoreProvider).requestReservationAsync(
        itemId: widget.item.id,
        date: _range.start,
        period: '$_nights ${_nights == 1 ? 'noite' : 'noites'} · ${room.name}',
        people: _guests,
        requestKey: _requestKey,
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
          title: tr('Pedido enviado à hospedagem'),
          message: tr('O parceiro confirma a disponibilidade e combina o pagamento com você. Acompanhe em Minhas reservas.'),
          details: MpCard(
            color: MP.soft,
            border: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.item.titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: MP.s1),
                Text('${fmtDate(_range.start)} a ${fmtDate(_range.end)} · ${r.people} hóspedes'),
                Text(room.name),
                Text('Total estimado: ${formatBrl(room.perNight * _nights)} (taxas incluídas)'),
              ],
            ),
          ),
          primaryLabel: tr('Ver minhas reservas'),
          onPrimary: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const ReservationsScreen()),
          ),
          secondaryLabel: tr('Voltar ao início'),
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
    final rooms = _rooms;
    final room = rooms[_room];
    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s3, MP.pageH, MP.s3),
          decoration: const BoxDecoration(color: MP.page, border: Border(top: BorderSide(color: MP.border))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatBrl(room.perNight * _nights), key: const Key('stay-total'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: MP.ink)),
                    Text('$_nights ${_nights == 1 ? 'noite' : 'noites'} · taxas incluídas', style: const TextStyle(fontSize: 13, color: MP.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: MP.s3),
              Expanded(
                child: MpPrimaryButton(key: const Key('stay-request'), label: tr('Solicitar'), busy: _busy, onPressed: _request),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            MpHeader(tr('Ver disponibilidade'), subtitle: i.titulo),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MpCard(
                    key: const Key('stay-dates'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Check-in ${fmtDate(_range.start)} → check-out ${fmtDate(_range.end)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(tr('Toque na entrada e depois na saída.'), style: TextStyle(fontSize: 13, color: MP.textSecondary)),
                        const SizedBox(height: MP.s2),
                        MpMonthCalendar(
                          range: true,
                          allowToday: true,
                          start: _pickStart ?? _range.start,
                          end: _pickStart != null ? null : _range.end,
                          isEnabled: (d) => d.difference(DateTime.now()).inDays < 365,
                          onChanged: (s, e) => setState(() {
                            if (s != null && e != null) {
                              _range = DateTimeRange(start: s, end: e);
                              _pickStart = null;
                            } else {
                              _pickStart = s;
                            }
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MP.s3),
                  MpCard(
                    child: Row(
                      children: [
                        const Icon(Icons.group_rounded, color: MP.navy),
                        const SizedBox(width: MP.s3),
                        Expanded(child: Text(tr('Hóspedes'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                        MpStepper(value: _guests, min: 1, max: 6, keyPrefix: 'stay-guests', onChanged: (v) => setState(() => _guests = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: MP.sectionGap),
                  MpSectionTitle(tr('Quartos disponíveis')),
                  const SizedBox(height: MP.s3),
                  for (var k = 0; k < rooms.length; k++) ...[
                    _RoomCard(
                      key: Key('stay-room-$k'),
                      room: rooms[k],
                      nights: _nights,
                      selected: k == _room,
                      tooSmall: rooms[k].sleeps < _guests,
                      onTap: rooms[k].sleeps < _guests ? null : () => setState(() => _room = k),
                    ),
                    const SizedBox(height: MP.s3),
                  ],
                  MpNotice.demo(tr('Tarifas de demonstração. Nesta versão o pagamento é combinado direto com a hospedagem; o app não cobra nada.')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({super.key, required this.room, required this.nights, required this.selected, required this.tooSmall, required this.onTap});
  final _Room room;
  final int nights;
  final bool selected, tooSmall;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: tooSmall ? .5 : 1,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MP.rLarge),
      child: AnimatedContainer(
        duration: MP.medium,
        padding: const EdgeInsets.all(MP.s4),
        decoration: BoxDecoration(
          color: selected ? MP.tintBlue : MP.card,
          borderRadius: BorderRadius.circular(MP.rLarge),
          border: Border.all(color: selected ? MP.navy : MP.border, width: selected ? 2 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? MP.navy : MP.textSecondary),
            const SizedBox(width: MP.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: MP.ink)),
                  const SizedBox(height: 2),
                  Text(tooSmall ? 'Até ${room.sleeps} hóspedes: não comporta o grupo' : 'Até ${room.sleeps} hóspedes', style: const TextStyle(fontSize: 14, color: MP.textSecondary)),
                  const SizedBox(height: MP.s2),
                  Wrap(
                    spacing: MP.s2,
                    runSpacing: MP.s2,
                    children: [
                      room.breakfast
                          ? const _Policy(Icons.free_breakfast_rounded, 'Café incluído', MP.green, MP.greenBg)
                          : const _Policy(Icons.no_meals_rounded, 'Sem café', MP.textSecondary, MP.soft),
                      const _Policy(Icons.event_available_rounded, 'Cancelamento grátis até 24 h', MP.green, MP.greenBg),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: MP.s2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatBrl(room.perNight), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: MP.ink)),
                const Text('/noite', style: TextStyle(fontSize: 13, color: MP.textSecondary)),
                const SizedBox(height: MP.s1),
                Text('${formatBrl(room.perNight * nights)} total', style: const TextStyle(fontSize: 13, color: MP.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
