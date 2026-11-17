import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide GeoPoint;

import '../../location/location_service.dart';
import '../../domain/tourism.dart';
import '../data/content.dart';
import '../data/repository.dart';
import '../data/store.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'checkin.dart';
import 'coupons.dart';
import 'shell.dart' show Tabs;

/// O que o QR lido representa.
sealed class ScanResult {
  const ScanResult();
}

class PlateScan extends ScanResult {
  const PlateScan(this.item, [this.token]);
  final Item item;

  /// Token secreto impresso só no QR da placa física (sem ele, o servidor
  /// pede a localização).
  final String? token;
}

class OfferScan extends ScanResult {
  const OfferScan(this.cupom);
  final Cupom cupom;
}

/// Interpreta o conteúdo de um QR MaraPass: placa do local (MP-XXXXXX, com ou
/// sem o prefixo marapass:plate:) ou oferta de parceiro (marapass:offer:ID).
ScanResult? parseScan(String raw) {
  final t = raw.trim();
  final offer = RegExp(r'marapass:offer:([\w:-]+)', caseSensitive: false).firstMatch(t);
  if (offer != null) {
    final c = Content.cupom(offer.group(1));
    return c == null ? null : OfferScan(c);
  }
  final plate = RegExp(r'(MP-[A-Z0-9]{2,6})(?::([0-9a-f]{12,64}))?', caseSensitive: false).firstMatch(t);
  if (plate != null) {
    final i = itemByPlate(plate.group(1)!);
    if (i != null) return PlateScan(i, plate.group(2)?.toLowerCase());
  }
  return null;
}

