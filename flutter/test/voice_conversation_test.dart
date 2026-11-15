import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/domain/municipality.dart';
import 'package:marapass_mapa/domain/tourism.dart';
import 'package:marapass_mapa/voice/command.dart';
import 'package:marapass_mapa/voice/conversation.dart';
import 'package:marapass_mapa/voice/place_resolver.dart';

void main() {
  final cities =
      (jsonDecode(File('assets/data/municipalities.json').readAsStringSync())
              as List)
          .map((j) => Municipality.fromJson(Map<String, dynamic>.from(j)))
          .toList();
  final places =
      (jsonDecode(File('assets/data/places.json').readAsStringSync()) as List)
          .map((j) => TourismPlace.fromJson(Map<String, dynamic>.from(j)))
          .toList();
  final now = DateTime(2026, 11, 8);
  for (final phrase in [
    "Vamos à praia do Olho d'Água",
    "Me leve até a Praia do Olho Dagua",
    "Quero conhecer a praia do olho d’água",
    "Como chegar à Praia do Olho de Água?",
  ]) {
    test('real catalogue resolves $phrase', () {
      final c = parseCommand(phrase, cities, now: now);
      expect(c.route, isTrue);
      final result = resolvePlaces(c, places);
      expect(result.single.place.id, 'osm:node:7700339991');
      expect(result.single.place.city, 'São Luís');
    });
  }
  test(
    'small typo is marked approximate and still requires route confirmation',
    () {
      final c = MapConversation();
      final turn = c.accept('vamos a praia do olho agwa', cities, now: now);
      final matched = resolvePlaces(turn.command!, places);
      expect(matched.single.place.id, 'osm:node:7700339991');
      expect(matched.single.approximate, isTrue);
      c.results(matched.map((m) => m.place).toList());
      expect(c.pendingRoute, isNull);
      c.choose(matched.single.place);
      expect(
        c.accept('sim', cities, now: now).action,
        ConversationAction.confirmRoute,
      );
    },
  );
  test('same name in two municipalities is never silently selected', () {
    final beach = places.firstWhere((p) => p.id == 'osm:node:7700339991');
    final duplicate = TourismPlace(
      id: 'test:other',
      name: beach.name,
      city: 'Outro município de teste',
      point: beach.point,
      category: beach.category,
      description: 'Test only',
    );
    final c = MapConversation();
    final turn = c.accept("vamos à praia do olho d'água", cities, now: now);
    final found = resolvePlaces(turn.command!, [beach, duplicate]);
    expect(found.length, 2);
    c.results(found.map((m) => m.place).toList());
    expect(c.pendingRoute, isNull);
    expect(
      c.accept('sim', cities, now: now).action,
      ConversationAction.clarify,
    );
    c.accept('a segunda', cities, now: now);
    expect(c.pendingRoute!.id, found[1].place.id);
    expect(
      c.accept('sim', cities, now: now).destination!.id,
      found[1].place.id,
    );
  });
  test('municipality correction keeps category, coupons and date', () {
    final c = MapConversation();
    c.accept(
      'restaurante em São Luís com cupons dia 20 de janeiro',
      cities,
      now: now,
    );
    final turn = c.accept('quis dizer Barreirinhas', cities, now: now);
    expect(turn.command!.city!.name, 'Barreirinhas');
    expect(turn.command!.coupons, isTrue);
    expect(turn.command!.category, PlaceCategory.gastronomy);
    expect(turn.command!.day, DateTime(2027, 1, 20));
    expect(turn.command!.term, isEmpty);
  });
  test('only restaurants with coupons inherits municipality', () {
    final c = MapConversation();
    c.accept('restaurantes em Barreirinhas', cities, now: now);
    final turn = c.accept('somente restaurantes com cupons', cities, now: now);
    expect(turn.command!.city!.name, 'Barreirinhas');
    expect(turn.command!.coupons, isTrue);
    expect(turn.command!.term, isEmpty);
  });
  test(
    'missing municipality is clarified without losing the initial request',
    () {
      final c = MapConversation();
      expect(
        c
            .accept(
              'restaurante com cupons dia 20 de janeiro',
              cities,
              now: now,
            )
            .action,
        ConversationAction.clarify,
      );
      final turn = c.accept('Barreirinhas', cities, now: now);
      expect(turn.command!.coupons, isTrue);
      expect(turn.command!.category, PlaceCategory.gastronomy);
      expect(turn.command!.day, DateTime(2027, 1, 20));
    },
  );
  test(
    'another beach excludes rejected destination and stays in known city',
    () {
      final c = MapConversation();
      var turn = c.accept("vamos à praia do olho d'água", cities, now: now);
      final first = resolvePlaces(turn.command!, places).single.place;
      c.results([first]);
      c.choose(first);
      turn = c.accept('não, a outra praia', cities, now: now);
      expect(turn.command!.term, 'praia');
      expect(turn.command!.city!.name, 'São Luís');
      expect(turn.command!.route, isTrue);
      final options = resolvePlaces(
        turn.command!,
        places,
        excluded: c.excluded,
      );
      expect(options, isNotEmpty);
      expect(options.any((m) => m.place.id == first.id), isFalse);
      expect(options.every((m) => m.place.city == 'São Luís'), isTrue);
    },
  );
  test('unknown names, no and cancel do not launch navigation', () {
    final c = MapConversation();
    final t = c.accept('vamos à praia Marte Secreta', cities, now: now);
    expect(resolvePlaces(t.command!, places), isEmpty);
    expect(
      c.accept('sim', cities, now: now).action,
      ConversationAction.clarify,
    );
    expect(
      c.accept('não', cities, now: now).action,
      ConversationAction.clarify,
    );
    expect(
      c.accept('cancelar', cities, now: now).action,
      ConversationAction.cancel,
    );
    expect(c.previous, isNull);
  });
  test('draft speech does not overwrite confirmed context', () {
    final c = MapConversation();
    c.accept('restaurante em Barreirinhas', cities, now: now);
    c.draft('restaurante em São Luís', cities, now: now);
    expect(c.previous!.city!.name, 'Barreirinhas');
  });
  test('frase natural identifica Lençóis Maranhenses como rota', () {
    final c = parseCommand(
      'a gente vai para os Lençóis Maranhenses',
      cities,
      now: now,
    );
    expect(c.route, isTrue);
    expect(
      resolvePlaces(c, places).any((m) => m.place.id == 'osm:relation:7458131'),
      isTrue,
    );
  });
  test('generic beach query retains alternatives', () {
    final c = parseCommand('mostre praias em São Luís', cities, now: now);
    expect(resolvePlaces(c, places).length, greaterThan(1));
  });
}
