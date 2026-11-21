import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/tourism.dart';
import '../../location/location_service.dart';
import '../data/content.dart';
import '../data/repository.dart';
import '../data/store.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'common.dart';
import 'scan.dart';
import 'shell.dart' show Tabs;

/// Coordenada real do item (sem o afastamento visual do mapa).
GeoPoint? itemAnchor(Item i) =>
    i.lat == null || i.lng == null ? null : GeoPoint(i.lat!, i.lng!);

/// Posição atual do aparelho. Substituível nos testes.
Future<GeoPoint> Function() checkinLocate = () async {
  final p = await LocationService().acquire().timeout(const Duration(seconds: 12));
  return GeoPoint(p.latitude, p.longitude);
};

String fmtMeters(double m) => m < 1000
    ? '${m.round()} m'
    : '${(m / 1000).toStringAsFixed(m < 10000 ? 1 : 0).replaceAll('.', ',')} km';

/// Código impresso na placa MaraPass do local: 4 letras do local e 2
/// caracteres de verificação (únicos por local, iguais em todo aparelho).
String plateCode(Item i) {
  final letters = i.id.replaceAll('-', '').toUpperCase();
  final head = (letters.length >= 4 ? letters.substring(0, 4) : letters.padRight(4, 'X'));
  var h = 2166136261;
  for (final u in i.id.codeUnits) {
    h = ((h ^ u) * 16777619) % 4294967296;
  }
  final tail = (h % 1296).toRadixString(36).toUpperCase().padLeft(2, '0');
  return 'MP-$head$tail';
}

Item? itemByPlate(String code) {
  final c = code.trim().toUpperCase();
  for (final i in Content.items) {
    if (plateCode(i) == c) return i;
  }
  return null;
}

/// Aba Check-in: registrar visita lendo a placa MaraPass ou confirmando que
/// está no local. Cada check-in vale pontos e o primeiro em cada polo dá um selo.
class CheckinScreen extends ConsumerWidget {
  const CheckinScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Scaffold(body: _body(context, ref));

