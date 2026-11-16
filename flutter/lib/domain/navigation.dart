import 'dart:math' as math;

import 'tourism.dart';

class RoadStep {
  const RoadStep({
    required this.instruction,
    required this.road,
    required this.type,
    required this.modifier,
    required this.startMeters,
    required this.distance,
    required this.duration,
    required this.point,
    this.mode = "driving",
  });
  final String instruction, road, type, modifier, mode;
  final double startMeters, distance, duration;
  final GeoPoint point;
}

String maneuverInstruction(Map<String, dynamic> step) {
  if (step['mode'] == 'ferry') {
    return 'Siga pela travessia de balsa';
  }
  final m = Map<String, dynamic>.from(step['maneuver'] as Map);
  final type = m['type'] as String? ?? 'continue';
  final modifier = m['modifier'] as String? ?? '';
  final road = (step['name'] as String? ?? '').trim();
  final suffix = road.isEmpty ? '' : ' em $road';
  final direction = switch (modifier) {
    'left' => 'à esquerda',
    'right' => 'à direita',
    'slight left' => 'levemente à esquerda',
    'slight right' => 'levemente à direita',
    'sharp left' => 'acentuadamente à esquerda',
    'sharp right' => 'acentuadamente à direita',
    'uturn' => 'e faça o retorno',
    _ => 'em frente',
  };
  return switch (type) {
    'depart' => 'Siga$suffix',
    'arrive' => 'Chegue ao destino',
    'roundabout' || 'rotary' =>
      m['exit'] == null
          ? 'Entre na rotatória$suffix'
          : 'Na rotatória, pegue a saída ${m['exit']}$suffix',
    'exit roundabout' || 'exit rotary' => 'Saia da rotatória$suffix',
    'merge' => 'Entre na via $direction$suffix',
    'on ramp' => 'Acesse a alça $direction$suffix',
    'off ramp' => 'Pegue a saída $direction$suffix',
    'fork' => 'Mantenha-se $direction$suffix',
    'end of road' || 'turn' =>
      modifier == 'uturn' ? 'Faça o retorno$suffix' : 'Vire $direction$suffix',
    'new name' => 'Continue$suffix',
    'notification' =>
      step['mode'] == 'ferry'
          ? 'Embarque na travessia de balsa'
          : 'Continue$suffix',
    _ =>
      modifier == 'uturn' ? 'Faça o retorno$suffix' : 'Siga $direction$suffix',
  };
}

class RoadRoute {
  RoadRoute({
    required this.points,
    required this.steps,
    required this.distance,
    required this.duration,
    required this.summary,
    required this.originSnap,
    required this.destinationSnap,
  });
  final List<GeoPoint> points;
  final List<RoadStep> steps;
  final double distance, duration, originSnap, destinationSnap;
  final String summary;
  late final List<double> cumulative = () {
    final result = <double>[0];
    for (var i = 1; i < points.length; i++) {
      result.add(result.last + points[i - 1].distanceKm(points[i]) * 1000);
    }
    return result;
  }();
  double get geometryLength => cumulative.last;
  bool get hasFerry => steps.any((s) => s.instruction.contains('balsa'));

  double? bearingAt(double meters) {
    if (points.length < 2) return null;
    var left = 1;
    var right = points.length - 1;
    while (left < right) {
      final middle = (left + right) ~/ 2;
      if (cumulative[middle] <= meters) {
        left = middle + 1;
      } else {
        right = middle;
      }
    }
    final start = points[left - 1], end = points[left];
    final north = end.lat - start.lat;
    final east = (end.lng - start.lng) * math.cos(start.lat * math.pi / 180);
    if (north == 0 && east == 0) return null;
    return (math.atan2(east, north) * 180 / math.pi + 360) % 360;
  }

