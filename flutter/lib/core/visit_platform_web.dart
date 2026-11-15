import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool get visitNetworkOffline => !web.window.navigator.onLine;

@JS()
extension type _ShareNavigator(JSObject _) implements JSObject {
  external JSPromise<JSAny?> share(JSObject data);
}

Future<bool> shareVisit(String title, String url) async {
  try {
    await _ShareNavigator(web.window.navigator)
        .share({'title': title, 'url': url}.jsify() as JSObject)
        .toDart;
    return true;
  } on Object catch (error) {
    // A cancelled platform share should leave the clipboard intact.
    return error.toString().contains('AbortError');
  }
}
