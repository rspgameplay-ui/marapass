import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ReferenceRoadNetwork {
  ReferenceRoadNetwork(Map<String, dynamic> json, Map<String, dynamic> land) {
    for (final r in json['roads'] as List) {
      final t = '${r['t']}';
      roads.add((
        bounds: (r['b'] as List).map((v) => (v as num).toDouble()).toList(),
        points: (r['c'] as List)
            .map(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
            )
            .toList(),
        major: ['motorway', 'trunk', 'primary', 'secondary'].contains(t),
        name: '${r['n']}',
      ));
    }
    for (final f in land['features'] as List) {
      final g = f['geometry'];
      for (final p
          in g['type'] == 'MultiPolygon'
              ? g['coordinates'] as List
              : [g['coordinates']]) {
        polygons.add(
          Polygon(
            points: ((p as List).first as List)
                .map(
                  (c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ),
                )
                .toList(),
            color: const Color(0xfff3f3ed),
            holePointsList: (p)
                .skip(1)
                .map(
                  (ring) => (ring as List)
                      .map(
                        (c) => LatLng(
                          (c[1] as num).toDouble(),
                          (c[0] as num).toDouble(),
                        ),
                      )
                      .toList(),
                )
                .toList(),
            borderColor: Colors.transparent,
            borderStrokeWidth: 0,
          ),
        );
      }
    }
  }
  final roads =
      <({List<double> bounds, List<LatLng> points, bool major, String name})>[];
  final polygons = <Polygon>[];
}

class ReferenceRoadLayer extends StatelessWidget {
  const ReferenceRoadLayer({
    super.key,
    required this.network,
    this.night = false,
  });
  final ReferenceRoadNetwork network;
  final bool night;
  @override
  Widget build(BuildContext context) {
    final c = MapCamera.of(context), b = cameraBounds(context);
    final visible = network.roads
        .where(
          (r) =>
              (c.zoom >= 13 || r.major) &&
              r.bounds[2] >= b.south &&
              r.bounds[0] <= b.north &&
              r.bounds[3] >= b.west &&
              r.bounds[1] <= b.east,
        )
        .toList();
    final cells = <String>{};
    final labels = <Marker>[];
    if (c.zoom >= 14) {
      for (final r in visible.where((r) => r.name.isNotEmpty)) {
        final p = r.points[r.points.length ~/ 2];
        if (!b.contains(p)) continue;
        final cell = 360 / (1 << c.zoom.floor()) * .5;
        final key =
            '${(p.latitude / cell).floor()}:${(p.longitude / cell).floor()}';
        if (!cells.add(key)) continue;
        labels.add(
          Marker(
            point: p,
            width: 140,
            height: 20,
            child: IgnorePointer(
              child: Center(
                child: Text(
                  r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: night
                        ? const Color(0xffc4cfcc)
                        : const Color(0xff59665f),
                    backgroundColor: night
                        ? const Color(0xdd253235)
                        : const Color(0xddf3f0e9),
                  ),
                ),
              ),
            ),
          ),
        );
        if (labels.length >= 24) break;
      }
    }
    return Stack(
      children: [
        PolygonLayer(
          polygons: [
            for (final p in network.polygons)
              Polygon(
                points: p.points,
                holePointsList: p.holePointsList,
                color: night
                    ? const Color(0xff1d292e)
                    : const Color(0xfff3f0e9),
                borderStrokeWidth: 0,
                borderColor: Colors.transparent,
              ),
          ],
        ),
        PolylineLayer(
          polylines: [
            for (final r in visible)
              Polyline(
                points: r.points,
                color: r.major
                    ? (night
                          ? const Color(0xff69706a)
                          : const Color(0xffe7d6b5))
                    : (night ? const Color(0xff4a5857) : Colors.white),
                strokeWidth: r.major
                    ? (c.zoom >= 13 ? 6 : 2.5)
                    : (c.zoom >= 15 ? 4 : 1.8),
                borderColor: night
                    ? const Color(0xff43504f)
                    : const Color(0xffd3d0c5),
                borderStrokeWidth: .6,
              ),
          ],
        ),
        MarkerLayer(markers: labels),
      ],
    );
  }

  LatLngBounds cameraBounds(BuildContext context) =>
      MapCamera.of(context).visibleBounds;
}
