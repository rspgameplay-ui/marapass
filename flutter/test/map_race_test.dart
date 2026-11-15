import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marapass_mapa/application/map_state.dart';
import 'package:marapass_mapa/data/tourism_repository.dart';
import 'package:marapass_mapa/domain/tourism.dart';

class DelayedCatalog extends TourismRepository {
  DelayedCatalog(super.prefs) {
    seed = [];
  }
  final pending = <Completer<CatalogResult>>[];
  @override
  Future<CatalogResult> fetchVisible(GeoBounds bounds) {
    final c = Completer<CatalogResult>();
    pending.add(c);
    return c.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'resposta da área anterior é descartada assim que a câmera muda',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = DelayedCatalog(await SharedPreferences.getInstance());
      final coordinator = MapCoordinator(repo);
      coordinator.viewport(const GeoBounds(-8, -48, -6, -46), 8);
      repo.pending.first.complete(
        CatalogResult([
          TourismPlace(
            id: 'old',
            name: 'Resposta antiga',
            city: 'São Luís',
            point: const GeoPoint(-2.5, -44.3),
            category: PlaceCategory.culture,
            description: '',
            isPartner: true,
          ),
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.state.places.any((p) => p.id == 'old'), isFalse);
      coordinator.dispose();
    },
  );
}
