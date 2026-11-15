import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marapass_mapa/application/map_state.dart';
import 'package:marapass_mapa/data/catalog_workspace.dart';
import 'package:marapass_mapa/data/tourism_repository.dart';
import 'package:marapass_mapa/domain/tourism.dart';

CatalogEntry entry(
  String id,
  CatalogStatus status, {
  String name = 'Meu atrativo',
}) => CatalogEntry(
  place: TourismPlace(
    id: id,
    name: name,
    city: 'São Luís',
    point: const GeoPoint(-2.53, -44.3),
    category: PlaceCategory.culture,
    description: 'Visita cultural',
    tags: 'azulejos',
    address: 'Rua de referência',
  ),
  kind: CatalogKind.attraction,
  status: status,
  updatedAt: DateTime.utc(2026, 10, 29),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('rascunho, visibilidade, busca e persistência sobrevivem a atualização remota', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = TourismRepository(prefs, apiUrl: '', publishableKey: '')
      ..seed = [entry('seed', CatalogStatus.visible).place];
    final coordinator = MapCoordinator(repo);
    await coordinator.refresh();
    await coordinator.saveEntry(entry('local:test', CatalogStatus.draft));
    expect(coordinator.state.places.length, 1);
    await coordinator.saveEntry(
      entry('local:test', CatalogStatus.visible, name: 'Museu da cidade'),
    );
    coordinator.query('azulejos');
    expect(coordinator.state.filtered.length, 2);
    await coordinator.refresh();
    expect(
      coordinator.state.places.any((p) => p.name == 'Museu da cidade'),
      isTrue,
    );
    expect(
      CatalogWorkspace(prefs).entries.single.place.name,
      'Museu da cidade',
    );
    await coordinator.saveEntry(entry('seed', CatalogStatus.archived));
    expect(coordinator.state.places.any((p) => p.id == 'seed'), isFalse);
    await coordinator.removeEntry('seed');
    expect(coordinator.state.places.any((p) => p.id == 'seed'), isTrue);
    final restored = MapCoordinator(repo);
    expect(
      restored.state.places.any((p) => p.name == 'Museu da cidade'),
      isTrue,
    );
    restored.dispose();
    coordinator.dispose();
  });
  test('backup inválido nunca substitui dados e importação mantém registros existentes', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = TourismRepository(prefs, apiUrl: '', publishableKey: '')
      ..seed = [];
    final coordinator = MapCoordinator(repo);
    await coordinator.refresh();
    await coordinator.saveEntry(entry('local:one', CatalogStatus.draft));
    final previous = prefs.getString(CatalogWorkspace.key);
    final duplicate = coordinator.workspace.encode([
      entry('x', CatalogStatus.draft),
      entry('x', CatalogStatus.visible),
    ]);
    await expectLater(
      coordinator.importEntries(duplicate),
      throwsFormatException,
    );
    expect(prefs.getString(CatalogWorkspace.key), previous);
    final json = coordinator.workspace.encode([
      entry('local:two', CatalogStatus.visible),
    ]);
    expect(await coordinator.importEntries(json), 1);
    expect(coordinator.entries.length, 2);
    expect(
      CatalogWorkspace.decode(coordinator.workspace.encode(coordinator.entries))
          .length,
      2,
    );
    expect(
      () => CatalogWorkspace.decode(json.replaceAll('-2.53', '0.0')),
      throwsFormatException,
    );
    expect(
      () => CatalogWorkspace.decode(
        json.replaceAll('"cat": "culture"', '"cat": null'),
      ),
      throwsFormatException,
    );
    coordinator.dispose();
  });
}
