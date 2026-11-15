import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/tourism.dart';

/// Complete public editorial snapshot; never reads drafts or author identities.
/// Tombstones suppress a bundled OSM point with the same stable identifier.
class PublishedCatalog {
  PublishedCatalog(this.client, this.preferences, this.url, this.key);
  final http.Client client;
  final SharedPreferences preferences;
  final String url, key;
  static const cacheKey = 'shared_publications_v1';
  List<Map<String, dynamic>> rows = [];
  DateTime? checkedAt;
  bool offline = false;
  bool _fetching = false;
  void restoreCache() {
    try {
      final cache = jsonDecode(preferences.getString(cacheKey) ?? '{}') as Map;
      rows = (cache['rows'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      for (final row in rows) {
        if (row['is_visible'] == true) {
          TourismPlace.fromJson(Map<String, dynamic>.from(row['content']));
        }
      }
      checkedAt = DateTime.tryParse(cache['checkedAt'] as String? ?? '');
      offline = rows.isNotEmpty;
    } catch (_) {
      rows = [];
    }
  }

  Future<void> refresh() async {
    if (_fetching || url.isEmpty || key.isEmpty) return;
    _fetching = true;
    try {
      final next = <Map<String, dynamic>>[];
      String? after;
      while (true) {
        final uri = Uri.parse('$url/rest/v1/map_publications').replace(
          queryParameters: {
            'select': 'id,content,is_visible,revision,published_at',
            'order': 'id.asc',
            'limit': '500',
            if (after != null) 'id': 'gt.$after',
          },
        );
        final response = await client
            .get(uri, headers: {'apikey': key, 'Cache-Control': 'no-cache'})
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) {
          throw const FormatException('Publicações indisponíveis');
        }
        final page = (jsonDecode(response.body) as List)
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        // Validate the entire snapshot before replacing a working cache.
        for (final row in page) {
          if (row['is_visible'] == true) {
            TourismPlace.fromJson(Map<String, dynamic>.from(row['content']));
          }
        }
        next.addAll(page);
        if (page.length < 500) break;
        after = page.last['id'] as String;
        if (next.length > 50000) {
          throw const FormatException(
            'Catálogo excede limite de sincronização',
          );
        }
      }
      final now = DateTime.now().toUtc();
      await preferences.setString(
        cacheKey,
        jsonEncode({'rows': next, 'checkedAt': now.toIso8601String()}),
      );
      rows = next;
      checkedAt = now;
      offline = false;
    } catch (_) {
      offline = true;
    } finally {
      _fetching = false;
    }
  }

  List<TourismPlace> merge(List<TourismPlace> base) {
    final ids = rows.map((r) => r['id']).toSet();
    return [
      ...base.where((p) => !ids.contains(p.id)),
      ...rows
          .where((r) => r['is_visible'] == true)
          .map(
            (r) =>
                TourismPlace.fromJson(Map<String, dynamic>.from(r['content'])),
          ),
    ];
  }
}
