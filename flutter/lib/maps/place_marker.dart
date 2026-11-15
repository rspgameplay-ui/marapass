import 'package:flutter/material.dart';

import '../domain/tourism.dart';
import '../presentation/brand.dart';

class PlaceMarker extends StatelessWidget {
  const PlaceMarker({
    super.key,
    required this.feature,
    this.selected = false,
    this.detailed = false,
  });
  final MapFeature feature;
  final bool selected, detailed;

  @override
  Widget build(BuildContext context) {
    final cluster = feature.isCluster;
    final size = cluster
        ? 28.0
        : selected
        ? 32.0
        : detailed
        ? 26.0
        : 16.0;
    return Tooltip(
      message: cluster
          ? '${feature.places.length} lugares'
          : feature.places.first.name,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: cluster
                ? MaraColors.navy
                : markerColor(feature.places.first.category),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x20000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (cluster)
                Center(
                  child: Text(
                    '${feature.places.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (selected || detailed)
                Center(
                  child: CustomPaint(
                    size: const Size(18, 18),
                    painter: TourismGlyph(
                      feature.places.first.category,
                      island: feature.places.first.isCoastalIsland,
                    ),
                  ),
                ),
              if (feature.places.any((p) => p.hasCoupon))
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: MaraColors.gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Color markerColor(PlaceCategory c) => switch (c) {
  PlaceCategory.nature => const Color(0xff507761),
  PlaceCategory.gastronomy => const Color(0xffa36f5d),
  PlaceCategory.lodging => const Color(0xff77788d),
  PlaceCategory.culture => const Color(0xff8d7559),
  PlaceCategory.tours => const Color(0xff466f79),
  _ => const Color(0xff647a7c),
};

/// Line artwork designed for MaraPass, independent of an icon font.
class TourismGlyph extends CustomPainter {
  TourismGlyph(this.category, {this.island = false});
  final PlaceCategory category;
  final bool island;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 24, size.height / 24);
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    if (island) {
      path.moveTo(3, 20);
      path.quadraticBezierTo(12, 15, 21, 20);
      path.moveTo(12, 18);
      path.quadraticBezierTo(14, 11, 12, 7);
      path.moveTo(12, 7);
      path.quadraticBezierTo(7, 3, 4, 8);
      path.moveTo(12, 7);
      path.quadraticBezierTo(17, 2, 21, 8);
      path.moveTo(12, 7);
      path.lineTo(8, 12);
    } else if (category == PlaceCategory.nature) {
      path.moveTo(2, 20);
      path.lineTo(10, 5);
      path.lineTo(17, 20);
      path.moveTo(13, 12);
      path.lineTo(17, 7);
      path.lineTo(23, 20);
      path.moveTo(7, 11);
      path.lineTo(10, 13);
      path.lineTo(13, 11);
    } else if (category == PlaceCategory.gastronomy) {
      for (final x in [5.0, 8.0, 11.0]) {
        path.moveTo(x, 3);
        path.lineTo(x, 9);
      }
      path.moveTo(5, 9);
      path.quadraticBezierTo(8, 14, 11, 9);
      path.moveTo(8, 12);
      path.lineTo(8, 21);
      path.moveTo(19, 21);
      path.lineTo(19, 3);
      path.quadraticBezierTo(13, 8, 19, 12);
    } else if (category == PlaceCategory.lodging) {
      path.moveTo(3, 21);
      path.lineTo(3, 5);
      path.moveTo(3, 17);
      path.lineTo(22, 17);
      path.lineTo(22, 21);
      path.moveTo(3, 10);
      path.lineTo(18, 10);
      path.quadraticBezierTo(22, 10, 22, 14);
      path.lineTo(22, 17);
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(5, 6, 5, 4),
          const Radius.circular(1),
        ),
        p,
      );
    } else if (category == PlaceCategory.culture) {
      path.moveTo(2, 9);
      path.lineTo(12, 3);
      path.lineTo(22, 9);
      path.close();
      for (final x in [5.0, 12.0, 19.0]) {
        path.moveTo(x, 11);
        path.lineTo(x, 19);
      }
      path.moveTo(2, 21);
      path.lineTo(22, 21);
    } else {
      c.drawCircle(const Offset(12, 12), 9, p);
      path.moveTo(16, 6);
      path.lineTo(14, 14);
      path.lineTo(7, 17);
      path.lineTo(10, 10);
      path.close();
    }
    c.drawPath(path, p);
    c.restore();
  }

  @override
  bool shouldRepaint(TourismGlyph old) =>
      old.category != category || old.island != island;
}