/// Leitura de QR em tela cheia, no padrão de carteira digital: visor central
/// iluminado, controles da câmera bem espaçados e digitação manual como
/// alternativa quando a câmera não está disponível.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  /// Desligado nos testes de widget, onde não existe câmera.
  static bool useCamera = true;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> with SingleTickerProviderStateMixin {
  MobileScannerController? _cam;
  late final AnimationController _line = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  bool _busy = false;
  bool _handling = false;
  bool _torch = false;
  String? _camError;

  @override
  void initState() {
    super.initState();
    if (ScanScreen.useCamera) {
      _line.repeat(reverse: true);
      _cam = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, formats: const [BarcodeFormat.qrCode]);
    } else {
      _camError = 'Câmera indisponível neste aparelho.';
    }
  }

  @override
  void dispose() {
    _line.dispose();
    _cam?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    for (final b in cap.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        _handle(v);
        return;
      }
    }
  }

  Future<void> _handle(String raw) async {
    if (_handling) return;
    final r = parseScan(raw);
    if (r == null) {
      HapticFeedback.heavyImpact();
      showMpSnack(
        context,
        raw.contains('marapass:offer:')
            ? 'Esta oferta não está mais ativa. Veja as ofertas disponíveis em Cupons.'
            : 'Este QR não é de um local MaraPass. Procure a placa no balcão ou na entrada.',
      );
      return;
    }
    _handling = true;
    HapticFeedback.mediumImpact();
    unawaited(_cam?.stop());
    switch (r) {
      case PlateScan(:final item, :final token):
        await _checkin(item, token);
      case OfferScan(:final cupom):
        await _offer(cupom);
    }
    _handling = false;
    if (!mounted) return;
    unawaited(_cam?.start());
  }

  Future<void> _checkin(Item item, String? token) async {
    final store = ref.read(appStoreProvider);
    if (store.alreadyCheckedIn(item.id)) {
      await _sheet(_ResultSheet.already(item: item));
      return;
    }
    final newStamp = !store.stampedPolos.contains(item.polo);
    Checkin c;
    setState(() => _busy = true);
    try {
      if (token != null || !store.online) {
        c = await store.checkInAsync(item, method: 'placa', token: token);
      } else {
        // Código digitado: o servidor confere pela localização.
        final GeoPoint me;
        try {
          me = await checkinLocate();
        } catch (_) {
          throw const LocationFailure(LocationProblem.unavailable, 'sem GPS');
        }
        c = await store.checkInAsync(item, method: 'codigo', lat: me.lat, lng: me.lng);
      }
    } on LocationFailure {
      if (mounted) setState(() => _busy = false);
      if (mounted) showMpSnack(context, 'Código digitado precisa da sua localização. Permita o GPS ou leia o QR da placa.');
      return;
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      if (mounted) showMpSnack(context, e is MvpException ? e.message : 'Não foi possível registrar agora. Tente de novo.');
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _sheet(_ResultSheet.stamp(item: item, checkin: c, newStamp: newStamp));
  }

  Future<void> _offer(Cupom cupom) => _sheet(_ResultSheet.offer(cupom: cupom));

  Future<void> _sheet(Widget child) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: MP.card,
    builder: (_) => child,
  );

  Future<void> _manual() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ManualSheet(),
    );
    if (code != null && mounted) await _handle(code);
  }

  Future<void> _toggleTorch() async {
    if (_cam == null || _camError != null) {
      showMpSnack(context, 'Lanterna indisponível sem a câmera.');
      return;
    }
    try {
      await _cam!.toggleTorch();
      setState(() => _torch = !_torch);
    } catch (_) {
      if (mounted) showMpSnack(context, 'Este aparelho não tem lanterna disponível.');
    }
  }

  Future<void> _switch() async {
    if (_cam == null || _camError != null) {
      showMpSnack(context, 'Câmera indisponível neste aparelho.');
      return;
    }
    try {
      await _cam!.switchCamera();
    } catch (_) {
      if (mounted) showMpSnack(context, 'Só há uma câmera disponível.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final box = math.min(size.width * .7, 280.0);
    final top = pad.top + 150;
    final frame = Rect.fromLTWH((size.width - box) / 2, top, box, box);
    return Scaffold(
      key: const Key('scan-screen'),
      backgroundColor: const Color(0xff07121f),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            Positioned.fill(
              child: _cam != null && _camError == null
                  ? MobileScanner(
                      controller: _cam,
                      onDetect: _onDetect,
                      errorBuilder: (context, error) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _camError == null) {
                            setState(() => _camError = error.errorCode == MobileScannerErrorCode.permissionDenied
                                ? 'Permita o uso da câmera nas configurações do navegador.'
                                : 'Não foi possível abrir a câmera.');
                          }
                        });
                        return const ColoredBox(color: Color(0xff07121f));
                      },
                    )
                  : const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xff0b2741), Color(0xff07121f)],
                        ),
                      ),
                    ),
            ),
            // Escurece tudo em volta do visor
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _ViewfinderPainter(frame)),
              ),
            ),
            // Linha de leitura animada
            Positioned.fromRect(
              rect: frame.deflate(18),
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _line,
                  builder: (_, __) => Align(
                    alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(_line.value)),
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: [MP.yellow.withValues(alpha: 0), MP.yellow, MP.yellow.withValues(alpha: 0)],
                        ),
                        boxShadow: [BoxShadow(color: MP.yellow.withValues(alpha: .6), blurRadius: 12)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_camError != null)
              Positioned.fromRect(
                rect: frame.deflate(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.no_photography_rounded, color: Colors.white70, size: 40),
                    const SizedBox(height: MP.s2),
                    Text(
                      _camError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            if (_busy)
              Positioned.fromRect(
                rect: frame,
                child: const Center(child: CircularProgressIndicator(color: MP.yellow)),
              ),
            // Cabeçalho
            Positioned(
              left: MP.pageH,
              right: MP.s3,
              top: pad.top + MP.s3,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: MP.s2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Escanear QR Code do Local',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
                          ),
                          SizedBox(height: MP.s2),
                          Text(
                            'Aponte a câmera para o código do estabelecimento para ganhar seu carimbo ou ativar o cupom.',
                            style: TextStyle(color: Color(0xffc9d6e3), fontSize: 15, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: MP.s2),
                  _GlassButton(
                    key: const Key('scan-close'),
                    icon: Icons.close_rounded,
                    tooltip: 'Fechar',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            // Controles da câmera
            Positioned(
              left: 0,
              right: 0,
              top: frame.bottom + MP.s6,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: size.width - 2 * MP.pageH),
                  child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(MP.rPill),
                    border: Border.all(color: Colors.white.withValues(alpha: .18)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: MP.s2, vertical: MP.s1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CamControl(
                          key: const Key('scan-torch'),
                          icon: _torch ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                          label: _torch ? 'Lanterna ligada' : 'Lanterna',
                          active: _torch,
                          onTap: _toggleTorch,
                        ),
                        Container(width: 1, height: 28, color: Colors.white24),
                        Flexible(child: _CamControl(
                          key: const Key('scan-switch'),
                          icon: Icons.cameraswitch_rounded,
                          label: 'Trocar câmera',
                          onTap: _switch,
                        )),
                      ],
                    ),
                  ),
                ),
                ),
              ),
            ),
            // Base: alternativa manual
            Positioned(
              left: MP.pageH,
              right: MP.pageH,
              bottom: pad.bottom + MP.s5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    key: const Key('scan-manual'),
                    onPressed: _busy ? null : _manual,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: MP.ink,
                      minimumSize: const Size.fromHeight(MP.buttonHeight),
                    ),
                    icon: const Icon(Icons.keyboard_rounded),
                    label: const Text('Digitar código manualmente'),
                  ),
                  // Simulação só sem conta: logado, o servidor exige a placa real.
                  if (!ref.watch(appStoreProvider).online) ...[
                  const SizedBox(height: MP.s1),
                  TextButton(
                    key: const Key('scan-simulate'),
                    onPressed: _busy ? null : () => _handle(plateCode(Content.items.first)),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xffc9d6e3)),
                    child: const Text('Simular leitura (demonstração)'),
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

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter(this.frame);
  final Rect frame;
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(frame, const Radius.circular(28));
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(r);
    canvas.drawPath(shade, Paint()..color = const Color(0xb3061220));
    canvas.drawRRect(r, Paint()
      ..color = Colors.white.withValues(alpha: .25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
    // Cantos iluminados na cor de destaque
    const len = 34.0, rad = 28.0;
    final glow = Paint()
      ..color = MP.yellow.withValues(alpha: .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final line = Paint()
      ..color = MP.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (final p in [glow, line]) {
      final l = frame.left, t = frame.top, rr = frame.right, b = frame.bottom;
      canvas.drawPath(
        Path()
          ..moveTo(l, t + rad + len)
          ..lineTo(l, t + rad)
          ..arcToPoint(Offset(l + rad, t), radius: const Radius.circular(rad))
          ..lineTo(l + rad + len, t),
        p,
      );
      canvas.drawPath(
        Path()
          ..moveTo(rr - rad - len, t)
          ..lineTo(rr - rad, t)
          ..arcToPoint(Offset(rr, t + rad), radius: const Radius.circular(rad))
          ..lineTo(rr, t + rad + len),
        p,
      );
      canvas.drawPath(
        Path()
          ..moveTo(rr, b - rad - len)
          ..lineTo(rr, b - rad)
          ..arcToPoint(Offset(rr - rad, b), radius: const Radius.circular(rad))
          ..lineTo(rr - rad - len, b),
        p,
      );
      canvas.drawPath(
        Path()
          ..moveTo(l + rad + len, b)
          ..lineTo(l + rad, b)
          ..arcToPoint(Offset(l, b - rad), radius: const Radius.circular(rad))
          ..lineTo(l, b - rad - len),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter old) => old.frame != frame;
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({super.key, required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.white.withValues(alpha: .16),
      shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: .22))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(width: 52, height: 48, child: Icon(icon, color: Colors.white, semanticLabel: tooltip)),
      ),
    ),
  );
}

