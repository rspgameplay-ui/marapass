import 'dart:convert';

import 'package:web/web.dart' as web;

const _key = 'marapass.gps.diagnostics.v1';
final _events = <Map<String, Object>>[];

// Opt-in, bounded, local to this tab. Survives a reload for WebKit diagnosis.
// No network transport and no coordinates or raw error messages.
void record(String stage, Set<String> allowed) {
  if (Uri.base.queryParameters['gpsDiagnostics'] != '1') return;
  try {
    if (_events.isEmpty) {
      final previous = web.window.sessionStorage.getItem(_key);
      if (previous != null) {
        final decoded = jsonDecode(previous);
        if (decoded is List) {
          for (final e in decoded.take(100)) {
            if (e is Map && allowed.contains(e['stage']) && e['time'] is int) {
              _events.add({
                'stage': e['stage'] as String,
                'time': e['time'] as int,
              });
            }
          }
        }
      }
    }
    _events.add({
      'stage': stage,
      'time': DateTime.now().millisecondsSinceEpoch,
    });
    if (_events.length > 100) _events.removeRange(0, _events.length - 100);
    web.window.sessionStorage.setItem(_key, jsonEncode(_events));
  } catch (_) {
    // Diagnostics must never prevent navigation (e.g. storage denied).
  }
}
