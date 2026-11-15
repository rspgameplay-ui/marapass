import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/application/map_state.dart';
import 'package:marapass_mapa/domain/municipality.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/voice/command.dart';
import 'package:marapass_mapa/voice/place_resolver.dart';

void main() {
  final places =
      (jsonDecode(File('assets/data/places.json').readAsStringSync()) as List)
          .map((j) => TourismPlace.fromJson(Map<String, dynamic>.from(j)))
          .toList();
  final cities =
      (jsonDecode(File('assets/data/municipalities.json').readAsStringSync())
              as List)
          .map((j) => Municipality.fromJson(Map<String, dynamic>.from(j)))
          .toList();
  test('voice variants resolve to Araçagy', () {
    for (final phrase in [
      'me leva pra praia do arassagi',
      'me leva pra praia do arasaji',
      'me leva pra praia do Araçagi',
    ]) {
      final command = parseCommand(phrase, cities);
      expect(command.route, isTrue);
      expect(
        resolvePlaces(command, places).first.place.id,
        'osm:node:7700339990',
      );
    }
  });
  test('search suggestions tolerate typos and retain normal filters', () {
    final state = MapState(
      places: places,
      query: 'aracajy',
      city: 'São José de Ribamar',
    );
    expect(state.filtered.any((p) => p.id == 'osm:node:7700339990'), isTrue);
    final typo = MapState(places: places, query: 'olho agwa');
    expect(typo.filtered.any((p) => p.id == 'osm:node:7700339991'), isTrue);
  });
  test('near-beach reference is not treated as verified driving access', () {
    final p = places.firstWhere((p) => p.id == 'osm:node:7700339990');
    expect(p.isBeach, isTrue);
    expect(p.needsVisitPlanning, isTrue);
    expect(
      TourismPlace.fromJson(p.toJson()).searchAliases,
      contains('arassagi'),
    );
  });
  test('where is Atins searches the beach', () {
    final command = parseCommand('onde fica Atins', cities);
    expect(
      resolvePlaces(command, places).any((m) => m.place.id == 'praia:atins'),
      isTrue,
    );
  });
}
