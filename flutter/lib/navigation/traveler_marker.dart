import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../presentation/brand.dart';

enum TravelMode { land, nautical }

double normalizeHeading(double value) =>
    value.isFinite ? (value % 360 + 360) % 360 : 0;
double headingDelta(double from, double to) => (to - from + 540) % 360 - 180;
String directionLabel(double heading) => [
  'norte',
  'nordeste',
  'leste',
  'sudeste',
  'sul',
  'sudoeste',
  'oeste',
  'noroeste',
][(normalizeHeading(heading) / 45).round() % 8];

/// No navigation decisions are made from these animated, visual coordinates.
class TravelerMarker extends StatefulWidget {
  const TravelerMarker({
    super.key,
    this.mode = TravelMode.land,
    this.heading = 0,
    this.accuracy = 12,
    this.imprecise = false,
    this.headingKnown = true,
    this.driving = false,
  });
  final TravelMode mode;
  final double heading, accuracy;
  final bool imprecise, headingKnown, driving;
  @override
  State<TravelerMarker> createState() => _TravelerMarkerState();
}

class _TravelerMarkerState extends State<TravelerMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController water = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  double angle = 0;
  void configureWater() {
    if (widget.mode == TravelMode.nautical &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!water.isAnimating) water.repeat(reverse: true);
    } else {
      water.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    angle = normalizeHeading(widget.heading);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    configureWater();
  }

  @override
  void didUpdateWidget(TravelerMarker old) {
    super.didUpdateWidget(old);
    if (widget.heading.isFinite) {
      final d = headingDelta(
        normalizeHeading(angle),
        normalizeHeading(widget.heading),
      );
      if (d.abs() > 2) angle += d;
    }
    configureWater();
  }

  @override
  void dispose() {
    water.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Capture mode: the outgoing child must retain its own artwork during fade.
    final mode = widget.mode,
        inaccurate = widget.imprecise,
        accuracy = widget.accuracy,
        driving = widget.driving;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label:
          'Você está aqui${widget.headingKnown ? ', seguindo para ${directionLabel(angle)}' : ', rumo indisponível'}${inaccurate ? ', Localização imprecisa' : ''}',
      child: AnimatedOpacity(
        opacity: inaccurate ? .55 : 1,
        duration: const Duration(milliseconds: 250),
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: reduced ? 0 : 250),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween<double>(begin: .92, end: 1).animate(a),
              child: child,
            ),
          ),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(mode),
            tween: Tween(end: angle),
            duration: Duration(milliseconds: reduced ? 0 : 500),
            builder: (context, a, _) => AnimatedBuilder(
              animation: water,
              builder: (context, _) => CustomPaint(
                size: const Size(64, 64),
                painter: TravelerPainter(
                  mode: mode,
                  driving: driving,
                  heading: a,
                  accuracy: accuracy,
                  imprecise: inaccurate,
                  bob: mode == TravelMode.nautical && !reduced
                      ? water.value * 3
                      : 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TravelerPainter extends CustomPainter {
  TravelerPainter({
    required this.mode,
    required this.heading,
    required this.accuracy,
    required this.imprecise,
    this.bob = 0,
    this.driving = false,
  });
  final TravelMode mode;
  final double heading, accuracy, bob;
  final bool imprecise, driving;
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.translate(s.width / 2, s.height / 2);
    final color = imprecise
        ? Colors.grey
        : mode == TravelMode.land
        ? MaraColors.blue
        : MaraColors.gold;
    if (mode == TravelMode.nautical) {
      c.drawOval(
        const Rect.fromLTWH(-14, 17, 28, 6),
        Paint()..color = Colors.black.withValues(alpha: .15),
      );
      c.translate(0, -bob);
    }
    c.rotate(normalizeHeading(heading) * math.pi / 180);
    if (mode == TravelMode.land && driving) {
      _drawCar(c);
    } else if (mode == TravelMode.land) {
      final radius = accuracy.isFinite
          ? (12 + accuracy * .18).clamp(14.0, 28.0).toDouble()
          : 28.0;
      c.drawCircle(
        Offset.zero,
        radius,
        Paint()..color = color.withValues(alpha: .15),
      );
      c.drawPath(
        Path()
          ..moveTo(0, -radius - 3)
          ..lineTo(-4, -radius + 4)
          ..lineTo(4, -radius + 4)
          ..close(),
        Paint()..color = color,
      );
      c.drawCircle(Offset.zero, 8, Paint()..color = Colors.white);
      c.drawCircle(Offset.zero, 6, Paint()..color = color);
    } else {
      c.drawCircle(Offset.zero, 17, Paint()..color = Colors.white);
      c.drawCircle(Offset.zero, 16, Paint()..color = color);
      final p = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      c.drawLine(const Offset(0, -11), const Offset(0, 10), p);
      c.drawPath(
        Path()
          ..moveTo(-2, -10)
          ..lineTo(-2, 6)
          ..lineTo(-11, 6)
          ..close(),
        p,
      );
      c.drawPath(
        Path()
          ..moveTo(2, -8)
          ..lineTo(10, 6)
          ..lineTo(2, 6)
          ..close(),
        p,
      );
      c.drawLine(const Offset(-10, 10), const Offset(10, 10), p);
    }
    c.restore();
  }

  void _drawCar(Canvas canvas) {
    canvas.drawOval(
      const Rect.fromLTWH(-21, -15, 42, 38),
      Paint()..color = const Color(0x44038e9d),
    );
    final body = Path()
      ..moveTo(0, -25)
      ..cubicTo(11, -25, 14, -18, 14, -7)
      ..lineTo(14, 16)
      ..quadraticBezierTo(14, 25, 5, 25)
      ..lineTo(-5, 25)
      ..quadraticBezierTo(-14, 25, -14, 16)
      ..lineTo(-14, -7)
      ..cubicTo(-14, -18, -11, -25, 0, -25)
      ..close();
    canvas.drawShadow(body, const Color(0xff0d3349), 4, false);
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xff087d92),
            Color(0xff65eff3),
            Color(0xff13bfd1),
            Color(0xff086c83),
          ],
        ).createShader(const Rect.fromLTWH(-14, -25, 28, 50)),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xffecfeff),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, -13, 20, 29),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xff153951),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-8, -4, 16, 13),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xff1cc4d3),
    );
    for (final x in [-10.0, 5.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, -19, 5, 2.5),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xfffff2b8),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 19, 5, 2.5),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xffff7162),
      );
    }
  }

  @override
  bool shouldRepaint(TravelerPainter old) =>
      old.mode != mode ||
      old.driving != driving ||
      old.heading != heading ||
      old.accuracy != accuracy ||
      old.imprecise != imprecise ||
      old.bob != bob;
}
