import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Baixa uma imagem PNG gerada no app (placa, QR de oferta).
bool downloadPng(Uint8List bytes, String fileName) {
  final link = web.HTMLAnchorElement()
    ..href = 'data:image/png;base64,${base64Encode(bytes)}'
    ..download = fileName;
  web.document.body!.append(link);
  link.click();
  link.remove();
  return true;
}
