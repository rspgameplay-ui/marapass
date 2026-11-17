import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../domain/navigation.dart';
import '../domain/tourism.dart';

enum RoutingProfile { driving, walking }

class RoutingRepository {
  RoutingRepository({http.Client? client, this.baseUrl = AppConfig.routingUrl})
    : client = client ?? http.Client();
  final http.Client client;
  final String baseUrl;
  DateTime? _lastRequest;
  bool _busy = false;
  /// Rota única passando por várias paradas, na ordem dada (roteiro do dia).
  Future<RoadRoute> routeThrough(List<GeoPoint> stops) async {
    if (stops.length < 2) {
      throw const FormatException('O roteiro precisa de ao menos duas paradas.');
    }
    final coords = stops.map((p) => '${p.lng},${p.lat}').join(';');
    final uri = Uri.parse('$baseUrl/route/v1/driving/$coords').replace(
      queryParameters: {
        'steps': 'true',
        'overview': 'full',
        'geometries': 'geojson',
        'radiuses': List.filled(stops.length, '1000').join(';'),
      },
    );
    final response = await client
        .get(
          uri,
          headers: kIsWeb
              ? null
              : {'User-Agent': 'MaraPass/0.2 (+https://marapass.com)'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw const FormatException(
        'Serviço de rotas indisponível. Tente novamente com conexão.',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['code'] != 'Ok') {
      throw const FormatException('Não foi possível ligar todas as paradas por estrada.');
    }
    return RoadRoute.fromOsrm(json, 0);
  }

  Future<List<RoadRoute>> routes(
    GeoPoint origin,
    GeoPoint destination, {
    RoutingProfile profile = RoutingProfile.driving,
    void Function(String response)? onResponse,
  }) async {
    if (_busy) {
      throw const FormatException('Aguarde o cálculo em andamento.');
    }
    if (origin.distanceKm(destination) < .025) {
      throw const FormatException('Origem e destino estão muito próximos.');
    }
    _busy = true;
    try {
      final lastRequest = _lastRequest;
      if (lastRequest != null) {
        final delay =
            const Duration(milliseconds: 1100) -
            DateTime.now().difference(lastRequest);
        if (!delay.isNegative) await Future<void>.delayed(delay);
      }
      _lastRequest = DateTime.now();
      final service = profile == RoutingProfile.walking
          ? AppConfig.walkingRoutingUrl
          : baseUrl;
      final uri =
          Uri.parse(
            '$service/route/v1/${profile.name}/${origin.lng},${origin.lat};${destination.lng},${destination.lat}',
          ).replace(
            queryParameters: {
              'steps': 'true',
              'overview': 'full',
              'geometries': 'geojson',
              'alternatives': 'true',
              'radiuses': '500;500',
            },
          );
      final response = await client
          .get(
            uri,
            headers: kIsWeb
                ? null
                : {'User-Agent': 'MaraPass/0.2 (+https://marapass.com)'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 429) {
        throw const FormatException(
          'Serviço de rotas ocupado. Aguarde antes de tentar novamente.',
        );
      }
      if (response.statusCode != 200 && response.statusCode != 400) {
        throw const FormatException(
          'Serviço de rotas indisponível. Tente novamente com conexão.',
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['code'] == 'NoSegment') {
        throw const FormatException(
          'Não há via acessível a até 500 m de um dos pontos. Escolha uma entrada ou acesso rodoviário.',
        );
      }
      if (json['code'] != 'Ok') {
        throw const FormatException(
          'Não foi encontrada uma ligação rodoviária. Travessias e acessos podem exigir outro transporte.',
        );
      }
      final routes = List.generate(
        (json['routes'] as List).length.clamp(0, 3),
        (i) => RoadRoute.fromOsrm(json, i),
      );
      onResponse?.call(response.body);
      return routes;
    } finally {
      _busy = false;
    }
  }
}
