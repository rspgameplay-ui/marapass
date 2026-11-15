import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/location/ahead_filter.dart';

void main() {
  test('o rumo do Safari pode ser inferido de dois pontos GPS confiáveis', () {
    final now = DateTime.now();
    Position position(double lat, DateTime time, {double accuracy = 6}) =>
        Position(
          latitude: lat,
          longitude: -44.3,
          timestamp: time,
          accuracy: accuracy,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: -1,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
    final before = position(-2.5, now.subtract(const Duration(seconds: 5)));
    expect(travelCourse(position(-2.4997, now), before), closeTo(0, .1));
    expect(travelCourse(position(-2.5003, now), before), closeTo(180, .1));
    expect(travelCourse(position(-2.49999, now), before), isNull);
    expect(travelCourse(position(-2.4997, now, accuracy: 70), before), isNull);
    expect(travelCourse(position(-2.4997, now), null), isNull);
  });

  const p = GeoPoint(-2.5, -44.3);
  test('direção de movimento diferencia frente e trás', () {
    expect(isAhead(p, const GeoPoint(-2.4, -44.3), 0), isTrue);
    expect(isAhead(p, const GeoPoint(-2.6, -44.3), 0), isFalse);
    expect(isAhead(p, const GeoPoint(-2.6, -44.3), 180), isTrue);
    expect(isAhead(p, p, 180), isFalse);
  });
}
