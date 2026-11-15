import '../domain/tourism.dart';
import 'command.dart';

String spokenName(String text) =>
    normalize(text)
        .replaceAll(RegExp(r"d[’'`´]\s*"), 'd ')
        .replaceAll(RegExp(r'\bdagua\b'), 'd agua')
        .replaceAll(RegExp(r'\bpraias\b'), 'praia')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\b(de|do|da|dos|das|d|a|o|e)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
int editDistance(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final row = <int>[i];
    for (var j = 1; j <= b.length; j++) {
      final replace = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
          insert = row[j - 1] + 1,
          delete = previous[j] + 1;
      row.add([replace, insert, delete].reduce((a, b) => a < b ? a : b));
    }
    previous = row;
  }
  return previous.last;
}

class PlaceMatch {
  const PlaceMatch(this.place, this.score, this.approximate);
  final TourismPlace place;
  final double score;
  final bool approximate;
}

/// Only catalogue names/explicit search aliases are eligible. No inferred coordinates.
List<PlaceMatch> resolvePlaces(
  MapCommand command,
  List<TourismPlace> places, {
  Set<String> excluded = const {},
}) {
  final needle = spokenName(command.term);
  final query = needle.split(' ').where((w) => w.isNotEmpty).toList();
  final matches = <PlaceMatch>[];
  for (final p in places) {
    if (excluded.contains(p.id) ||
        (command.city != null && p.city != command.city!.name) ||
        (command.category != null && p.category != command.category))
      continue;
    if (p.category == PlaceCategory.residential &&
        command.category != PlaceCategory.residential &&
        needle.isEmpty)
      continue;
    if (command.route &&
        needle.isEmpty &&
        command.category == null &&
        command.city != null &&
        p.category != PlaceCategory.destination)
      continue;
    if (query.isEmpty) {
      matches.add(PlaceMatch(p, 1, false));
      continue;
    }
    final name = spokenName(p.name), tokens = spokenName(p.name).split(' ');
    // A bar/hotel mentioning a beach is not the beach itself.
    if (query.first == 'praia' && tokens.first != 'praia' && !p.isBeach)
      continue;
    final aliasQuery = needle.replaceFirst(RegExp(r'^praia\s+'), '');
    if (p.isBeach && aliasQuery.isNotEmpty && aliasQuery != 'praia') {
      final variants = [p.name, ...p.searchAliases];
      if (variants.any(
        (value) =>
            spokenName(value).replaceFirst(RegExp(r'^praia\s+'), '') ==
            aliasQuery,
      )) {
        matches.add(PlaceMatch(p, 1, false));
        continue;
      }
    }
    var total = 0.0, valid = true, approximate = false;
    final used = <int>{};
    for (final word in query) {
      var best = 0.0, index = -1;
      for (var i = 0; i < tokens.length; i++) {
        if (used.contains(i)) continue;
        final candidate = tokens[i];
        var score = 0.0;
        if (word == candidate)
          score = 1;
        else if (word.length >= 4 && candidate.length >= 4) {
          final d = editDistance(word, candidate);
          final maxLength = word.length > candidate.length
              ? word.length
              : candidate.length;
          if (d <= (maxLength >= 8 ? 2 : 1) && d / maxLength <= .25)
            score = 1 - d / maxLength;
        }
        if (score > best) {
          best = score;
          index = i;
        }
      }
      if (best == 0) {
        valid = false;
        break;
      }
      used.add(index);
      total += best;
      if (best < 1) approximate = true;
    }
    if (valid) {
      final score = name == needle
          ? 1.0
          : (total / query.length) * .9 + (.1 * query.length / tokens.length);
      matches.add(PlaceMatch(p, score, approximate));
    }
  }
  matches.sort((a, b) {
    final score = b.score.compareTo(a.score);
    return score != 0 ? score : a.place.id.compareTo(b.place.id);
  });
  // Exact full names outrank longer business names, but retain equal-name ambiguity.
  if (query.length >= 2 && matches.isNotEmpty && matches.first.score == 1)
    return matches.where((m) => m.score == 1).toList();
  return matches;
}
