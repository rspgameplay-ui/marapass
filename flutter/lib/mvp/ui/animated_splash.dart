import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../i18n.dart';
import 'package:flutter_svg/flutter_svg.dart';


/// Abertura animada (3,2 s) com a logo OFICIAL (os arquivos do manual, em
/// vetor): ponto de luz e rosa dos ventos sobre a foto dos Lençóis, o símbolo
/// entra girando como cata-vento, o nome sobe e surge a assinatura.
/// Um toque pula a abertura.
class AnimatedSplash extends StatefulWidget {
  const AnimatedSplash({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash> with SingleTickerProviderStateMixin {
  static const _total = 3200.0;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
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

  double _seg(double t, double from, double to, [Curve curve = Curves.linear]) {
    final ms = t * _total;
    if (ms <= from) return 0;
    if (ms >= to) return 1;
    return curve.transform((ms - from) / (to - from));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = math.min(size.width * .72, 330.0);
    return Semantics(
      label: tr('MaraPass, carregando'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: Material(
          color: const Color(0xff1b2a3b),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final pulse = _seg(t, 0, 900, Curves.easeOutCubic);
              final symbol = Curves.easeOutBack.transform(_seg(t, 700, 1500));
              final spin = _seg(t, 1400, 2450, Curves.easeOutCubic);
              final word = _seg(t, 2000, 2700, Curves.easeOutCubic);
              final tag = _seg(t, 2500, 3100);
              return Stack(
                fit: StackFit.expand,
                children: [
                  Transform.scale(
                    scale: 1.14 - .14 * Curves.easeOut.transform(t),
                    child: Image.asset('assets/photos/splash_bg.jpg', fit: BoxFit.cover),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xb80e1b2a), Color(0x4d142436), Color(0xeb0e1b2a)],
                        stops: [0, .4, 1],
                      ),
                    ),
                  ),
                  RepaintBoundary(child: CustomPaint(painter: _TerritoryPainter(pulse: pulse, rings: _seg(t, 100, 1100, Curves.easeOut), wave: 0))),
                  // Catavento exatamente no centro da tela, onde a rosa dos
                  // ventos é desenhada; o nome e a assinatura ficam abaixo.
                  Center(
                    child: Opacity(
                      opacity: symbol.clamp(0.0, 1.0),
                      child: Transform.rotate(
                        angle: (1 - symbol.clamp(0.0, 1.0)) * -1.9 + spin * math.pi * 2,
                        child: Transform.scale(
                          scale: symbol.clamp(.05, 1.12),
                          child: SvgPicture.asset('assets/brand/logo_mark.svg', width: w * .62, height: w * .62 * 260 / 242),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: size.height / 2 + w * .62 * 260 / 242 / 2 + w * .09,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: word,
                          child: Transform.translate(
                            offset: Offset(0, (1 - word) * 24),
                            child: SvgPicture.asset('assets/brand/logo_word_white.svg', width: w),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Opacity(
                          opacity: tag,
                          child: Column(
                            children: [
                              Text(
                                tr('DESCUBRA · VIVA · VALORIZE'),
                                style: TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 4.6, color: Colors.white),
                              ),
                              SizedBox(height: 8),
                              Text(
                                tr('MARANHÃO 2026'),
                                style: TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 5, color: Color(0x9effffff)),
                              ),
                            ],
                          ),
                        ),
                      ],
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
