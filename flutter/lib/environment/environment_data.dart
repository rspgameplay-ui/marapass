import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';

String windCompass(num degrees) => [
  'N',
  'NE',
  'L',
  'SE',
  'S',
  'SO',
  'O',
  'NO',
][((degrees % 360) / 45).round() % 8];
String weatherDescription(String symbol) {
  if (symbol.contains('thunder')) return 'Trovoadas';
  if (symbol.contains('rain')) return 'Chuva';
  if (symbol.contains('fog')) return 'Nevoeiro';
  if (symbol.contains('partlycloudy')) return 'Parcialmente nublado';
  if (symbol.contains('cloudy')) return 'Nublado';
  if (symbol.contains('fair')) return 'Poucas nuvens';
  if (symbol.contains('clearsky')) return 'Céu limpo';
  return 'Condição não informada';
}

class EnvironmentalForecast {
  EnvironmentalForecast(this.json);
  final Map<String, dynamic> json;
  Map<String, dynamic>? at(DateTime now) {
    Map<String, dynamic>? best;
    int? distance;
    for (final p in json['points'] as List) {
      final time = DateTime.tryParse('${p['time']}');
      if (time == null) continue;
      final d = time.difference(now).inSeconds.abs();
      if (distance == null || d < distance) {
        distance = d;
        best = Map<String, dynamic>.from(p);
      }
    }
    return distance != null && distance <= 5400 ? best : null;
  }
}

class EnvironmentService {
  EnvironmentService({http.Client? client}) : client = client ?? http.Client();
  final http.Client client;
  static final shared = EnvironmentService();
  final cache = <String, ({DateTime fetched, EnvironmentalForecast data})>{};
  Future<EnvironmentalForecast> load(String city) async {
    final saved = cache[city];
    if (saved != null &&
        DateTime.now().difference(saved.fetched).inMinutes < 10) {
      return saved.data;
    }
    final response = await client
        .get(
          Uri.parse(
            '${AppConfig.supabaseUrl}/functions/v1/marapass-environment',
          ).replace(queryParameters: {'city': city}),
          headers: {'apikey': AppConfig.publishableKey},
        )
        .timeout(const Duration(seconds: 18));
    if (response.statusCode != 200) throw StateError('Previsão indisponível');
    final j = jsonDecode(response.body) as Map<String, dynamic>;
    final data = EnvironmentalForecast(j);
    if (j['city']?['code'] != city || data.at(DateTime.now()) == null) {
      throw StateError('Previsão fora da validade');
    }
    cache[city] = (fetched: DateTime.now(), data: data);
    return data;
  }
}
