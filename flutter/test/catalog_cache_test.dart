import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/mvp/data/catalog_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('guarda a resposta do servidor e a usa quando a rede falha', () async {
    final cache = CatalogCache(await SharedPreferences.getInstance());
    final fresh = await cache.rows('exp::', () async => [
      {'id': 'a', 'title': 'Passeio'},
    ]);
    expect(fresh.single['title'], 'Passeio');
    expect(CatalogCache.servingStale, isFalse);

    final offline = await cache.rows('exp::', () async => throw Exception('sem rede'));
    expect(offline.single['id'], 'a');
    expect(CatalogCache.servingStale, isTrue);
  });

  test('sem cópia guardada, o erro de rede continua aparecendo', () async {
    final cache = CatalogCache(await SharedPreferences.getInstance());
    expect(
      () => cache.rows('off:', () async => throw Exception('sem rede')),
      throwsException,
    );
  });

  test('uma resposta nova substitui a cópia antiga', () async {
    final cache = CatalogCache(await SharedPreferences.getInstance());
    await cache.rows('est:', () async => [{'id': '1'}]);
    await cache.rows('est:', () async => [{'id': '2'}]);
    final offline = await cache.rows('est:', () async => throw Exception('x'));
    expect(offline.single['id'], '2');
  });
}
