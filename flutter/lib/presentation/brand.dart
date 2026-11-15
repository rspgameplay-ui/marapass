import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class MaraColors {
  static const navy = Color(0xff223449);
  static const blue = Color(0xff307ee9);
  static const gold = Color(0xffffbf16);
  static const red = Color(0xffeb4d49);
  static const green = Color(0xff35a55c);
  static const sand = Color(0xffdfc39b);
  static const brown = Color(0xff82634a);
  static const background = Color(0xfff7f9fc);
}

class MaraBrand extends StatelessWidget {
  const MaraBrand({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'MaraPass',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 34,
          height: 34,
          child: CustomPaint(painter: PinwheelPainter()),
        ),
        if (!compact) ...[
          const SizedBox(width: 9),
          const Flexible(
            child: Text(
              'MaraPass',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: MaraColors.navy,
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -.9,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

// Reinterpretação vetorial da referência visual fornecida pelo MaraPass.
class PinwheelPainter extends CustomPainter {
  const PinwheelPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.shortestSide / 100);
    const colors = [
      MaraColors.gold,
      MaraColors.brown,
      MaraColors.blue,
      MaraColors.sand,
      MaraColors.green,
      MaraColors.red,
    ];
    for (var i = 0; i < 6; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 3);
      final p = Path()
        ..moveTo(0, 0)
        ..lineTo(-1, -46)
        ..cubicTo(-1, -57, -43, -28, -23, -12)
        ..quadraticBezierTo(-10, -5, 0, 0)
        ..close();
      canvas.drawPath(p, Paint()..color = colors[i]);
      final fold = Path()
        ..moveTo(0, 0)
        ..lineTo(-23, -12)
        ..quadraticBezierTo(-34, -25, -26, -35)
        ..close();
      canvas.drawPath(
        fold,
        Paint()..color = Colors.black.withValues(alpha: .10),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
