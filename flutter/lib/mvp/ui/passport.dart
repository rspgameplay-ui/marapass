import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'route_builder.dart' show MyRoutesScreen;
import 'scan.dart';
import 'common.dart';

/// Ícone e cor de cada polo nos carimbos (vetoriais: nítidos em qualquer tela).
const _poloStyle = <String, (IconData, Color)>{
  'lencois': (Icons.waves_rounded, Color(0xff1f6fd1)),
  'delta': (Icons.sailing_rounded, Color(0xff0f7a8a)),
  'chapada': (Icons.terrain_rounded, Color(0xffb4541f)),
  'saoluis': (Icons.account_balance_rounded, Color(0xff8a5a2b)),
  'munim': (Icons.kayaking_rounded, MP.green),
  'guaras': (Icons.flutter_dash_rounded, MP.error),
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
    return ColoredBox(
      color: MP.soft,
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s10),
        children: [
          MpHero(
            title: 'Meu passaporte',
            subtitle: 'Visite lugares, ganhe carimbos e pontos.',
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
                  onPressed: () => push<void>(context, const ScanScreen()),
                ),
                const SizedBox(height: MP.s3),
                MpListTile(
                  key: const Key('pass-routes'),
                  icon: Icons.route_rounded,
                  title: 'Minhas rotas',
                  subtitle: store.trips.isEmpty ? 'Monte seu passeio do seu jeito' : '${store.trips.length} ${store.trips.length == 1 ? 'rota salva' : 'rotas salvas'}',
                  tint: MP.tintGreen,
                  onTap: () => push<void>(context, const MyRoutesScreen()),
                ),
              ],
            ),
          ),
          const SizedBox(height: MP.s5),
          FilterChips<int>(
            options: const [0, 1, 2, 3],
            selected: _tab,
            label: (v) =>
                const ['Conquistas', 'Carimbos', 'Cidades', 'Extrato'][v],
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

/// Capa do passaporte em formato de bilhete: parte branca com nível e
/// progresso, estatísticas, e canhoto azul com os pontos e código de barras.
class _Cover extends StatelessWidget {
  const _Cover({required this.store, required this.progress});
  final AppStore store;
  final double progress;

  static const _blue = MP.ticket;
  static const _blueDark = MP.ticketDark;

  @override
  Widget build(BuildContext context) {
    final lv = store.level;
    final name = store.name ?? 'Viajante';
    final stamped = store.stampedPolos.length;
    final used = store.coupons.where((c) => c.used).length;
    return Semantics(
      label: 'Nível ${lv.$1}, ${store.points} pontos, $stamped de ${Content.polos.length} carimbos',
      child: Container(
        decoration: BoxDecoration(boxShadow: MP.shadowFloat),
        child: Column(
          children: [
            ClipPath(
              clipper: _TicketClipper(top: false),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(MP.s5, MP.s5, MP.s5, MP.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.explore_rounded, color: _blue, size: MP.iconLg),
                        const SizedBox(width: MP.s2),
                        const Expanded(
                          child: Text(
                            'PASSAPORTE\nMARAPASS',
                            style: TextStyle(color: MP.ink, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2, height: 1.2),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: MP.s3, vertical: 6),
                          decoration: BoxDecoration(color: _blueDark, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            lv.$1.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: .6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MP.s5),
                    const Text('Viajante', style: TextStyle(color: MP.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _blue, fontSize: 32, fontWeight: FontWeight.w800, height: 1.1),
                    ),
                    const SizedBox(height: MP.s4),
                    // "Rota" de nível: de onde está até o próximo
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(flex: 3, child: _Leg(label: 'Nível atual', value: lv.$1)),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(MP.s2, 0, MP.s2, 6),
                            child: LayoutBuilder(
                              builder: (_, c) {
                                final plane = Icon(Icons.flight_takeoff_rounded, color: _blue.withValues(alpha: .8), size: 22);
                                if (c.maxWidth < 64) return Center(child: plane);
                                return Row(
                                  children: [
                                    const Expanded(child: _Dashes()),
                                    const SizedBox(width: 6),
                                    plane,
                                    const SizedBox(width: 6),
                                    const Expanded(child: _Dashes()),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        Flexible(flex: 3, child: _Leg(label: 'Próximo nível', value: lv.$4 == null ? 'Máximo' : lv.$3 ?? '', end: true)),
                      ],
                    ),
                    const SizedBox(height: MP.s3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(MP.rPill),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 8,
                          backgroundColor: MP.ticketTrack,
                          valueColor: const AlwaysStoppedAnimation(_blue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lv.$4 == null ? 'Nível máximo alcançado' : 'Faltam ${lv.$4! - store.points} pts para ${lv.$3}',
                      style: const TextStyle(color: MP.textSecondary, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: MP.s4),
                    const Divider(height: 1, color: MP.border),
                    const SizedBox(height: MP.s3),
                    Row(
                      children: [
                        _Stat(label: 'Visitas', value: '${store.checkins.length}'),
                        const _StatDivider(),
                        _Stat(label: 'Carimbos', value: '$stamped/${Content.polos.length}'),
                        const _StatDivider(),
                        _Stat(label: 'Cupons', value: '$used'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 3),
            ClipPath(
              clipper: _TicketClipper(top: true),
              child: Container(
                color: _blue,
                padding: const EdgeInsets.fromLTRB(MP.s5, MP.s5, MP.s5, MP.s4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Seus pontos', style: TextStyle(color: MP.onBlueMuted, fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(
                            '${store.points}',
                            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, height: 1.1),
                          ),
                          const Text('pts acumulados', style: TextStyle(color: MP.onBlueMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 120,
                          height: 44,
                          child: CustomPaint(painter: _BarcodePainter(store.points + store.checkins.length * 7)),
                        ),
                        const SizedBox(height: 6),
                        const Text('Obrigado por viajar!', style: TextStyle(color: MP.onBlueMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Leg extends StatelessWidget {
  const _Leg({required this.label, required this.value, this.end = false});
  final String label, value;
  final bool end;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: MP.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: MP.ink, fontSize: 20, fontWeight: FontWeight.w800)),
    ],
  );
}

class _Dashes extends StatelessWidget {
  const _Dashes();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final n = (c.maxWidth / 8).floor().clamp(0, 40);
      if (n == 0) return const SizedBox.shrink();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(n, (_) => Container(width: 4, height: 2, color: const Color(0xffb7c6e6))),
      );
    },
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: const TextStyle(color: MP.ink, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: MP.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 32, color: MP.border);
}

/// Recorta o bilhete: cantos arredondados e meia-lua de cada lado na
/// "picotagem" (base da parte branca / topo do canhoto).
class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper({required this.top});
  final bool top;
  @override
  Path getClip(Size size) {
    const r = 18.0, n = 10.0;
    final rr = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: Radius.circular(top ? 0 : r),
      topRight: Radius.circular(top ? 0 : r),
      bottomLeft: Radius.circular(top ? r : 0),
      bottomRight: Radius.circular(top ? r : 0),
    );
    final base = Path()..addRRect(rr);
    final y = top ? 0.0 : size.height;
    final cut = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, y), radius: n))
      ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: n));
    return Path.combine(PathOperation.difference, base, cut);
  }

  @override
  bool shouldReclip(covariant _TicketClipper old) => old.top != top;
}

class _BarcodePainter extends CustomPainter {
  _BarcodePainter(this.seed);
  final int seed;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white;
    var x = 0.0, s = seed * 2654435761 % 4294967296;
    while (x < size.width) {
      s = (s * 1103515245 + 12345) % 2147483648;
      final w = 1.0 + (s % 3);
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), p);
      x += w + 1.5 + (s >> 4) % 3;
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter old) => old.seed != seed;
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
                              fontSize: 13,
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
    if (earned) {
      canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: .08));
    }
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
        if (store.missions.isNotEmpty) ...[
          const Text(
            'Próximas missões',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: MP.s2),
          for (final m in store.missions)
            Padding(
              padding: const EdgeInsets.only(bottom: MP.s2),
              child: Container(
                padding: const EdgeInsets.all(MP.s3),
                decoration: BoxDecoration(
                  color: MP.card,
                  borderRadius: BorderRadius.circular(MP.rLarge),
                  border: Border.all(color: MP.borderSubtle),
                ),
                child: Row(
                  children: [
                    Icon(m.$1, color: MP.navy),
                    const SizedBox(width: MP.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: m.$3 / m.$4,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: MP.s3),
                    Text(
                      '${m.$3}/${m.$4}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: MP.s4),
        ],
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
                                      MP.gold,
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
        MpNotice(
          store.remote != null
              ? 'Compras elegíveis geram 1 ponto por real inteiro confirmado. Estornos ajustam os pontos no extrato.'
              : 'Níveis: Viajante (0), Explorador (500), Aventureiro (1.000) e Mestre (2.500 pontos). Check-in vale 50, cupom usado 20 e o primeiro check-in em cada polo, 100.',
        ),
      ],
    );
  }
}

/// Lançamento do extrato do Passaporte.
class _Entry {
  const _Entry(this.at, this.icon, this.color, this.title, this.detail, this.points, this.ref, {this.status});
  final DateTime at;
  final IconData icon;
  final Color color;
  final String title, detail, ref;
  final int points;
  final String? status;
}

/// Extrato do Passaporte: visitas, carimbos e cupons usados com data, hora,
/// polo, pontos e saldo após cada lançamento (fecha com o saldo atual).
class _History extends StatefulWidget {
  const _History({required this.store});
  final AppStore store;
  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  int _days = 30; // 7, 30 ou 0 (tudo)

  List<(_Entry, int)> _ledger() {
    final store = widget.store;
    final out = <_Entry>[];
    final seenPolos = <String>{};
    final checkins = [...store.checkins]..sort((a, b) => a.at.compareTo(b.at));
    var n = 0;
    for (final c in checkins) {
      n++;
      final polo = Content.polo(c.polo).nome;
      out.add(_Entry(c.at, Icons.verified_rounded, MP.success, 'Visita: ${Content.item(c.itemId)?.titulo ?? 'Local'}', '${c.cidade} · $polo', 50, 'CK-${n.toString().padLeft(4, '0')}'));
      if (seenPolos.add(c.polo)) {
        out.add(_Entry(c.at.add(const Duration(seconds: 1)), Icons.workspace_premium_rounded, MP.goldText, 'Carimbo novo: $polo', 'Primeira visita no polo', 100, 'ST-${c.polo.toUpperCase()}'));
      }
    }
    for (final e in store.commercialPoints) {
      out.add(
        _Entry(
          DateTime.parse(e['at'] as String).toLocal(),
          Icons.receipt_long,
          MP.navy,
          '${e['kind'] == 'refund' ? 'Estorno' : 'Compra'}: ${e['title']}',
          'Compra com cupom',
          e['points'] as int,
          '${e['coupon_id']} · ${e['reference']}',
        ),
      );
    }
    for (final c in store.coupons.where((c) => c.sale == null && c.used)) {
      out.add(
        _Entry(
          c.usedAt!,
          Icons.local_activity_rounded,
          MP.navy,
          'Cupom usado: ${c.cupom?.parceiro ?? ''}',
          c.cupom?.beneficio ?? '',
          20,
          'CP-${c.code}',
        ),
      );
    }
    for (final r in store.myReservations) {
      out.add(_Entry(r.date, Icons.event_rounded, MP.textSecondary, 'Reserva: ${r.item?.titulo ?? ''}', r.period, 0, 'RS-${r.id.length > 6 ? r.id.substring(0, 6).toUpperCase() : r.id.toUpperCase()}', status: r.status.label));
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    var bal = 0;
    final withBal = [
      for (final e in out) (e, bal += e.points),
    ];
    return withBal.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = _ledger();
    final from = _days == 0 ? null : DateTime.now().subtract(Duration(days: _days));
    final rows = from == null ? all : all.where((r) => r.$1.at.isAfter(from) || r.$1.at.isAfter(DateTime.now())).toList();
    final earned = rows.fold<int>(0, (a, r) => a + r.$1.points);
    return Column(
      key: const Key('passport-ledger'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final d in const [7, 30, 0]) ...[
              ChoiceChip(
                key: Key('ledger-$d'),
                label: Text(d == 0 ? 'Tudo' : '$d dias'),
                selected: _days == d,
                showCheckmark: false,
                selectedColor: MP.navy,
                labelStyle: TextStyle(fontFamily: mpFont, fontWeight: FontWeight.w700, color: _days == d ? Colors.white : MP.ink),
                onSelected: (_) => setState(() => _days = d),
              ),
              const SizedBox(width: MP.s2),
            ],
          ],
        ),
        const SizedBox(height: MP.s3),
        MpCard(
          color: MP.soft,
          border: false,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_days == 0 ? 'Ganhos no total' : 'Ganhos em $_days dias', style: const TextStyle(fontSize: 13, color: MP.textSecondary)),
                    Text('+$earned pts', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: MP.success)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Saldo atual', style: TextStyle(fontSize: 13, color: MP.textSecondary)),
                  Text('${widget.store.points} pts', key: const Key('ledger-balance'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: MP.ink)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: MP.s3),
        if (rows.isEmpty)
          const MpEmpty(
            icon: Icons.receipt_long_rounded,
            title: 'Nenhum lançamento no período',
            message: 'Seu extrato mostra visitas, carimbos e cupons usados.',
          ),
        for (var k = 0; k < rows.length; k++) ...[
          if (k == 0 || !_sameDay(rows[k - 1].$1.at, rows[k].$1.at))
            Padding(
              padding: const EdgeInsets.only(top: MP.s3, bottom: MP.s2),
              child: Text(fmtDate(rows[k].$1.at), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: .6, color: MP.textSecondary)),
            ),
          _LedgerRow(entry: rows[k].$1, balance: rows[k].$2),
        ],
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, required this.balance});
  final _Entry entry;
  final int balance;
  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: MP.s3),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: MP.borderSubtle))),
      child: Row(
        children: [
          CircleAvatar(radius: 20, backgroundColor: e.color.withValues(alpha: .12), child: Icon(e.icon, color: e.color, size: 22)),
          const SizedBox(width: MP.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: MP.ink)),
                Text('${fmtTime(e.at)} · ${e.detail}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: MP.textSecondary)),
                Text('Ref. ${e.ref}', style: const TextStyle(fontSize: 13, color: MP.textMuted, letterSpacing: .4)),
              ],
            ),
          ),
          const SizedBox(width: MP.s2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (e.status != null)
                MpBadge(e.status!, fg: MP.textSecondary)
              else
                Text('+${e.points}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: MP.success)),
              Text('Saldo $balance', style: const TextStyle(fontSize: 13, color: MP.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
