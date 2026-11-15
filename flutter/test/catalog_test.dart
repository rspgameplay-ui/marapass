import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marapass_mapa/data/tourism_repository.dart';
import 'package:marapass_mapa/domain/tourism.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'consulta apenas parceiros públicos da área e descarta ofertas vencidas',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final client = MockClient((r) async {
        expect(r.headers['apikey'], 'public-test-key');
        expect(r.headers.containsKey('authorization'), isFalse);
        if (r.url.path.endsWith('establishments')) {
          expect(r.url.queryParameters['is_public'], 'eq.true');
          expect(r.url.queryParameters['is_active'], 'eq.true');
          expect(r.url.queryParameters['and'], contains('latitude.gte.-10.3'));
          return http.Response(
            jsonEncode([
              {
                'id': 'p1',
                'name': 'Parceiro homologado',
                'city': 'São Luís',
                'category': 'gastronomy',
                'description': '',
                'latitude': -2.53,
                'longitude': -44.3,
              },
            ]),
            200,
          );
        }
        return http.Response(
          jsonEncode([
            {
              'id': 'o1',
              'establishment_id': 'p1',
              'title': 'Vencida',
              'ends_at': '2020-01-01T00:00:00Z',
            },
            {
              'id': 'o2',
              'establishment_id': 'p1',
              'title': 'Publicada',
              'starts_at': null,
              'ends_at': null,
            },
          ]),
          200,
        );
      });
      final repo = TourismRepository(
        prefs,
        client: client,
        apiUrl: 'https://catalog.example',
        publishableKey: 'public-test-key',
      );
      final result = await repo.fetchVisible(GeoBounds.maranhao);
      expect(result.error, isFalse);
      expect(result.places.single.offerTitle, 'Publicada');
      expect(result.places.single.hasCoupon, isTrue);
      expect(repo.cachedPartners().single.hasCoupon, isFalse);
      client.close();
    },
  );
  test(
    'falha de rede vira estado de contingência, sem apagar dados locais',
    () async {
      final repo = TourismRepository(
        await SharedPreferences.getInstance(),
        apiUrl: 'https://catalog.example',
        publishableKey: 'public-test-key',
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );
      final result = await repo.fetchVisible(GeoBounds.maranhao);
      expect(result.error, isTrue);
      expect(result.places, isEmpty);
      repo.client.close();
    },
  );
}
