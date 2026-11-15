import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/domain/tourism.dart';

TourismPlace place(
  String id, {
  double lat = -2.53,
  double lng = -44.30,
  bool fresh = false,
  DateTime? end,
}) => TourismPlace(
  id: id,
  name: 'São Luís',
  city: 'São Luís',
  point: GeoPoint(lat, lng),
  category: PlaceCategory.culture,
  description: 'Centro histórico',
  offerTitle: 'Benefício',
  offerId: 'offer-$id',
  isPartner: true,
  offerCheckedAt: DateTime.now(),
  offersFresh: fresh,
  offerEndsAt: end,
);

void main() {
  test('busca normaliza acentos sem exigir teclado em português', () {
    expect(normalize('São Luís • AÇAILÂNDIA'), 'sao luis • acailandia');
  });
  test(
    'benefício vencido ou vindo do cache não é apresentado como vigente',
    () {
      expect(
        place(
          'a',
          fresh: true,
          end: DateTime.now().subtract(const Duration(seconds: 1)),
        ).hasCoupon,
        isFalse,
      );
      expect(
        place(
          'b',
          fresh: false,
          end: DateTime.now().add(const Duration(days: 1)),
        ).hasCoupon,
        isFalse,
      );
      final original = place(
        'c',
        fresh: true,
        end: DateTime.now().add(const Duration(days: 1)),
      );
      expect(original.hasCoupon, isTrue);
      expect(TourismPlace.fromJson(original.toJson()).hasCoupon, isFalse);
    },
  );
  test('clusters preservam todos os pontos e se abrem no zoom de detalhe', () {
    final points = [
      place('a'),
      place('b', lat: -2.531),
      place('c', lat: -7, lng: -47.5),
    ];
    final grouped = clusterPlaces(points, 6);
    expect(grouped.expand((f) => f.places).map((p) => p.id).toSet(), {
      'a',
      'b',
      'c',
    });
    expect(grouped.any((f) => f.isCluster), isTrue);
    expect(clusterPlaces(points, 18).every((f) => !f.isCluster), isTrue);
  });
  test('agrupa vizinhos em zoom urbano e mantém coincidentes acessíveis', () {
    final points = [
      place('a'),
      place('b', lat: -2.53001),
      place('c', lat: -2.53),
    ];
    expect(clusterPlaces(points, 14).single.places.length, 3);
    expect(clusterPlaces(points, 18).single.places.length, 3);
    final selected = clusterPlaces(points, 18, selectedId: 'b');
    expect(selected.where((f) => f.id == 'b').single.isCluster, isFalse);
    expect(selected.expand((f) => f.places).length, 3);
    expect(
      clusterPlaces(points.reversed.toList(), 14).single.id,
      clusterPlaces(points, 14).single.id,
    );
  });
  test('uma sequência de vizinhos não vira um único grupo pela cidade', () {
    final points = List.generate(
      100,
      (i) => place('p$i', lng: -44.3 + i * .0002),
    );
    final grouped = clusterPlaces(points, 16);
    expect(grouped.length, greaterThan(5));
    expect(grouped.expand((f) => f.places).length, points.length);
  });
  test('distância é simétrica e não apresenta caminho rodoviário', () {
    const a = GeoPoint(-2.53, -44.30), b = GeoPoint(-2.75, -42.82);
    expect(a.distanceKm(a), 0);
    expect(a.distanceKm(b), closeTo(b.distanceKm(a), .001));
    expect(a.distanceKm(b), greaterThan(100));
  });
}
