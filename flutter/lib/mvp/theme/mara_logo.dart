import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hélice do símbolo: face iluminada e dobra interna sombreada.
class Blade {
  const Blade(this.face, this.fold);
  final Color face, fold;
}

/// Paleta oficial das 6 hélices, em ordem radial horária a partir do topo.
const maraBlades = <Blade>[
  Blade(Color(0xFFF5C428), Color(0xFFC99B14)), // amarelo dourado: sol e hospitalidade
  Blade(Color(0xFF7C5D46), Color(0xFF5A412F)), // marrom cultural: raízes e tambores
  Blade(Color(0xFF2E7CF6), Color(0xFF1D5AC0)), // azul profundo: lagoas
  Blade(Color(0xFFDFC39D), Color(0xFFB89B75)), // areia dos Lençóis: dunas
  Blade(Color(0xFF43A854), Color(0xFF2E7D3B)), // verde tropical: palmeiras
  Blade(Color(0xFFE3524B), Color(0xFFB53832)), // vermelho cultural: Bumba meu boi
];

const maraNight = Color(0xFF233347);

/// Pinta o símbolo de 6 hélices em vetor (nítido em qualquer tamanho).
///
/// [progress] (0..1 por hélice) controla a entrada de cada pétala: ela gira
/// em espiral, cresce e se desdobra até o eixo central. [spin] gira o
/// conjunto inteiro (radianos). [mono] desenha tudo numa cor só.
class MaraSymbolPainter extends CustomPainter {
  MaraSymbolPainter({
    this.progress = const [1, 1, 1, 1, 1, 1],
    this.spin = 0,
    this.mono,
    this.glow = 0,
  });
  final List<double> progress;
  final double spin;
  final Color? mono;
  final double glow;

  // Geometria do manual em uma caixa de -55 a 55.
  static final Path _face = Path()
    ..moveTo(0, 0)
    ..lineTo(-1, -46)
    ..cubicTo(-1, -57, -43, -28, -23, -12)
    ..quadraticBezierTo(-10, -5, 0, 0)
    ..close();
  static final Path _fold = Path()
    ..moveTo(0, 0)
    ..lineTo(-23, -12)
    ..quadraticBezierTo(-34, -25, -26, -35)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / 110;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    canvas.rotate(spin);
    if (glow > 0) {
      canvas.drawCircle(
        Offset.zero,
        50,
        Paint()
          ..color = const Color(0xFFF5C428).withValues(alpha: .28 * glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 * glow + 1),
      );
    }
    for (var i = 0; i < 6; i++) {
      final t = progress[i].clamp(0.0, 1.2);
      if (t <= 0) continue;
      final b = maraBlades[i];
      canvas.save();
      // Entrada em espiral: vem girando de fora para o lugar final.
      canvas.rotate(i * math.pi / 3 + (1 - t.clamp(0.0, 1.0)) * -1.6);
      canvas.translate(0, (1 - t.clamp(0.0, 1.0)) * -26);
      canvas.scale(t);
      final alpha = t.clamp(0.0, 1.0);
      canvas.drawPath(_face, Paint()..color = (mono ?? b.face).withValues(alpha: alpha));
      canvas.drawPath(
        _fold,
        Paint()
          ..color = mono == null
              ? b.fold.withValues(alpha: alpha)
              : Colors.black.withValues(alpha: .12 * alpha),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MaraSymbolPainter old) =>
      old.spin != spin || old.glow != glow || old.mono != mono || !_same(old.progress, progress);

  static bool _same(List<double> a, List<double> b) {
    for (var i = 0; i < 6; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

enum MaraLogoVariant { symbol, horizontal, stacked }

/// Logo oficial do MaraPass em vetor, com as variações do manual:
/// símbolo, horizontal (símbolo + nome, para cabeçalhos) e empilhada.
/// [mono] gera a versão monocromática (branca ou azul-escuro) para carimbos.
class MaraPassLogo extends StatelessWidget {
  const MaraPassLogo({
    super.key,
    this.size = 48,
    this.variant = MaraLogoVariant.symbol,
    this.onDark = false,
    this.mono,
  });
  final double size;
  final MaraLogoVariant variant;
  final bool onDark;
  final Color? mono;

  @override
  Widget build(BuildContext context) {
    final symbol = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: MaraSymbolPainter(mono: mono)),
    );
    if (variant == MaraLogoVariant.symbol) {
      return Semantics(label: 'MaraPass', image: true, child: symbol);
    }
    final word = Text(
      'MaraPass',
      style: TextStyle(
        fontFamily: 'Jakarta',
        fontWeight: FontWeight.w800,
        fontSize: size * (variant == MaraLogoVariant.horizontal ? .52 : .34),
        letterSpacing: -.5,
        color: mono ?? (onDark ? Colors.white : maraNight),
        height: 1,
      ),
    );
    return Semantics(
      label: 'MaraPass',
      image: true,
      child: ExcludeSemantics(
        child: variant == MaraLogoVariant.horizontal
            ? Row(mainAxisSize: MainAxisSize.min, children: [symbol, SizedBox(width: size * .22), word])
            : Column(mainAxisSize: MainAxisSize.min, children: [symbol, SizedBox(height: size * .12), word]),
      ),
    );
  }
}
