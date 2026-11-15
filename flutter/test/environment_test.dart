import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marapass_mapa/domain/municipality.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/environment/environment_data.dart';
import 'package:marapass_mapa/environment/environment_control.dart';
import 'package:marapass_mapa/environment/map_appearance.dart';

Map<String, dynamic> fixture() => {
  'city': {'code': '2111300'},
  'modelUpdatedAt': DateTime.now().toUtc().toIso8601String(),
  'source': 'MET Norway · ECMWF',
  'points': [
    {
      'time': DateTime.now().toUtc().toIso8601String(),
      'temperature': 29.2,
      'windKmh': 18.3,
      'windFrom': 45,
      'humidity': 70,
      'gustKmh': null,
      'symbol': 'partlycloudy_day',
      'rainMm': 0,
      'rainHours': 1,
    },
  ],
};
void main() {
  test('appearance uses destination UTC-3 and explicit modes', () {
    expect(
      mapIsNight(MapAppearance.automatic, DateTime.utc(2026, 11, 7, 20)),
      false,
    );
    expect(
      mapIsNight(MapAppearance.automatic, DateTime.utc(2026, 11, 7, 21)),
      true,
    );
    expect(mapIsNight(MapAppearance.day, DateTime.utc(2026, 11, 7, 23)), false);
  });
  test('wind compass wraps and uses Portuguese east/west', () {
    expect(windCompass(359), 'N');
    expect(windCompass(90), 'L');
    expect(windCompass(270), 'O');
    expect(windCompass(45), 'NE');
  });
  test('expired point is never presented as current', () {
    final f = EnvironmentalForecast(fixture());
    expect(f.at(DateTime.now().add(const Duration(hours: 4))), isNull);
  });
  test('request sends municipality code, rejects another city', () async {
    final service = EnvironmentService(
      client: MockClient((r) async {
        expect(r.url.queryParameters, {'city': '2111300'});
        expect(r.headers.containsKey('Authorization'), false);
        final j = fixture();
        j['city'] = {'code': '2101707'};
        return http.Response(jsonEncode(j), 200);
      }),
    );
    await expectLater(service.load('2111300'), throwsStateError);
  });
  testWidgets('compact weather and detailed sheet fit narrow scaled screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = EnvironmentService(
      client: MockClient(
        (r) async => http.Response(jsonEncode(fixture()), 200),
      ),
    );
    const city = Municipality(
      id: '2111300',
      name: 'São Luís',
      point: GeoPoint(-2.5, -44.3),
      bounds: GeoBounds.maranhao,
      region: '',
      intermediateRegion: '',
      mappedPlaces: 0,
      areaKm2: 0,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 740),
              textScaler: TextScaler.linear(1.6),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 224,
                  child: EnvironmentControl(city: city, service: service),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('São Luís'));
    await tester.pumpAndSettle();
    expect(find.text('Tempo e paisagem'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
