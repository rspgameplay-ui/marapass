import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/map_state.dart';
import '../domain/tourism.dart';

class EssentialMap extends StatefulWidget {
  const EssentialMap({
    super.key,
    required this.state,
    required this.boundary,
    required this.onFeature,
    required this.onViewport,
  });
  final MapState state;
  final Map<String, dynamic> boundary;
  final ValueChanged<MapFeature> onFeature;
  final void Function(GeoBounds, double) onViewport;
  @override
  State<EssentialMap> createState() => _EssentialMapState();
}

class _EssentialMapState extends State<EssentialMap> {
  final transform = TransformationController();
  Size size = const Size(400, 700);
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EssentialMap old) {
    super.didUpdateWidget(old);
    if (old.state.request.serial != widget.state.request.serial) {
      final r = widget.state.request;
      final p = project(r.target, size);
      final scale = math.pow(2, (r.zoom - 6).clamp(0, 8)).toDouble();
      transform.value = Matrix4.identity()
        ..translateByDouble(
          size.width / 2 - p.dx * scale,
          size.height / 2 - p.dy * scale,
          0,
          1,
        )
        ..scaleByDouble(scale, scale, 1, 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _idle();
        }
      });
    }
  }

  double scaleFor(Size s) =>
      math.min((s.width - 32) / 8, math.max(100, s.height - 380) / 10.4);
  Offset project(GeoPoint p, Size s) {
    final scale = scaleFor(s);
    return Offset(
      (s.width - 8 * scale) / 2 + (p.lng + 49) * scale,
      200 + (-p.lat - .5) * scale,
    );
  }

  GeoPoint unproject(Offset p) {
    final scale = scaleFor(size);
    return GeoPoint(
      -.5 - (p.dy - 200) / scale,
      -49 + (p.dx - (size.width - 8 * scale) / 2) / scale,
    );
  }

  void _idle() {
    final top = unproject(transform.toScene(Offset.zero));
    final bottom = unproject(
      transform.toScene(Offset(size.width, size.height)),
    );
    widget.onViewport(
      GeoBounds(bottom.lat, top.lng, top.lat, bottom.lng),
      6 + math.log(transform.value.getMaxScaleOnAxis()) / math.ln2,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      size = constraints.biggest;
      final features = clusterPlaces(
        widget.state.filtered,
        widget.state.zoom,
        selectedId: widget.state.selectedId,
      );
      return ColoredBox(
        color: const Color(0xffd6e7ea),
        child: InteractiveViewer(
          transformationController: transform,
          minScale: 1,
          maxScale: 256,
          boundaryMargin: const EdgeInsets.all(1000),
          onInteractionEnd: (_) => _idle(),
          onInteractionUpdate: (_) => setState(() {}),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              // O filho recebe coordenadas locais já transformadas pelo InteractiveViewer.
              final local = details.localPosition;
              MapFeature? nearest;
              var distance = 30 / transform.value.getMaxScaleOnAxis();
              for (final f in features) {
                final d = (project(f.point, size) - local).distance;
                if (d < distance) {
                  nearest = f;
                  distance = d;
                }
              }
              if (nearest != null) {
                widget.onFeature(nearest);
              }
            },
            child: CustomPaint(
              size: size,
              painter: _EssentialPainter(
                widget.boundary,
                features,
                widget.state.location,
                project,
                transform.value.getMaxScaleOnAxis(),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _EssentialPainter extends CustomPainter {
  _EssentialPainter(
    this.boundary,
    this.features,
    this.location,
    this.project,
    this.zoomScale,
  );
  final double zoomScale;
  final Map<String, dynamic> boundary;
  final List<MapFeature> features;
  final GeoPoint? location;
  final Offset Function(GeoPoint, Size) project;
  void text(
    Canvas c,
    String value,
    Offset at, {
    double size = 10,
    Color color = const Color(0xff315d62),
    bool bold = false,
  }) {
    final t = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: size / zoomScale,
          fontFamily: 'MaraSans',
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    t.paint(c, at - Offset(t.width / 2, t.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = (boundary['features'] as List).first['geometry'];
    final coordinates = geometry['coordinates'] as List;
    final polygons = geometry['type'] == 'MultiPolygon'
        ? coordinates
        : [coordinates];
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final polygon in polygons) {
      for (final ring in polygon as List) {
        final coords = ring as List;
        for (var i = 0; i < coords.length; i++) {
          final p = project(
            GeoPoint(
              (coords[i][1] as num).toDouble(),
              (coords[i][0] as num).toDouble(),
            ),
            size,
          );
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
      }
    }
    canvas.drawPath(path, Paint()..color = const Color(0xffe9eedc));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xffb2b39f)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .45 / zoomScale,
    );
    text(
      canvas,
      'O C E A N O  A T L Â N T I C O',
      Offset(size.width * .62, size.height * .19),
      size: 10,
      color: const Color(0xff63939c),
    );
    text(
      canvas,
      'MARANHÃO',
      Offset(size.width * .49, size.height * .53),
      size: 17,
      bold: true,
      color: const Color(0xffa0b39a),
    );
    for (final f in features) {
      final p = project(f.point, size);
      final cat = f.places.first.category;
      canvas.drawCircle(
        p + const Offset(0, 1),
        (f.isCluster ? 15 : 9) / zoomScale,
        Paint()..color = Colors.black.withValues(alpha: .12),
      );
      canvas.drawCircle(
        p,
        (f.isCluster ? 14 : 8) / zoomScale,
        Paint()..color = f.isCluster ? const Color(0xff105f73) : cat.color,
      );
      canvas.drawCircle(
        p,
        (f.isCluster ? 14 : 8) / zoomScale,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 / zoomScale,
      );
      if (f.isCluster) {
        text(
          canvas,
          '${f.places.length}',
          p,
          size: 11,
          color: Colors.white,
          bold: true,
        );
      } else {
        text(
          canvas,
          f.places.first.name,
          p + Offset(0, 17 / zoomScale),
          size: 9,
        );
      }
    }
    if (location != null) {
      final p = project(location!, size);
      canvas.drawCircle(
        p,
        13 / zoomScale,
        Paint()..color = Colors.blue.withValues(alpha: .18),
      );
      canvas.drawCircle(p, 6 / zoomScale, Paint()..color = Colors.blue);
    }
  }

  @override
  bool shouldRepaint(_EssentialPainter old) => true;
}
