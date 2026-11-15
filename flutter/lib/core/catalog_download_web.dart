import 'package:web/web.dart' as web;

bool downloadCatalog(String json) {
  final link = web.HTMLAnchorElement()
    ..href = 'data:application/json;charset=utf-8,${Uri.encodeComponent(json)}'
    ..download = 'marapass-catalogo.json';
  web.document.body!.append(link);
  link.click();
  link.remove();
  return true;
}
