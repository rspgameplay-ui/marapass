import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../domain/tourism.dart';

class CalendarOffer {
  CalendarOffer(this.place, this.title, this.id, this.startsAt, this.endsAt);
  final TourismPlace place;
  final String title, id;
  final DateTime? startsAt, endsAt;
  factory CalendarOffer.fromJson(Map<String, dynamic> j) => CalendarOffer(
    TourismPlace(
      id: j['establishment_id'] as String,
      name: j['name'] as String,
      city: j['city'] as String,
      point: GeoPoint(
        (j['lat'] as num).toDouble(),
        (j['lng'] as num).toDouble(),
      ),
      category: PlaceCategory.parse(j['category'] as String),
      description: 'Estabelecimento público do catálogo MaraPass. Oferta com vigência compatível com a data consultada; confira dias, horários e regras na emissão.',
      address: j['address'] as String?,
      isPartner: true,
      referenceLocation: false,
    ),
    j['title'] as String,
    j['offer_id'] as String,
    DateTime.tryParse(j['starts_at'] as String? ?? ''),
    DateTime.tryParse(j['ends_at'] as String? ?? ''),
  );
}

class OfferCalendar {
  OfferCalendar({
    http.Client? client,
    this.url = AppConfig.supabaseUrl,
    this.key = AppConfig.publishableKey,
  }) : client = client ?? http.Client();
  final http.Client client;
  final String url, key;
  Future<List<CalendarOffer>> search(
    DateTime day,
    String city, {
    PlaceCategory? category,
    String term = '',
  }) async {
    if (url.isEmpty || key.isEmpty)
      throw const FormatException(
        'A consulta de ofertas precisa de conexão com o catálogo.',
      );
    final date =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final r = await client
        .post(
          Uri.parse('$url/rest/v1/rpc/map_offer_calendar'),
          headers: {'apikey': key, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'p_day': date,
            'p_city': city,
            'p_category': category?.name,
            'p_term': term,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200)
      throw const FormatException(
        'Não foi possível consultar as ofertas. Tente novamente com internet.',
      );
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final rows = data['offers'] as List;
    if (rows.length > 100)
      throw const FormatException(
        'Muitas ofertas neste município. Refine a pesquisa antes de continuar.',
      );
    return rows
        .map((j) => CalendarOffer.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  void dispose() => client.close();
}