  double remainingDuration(double meters) {
    if (geometryLength <= 0 || meters >= geometryLength) return 0;
    if (meters <= 0) return duration;
    var totalStepTime = 0.0;
    var remainingStepTime = 0.0;
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final end = i + 1 < steps.length
          ? steps[i + 1].startMeters
          : geometryLength;
      totalStepTime += step.duration;
      if (meters <= step.startMeters) {
        remainingStepTime += step.duration;
      } else if (meters < end) {
        remainingStepTime +=
            step.duration * (end - meters) / (end - step.startMeters);
      }
    }
    return totalStepTime > 0
        ? duration * (remainingStepTime / totalStepTime)
        : duration * (1 - meters / geometryLength);
  }

  factory RoadRoute.fromOsrm(Map<String, dynamic> root, int index) {
    if (root['code'] != 'Ok' ||
        root['routes'] is! List ||
        (root['routes'] as List).length <= index) {
      throw const FormatException('Não foi encontrada uma rota rodoviária.');
    }
    final raw = Map<String, dynamic>.from((root['routes'] as List)[index]);
    final points = <GeoPoint>[];
    final steps = <RoadStep>[];
    var traveled = 0.0;
    final summaries = <String>[];
    final legs = raw['legs'] as List;
    for (var legIndex = 0; legIndex < legs.length; legIndex++) {
      final leg = legs[legIndex];
      final lastLeg = legIndex == legs.length - 1;
      if ('${leg['summary']}'.trim().isNotEmpty) {
        summaries.add('${leg['summary']}');
      }
      for (final value in leg['steps'] as List) {
        final s = Map<String, dynamic>.from(value);
        final coords = (s['geometry']['coordinates'] as List);
        final segment = coords
            .map(
              (c) =>
                  GeoPoint((c[1] as num).toDouble(), (c[0] as num).toDouble()),
            )
            .toList();
        if (segment.isEmpty) {
          continue;
        }
        final m = s['maneuver'] as Map;
        steps.add(
          RoadStep(
            mode: "${s['mode'] ?? 'driving'}",
            // Em roteiros com paradas, só a última chegada é o destino.
            instruction: m['type'] == 'arrive' && !lastLeg
                ? 'Chegue à parada ${legIndex + 1}'
                : m['type'] == 'depart' && legIndex > 0
                ? 'Siga para a parada ${legIndex + 2}'
                : maneuverInstruction(s),
            road: '${s['name'] ?? ''}',
            type: '${m['type']}',
            modifier: '${m['modifier'] ?? ''}',
            startMeters: traveled,
            distance: (s['distance'] as num).toDouble(),
            duration: (s['duration'] as num).toDouble(),
            point: segment.first,
          ),
        );
        for (final p in segment) {
          if (points.isEmpty) {
            points.add(p);
          } else if (points.last.distanceKm(p) > .000001) {
            traveled += points.last.distanceKm(p) * 1000;
            points.add(p);
          }
        }
      }
    }
    if (points.length < 2 || steps.isEmpty) {
      throw const FormatException('Rota sem geometria de navegação.');
    }
    final waypoints = root['waypoints'] as List;
    return RoadRoute(
      points: points,
      steps: steps,
      distance: (raw['distance'] as num).toDouble(),
      duration: (raw['duration'] as num).toDouble(),
      summary: summaries.join(' • '),
      originSnap: (waypoints.first['distance'] as num).toDouble(),
      destinationSnap: (waypoints.last['distance'] as num).toDouble(),
    );
  }
}

class RouteProjection {
  const RouteProjection(this.meters, this.distanceToRoad, this.point);
  final double meters, distanceToRoad;
  final GeoPoint point;
}

RouteProjection projectOnRoute(
  GeoPoint point,
  RoadRoute route, {
  double minimum = 0,
  double maximum = double.infinity,
}) {
  var nearest = RouteProjection(0, double.infinity, route.points.first);
  // Projeção local em metros, suficiente para segmentos curtos de uma rota.
  final longitudeScale = 111320 * math.cos(point.lat * math.pi / 180);
  for (var i = 1; i < route.points.length; i++) {
    if (route.cumulative[i] < minimum || route.cumulative[i - 1] > maximum) {
      continue;
    }
    final a = route.points[i - 1], b = route.points[i];
    final ax = (a.lng - point.lng) * longitudeScale,
        ay = (a.lat - point.lat) * 111320;
    final bx = (b.lng - point.lng) * longitudeScale,
        by = (b.lat - point.lat) * 111320;
    final dx = bx - ax, dy = by - ay, length2 = dx * dx + dy * dy;
    final t = length2 == 0
        ? 0.0
        : (-(ax * dx + ay * dy) / length2).clamp(0.0, 1.0);
    final distance = math.sqrt(
      math.pow(ax + t * dx, 2) + math.pow(ay + t * dy, 2),
    );
    if (distance < nearest.distanceToRoad) {
      nearest = RouteProjection(
        route.cumulative[i - 1] +
            t * (route.cumulative[i] - route.cumulative[i - 1]),
        distance,
        GeoPoint(a.lat + t * (b.lat - a.lat), a.lng + t * (b.lng - a.lng)),
      );
    }
  }
  return nearest;
}

String formatDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
String formatDuration(double seconds) {
  final minutes = (seconds / 60).ceil();
  return minutes < 60
      ? '$minutes min'
      : '${minutes ~/ 60} h ${minutes % 60} min';
}