class _CamControl extends StatelessWidget {
  const _CamControl({super.key, required this.icon, required this.label, required this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(MP.rPill),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MP.s3, vertical: MP.s2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? MP.yellow : Colors.white, size: 22),
            const SizedBox(width: MP.s2),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: active ? MP.yellow : Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ManualSheet extends StatefulWidget {
  const _ManualSheet();
  @override
  State<_ManualSheet> createState() => _ManualSheetState();
}

class _ManualSheetState extends State<_ManualSheet> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _go() {
    if (parseScan(_ctrl.text) == null) {
      setState(() => _error = 'Não reconhecemos este código. Confira as letras impressas embaixo do QR da placa.');
      return;
    }
    Navigator.of(context).pop(_ctrl.text);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s6 + MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Digitar código', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: MP.s1),
        const Text('Use o código impresso embaixo do QR da placa MaraPass.', style: TextStyle(fontSize: 15, color: MP.textSecondary)),
        const SizedBox(height: MP.s4),
        TextField(
          key: const Key('plate-code'),
          controller: _ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9:-]')),
            LengthLimitingTextInputFormatter(40),
          ],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 3),
          decoration: const InputDecoration(labelText: 'Código da placa', hintText: 'MP-XXXXXX'),
          onSubmitted: (_) => _go(),
        ),
        if (_error != null) ...[
          const SizedBox(height: MP.s3),
          MpNotice(_error!, icon: Icons.error_outline_rounded, fg: MP.error, bg: MP.errorBg),
        ],
        const SizedBox(height: MP.s4),
        MpPrimaryButton(key: const Key('plate-submit'), label: 'Confirmar código', onPressed: _go),
        const SizedBox(height: MP.s3),
        MpNotice.demo('Demonstração: experimente ${plateCode(Content.items.first)} (${Content.items.first.titulo}).'),
      ],
    ),
  );
}

