import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/mara_logo.dart';

/// Abertura animada (2,8 s) contando a construção do símbolo:
/// 1. Pulso do território: ponto dourado vira rosa dos ventos, com a onda
///    das dunas na base (0,0–0,8 s).
/// 2. Giro cultural: as 6 hélices entram em espiral, como as fitas do
///    Caboclo de Fitas e a saia rodada do Tambor de Crioula, e o cata-vento
///    dá um giro completo com brilho (0,8–1,9 s).
/// 3. Assinatura: o símbolo sobe e surge "MaraPass · MARANHÃO 2026"
///    (1,9–2,8 s). Um toque pula a abertura.
class AnimatedSplash extends StatefulWidget {
  const AnimatedSplash({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash> with SingleTickerProviderStateMixin {
  static const _total = 2800.0;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Progresso (0..1) de um trecho em milissegundos, com curva.
  double _seg(double t, double from, double to, [Curve curve = Curves.linear]) {
    final ms = t * _total;
    if (ms <= from) return 0;
    if (ms >= to) return 1;
    return curve.transform((ms - from) / (to - from));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logo = math.min(size.width * .46, 210.0);
    return Semantics(
      label: 'MaraPass, carregando',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: Material(
          color: maraNight,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              // Ato 1
              final pulse = _seg(t, 0, 800, Curves.easeOutCubic);
              final rings = _seg(t, 100, 1100, Curves.easeOut);
              // Ato 2: hélices a cada 80 ms, cada uma em 450 ms
              final blades = [
                for (var i = 0; i < 6; i++)
                  Curves.easeOutBack.transform(_seg(t, 800 + i * 80.0, 1250 + i * 80.0)),
              ];
              final spin = _seg(t, 1450, 2350, Curves.easeOutCubic) * math.pi * 2;
              final glow = math.sin(_seg(t, 1450, 2400) * math.pi);
              // Ato 3
              final sign = _seg(t, 1900, 2600, Curves.easeOutCubic);
              final lift = sign * 36;
              return Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(child: CustomPaint(painter: _TerritoryPainter(pulse: pulse, rings: rings, wave: t))),
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, -lift),
                      child: RepaintBoundary(
                        child: SizedBox.square(
                        dimension: logo,
                        child: CustomPaint(
                          painter: MaraSymbolPainter(progress: blades, spin: spin, glow: glow),
                        ),
                      ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: size.height / 2 + logo / 2 - lift + 18,
                    child: Opacity(
                      opacity: sign,
                      child: Transform.translate(
                        offset: Offset(0, (1 - sign) * 22),
                        child: const Column(
                          children: [
                            Text(
                              'MaraPass',
                              style: TextStyle(
                                fontFamily: 'Jakarta',
                                fontWeight: FontWeight.w800,
                                fontSize: 40,
                                letterSpacing: -.8,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'MARANHÃO 2026',
                              style: TextStyle(
                                fontFamily: 'Jakarta',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: 6,
                                color: Color(0xCCFFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Ato 1: ponto de luz, anéis e linhas da rosa dos ventos e a onda das dunas.
class _TerritoryPainter extends CustomPainter {
  _TerritoryPainter({required this.pulse, required this.rings, required this.wave});
  final double pulse, rings, wave;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * .42;
    const gold = Color(0xFFF5C428);

    // Ponto de luz dourado
    final dot = (1 - rings).clamp(0.0, 1.0) * pulse;
    if (dot > 0) {
      final rr = 12 + 30 * pulse;
      canvas.drawCircle(c, rr, Paint()
        ..shader = RadialGradient(colors: [gold.withValues(alpha: .4 * dot), gold.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: c, radius: rr)));
      canvas.drawCircle(c, 5, Paint()..color = gold.withValues(alpha: dot));
    }

    // Anéis da bússola
    for (var k = 0; k < 3; k++) {
      final p = (rings - k * .15).clamp(0.0, 1.0);
      if (p <= 0) continue;
      canvas.drawCircle(c, r * (.35 + .25 * k) * Curves.easeOut.transform(p), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: .16 * (1 - k * .25)));
    }

    // Linhas guia da rosa dos ventos (8 direções)
    final lines = Paint()
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: .10 * rings);
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4;
      final len = r * (k.isEven ? 1.0 : .62) * rings;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r * .12, c + Offset(math.cos(a), math.sin(a)) * len, lines);
    }

    // Onda das dunas na base
    final h = size.height;
    final path = Path()..moveTo(0, h);
    final amp = 14.0 * pulse;
    for (double x = 0; x <= size.width + 24; x += 24) {
      final y = h * .86 + math.sin(x / size.width * math.pi * 2 + wave * math.pi * 2) * amp;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, h)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFDFC39D).withValues(alpha: .10 * pulse));
  }

  @override
  bool shouldRepaint(covariant _TerritoryPainter old) =>
      old.pulse != pulse || old.rings != rings || old.wave != wave;
}
