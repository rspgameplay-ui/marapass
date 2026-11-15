import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marapass_mapa/data/published_catalog.dart';
import 'package:marapass_mapa/domain/tourism.dart';

const base = TourismPlace(
  id: 'osm:node:1',
  name: 'Nome de referência',
  city: 'São Luís',
  point: GeoPoint(-2.53, -44.3),
  category: PlaceCategory.culture,
  description: 'Referência',
);
Map<String, dynamic> published(String name, int revision) => {
  'id': base.id,
  'content': {...base.toJson(), 'name': name},
  'is_visible': true,
  'revision': revision,
  'published_at': '2026-10-30T15:00:00Z',
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('dois dispositivos recebem a publicação e preservam cache offline; arquivo suprime referência', () async {
    final prefs = await SharedPreferences.getInstance();
    var rows = [published('Primeira publicação', 2)];
    var online = true;
    final client = MockClient((r) async {
      expect(r.url.path, endsWith('/map_publications'));
      expect(r.headers['apikey'], 'public-key');
      expect(r.headers.containsKey('authorization'), false);
      if (!online) return http.Response('', 503);
      return http.Response(jsonEncode(rows), 200);
    });
    final computer = PublishedCatalog(
      client,
      prefs,
      'https://example.test',
      'public-key',
    );
    final phone = PublishedCatalog(
      client,
      prefs,
      'https://example.test',
      'public-key',
    );
    await computer.refresh();
    await phone.refresh();
    expect(phone.merge([base]).single.name, 'Primeira publicação');
    rows = [published('Publicação editada no computador', 4)];
    await phone.refresh();
    expect(phone.merge([base]).single.name, 'Publicação editada no computador');
    online = false;
    await phone.refresh();
    expect(phone.offline, true);
    expect(phone.merge([base]).single.name, 'Publicação editada no computador');
    final reopened = PublishedCatalog(
      client,
      prefs,
      'https://example.test',
      'public-key',
    )..restoreCache();
    expect(
      reopened.merge([base]).single.name,
      'Publicação editada no computador',
    );
    online = true;
    rows = [
      {'id': base.id, 'content': null, 'is_visible': false, 'revision': 6},
    ];
    await phone.refresh();
    expect(phone.merge([base]), isEmpty);
    expect(phone.offline, false);
  });
  test('falha numa página mantém snapshot inteiro anterior, sem misturar catálogo parcial', () async {
    final prefs = await SharedPreferences.getInstance();
    var paged = false;
    final client = MockClient((r) async {
      if (!paged) {
        return http.Response(jsonEncode([published('Versão íntegra', 2)]), 200);
      }
      if (r.url.queryParameters['id'] != null) return http.Response('', 500);
      return http.Response(
        jsonEncode(
          List.generate(500, (i) => {...published('Parcial', 4), 'id': 'id$i'}),
        ),
        200,
      );
    });
    final catalog = PublishedCatalog(
      client,
      prefs,
      'https://example.test',
      'key',
    );
    await catalog.refresh();
    paged = true;
    await catalog.refresh();
    expect(catalog.offline, true);
    expect(catalog.merge([base]).single.name, 'Versão íntegra');
  });
}
