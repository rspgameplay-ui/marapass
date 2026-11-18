import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marapass_mapa/data/tourism_repository.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/journey/journey.dart';
import 'package:marapass_mapa/journey/journey_controller.dart';

import 'navigation_test.dart' show road;

TourismPlace poi(
  String id, {
  double lng = -44.295,
  double lat = -2.53,
  PlaceCategory category = PlaceCategory.culture,
  bool coupon = false,
  DateTime? checked,
}) => TourismPlace(
  id: id,
  name: id,
  city: 'São Luís',
  description: 'Informação pública',
  point: GeoPoint(lat, lng),
  category: category,
  isPartner: coupon,
  offersFresh: coupon,
  offerId: coupon ? 'offer-$id' : null,
  offerTitle: coupon ? 'Benefício de teste' : null,
  offerCheckedAt: checked ?? DateTime.now(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'seleção usa corredor real da rota, interesses, salvos e posição à frente',
    () {
      final route = road(), index = JourneyIndex();
      final candidates = index.candidates(route, [
        poi('cultura'),
        poi('longe', lat: -2.60),
        poi('comida', category: PlaceCategory.gastronomy),
        poi('passado', lng: -44.299),
        poi('futuro', lng: -44.29, lat: -2.52),
      ]);
      const preferences = JourneyPreferences(
        interests: {PlaceCategory.culture},
        corridorMeters: 500,
        aheadMeters: 5000,
      );
      final chosen = recommendJourney(
        candidates,
        preferences,
        progress: 500,
        traveling: true,
      );
      expect(chosen.map((e) => e.place.id), ['cultura', 'futuro']);
      final saved = recommendJourney(
        candidates,
        preferences,
        mode: JourneyMode.saved,
        saved: {'futuro'},
      );
      expect(saved.single.place.id, 'futuro');
      expect(
        recommendJourney(
          candidates,
          preferences,
          destinationId: 'cultura',
        ).any((e) => e.place.id == 'cultura'),
        isFalse,
      );
    },
  );
  test('cupom exige parceiro, ID, publicação recente e vigência; cache nunca ativa', () {
    final now = DateTime.now();
    final p = poi('parceiro', coupon: true, checked: now);
    expect(p.hasCouponAt(now), isTrue);
    expect(p.hasCouponAt(now.add(const Duration(seconds: 90))), isFalse);
    expect(TourismPlace.fromJson(p.toJson()).hasCoupon, isFalse);
    final future = TourismPlace.fromJson({
      ...p.toJson(),
      'offersFresh': true,
      'offerStartsAt': now.add(const Duration(days: 1)).toIso8601String(),
    });
    final missingId = TourismPlace.fromJson({
      ...p.toJson(),
      'offersFresh': true,
      'offerId': null,
    });
    final unverified = TourismPlace.fromJson({
      ...p.toJson(),
      'offersFresh': true,
      'isPartner': false,
    });
    final expired = TourismPlace.fromJson({
      ...p.toJson(),
      'offersFresh': true,
      'offerEndsAt': now.subtract(const Duration(seconds: 1)).toIso8601String(),
    });
    expect(
      [
        future,
        missingId,
        unverified,
        expired,
      ].every((e) => !e.hasCouponAt(now)),
      isTrue,
    );
    final candidates = JourneyIndex().candidates(road(), [
      p,
      unverified,
      poi('osm'),
    ]);
    expect(
      recommendJourney(
        candidates,
        const JourneyPreferences(),
        mode: JourneyMode.coupons,
      ).map((e) => e.place.id),
      ['parceiro'],
    );
  });
  test('índice reflete edição de coordenadas e retirada de ponto', () {
    final route = road(), index = JourneyIndex();
    expect(index.candidates(route, [poi('editável')]), hasLength(1));
    expect(index.candidates(route, [poi('editável', lat: -3)]), isEmpty);
    expect(index.candidates(route, []), isEmpty);
  });
  test(
    'preferências persistem sem conta e valores corrompidos retornam ao padrão',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = TourismRepository(prefs, apiUrl: '', publishableKey: '');
      final first = JourneyController(repo);
      await first.personalize(
        const JourneyPreferences(
          interests: {PlaceCategory.crafts},
          corridorMeters: 5000,
          aheadMeters: 50000,
        ),
      );
      first.dispose();
      final reopened = JourneyController(repo);
      expect(reopened.preferences.interests, {PlaceCategory.crafts});
      expect(reopened.preferences.corridorMeters, 5000);
      reopened.dispose();
      await prefs.setString(JourneyController.key, '{broken');
      final reset = JourneyController(repo);
      expect(reset.preferences.corridorMeters, 2000);
      reset.dispose();
      repo.client.close();
    },
  );
  test(
    'atualização retira oferta removida e falha de rede retira confirmação',
    () async {
      var online = true, published = true;
      final repo = TourismRepository(
        await SharedPreferences.getInstance(),
        apiUrl: 'https://test.invalid',
        publishableKey: 'public',
        client: MockClient((r) async {
          if (!online) return http.Response('', 503);
          if (r.url.path.endsWith('/establishments')) {
            return http.Response(
              jsonEncode([
                {
                  'id': 'p',
                  'name': 'Parceiro de teste',
                  'city': 'São Luís',
                  'description': '',
                  'category': 'culture',
                  'latitude': -2.53,
                  'longitude': -44.295,
                },
              ]),
              200,
            );
          }
          return http.Response(
            jsonEncode(
              published
                  ? [
                      {
                        'id': 'o',
                        'establishment_id': 'p',
                        'title': 'Oferta de teste',
                        'starts_at': null,
                        'ends_at': null,
                      },
                    ]
                  : [],
            ),
            200,
          );
        }),
      );
      final c = JourneyController(repo), r = road();
      await c.refresh(r);
      expect(c.partners.single.hasCoupon, isTrue);
      online = false;
      await c.refresh(r);
      expect(c.offline, isTrue);
      expect(c.partners.single.hasCoupon, isFalse);
      online = true;
      published = false;
      await c.refresh(r);
      expect(c.partners.single.hasCoupon, isFalse);
      c.dispose();
      repo.client.close();
    },
  );
  test('resposta de rota anterior não contamina uma seleção nova', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final repo = TourismRepository(
      await SharedPreferences.getInstance(),
      apiUrl: 'https://test.invalid',
      publishableKey: 'public',
      client: MockClient((r) async {
        calls++;
        return calls == 1 ? pending.future : http.Response('[]', 200);
      }),
    );
    final c = JourneyController(repo);
    final previous = c.refresh(road());
    await Future<void>.delayed(Duration.zero);
    await c.refresh(road());
    pending.complete(
      http.Response(
        jsonEncode([
          {
            'id': 'old',
            'name': 'Anterior',
            'city': 'São Luís',
            'category': 'culture',
            'latitude': -2.53,
            'longitude': -44.295,
          },
        ]),
        200,
      ),
    );
    await previous;
    expect(c.partners, isEmpty);
    expect(c.loading, isFalse);
    c.dispose();
    repo.client.close();
  });
}
