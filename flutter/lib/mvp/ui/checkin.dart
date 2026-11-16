import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content.dart';
import '../data/repository.dart';
import '../data/store.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'common.dart';

/// Código impresso na placa MaraPass do local (demonstração).
String plateCode(Item i) =>
    'MP-${i.id.replaceAll('-', '').toUpperCase().substring(0, min(6, i.id.replaceAll('-', '').length))}';

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
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s10),
        children: [
          const MpHeader(
            'Registrar visita',
            back: false,
            subtitle:
                'Faça check-in nos lugares que visitar e ganhe pontos e selos.',
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
                      const Text(
                        'Ler placa MaraPass',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: MP.s1),
                      const Text(
                        'Procure a placa no balcão ou na entrada do local.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: MP.s4),
                      MpCtaButton(
                        key: const Key('checkin-plate'),
                        label: 'Ler placa',
                        icon: Icons.photo_camera_rounded,
                        onPressed: () =>
                            push<void>(context, const PlateScreen()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MP.s4),
                MpListTile(
                  key: const Key('checkin-here'),
                  icon: Icons.my_location_rounded,
                  title: 'Estou no local',
                  subtitle: 'Escolha o lugar e confirme pela localização',
                  tint: MP.tintGreen,
                  color: MP.green,
                  onTap: () => push<void>(context, const PickPlaceScreen()),
                ),
                const SizedBox(height: MP.s2),
                MpListTile(
                  icon: Icons.badge_rounded,
                  title: 'Ver meu passaporte',
                  subtitle:
                      '${store.points} pontos · ${store.stampedPolos.length} de ${Content.polos.length} selos',
                  tint: MP.tintYellow,
                  color: const Color(0xffa87b00),
                  onTap: () => ref.read(shellTabProvider.notifier).go(4),
                ),
                const SizedBox(height: MP.sectionGap),
                const MpSectionTitle('Visitas recentes'),
                const SizedBox(height: MP.s3),
                if (store.checkins.isEmpty)
                  const MpCard(
                    color: MP.soft,
                    child: Text(
                      'Você ainda não registrou visitas. Que tal começar hoje?',
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
                      title: Content.item(c.itemId)?.titulo ?? 'Visita',
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

/// Leitura da placa. Na web de teste, o turista digita o código impresso
/// abaixo do QR (a câmera entra na versão instalada).
class PlateScreen extends ConsumerStatefulWidget {
  const PlateScreen({super.key});
  @override
  ConsumerState<PlateScreen> createState() => _PlateScreenState();
}

class _PlateScreenState extends ConsumerState<PlateScreen> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _go() {
    final it = itemByPlate(_ctrl.text);
    if (it == null) {
      setState(
        () => _error = 'Não reconhecemos este código. Confira as letras impressas embaixo do QR da placa.',
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CheckinFlowScreen(item: it, viaPlate: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s8),
        children: [
          const MpHeader(
            'Ler placa MaraPass',
            subtitle: 'Digite o código impresso embaixo do QR da placa.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: MP.ink,
                    borderRadius: BorderRadius.circular(MP.rXl),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: MP.yellow, width: 4),
                          borderRadius: BorderRadius.circular(MP.rLarge),
                        ),
                      ),
                      const Positioned(
                        bottom: 14,
                        child: Text(
                          'A câmera abre na versão instalada do app',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MP.s5),
                TextField(
                  key: const Key('plate-code'),
                  controller: _ctrl,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                    LengthLimitingTextInputFormatter(12),
                  ],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Código da placa',
                    hintText: 'MP-XXXXXX',
                  ),
                  onSubmitted: (_) => _go(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: MP.s3),
                  MpNotice(
                    _error!,
                    icon: Icons.error_outline_rounded,
                    fg: MP.error,
                    bg: MP.errorBg,
                  ),
                ],
                const SizedBox(height: MP.s4),
                FilledButton(
                  key: const Key('plate-submit'),
                  onPressed: _go,
                  child: const Text('Confirmar código'),
                ),
                const SizedBox(height: MP.s4),
                MpNotice.demo(
                  'Demonstração: experimente o código ${plateCode(Content.items.first)} (${Content.items.first.titulo}).',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// "Estou no local": escolher o lugar.
class PickPlaceScreen extends StatelessWidget {
  const PickPlaceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final list =
        Content.items
            .where(
              (i) =>
                  i.cat != Cat.transporte &&
                  i.cat != Cat.fotografia &&
                  i.cat != Cat.artesanato,
            )
            .toList()
          ..sort(
            (a, b) => (a.distanciaKm ?? 999).compareTo(b.distanciaKm ?? 999),
          );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            const MpHeader(
              'Onde você está?',
              subtitle: 'Lugares mais próximos primeiro.',
            ),
            for (final i in list)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MP.pageH,
                  0,
                  MP.pageH,
                  MP.s2,
                ),
                child: MpListTile(
                  icon: i.cat.icon,
                  tint: i.cat.tint.bg,
                  color: i.cat.tint.fg,
                  title: i.titulo,
                  subtitle:
                      '${i.cidade}${i.distanciaKm != null ? ' · ${i.distanciaKm!.round()} km' : ''}',
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => CheckinFlowScreen(item: i),
                    ),
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

enum _Step { permission, checking, done, already }

class _FlowState extends ConsumerState<CheckinFlowScreen> {
  late _Step _step;
  Checkin? _c;
  bool _newStamp = false;
  int _stars = 0;

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
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final store = ref.read(appStoreProvider);
    _newStamp = !store.stampedPolos.contains(widget.item.polo);
    try {
      _c = await store.checkInAsync(widget.item);
    } catch (e) {
      if (!mounted) return;
      showMpSnack(
        context,
        e is MvpException
            ? e.message
            : 'Não foi possível registrar agora. Tente de novo.',
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
          title: 'Visita já registrada hoje',
          message:
              'Você já fez check-in em ${i.titulo} hoje. Volte amanhã ou visite outro lugar.',
          primaryLabel: 'Ver meu passaporte',
          onPrimary: () {
            ref.read(shellTabProvider.notifier).go(4);
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
        );
      case _Step.permission:
        return MpStatusScreen(
          icon: Icons.location_on_rounded,
          color: MP.navy,
          bg: MP.tintBlue,
          title: 'Precisamos confirmar que você está lá',
          message:
              'Vamos usar a sua localização só agora, para registrar a visita em ${i.titulo}. Ela não fica salva.',
          primaryLabel: 'Permitir e continuar',
          onPrimary: _check,
          secondaryLabel: 'Agora não',
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
                      ? 'Placa reconhecida'
                      : 'Verificando localização…',
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
                  'Visita registrada!',
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
                    const MpBadge(
                      '+50 pontos',
                      fg: MP.success,
                      icon: Icons.add_circle_rounded,
                    ),
                    if (_newStamp)
                      MpBadge(
                        'Novo selo: ${polo.nome} (+100)',
                        fg: const Color(0xffa87b00),
                        bg: MP.goldBg,
                        icon: Icons.workspace_premium_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: MP.sectionGap),
                Text(
                  'Como foi a experiência?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: MP.s2),
                StarRating(
                  value: _stars,
                  onChanged: (v) {
                    setState(() => _stars = v);
                    if (_c != null)
                      ref.read(appStoreProvider).rateAsync(_c!, v);
                  },
                ),
                if (_stars > 0)
                  Text(
                    const [
                      '',
                      'Que pena. Vamos avisar o parceiro.',
                      'Obrigado pela sinceridade.',
                      'Obrigado! Bom saber.',
                      'Que bom que gostou!',
                      'Maravilha! Obrigado!',
                    ][_stars],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MP.textSecondary,
                    ),
                  ),
                const SizedBox(height: MP.s3),
                const Text(
                  'Sua avaliação é vista pela gestão do programa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MP.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: MP.sectionGap),
                FilledButton(
                  key: const Key('checkin-to-passport'),
                  onPressed: () {
                    ref.read(shellTabProvider.notifier).go(4);
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: const Text('Ver meu passaporte'),
                ),
                const SizedBox(height: MP.s3),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Voltar'),
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
      builder: (_, __) => CustomPaint(
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
