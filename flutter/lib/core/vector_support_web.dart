import 'package:web/web.dart' as web;

import 'dart:js_interop';

@JS()
extension type _LoseContext(JSObject _) implements JSObject {
  external void loseContext();
}

final _supported = _probe();

bool supportsVectorMaps() => _supported;

bool _probe() {
  try {
    final context = web.HTMLCanvasElement().getContext('webgl2');
    if (context == null) return false;
    try {
      final extension = (context as web.WebGL2RenderingContext).getExtension(
        'WEBGL_lose_context',
      );
      if (extension != null) _LoseContext(extension).loseContext();
    } catch (_) {
      // Optional extension: support remains valid if it is absent.
    }
    return true;
  } catch (_) {
    return false;
  }
}
