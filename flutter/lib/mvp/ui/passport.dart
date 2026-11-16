import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'booking.dart';
import 'checkin.dart';
import 'common.dart';

/// MP-T16 · Passaporte: nível, pontos, selos dos 11 polos, selos municipais,
/// conquistas e histórico.
class PassportScreen extends ConsumerStatefulWidget {
  const PassportScreen({super.key});
  @override
  ConsumerState<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends ConsumerState<PassportScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(appStoreProvider);
    final lv = store.level;
    final progress = lv.$4 == null
        ? 1.0
        : ((store.points - lv.$2) / (lv.$4! - lv.$2)).clamp(0.0, 1.0);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s10),
        children: [
          const MpHeader('Meu passaporte', back: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Container(
              padding: const EdgeInsets.all(MP.s5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [MP.navy, Color(0xff2a5a85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(MP.rXl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.badge_rounded,
                        color: MP.yellow,
                        size: 30,
                      ),
                      const SizedBox(width: MP.s2),
                      const Text(
                        'PASSAPORTE MARAPASS',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        store.name ?? 'Viajante',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MP.s4),
                  const Text(
                    'Seu nível',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  Text(
                    lv.$1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${store.points} pontos',
                    style: const TextStyle(
                      color: MP.yellow,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: MP.s3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(MP.rPill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      color: MP.yellow,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  const SizedBox(height: MP.s2),
                  Text(
                    lv.$4 == null
                        ? 'Nível máximo alcançado'
                        : 'Faltam ${lv.$4! - store.points} pontos para ${lv.$3}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: MP.s4),
                  Row(
                    children: [
                      _Mini(
                        label: 'Visitas',
                        value: '${store.checkins.length}',
                      ),
                      _Mini(
                        label: 'Selos',
                        value:
                            '${store.stampedPolos.length}/${Content.polos.length}',
                      ),
                      _Mini(
                        label: 'Cupons usados',
                        value: '${store.coupons.where((c) => c.used).length}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MP.s4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('pass-checkin'),
                    onPressed: () => push<void>(context, const CheckinScreen()),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Registrar visita'),
                  ),
                ),
                const SizedBox(width: MP.s2),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('pass-reservas'),
                    onPressed: () =>
                        push<void>(context, const ReservationsScreen()),
                    icon: const Icon(Icons.event_note_rounded),
                    label: const Text('Reservas'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MP.s4),
          FilterChips<int>(
            options: const [0, 1, 2, 3],
            selected: _tab,
            label: (v) => const [
              'Conquistas',
              'Destinos visitados',
              'Cidades',
              'Histórico',
            ][v],
            onSelect: (v) => setState(() => _tab = v),
          ),
          const SizedBox(height: MP.s4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: switch (_tab) {
              0 => _Achievements(store: store),
              1 => _PoloStamps(store: store),
              2 => _CityStamps(store: store),
              _ => _History(store: store),
            },
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _PoloStamps extends StatelessWidget {
  const _PoloStamps({required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) {
    final got = store.stampedPolos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ganhe um selo no primeiro check-in de cada polo. ${got.length} de ${Content.polos.length}.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: MP.s3),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: MP.s3,
          crossAxisSpacing: MP.s3,
          childAspectRatio: .78,
          children: [
            for (final p in Content.polos)
              Semantics(
                label:
                    '${p.nome}: ${got.contains(p.id) ? 'selo conquistado' : 'ainda não visitado'}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(MP.rLarge),
                  onTap: () => openPolo(context, p),
                  child: Column(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: got.contains(p.id) ? MP.goldBg : MP.soft,
                          border: Border.all(
                            color: got.contains(p.id) ? MP.gold : MP.border,
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: got.contains(p.id) && p.foto != null
                              ? Image.asset(
                                  'assets/photos/${p.foto}.jpg',
                                  fit: BoxFit.cover,
                                )
                              : Icon(
                                  got.contains(p.id)
                                      ? Icons.workspace_premium_rounded
                                      : Icons.lock_outline_rounded,
                                  color: got.contains(p.id)
                                      ? MP.gold
                                      : MP.textMuted,
                                  size: 34,
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.nome,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: got.contains(p.id) ? MP.ink : MP.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CityStamps extends StatelessWidget {
  const _CityStamps({required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) {
    final cities = {for (final p in Content.polos) ...p.cidades}.toList()
      ..sort();
    final got = store.stampedCities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${got.length} cidades visitadas de ${cities.length} no programa.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: MP.s3),
        Wrap(
          spacing: MP.s2,
          runSpacing: MP.s2,
          children: [
            for (final c in cities)
              MpBadge(
                c,
                fg: got.contains(c) ? MP.success : MP.textMuted,
                bg: got.contains(c) ? MP.successBg : MP.soft,
                icon: got.contains(c)
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
              ),
          ],
        ),
      ],
    );
  }
}

class _Achievements extends StatelessWidget {
  const _Achievements({required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final a in store.achievements)
        Padding(
          padding: const EdgeInsets.only(bottom: MP.s2),
          child: MpListTile(
            icon: a.$1,
            title: a.$2,
            subtitle: a.$3 ? 'Conquistada' : 'Ainda não',
            tint: a.$3 ? MP.goldBg : MP.soft,
            color: a.$3 ? const Color(0xffa87b00) : MP.textMuted,
            trailing: Icon(
              a.$3 ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
              color: a.$3 ? MP.gold : MP.textMuted,
            ),
          ),
        ),
      const SizedBox(height: MP.s3),
      const MpNotice(
        'Níveis: Viajante (0), Explorador (500), Aventureiro (1.000) e Mestre (2.500 pontos). Check-in vale 50, cupom usado 20 e o primeiro check-in em cada polo, 100.',
      ),
    ],
  );
}

class _History extends StatelessWidget {
  const _History({required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) {
    final rows = <(DateTime, IconData, String, String)>[
      for (final c in store.checkins)
        (
          c.at,
          Icons.verified_rounded,
          'Check-in: ${Content.item(c.itemId)?.titulo ?? ''}',
          '+50 pontos',
        ),
      for (final c in store.coupons.where((c) => c.used))
        (
          c.usedAt!,
          Icons.local_activity_rounded,
          'Cupom usado: ${c.cupom?.parceiro ?? ''}',
          '+20 pontos',
        ),
      for (final r in store.myReservations)
        (
          r.date,
          Icons.event_rounded,
          'Reserva: ${r.item?.titulo ?? ''}',
          r.status.label,
        ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    if (rows.isEmpty) {
      return const MpCard(
        color: MP.soft,
        child: Text(
          'Seu histórico aparece aqui quando você fizer check-in, usar cupons ou reservar.',
          style: TextStyle(fontSize: 16, color: MP.textSecondary),
        ),
      );
    }
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: MP.s2),
            child: MpListTile(
              icon: r.$2,
              title: r.$3,
              subtitle: '${fmtDate(r.$1)} · ${r.$4}',
            ),
          ),
      ],
    );
  }
}
