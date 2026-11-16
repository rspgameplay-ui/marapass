import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'booking.dart';
import 'checkin.dart';
import 'common.dart';

/// Ícone e cor de cada polo nos carimbos (vetoriais: nítidos em qualquer tela).
const _poloStyle = <String, (IconData, Color)>{
  'lencois': (Icons.waves_rounded, Color(0xff1f6fd1)),
  'delta': (Icons.sailing_rounded, Color(0xff0f7a8a)),
  'chapada': (Icons.terrain_rounded, Color(0xffb4541f)),
  'saoluis': (Icons.account_balance_rounded, Color(0xff8a5a2b)),
  'munim': (Icons.kayaking_rounded, Color(0xff14775a)),
  'guaras': (Icons.flutter_dash_rounded, Color(0xffc53b36)),
  'lagos': (Icons.local_florist_rounded, Color(0xff6a4fb3)),
  'cocais': (Icons.park_rounded, Color(0xff5d7a1f)),
  'amazonia': (Icons.forest_rounded, Color(0xff1e6b3a)),
  'serras': (Icons.landscape_rounded, Color(0xff7a4b2a)),
  'balaiada': (Icons.festival_rounded, Color(0xffb0407e)),
};

/// MP-T16 · Passaporte: capa com nível e progresso, Registrar visita,
/// conquistas, carimbos dos 11 polos, cidades e histórico.
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
            child: _Cover(store: store, progress: progress),
          ),
          const SizedBox(height: MP.s4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MpCtaButton(
                  key: const Key('pass-checkin'),
                  label: 'Registrar visita',
                  icon: Icons.qr_code_scanner_rounded,
                  onPressed: () => push<void>(context, const CheckinScreen()),
                ),
                const SizedBox(height: MP.s2),
                OutlinedButton.icon(
                  key: const Key('pass-reservas'),
                  onPressed: () =>
                      push<void>(context, const ReservationsScreen()),
                  icon: const Icon(Icons.event_note_rounded, size: MP.iconMd),
                  label: const Text('Minhas reservas'),
                ),
              ],
            ),
          ),
          const SizedBox(height: MP.s5),
          FilterChips<int>(
            options: const [0, 1, 2, 3],
            selected: _tab,
            label: (v) =>
                const ['Conquistas', 'Carimbos', 'Cidades', 'Histórico'][v],
            onSelect: (v) => setState(() => _tab = v),
          ),
          const SizedBox(height: MP.s4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: AnimatedSwitcher(
              duration: MP.medium,
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: switch (_tab) {
                  0 => _Achievements(store: store),
                  1 => _PoloStamps(store: store),
                  2 => _CityStamps(store: store),
                  _ => _History(store: store),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Capa do passaporte: azul-marinho com cata-vento discreto, anel de progresso.
class _Cover extends StatelessWidget {
  const _Cover({required this.store, required this.progress});
  final AppStore store;
  final double progress;
  @override
  Widget build(BuildContext context) {
    final lv = store.level;
    return Semantics(
      label: 'Nível ${lv.$1}, ${store.points} pontos',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff0b3a66), Color(0xff0e4d84)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(MP.rXl),
          boxShadow: MP.shadowFloat,
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: CustomPaint(
                size: const Size(200, 200),
                painter: _CoverPattern(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(MP.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: MP.yellow,
                        size: MP.iconMd,
                      ),
                      const SizedBox(width: MP.s2),
                      const Expanded(
                        child: Text(
                          'PASSAPORTE MARAPASS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          store.name ?? 'Viajante',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MP.s5),
                  Row(
                    children: [
                      SizedBox(
                        width: 108,
                        height: 108,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => CustomPaint(
                            painter: _Ring(v),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${store.points}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      height: 1,
                                    ),
                                  ),
                                  const Text(
                                    'pontos',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: MP.s5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Seu nível',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              lv.$1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lv.$4 == null
                                  ? 'Nível máximo alcançado'
                                  : 'Faltam ${lv.$4! - store.points} pts para ${lv.$3}',
                              style: const TextStyle(
                                color: MP.yellow,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MP.s5),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: MP.s3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(MP.rMedium),
                    ),
                    child: Row(
                      children: [
                        _Mini(
                          label: 'Visitas',
                          value: '${store.checkins.length}',
                        ),
                        _Mini(
                          label: 'Carimbos',
                          value:
                              '${store.stampedPolos.length}/${Content.polos.length}',
                        ),
                        _Mini(
                          label: 'Cupons usados',
                          value: '${store.coupons.where((c) => c.used).length}',
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
    );
  }
}

class _Ring extends CustomPainter {
  _Ring(this.v);
  final double v;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const stroke = 10.0;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * v,
      false,
      Paint()
        ..color = MP.yellow
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _Ring old) => old.v != v;
}

class _CoverPattern extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Paint()..color = Colors.white.withValues(alpha: .05);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..quadraticBezierTo(
          c.dx + math.cos(a) * 90,
          c.dy + math.sin(a) * 90,
          c.dx + math.cos(a + .6) * 95,
          c.dy + math.sin(a + .6) * 95,
        )
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// Carimbo vetorial: anel duplo tracejado, ícone do polo e data da visita.
class Stamp extends StatelessWidget {
  const Stamp({super.key, required this.polo, required this.earned, this.date});
  final Polo polo;
  final bool earned;
  final DateTime? date;
  @override
  Widget build(BuildContext context) {
    final st = _poloStyle[polo.id] ?? (Icons.place_rounded, MP.navy);
    final color = earned ? st.$2 : MP.textMuted;
    return Semantics(
      label:
          '${polo.nome}: ${earned ? 'carimbo conquistado' : 'ainda não visitado'}',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Transform.rotate(
              angle: earned ? -.12 : 0,
              child: SizedBox(
                width: 88,
                height: 88,
                child: CustomPaint(
                  painter: _StampPainter(color: color, earned: earned),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          earned ? st.$1 : Icons.lock_outline_rounded,
                          color: color,
                          size: 30,
                        ),
                        if (earned && date != null)
                          Text(
                            '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              polo.nome,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: earned ? MP.ink : MP.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  _StampPainter({required this.color, required this.earned});
  final Color color;
  final bool earned;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    if (earned)
      canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: .08));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // anel interno tracejado
    final dash = Paint()
      ..color = color.withValues(alpha: earned ? .8 : .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    const n = 36;
    for (var i = 0; i < n; i += 2) {
      final a0 = i * 2 * math.pi / n, a1 = (i + 1) * 2 * math.pi / n;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - 7),
        a0,
        a1 - a0,
        false,
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StampPainter old) =>
      old.color != color || old.earned != earned;
}

class _PoloStamps extends StatelessWidget {
  const _PoloStamps({required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) {
    final first = <String, DateTime>{};
    for (final c in store.checkins.reversed) {
      first.putIfAbsent(c.polo, () => c.at);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Um carimbo no primeiro check-in de cada polo · ${first.length} de ${Content.polos.length}',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: MP.textSecondary),
        ),
        const SizedBox(height: MP.s4),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: MP.s4,
          crossAxisSpacing: MP.s3,
          childAspectRatio: .72,
          children: [
            for (final p in Content.polos)
              InkWell(
                borderRadius: BorderRadius.circular(MP.rLarge),
                onTap: () => openPolo(context, p),
                child: Stamp(
                  polo: p,
                  earned: first.containsKey(p.id),
                  date: first[p.id],
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
          '${got.length} de ${cities.length} cidades do programa',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: MP.textSecondary),
        ),
        const SizedBox(height: MP.s3),
        Wrap(
          spacing: MP.s2,
          runSpacing: MP.s2,
          children: [
            for (final c in cities)
              MpBadge(
                c,
                fg: got.contains(c) ? MP.success : MP.textSecondary,
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
  Widget build(BuildContext context) {
    final list = store.achievements;
    final done = list.where((a) => a.$3).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$done de ${list.length} conquistas',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: MP.textSecondary),
        ),
        const SizedBox(height: MP.s3),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: MP.s3,
          crossAxisSpacing: MP.s3,
          childAspectRatio: 1.15,
          children: [
            for (final a in list)
              Semantics(
                label: '${a.$2}: ${a.$3 ? 'conquistada' : 'bloqueada'}',
                child: Container(
                  padding: const EdgeInsets.all(MP.s4),
                  decoration: BoxDecoration(
                    color: MP.card,
                    borderRadius: BorderRadius.circular(MP.rLarge),
                    border: Border.all(
                      color: a.$3 ? const Color(0xffeccf73) : MP.borderSubtle,
                    ),
                    boxShadow: MP.shadowCard,
                  ),
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: a.$3
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xfff6d365),
                                      Color(0xffd4a017),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: a.$3 ? null : MP.soft,
                          ),
                          child: Icon(
                            a.$3 ? a.$1 : Icons.lock_outline_rounded,
                            color: a.$3 ? Colors.white : MP.textMuted,
                            size: MP.iconMd,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          a.$2,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: a.$3 ? MP.ink : MP.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: MP.s4),
        const MpNotice(
          'Níveis: Viajante (0), Explorador (500), Aventureiro (1.000) e Mestre (2.500 pontos). Check-in vale 50, cupom usado 20 e o primeiro check-in em cada polo, 100.',
        ),
      ],
    );
  }
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
      return const MpEmpty(
        icon: Icons.history_rounded,
        title: 'Nada por aqui ainda',
        message: 'Seu histórico aparece quando você fizer check-in, usar cupons ou reservar.',
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
