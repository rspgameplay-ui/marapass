import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../i18n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide GeoPoint;

import '../../core/config.dart';
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
      _camError = tr('Câmera indisponível neste aparelho.');
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
            ? tr('Esta oferta não está mais ativa. Veja as ofertas disponíveis em Cupons.')
            : tr('Este QR não é de um local MaraPass. Procure a placa no balcão ou na entrada.'),
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
          throw LocationFailure(LocationProblem.unavailable, tr('sem GPS'));
        }
        c = await store.checkInAsync(item, method: 'codigo', lat: me.lat, lng: me.lng);
      }
    } on LocationFailure {
      if (mounted) setState(() => _busy = false);
      if (mounted) showMpSnack(context, tr('Código digitado precisa da sua localização. Permita o GPS ou leia o QR da placa.'));
      return;
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      if (mounted) showMpSnack(context, e is MvpException ? e.message : tr('Não foi possível registrar agora. Tente de novo.'));
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
      showMpSnack(context, tr('Lanterna indisponível sem a câmera.'));
      return;
    }
    try {
      await _cam!.toggleTorch();
      setState(() => _torch = !_torch);
    } catch (_) {
      if (mounted) showMpSnack(context, tr('Este aparelho não tem lanterna disponível.'));
    }
  }

  Future<void> _switch() async {
    if (_cam == null || _camError != null) {
      showMpSnack(context, tr('Câmera indisponível neste aparelho.'));
      return;
    }
    try {
      await _cam!.switchCamera();
    } catch (_) {
      if (mounted) showMpSnack(context, tr('Só há uma câmera disponível.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final box = math.min(size.width * .62, 250.0);
    final frame = Rect.fromCenter(
      center: Offset(size.width / 2, (size.height - pad.bottom) * .36),
      width: box,
      height: box,
    );
    final store = ref.watch(appStoreProvider);
    final recent = store.checkins.reversed.take(4).toList();
    return Scaffold(
      key: const Key('scan-screen'),
      backgroundColor: MP.scanBg,
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
                                ? tr('Permita o uso da câmera nas configurações do navegador.')
                                : tr('Não foi possível abrir a câmera.'));
                          }
                        });
                        return const ColoredBox(color: MP.scanBg);
                      },
                    )
                  : const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xff0b2741), MP.scanBg],
                        ),
                      ),
                    ),
            ),
            // Véu leve em volta do visor + cantos brancos
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ViewfinderPainter(frame)))),
            // Linha de leitura
            Positioned.fromRect(
              rect: frame.deflate(14),
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _line,
                  builder: (_, _) => Align(
                    alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(_line.value)),
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0), Colors.white, Colors.white.withValues(alpha: 0)]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Instrução ou erro dentro do visor
            Positioned.fromRect(
              rect: frame.deflate(22),
              child: Center(
                child: _busy
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_camError != null) ...[
                            const Icon(Icons.no_photography_rounded, color: Colors.white70, size: 34),
                            const SizedBox(height: MP.s2),
                          ],
                          Text(
                            _camError ?? tr('Aponte a câmera\npara o código'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              shadows: [Shadow(color: Color(0x99000000), blurRadius: 8)],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            // Topo: fechar · título · digitar código
            Positioned(
              left: MP.s4,
              right: MP.s4,
              top: pad.top + MP.s3,
              child: Row(
                children: [
                  _GlassButton(
                    key: const Key('scan-close'),
                    icon: Icons.close_rounded,
                    tooltip: tr('Fechar'),
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      tr('Escanear QR Code do Local'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  _GlassButton(
                    key: const Key('scan-manual'),
                    icon: Icons.keyboard_rounded,
                    tooltip: tr('Digitar código'),
                    onTap: _busy ? () {} : _manual,
                  ),
                ],
              ),
            ),
            // Lanterna e troca de câmera, logo abaixo do visor
            Positioned(
              left: 0,
              right: 0,
              top: frame.bottom + MP.s4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GlassButton(
                    key: const Key('scan-torch'),
                    icon: _torch ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                    tooltip: _torch ? tr('Desligar lanterna') : tr('Ligar lanterna'),
                    active: _torch,
                    onTap: _toggleTorch,
                  ),
                  const SizedBox(width: MP.s4),
                  _GlassButton(
                    key: const Key('scan-switch'),
                    icon: Icons.cameraswitch_rounded,
                    tooltip: tr('Trocar câmera'),
                    onTap: _switch,
                  ),
                ],
              ),
            ),
            // Base: saudação + últimas visitas
            Positioned(
              left: MP.s4,
              right: MP.s4,
              bottom: pad.bottom + MP.s4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('Olá!\nLeio as placas dos locais e as ofertas dos parceiros.'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      shadows: [Shadow(color: Color(0x99000000), blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(height: MP.s3),
                  Row(
                    children: [
                      for (final c in recent)
                        Padding(
                          padding: const EdgeInsets.only(right: MP.s2),
                          child: _RecentTile(checkin: c),
                        ),
                      if (recent.isEmpty)
                        Expanded(
                          child: Text(
                            tr('Suas visitas recentes aparecem aqui.'),
                            style: TextStyle(color: MP.onDarkMuted, fontSize: 14),
                          ),
                        )
                      else
                        const Spacer(),
                      _GlassButton(
                        key: const Key('scan-history'),
                        icon: Icons.menu_book_rounded,
                        tooltip: tr('Abrir meu passaporte'),
                        onTap: () {
                          ref.read(shellTabProvider.notifier).go(Tabs.passaporte);
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: MP.s3),
                  FilledButton.icon(
                    key: const Key('checkin-here'),
                    onPressed: _busy ? null : () => push<void>(context, const PickPlaceScreen()),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: MP.ink,
                      minimumSize: const Size.fromHeight(MP.buttonHeight),
                    ),
                    icon: const Icon(Icons.my_location_rounded),
                    label: Text(tr('Não achei o QR: usar localização')),
                  ),
                  // Simulação só em demonstração e sem conta: o turista real
                  // não vê este botão; logado, o servidor exige a placa real.
                  if ((kDebugMode || AppConfig.demoMode) && !store.online)
                    TextButton(
                      key: const Key('scan-simulate'),
                      onPressed: _busy ? null : () => _handle(plateCode(Content.items.first)),
                      style: TextButton.styleFrom(foregroundColor: MP.onDarkMuted),
                      child: Text(tr('Simular leitura (demonstração)')),
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

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter(this.frame);
  final Rect frame;
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(frame, const Radius.circular(22));
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(r);
    canvas.drawPath(shade, Paint()..color = const Color(0x66061220));
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const len = 30.0, rad = 22.0;
    final l = frame.left, t = frame.top, rr = frame.right, b = frame.bottom;
    canvas.drawPath(
      Path()
        ..moveTo(l, t + rad + len)
        ..lineTo(l, t + rad)
        ..arcToPoint(Offset(l + rad, t), radius: const Radius.circular(rad))
        ..lineTo(l + rad + len, t)
        ..moveTo(rr - rad - len, t)
        ..lineTo(rr - rad, t)
        ..arcToPoint(Offset(rr, t + rad), radius: const Radius.circular(rad))
        ..lineTo(rr, t + rad + len)
        ..moveTo(rr, b - rad - len)
        ..lineTo(rr, b - rad)
        ..arcToPoint(Offset(rr - rad, b), radius: const Radius.circular(rad))
        ..lineTo(rr - rad - len, b)
        ..moveTo(l + rad + len, b)
        ..lineTo(l + rad, b)
        ..arcToPoint(Offset(l, b - rad), radius: const Radius.circular(rad))
        ..lineTo(l, b - rad - len),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter old) => old.frame != frame;
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: active ? Colors.white : Colors.white.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(MP.rMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(MP.rMedium),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: active ? MP.ink : Colors.white, semanticLabel: tooltip),
        ),
      ),
    ),
  );
}

/// Miniatura de uma visita recente (ícone do polo) no rodapé do scanner.
class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.checkin});
  final Checkin checkin;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: checkin.cidade,
    child: Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(MP.rMedium)),
      child: Icon(_scanPoloIcon(checkin.polo), color: MP.navy, size: 26),
    ),
  );
}

