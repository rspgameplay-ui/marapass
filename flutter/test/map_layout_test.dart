import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marapass_mapa/main.dart';
import 'package:marapass_mapa/application/map_state.dart';
import 'package:marapass_mapa/data/tourism_repository.dart';

void main() {
  testWidgets('map starts collapsed and list expands without losing search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'map_recent_places': ['ilha-lencois'],
    });
    final repo = TourismRepository(
      await SharedPreferences.getInstance(),
      apiUrl: '',
      publishableKey: '',
    );
    await tester.runAsync(repo.initialize);
    final c = MapCoordinator(repo)..engine(MapEngine.streets);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          mapStateProvider.overrideWith((ref) => c),
        ],
        child: const MaraPassApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Explore o Maranhão'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    final view = tester.getSize(find.byKey(const ValueKey('map-viewport')));
    double area(Size s) => s.width * s.height;
    final covered =
        area(tester.getSize(find.byKey(const ValueKey('map-search-bar')))) +
        area(tester.getSize(find.byKey(const ValueKey('map-weather')))) +
        view.width * 132 +
        2 * 44 * 44;
    expect(
      tester.getCenter(find.byType(TextField)).dy,
      greaterThan(view.height * .75),
    );
    final free = 1 - covered / area(view);
    print(
      'INITIAL_MAP_FREE_AREA=${(100 * free).toStringAsFixed(1)}% viewport=${view.width}x${view.height}',
    );
    expect(free, greaterThanOrEqualTo(.70));

    expect(tester.takeException(), isNull);
    final sheet = find.byType(DraggableScrollableSheet);
    expect(tester.getSize(sheet).height, greaterThan(500));
    await tester.drag(
      find.byKey(const ValueKey('map-dock-handle')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Explore o Maranhão'), findsOneWidget);
    expect(find.text('Recentes'), findsOneWidget);
    expect(find.text('Ilha dos Lençóis'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