/// Resultado da leitura em folha animada: carimbo conquistado, visita já
/// registrada ou oferta para ativar.
class _ResultSheet extends ConsumerStatefulWidget {
  const _ResultSheet.stamp({required this.item, required this.checkin, required this.newStamp}) : cupom = null, already = false;
  const _ResultSheet.already({required this.item}) : checkin = null, newStamp = false, cupom = null, already = true;
  const _ResultSheet.offer({required this.cupom}) : item = null, checkin = null, newStamp = false, already = false;
  final Item? item;
  final Checkin? checkin;
  final bool newStamp, already;
  final Cupom? cupom;
  @override
  ConsumerState<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends ConsumerState<_ResultSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  int _stars = 0;

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _toPassport() {
    ref.read(shellTabProvider.notifier).go(Tabs.passaporte);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final cupom = widget.cupom;
    final item = widget.item;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedBuilder(
              animation: _a,
              builder: (_, child) {
                final t = Curves.elasticOut.transform(_a.value.clamp(0, 1));
                return Transform.rotate(angle: (1 - t) * -.5, child: Transform.scale(scale: .4 + .6 * t, child: child));
              },
              child: Center(child: _StampBadge(cupom: cupom, already: widget.already)),
            ),
            const SizedBox(height: MP.s4),
            if (cupom != null) ...[
              Text('Oferta encontrada', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: MP.s1),
              Text('${cupom.beneficio} · ${cupom.parceiro}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, color: MP.text)),
              const SizedBox(height: MP.s4),
              MpPrimaryButton(
                key: const Key('scan-offer-open'),
                label: 'Ativar cupom',
                icon: Icons.local_activity_rounded,
                onPressed: () {
                  Navigator.of(context).pop();
                  push<void>(context, CouponDetailScreen(cupom: cupom));
                },
              ),
            ] else if (widget.already) ...[
              Text('Visita já registrada hoje', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: MP.s1),
              Text('Você já fez check-in em ${item!.titulo} hoje.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: MP.textSecondary)),
              const SizedBox(height: MP.s4),
              MpPrimaryButton(label: 'Ver meu passaporte', onPressed: _toPassport),
            ] else ...[
              Text('Visita registrada!', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: MP.s1),
              Text(item!.titulo, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: MP.s3),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: MP.s2,
                runSpacing: MP.s2,
                children: [
                  const MpBadge('+50 pontos', fg: MP.success, icon: Icons.add_circle_rounded),
                  if (widget.newStamp)
                    MpBadge(
                      'Novo carimbo: ${Content.polo(item.polo).nome} (+100)',
                      fg: const Color(0xffa87b00),
                      bg: MP.goldBg,
                      icon: Icons.workspace_premium_rounded,
                    ),
                ],
              ),
              const SizedBox(height: MP.s4),
              const Text('Como foi a experiência?', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              StarRating(
                value: _stars,
                onChanged: (v) {
                  setState(() => _stars = v);
                  if (widget.checkin != null) ref.read(appStoreProvider).rateAsync(widget.checkin!, v);
                },
              ),
              const SizedBox(height: MP.s3),
              MpPrimaryButton(key: const Key('checkin-to-passport'), label: 'Ver meu passaporte', onPressed: _toPassport),
            ],
            const SizedBox(height: MP.s1),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Continuar lendo')),
          ],
        ),
      ),
    );
  }
}

class _StampBadge extends StatelessWidget {
  const _StampBadge({this.cupom, this.already = false});
  final Cupom? cupom;
  final bool already;
  @override
  Widget build(BuildContext context) {
    final color = cupom != null ? MP.green : (already ? MP.info : const Color(0xffa87b00));
    final bg = cupom != null ? MP.greenBg : (already ? MP.infoBg : MP.goldBg);
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        boxShadow: [BoxShadow(color: color.withValues(alpha: .25), blurRadius: 24, spreadRadius: 2)],
      ),
      child: Icon(
        cupom != null ? Icons.local_activity_rounded : (already ? Icons.verified_rounded : Icons.workspace_premium_rounded),
        color: color,
        size: 56,
      ),
    );
  }
}
