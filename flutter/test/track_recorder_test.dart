import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marapass_mapa/location/location_service.dart';
import 'package:marapass_mapa/recording/track_recorder.dart';

import 'location_service_test.dart' show FakeLocation;

Position sample(double lat, int offset, {double accuracy = 5}) => Position(
  latitude: lat,
  longitude: -43.25,
  timestamp: DateTime.now().subtract(Duration(seconds: 8 - offset)),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
Future<void> flush() => Future<void>.delayed(const Duration(milliseconds: 5));
void main() {
  test(
    'pausar e retomar não conecta deslocamento; salvar restaura os segmentos',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gps = FakeLocation();
      final recorder = TrackRecorder(
        prefs,
        location: LocationService(gateway: gps),
      );
      final start = recorder.start();
      await flush();
      gps.streams.last.add(sample(-2.5, 0));
      await start;
      gps.streams.last.add(sample(-2.49995, 1));
      await flush();
      await recorder.pause();
      final distance = recorder.draft!.kilometers;
      final resume = recorder.start();
      await flush();
      gps.streams.last.add(sample(-2.4, 2));
      await resume;
      gps.streams.last.add(sample(-2.39995, 3));
      await flush();
      await recorder.pause();
      expect(recorder.draft!.segments.map((s) => s.length), [2, 2]);
      expect(recorder.draft!.kilometers, closeTo(distance * 2, .0001));
      expect(await recorder.save('Minha caminhada'), isTrue);
      final restored = TrackRecorder(prefs);
      expect(restored.saved.single.name, 'Minha caminhada');
      expect(restored.saved.single.points.length, 4);
      expect(restored.draft, isNull);
      recorder.dispose();
      restored.dispose();
      await flush();
    },
  );
  test('GPS impreciso e saltos não geram distância artificial', () async {
    SharedPreferences.setMockInitialValues({});
    final gps = FakeLocation();
    final recorder = TrackRecorder(
      await SharedPreferences.getInstance(),
      location: LocationService(gateway: gps),
    );
    final starting = recorder.start();
    await flush();
    gps.streams.last.add(sample(-2.5, 0));
    await starting;
    gps.streams.last.add(sample(-2.4999, 1, accuracy: 100));
    gps.streams.last.add(sample(-2.0, 2));
    await flush();
    expect(recorder.draft!.points.length, 1);
    expect(recorder.canSave, isFalse);
    expect(recorder.draft!.kilometers, 0);
    await recorder.pause();
    recorder.dispose();
    await flush();
  });
  test('cancelar busca não cria gravação após o cancelamento', () async {
    SharedPreferences.setMockInitialValues({});
    final gps = FakeLocation();
    final recorder = TrackRecorder(
      await SharedPreferences.getInstance(),
      location: LocationService(gateway: gps),
    );
    final start = recorder.start();
    await flush();
    await recorder.pause();
    await start;
    expect(recorder.active, isFalse);
    expect(recorder.busy, isFalse);
    expect(recorder.draft, isNull);
    expect(gps.cancelled, 1);
    recorder.dispose();
    await flush();
  });
  test('dados ilegíveis são preservados e bloqueiam sobrescrita', () async {
    SharedPreferences.setMockInitialValues({
      TrackRecorder.storageKey: 'invalid-json',
    });
    final prefs = await SharedPreferences.getInstance();
    final recorder = TrackRecorder(prefs);
    await recorder.start();
    await recorder.discard();
    expect(recorder.damaged, isTrue);
    expect(prefs.getString(TrackRecorder.storageKey), 'invalid-json');
    recorder.dispose();
    await flush();
  });
}
