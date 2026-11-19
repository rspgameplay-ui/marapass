import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cache local das leituras públicas do catálogo (experiências, ofertas,
/// estabelecimentos, produtos do passaporte). Com internet, a resposta nova
/// sempre vence e é guardada; sem internet, a última resposta guardada
/// aparece com a data da atualização.
class CatalogCache {
  CatalogCache(this._prefs);
  final SharedPreferences? _prefs;

  static const _prefix = 'mp_catalog_v1:';

  /// Último momento em que o catálogo veio do servidor (qualquer leitura).
  static DateTime? lastSync;

  /// Verdadeiro quando a última leitura precisou usar o cache.
  static bool servingStale = false;

  /// Busca no servidor e guarda; se falhar e houver cópia, devolve a cópia.
  Future<List<Map<String, dynamic>>> rows(
    String key,
    Future<List<Map<String, dynamic>>> Function() fetch,
  ) async {
    try {
      final fresh = await fetch();
      servingStale = false;
      lastSync = DateTime.now();
      await _write(key, fresh);
      return fresh;
    } catch (_) {
      final cached = _read(key);
      if (cached == null) rethrow;
      servingStale = true;
      return cached;
    }
  }

  Future<void> _write(String key, List<Map<String, dynamic>> rows) async {
    final p = _prefs;
    if (p == null) return;
    try {
      await p.setString(
        '$_prefix$key',
        jsonEncode({'at': DateTime.now().toUtc().toIso8601String(), 'rows': rows}),
      );
    } catch (_) {
      // cache é só conveniência: falha de gravação não pode quebrar a tela
    }
  }

  List<Map<String, dynamic>>? _read(String key) {
    final raw = _prefs?.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map;
      lastSync ??= DateTime.tryParse(m['at'] as String? ?? '')?.toLocal();
      return [
        for (final r in m['rows'] as List) Map<String, dynamic>.from(r as Map),
      ];
    } catch (_) {
      return null;
    }
  }
}
