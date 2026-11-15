import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marapass_mapa/domain/municipality.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/voice/command.dart';
import 'package:marapass_mapa/voice/offer_calendar.dart';

void main() {
  final cities =
      (jsonDecode(File('assets/data/municipalities.json').readAsStringSync())
              as List)
          .map((j) => Municipality.fromJson(Map<String, dynamic>.from(j)))
          .toList();
  final now = DateTime(2026, 11, 8);
  test('request resolves category, city and next January', () {
    final p = parseCommand(
      'Localize restaurante em Barreirinhas que tem cupons de descontos no dia 20 de janeiro',
      cities,
      now: now,
    );
    expect(p.error, isNull);
    expect(p.city!.name, 'Barreirinhas');
    expect(p.category, PlaceCategory.gastronomy);
    expect(p.day, DateTime(2027, 1, 20));
    expect(p.coupons, isTrue);
    expect(p.term, isEmpty);
    expect(p.summary, contains('20/01/2027'));
  });
  test('route request identifies destination without issuing a coupon', () {
    final p = parseCommand(
      'Trace uma rota para Barreirinhas',
      cities,
      now: now,
    );
    expect(p.route, isTrue);
    expect(p.term, isEmpty);
    expect(p.coupons, isFalse);
    expect(p.city!.name, 'Barreirinhas');
  });
  test('spoken date and article are not mistaken for a business name', () {
    final p = parseCommand(
      'Localize um restaurante em Barreirinhas com cupons dia vinte de janeiro',
      cities,
      now: now,
    );
    expect(p.day, DateTime(2027, 1, 20));
    expect(p.term, isEmpty);
  });
  test('invalid, old and ambiguous dates/cities are rejected', () {
    expect(
      parseCommand(
        'cupons em Barreirinhas dia 31 de fevereiro',
        cities,
        now: now,
      ).error,
      isNotNull,
    );
    expect(
      parseCommand(
        'cupons em Barreirinhas dia 20/01/2026',
        cities,
        now: now,
      ).error,
      isNotNull,
    );
    expect(
      parseCommand('cupons em Barreirinhas e São Luís', cities, now: now).error,
      isNotNull,
    );
    expect(
      parseCommand(
        'restaurante com cupons dia 20 de janeiro',
        cities,
        now: now,
      ).error,
      isNotNull,
    );
  });
  test('long municipality names do not create a second destination', () {
    final p = parseCommand(
      'rota para São Luís Gonzaga do Maranhão',
      cities,
      now: now,
    );
    expect(p.error, isNull);
    expect(p.city!.name, 'São Luís Gonzaga do Maranhão');
  });
  test('tomorrow respects year rollover', () {
    expect(
      parseCommand(
        'ofertas em Barreirinhas amanhã',
        cities,
        now: DateTime(2026, 12, 31),
      ).day,
      DateTime(2027, 1, 1),
    );
  });
  test(
    'calendar sends explicit date and future offers have no usable-now badge',
    () async {
      final c = OfferCalendar(
        url: 'https://example.test',
        key: 'public',
        client: MockClient((req) async {
          expect(req.url.path, '/rest/v1/rpc/map_offer_calendar');
          expect(jsonDecode(req.body), {
            'p_day': '2027-01-20',
            'p_city': 'Barreirinhas',
            'p_category': 'gastronomy',
            'p_term': '',
          });
          return http.Response(
            jsonEncode({
              'offers': [
                {
                  'offer_id': 'offer-test',
                  'establishment_id': 'place-test',
                  'name': 'Restaurante de teste',
                  'city': 'Barreirinhas',
                  'category': 'gastronomy',
                  'lat': -2.75,
                  'lng': -42.83,
                  'title': 'Oferta de teste',
                  'starts_at': '2027-01-19T03:00:00Z',
                  'ends_at': '2027-01-21T03:00:00Z',
                },
              ],
            }),
            200,
          );
        }),
      );
      final results = await c.search(
        DateTime(2027, 1, 20),
        'Barreirinhas',
        category: PlaceCategory.gastronomy,
      );
      expect(results.single.title, 'Oferta de teste');
      expect(results.single.place.hasCoupon, isFalse);
      c.dispose();
    },
  );
  test('offline is distinct from no offers', () async {
    final c = OfferCalendar(
      url: 'https://example.test',
      key: 'public',
      client: MockClient((_) async => http.Response('{}', 503)),
    );
    await expectLater(
      c.search(DateTime(2027, 1, 20), 'Barreirinhas'),
      throwsFormatException,
    );
    c.dispose();
  });
}
