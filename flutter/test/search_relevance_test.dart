import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/application/map_state.dart';
import 'package:marapass_mapa/domain/tourism.dart';

void main() {
  final places =
      (jsonDecode(File('assets/data/places.json').readAsStringSync()) as List)
          .map((j) => TourismPlace.fromJson(Map<String, dynamic>.from(j)))
          .toList();
  test('nomes de destinos prevalecem sobre menções em descrições', () {
    final unrelated = TourismPlace(
      id: 'test:ilha',
      name: 'Ilha de teste',
      city: 'São Luís',
      point: const GeoPoint(-2.5, -44.3),
      category: PlaceCategory.nature,
      description: 'Veja também Lençóis Maranhenses e Chapada das Mesas.',
    );
    final all = [...places, unrelated];
    final lencois = MapState(
      places: all,
      query: 'Lençóis Maranhenses',
    ).filtered;
    expect(lencois.first.id, 'osm:relation:7458131');
    expect(lencois.any((p) => p.id == 'test:ilha'), isFalse);
    final chapada = MapState(places: all, query: 'Chapada das Mesas').filtered;
    expect(chapada.first.id, 'osm:node:2085086950');
    expect(chapada.any((p) => p.id == 'test:ilha'), isFalse);
  });
  test('pontuação isolada não devolve catálogo inteiro', () {
    expect(MapState(places: places, query: '...').filtered, isEmpty);
  });
}
