import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// In-memory, same-origin parent communication. No draft, session token or URL
/// payload is persisted or fetched by the visitor application.
VoidCallback listenForEditorialPreview(
  void Function(Map<String, dynamic>) receive,
) {
  final parent = web.window.parent;
  final origin = web.window.location.origin;
  final handler = ((web.Event raw) {
    final event = raw as web.MessageEvent;
    if (event.origin != origin || event.source != parent) return;
    try {
      final value = event.data.dartify();
      if (value is! String || value.length > 30000) return;
      final json = jsonDecode(value) as Map<String, dynamic>;
      if (json['type'] != 'marapass.editorial.preview') return;
      receive(Map<String, dynamic>.from(json['content']));
    } catch (_) {
      /* Ignore unrelated or malformed parent messages. */
    }
  }).toJS;
  web.window.addEventListener('message', handler);
  parent?.postMessage(
    jsonEncode({'type': 'marapass.editorial.ready'}).toJS,
    origin.toJS,
  );
  return () => web.window.removeEventListener('message', handler);
}