  Widget _body(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s10),
        children: [
          MpHeader(
            tr('Registrar visita'),
            back: true,
            subtitle:
                tr('Faça check-in nos lugares que visitar e ganhe pontos e selos.'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(MP.s5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [MP.green, MP.navy]),
                    borderRadius: BorderRadius.circular(MP.rXl),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 72,
                        color: Colors.white,
                      ),
                      const SizedBox(height: MP.s3),
                      Text(
                        tr('Escanear QR Code'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: MP.s1),
                      Text(
                        tr('Aponte a câmera para a placa MaraPass no balcão ou na entrada do local.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: MP.s4),
                      MpCtaButton(
                        key: const Key('checkin-plate'),
                        label: tr('Abrir leitor'),
                        icon: Icons.qr_code_scanner_rounded,
                        onPressed: () =>
                            push<void>(context, const ScanScreen()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MP.s4),
                MpListTile(
                  key: const Key('checkin-here'),
                  icon: Icons.my_location_rounded,
                  title: tr('Estou no local'),
                  subtitle: tr('Escolha o lugar e confirme pela localização'),
                  tint: MP.tintGreen,
                  color: MP.green,
                  onTap: () => push<void>(context, const PickPlaceScreen()),
                ),
                const SizedBox(height: MP.s2),
                MpListTile(
                  icon: Icons.badge_rounded,
                  title: tr('Ver meu passaporte'),
                  subtitle:
                      '${store.points} ${tr('pontos')} · ${store.stampedPolos.length} ${tr('de')} ${Content.polos.length} ${tr('selos')}',
                  tint: MP.tintYellow,
                  color: MP.goldText,
                  onTap: () =>
                      ref.read(shellTabProvider.notifier).go(Tabs.passaporte),
                ),
                const SizedBox(height: MP.sectionGap),
                MpSectionTitle(tr('Visitas recentes')),
                const SizedBox(height: MP.s3),
                if (store.checkins.isEmpty)
                  MpCard(
                    color: MP.soft,
                    child: Text(
                      tr('Você ainda não registrou visitas. Que tal começar hoje?'),
                      style: TextStyle(fontSize: 16, color: MP.textSecondary),
                    ),
                  ),
                for (final c in store.checkins.take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: MP.s2),
                    child: MpListTile(
                      icon: Icons.verified_rounded,
                      tint: MP.successBg,
                      color: MP.success,
                      title: Content.item(c.itemId)?.titulo ?? tr('Visita'),
                      subtitle:
                          '${c.cidade} · ${fmtDate(c.at)}${c.rating > 0 ? ' · ${'★' * c.rating}' : ''}',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Estou no local": escolher o lugar, do mais perto para o mais longe
/// (distância real pelo GPS; sem GPS, a ordem do catálogo).
class PickPlaceScreen extends StatefulWidget {
  const PickPlaceScreen({super.key});
  @override
  State<PickPlaceScreen> createState() => _PickPlaceState();
}

class _PickPlaceState extends State<PickPlaceScreen> {
  GeoPoint? _me;
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    checkinLocate().then((p) {
      if (mounted) setState(() => _me = p);
    }).catchError((Object _) {}).whenComplete(() {
      if (mounted) setState(() => _locating = false);
    });
  }

  double? _dist(Item i) {
    final a = itemAnchor(i), me = _me;
    return a == null || me == null ? null : me.distanceKm(a) * 1000;
  }

  @override
  Widget build(BuildContext context) {
    final list = Content.items
        .where((i) => i.cat != Cat.transporte && i.cat != Cat.fotografia && i.cat != Cat.artesanato)
        .toList()
      ..sort((a, b) => (_dist(a) ?? (a.distanciaKm ?? 999) * 1e6).compareTo(_dist(b) ?? (b.distanciaKm ?? 999) * 1e6));
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            MpHeader(
              tr('Onde você está?'),
              subtitle: _me != null
                  ? tr('Lugares mais próximos de você primeiro.')
                  : (_locating ? tr('Buscando sua localização…') : tr('Sem localização: escolha o lugar na lista.')),
            ),
            for (final i in list)
              Padding(
                padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s2),
                child: MpListTile(
                  icon: i.cat.icon,
                  tint: i.cat.tint.bg,
                  color: i.cat.tint.fg,
                  title: i.titulo,
                  subtitle: '${i.cidade}${_dist(i) != null ? ' · a ${fmtMeters(_dist(i)!)}' : ''}',
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(builder: (_) => CheckinFlowScreen(item: i)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fluxo de check-in: permissão → verificação → sucesso → avaliação.
class CheckinFlowScreen extends ConsumerStatefulWidget {
  const CheckinFlowScreen({
    super.key,
    required this.item,
    this.viaPlate = false,
  });
  final Item item;
  final bool viaPlate;
  @override
  ConsumerState<CheckinFlowScreen> createState() => _FlowState();
}

enum _Step { permission, checking, done, already, far, noGps }

class _FlowState extends ConsumerState<CheckinFlowScreen> {
  late _Step _step;
  Checkin? _c;
  bool _newStamp = false;
  int _stars = 0;
  double? _distance;
  GeoPoint? _me;

  @override
  void initState() {
    super.initState();
    final store = ref.read(appStoreProvider);
    _step = store.alreadyCheckedIn(widget.item.id)
        ? _Step.already
        : (widget.viaPlate ? _Step.checking : _Step.permission);
    if (_step == _Step.checking) _check();
  }

  Future<void> _check() async {
    setState(() => _step = _Step.checking);
    if (widget.viaPlate) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
    } else {
      // Confirma pelo GPS que a pessoa está perto do local de verdade.
      final anchor = itemAnchor(widget.item);
      GeoPoint me;
      try {
        me = await checkinLocate();
      } catch (_) {
        if (mounted) setState(() => _step = _Step.noGps);
        return;
      }
      if (!mounted) return;
      if (anchor != null) {
        _distance = me.distanceKm(anchor) * 1000;
        if (_distance! > widget.item.loc.checkinRadiusM) {
          setState(() => _step = _Step.far);
          return;
        }
      }
      _me = me;
    }
    if (!mounted) return;
    final store = ref.read(appStoreProvider);
    _newStamp = !store.stampedPolos.contains(widget.item.polo);
    try {
      _c = await store.checkInAsync(widget.item, method: 'gps', lat: _me?.lat, lng: _me?.lng);
    } catch (e) {
      if (!mounted) return;
      showMpSnack(
        context,
        e is MvpException
            ? e.message
            : tr('Não foi possível registrar agora. Tente de novo.'),
      );
      Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    setState(() => _step = _Step.done);
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    switch (_step) {
      case _Step.already:
        return MpStatusScreen(
          icon: Icons.verified_rounded,
          color: MP.info,
          bg: MP.infoBg,
          title: tr('Visita já registrada hoje'),
          message:
              '${tr('Você já fez check-in em')} ${i.titulo} ${tr('hoje. Volte amanhã ou visite outro lugar')}.',
          primaryLabel: tr('Ver meu passaporte'),
          onPrimary: () {
            ref.read(shellTabProvider.notifier).go(Tabs.passaporte);
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
        );
      case _Step.far:
        return MpStatusScreen(
          icon: Icons.wrong_location_rounded,
          color: MP.warning,
          bg: MP.warningBg,
          title: tr('Você ainda não está no local'),
          message:
              '${tr('Sua localização está a')} ${fmtMeters(_distance!)} ${tr('de')} ${i.titulo}. ${tr('O check-in vale a até')} ${fmtMeters(i.loc.checkinRadiusM)} ${tr('do local. Se você já está lá, leia o QR da placa MaraPass')}.',
          primaryLabel: tr('Ler QR da placa'),
          onPrimary: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const ScanScreen()),
          ),
          secondaryLabel: tr('Tentar de novo'),
          onSecondary: _check,
        );
      case _Step.noGps:
        return MpStatusScreen(
          icon: Icons.location_off_rounded,
          color: MP.warning,
          bg: MP.warningBg,
          title: tr('Não conseguimos sua localização'),
          message:
              tr('Permita a localização no navegador ou no aparelho e tente de novo. Você também pode registrar a visita lendo o QR da placa MaraPass.'),
          primaryLabel: tr('Ler QR da placa'),
          onPrimary: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const ScanScreen()),
          ),
          secondaryLabel: tr('Tentar de novo'),
          onSecondary: _check,
        );
      case _Step.permission:
        return MpStatusScreen(
          icon: Icons.location_on_rounded,
          color: MP.navy,
          bg: MP.tintBlue,
          title: tr('Precisamos confirmar que você está lá'),
          message:
              '${tr('Vamos usar a sua localização só agora, para registrar a visita em')} ${i.titulo}. ${tr('Ela não fica salva')}.',
          primaryLabel: tr('Permitir e continuar'),
          onPrimary: _check,
          secondaryLabel: tr('Agora não'),
          onSecondary: () => Navigator.of(context).pop(),
        );
      case _Step.checking:
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    color: MP.green,
                  ),
                ),
                const SizedBox(height: MP.s5),
                Text(
                  widget.viaPlate
                      ? tr('Placa reconhecida')
                      : tr('Verificando localização…'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: MP.s2),
                Text(i.titulo, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        );
      case _Step.done:
        final polo = Content.polo(i.polo);
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(MP.pageH),
              children: [
                const SizedBox(height: MP.s5),
                const _Confetti(),
                Text(
                  tr('Visita registrada!'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: MP.s2),
                Text(
                  i.titulo,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: MP.s4),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: MP.s2,
                  runSpacing: MP.s2,
                  children: [
                    MpBadge(
                      tr('+50 pontos'),
                      fg: MP.success,
                      icon: Icons.add_circle_rounded,
                    ),
                    if (_newStamp)
                      MpBadge(
                        '${tr('Novo selo')}: ${polo.nome} (+100)',
                        fg: MP.goldText,
                        bg: MP.goldBg,
                        icon: Icons.workspace_premium_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: MP.sectionGap),
                Text(
                  tr('Como foi a experiência?'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: MP.s2),
                StarRating(
                  value: _stars,
                  onChanged: (v) {
                    setState(() => _stars = v);
                    if (_c != null) {
                      ref.read(appStoreProvider).rateAsync(_c!, v);
                    }
                  },
                ),
                if (_stars > 0)
                  Text(
                    [
                      '',
                      tr('Que pena. Vamos avisar o parceiro.'),
                      tr('Obrigado pela sinceridade.'),
                      tr('Obrigado! Bom saber.'),
                      tr('Que bom que gostou!'),
                      tr('Maravilha! Obrigado!'),
                    ][_stars],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MP.textSecondary,
                    ),
                  ),
                const SizedBox(height: MP.s3),
                Text(
                  tr('Sua avaliação é vista pela gestão do programa.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MP.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: MP.sectionGap),
                FilledButton(
                  key: const Key('checkin-to-passport'),
                  onPressed: () {
                    ref.read(shellTabProvider.notifier).go(Tabs.passaporte);
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: Text(tr('Ver meu passaporte')),
                ),
                const SizedBox(height: MP.s3),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr('Voltar')),
                ),
              ],
            ),
          ),
        );
    }
  }
}

class _Confetti extends StatefulWidget {
  const _Confetti();
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 150,
    child: AnimatedBuilder(
      animation: _a,
      builder: (_, _) => CustomPaint(
        painter: _ConfettiPainter(_a.value),
        child: Center(
          child: Transform.scale(
            scale: Curves.elasticOut.transform(_a.value.clamp(0, 1)),
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: MP.successBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: MP.success,
                size: 60,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);
  final double t;
  static const _colors = [MP.green, MP.yellow, MP.error, MP.navy, MP.info];
  @override
  void paint(Canvas canvas, Size size) {
    final r = Random(7);
    for (var k = 0; k < 40; k++) {
      final angle = r.nextDouble() * pi * 2;
      final dist = (40 + r.nextDouble() * 120) * Curves.easeOut.transform(t);
      final o = Offset(
        size.width / 2 + cos(angle) * dist,
        size.height / 2 + sin(angle) * dist + t * 30,
      );
      canvas.drawRect(
        Rect.fromCenter(center: o, width: 8, height: 5),
        Paint()
          ..color = _colors[k % _colors.length].withValues(alpha: 1 - t * .7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
