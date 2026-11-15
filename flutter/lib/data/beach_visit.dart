import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/navigation.dart';
import '../domain/tourism.dart';
import 'routing_repository.dart';

const semaReports = 'https://www.sema.ma.gov.br/laudos-de-balneabilidade';
const saoLuisTides = 'https://pam.marinha.mil.br/tabuamares/tabuamares.html';
const pontaAreiaId = 'osm:node:7700339995';

class BeachAccess {
  const BeachAccess({
    required this.id,
    required this.name,
    required this.point,
    required this.verified,
    this.samplingPoint,
  });
  final String id, name;
  final GeoPoint point;
  final bool verified;
  final String? samplingPoint;
}

// P01–P03 are sampling locations from the SEMA report. The router uses them
// to find the nearest accessible path; the samples themselves are in the water.
List<BeachAccess> beachAccesses(TourismPlace beach) => beach.id == pontaAreiaId
    ? const [
        BeachAccess(
          id: 'praia-mar',
          name: 'Rampa ao lado do Hotel Praia Mar',
          point: GeoPoint(-2.497611111111, -44.312305555556),
          verified: false,
          samplingPoint: 'P02',
        ),
        BeachAccess(
          id: 'espigao',
          name: 'Entorno do Espigão Costeiro',
          point: GeoPoint(-2.5003, -44.319805555556),
          verified: false,
          samplingPoint: 'P01',
        ),
        BeachAccess(
          id: 'praca-sol',
          name: 'Entorno da Praça do Sol',
          point: GeoPoint(-2.494305555556, -44.307805555556),
          verified: false,
          samplingPoint: 'P03',
        ),
      ]
    : [
        BeachAccess(
          id: 'principal',
          name: beach.referenceLocation
              ? 'Via próxima à praia'
              : 'Acesso principal',
          point: beach.point,
          verified: !beach.referenceLocation,
        ),
      ];

const semaPontaAreia =
    'https://www.sema.ma.gov.br/uploads/sema/docs/Laudo_de_Balneabilidade_09_11_2026.pdf';
final semaCollection = DateTime.utc(2026, 11, 9, 3);
const semaResults = {'P01': 'Próprio', 'P02': 'Próprio', 'P03': 'Impróprio'};

DateTime saoLuisLocalTime(DateTime now) =>
    now.toUtc().subtract(const Duration(hours: 3));

String? recentBathingResult(BeachAccess access, DateTime now) {
  if (now.isBefore(semaCollection) ||
      !now.isBefore(semaCollection.add(const Duration(days: 7)))) {
    return null;
  }
  return semaResults[access.samplingPoint];
}

double visitBearing(GeoPoint from, GeoPoint to) =>
    (const Distance().bearing(
          LatLng(from.lat, from.lng),
          LatLng(to.lat, to.lng),
        ) +
        360) %
    360;

String compassDirection(double bearing) => const [
  'N',
  'NE',
  'L',
  'SE',
  'S',
  'SO',
  'O',
  'NO',
][((bearing + 22.5) / 45).floor() % 8];

class VisitPlan {
  const VisitPlan(
    this.route,
    this.origin,
    this.response, {
    this.downloaded = false,
  });
  final RoadRoute route;
  final GeoPoint origin;
  final String response;
  final bool downloaded;
}

class DownloadedVisitRoutes {
  DownloadedVisitRoutes(this.preferences);
  final SharedPreferences preferences;
  static const _key = 'marapass_visit_routes_v1';

  Map<String, dynamic> _read() {
    try {
      return jsonDecode(preferences.getString(_key) ?? '{}')
          as Map<String, dynamic>;
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  VisitPlan? load(String key, GeoPoint current) {
    final value = _read()[key];
    if (value is! Map) return null;
    try {
      final origin = GeoPoint(
        (value['lat'] as num).toDouble(),
        (value['lng'] as num).toDouble(),
      );
      final response = value['route'] as String;
      final route = RoadRoute.fromOsrm(
        jsonDecode(response) as Map<String, dynamic>,
        value['index'] as int,
      );
      if (origin.distanceKm(current) > .1) return null;
      return VisitPlan(route, origin, response, downloaded: true);
    } catch (_) {
      return null;
    }
  }

  Future<bool> save(String key, VisitPlan plan, int index) {
    final entries = _read()..remove(key);
    while (entries.length >= 8) {
      entries.remove(entries.keys.first);
    }
    entries[key] = {
      'lat': plan.origin.lat,
      'lng': plan.origin.lng,
      'route': plan.response,
      'index': index,
    };
    return preferences.setString(_key, jsonEncode(entries));
  }
}

Future<(VisitPlan, int)> calculateVisitRoute(
  RoutingRepository routing,
  GeoPoint origin,
  BeachAccess access,
  RoutingProfile profile,
) async {
  var raw = '';
  final routes = await routing.routes(
    origin,
    access.point,
    profile: profile,
    onResponse: (response) => raw = response,
  );
  final index = routes.indexWhere(
    (r) => !r.hasFerry && r.steps.every((s) => s.mode == profile.name),
  );
  if (index < 0) {
    throw const FormatException(
      'Nenhuma rota terrestre disponível para este acesso.',
    );
  }
  return (VisitPlan(routes[index], origin, raw), index);
}

typedef TideEvent = ({DateTime time, double height, bool high});

class SaoLuisTideForecast {
  const SaoLuisTideForecast(this.events, this.hourly);
  final List<TideEvent> events;
  final List<double> hourly;

  static Future<SaoLuisTideForecast?> load() async {
    try {
      final data = jsonDecode(
        await rootBundle.loadString('assets/data/tides_sao_luis_2026.json'),
      ) as Map;
      return SaoLuisTideForecast(
        (data['events'] as List)
            .map(
              (event) => (
                time: DateTime.parse(event[0] as String),
                height: (event[1] as num).toDouble(),
                high: event[2] as bool,
              ),
            )
            .toList(),
        (data['hourly'] as List)
            .map((hour) => (hour as num).toDouble())
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  ({TideEvent next, double height})? at(DateTime now) {
    final minutes = now.difference(DateTime.utc(2026, 1, 1, 3)).inMinutes;
    if (minutes < 0) return null;
    final hour = minutes ~/ 60;
    if (hour + 1 >= hourly.length) return null;
    final next = events.indexWhere((event) => event.time.isAfter(now));
    if (next <= 0 ||
        events[next].time.difference(events[next - 1].time).inHours >= 10)
      return null;
    final height =
        hourly[hour] + (hourly[hour + 1] - hourly[hour]) * (minutes % 60) / 60;
    return (next: events[next], height: height);
  }
}
