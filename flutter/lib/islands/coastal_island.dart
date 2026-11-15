import '../domain/tourism.dart';

class CoastalIsland {
  CoastalIsland.fromJson(Map<String, dynamic> j)
    : place = TourismPlace.fromJson(
        Map<String, dynamic>.from(j['place'] as Map),
      ),
      region = j['region'] as String,
      aliases = (j['aliases'] as List).cast<String>(),
      sources = (j['sources'] as List).cast<String>(),
      note = j['note'] as String? ?? '',
      rings = [
        for (final ring in j['rings'] as List)
          [
            for (final p in ring as List)
              GeoPoint((p[1] as num).toDouble(), (p[0] as num).toDouble()),
          ],
      ];
  final TourismPlace place;
  final String region, note;
  final List<String> aliases, sources;
  final List<List<GeoPoint>> rings;
  bool matches(String q) =>
      normalize('${place.name} ${place.city} $region ${aliases.join(' ')}')
          .contains(normalize(q));
}