IconData _scanPoloIcon(String polo) => switch (polo) {
  'lencois' => Icons.waves_rounded,
  'delta' => Icons.sailing_rounded,
  'chapada' => Icons.terrain_rounded,
  'saoluis' => Icons.account_balance_rounded,
  'munim' => Icons.kayaking_rounded,
  _ => Icons.place_rounded,
};

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
      setState(() => _error = tr('Não reconhecemos este código. Confira as letras impressas embaixo do QR da placa.'));
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
        Text(tr('Digitar código'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: MP.s1),
        Text(tr('Use o código impresso embaixo do QR da placa MaraPass.'), style: TextStyle(fontSize: 15, color: MP.textSecondary)),
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
          decoration: InputDecoration(labelText: tr('Código da placa'), hintText: tr('MP-XXXXXX')),
          onSubmitted: (_) => _go(),
        ),
        if (_error != null) ...[
          const SizedBox(height: MP.s3),
          MpNotice(_error!, icon: Icons.error_outline_rounded, fg: MP.error, bg: MP.errorBg),
        ],
        const SizedBox(height: MP.s4),
        MpPrimaryButton(key: const Key('plate-submit'), label: tr('Confirmar código'), onPressed: _go),
        const SizedBox(height: MP.s3),
        MpNotice.demo('${tr('Demonstração: experimente')} ${plateCode(Content.items.first)} (${Content.items.first.titulo}).'),
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
              Text(tr('Oferta encontrada'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: MP.s1),
              Text('${cupom.beneficio} · ${cupom.parceiro}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, color: MP.text)),
              const SizedBox(height: MP.s4),
              MpPrimaryButton(
                key: const Key('scan-offer-open'),
                label: tr('Ativar cupom'),
                icon: Icons.local_activity_rounded,
                onPressed: () {
                  Navigator.of(context).pop();
                  push<void>(context, CouponDetailScreen(cupom: cupom));
                },
              ),
            ] else if (widget.already) ...[
              Text(tr('Visita já registrada hoje'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: MP.s1),
              Text('${tr('Você já fez check-in em')} ${item!.titulo} ${tr('hoje')}.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: MP.textSecondary)),
              const SizedBox(height: MP.s4),
              MpPrimaryButton(label: tr('Ver meu passaporte'), onPressed: _toPassport),
            ] else ...[
              Text(tr('Visita registrada!'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: MP.s1),
              Text(item!.titulo, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: MP.s3),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: MP.s2,
                runSpacing: MP.s2,
                children: [
                  MpBadge(tr('+50 pontos'), fg: MP.success, icon: Icons.add_circle_rounded),
                  if (widget.newStamp)
                    MpBadge(
                      '${tr('Novo carimbo')}: ${Content.polo(item.polo).nome} (+100)',
                      fg: MP.goldText,
                      bg: MP.goldBg,
                      icon: Icons.workspace_premium_rounded,
                    ),
                ],
              ),
              const SizedBox(height: MP.s4),
              Text(tr('Como foi a experiência?'), textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              StarRating(
                value: _stars,
                onChanged: (v) {
                  setState(() => _stars = v);
                  if (widget.checkin != null) ref.read(appStoreProvider).rateAsync(widget.checkin!, v);
                },
              ),
              const SizedBox(height: MP.s3),
              MpPrimaryButton(key: const Key('checkin-to-passport'), label: tr('Ver meu passaporte'), onPressed: _toPassport),
            ],
            const SizedBox(height: MP.s1),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('Continuar lendo'))),
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
    final color = cupom != null ? MP.green : (already ? MP.info : MP.goldText);
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
