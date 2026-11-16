// Gera as placas MaraPass para impressão (SVG vetorial, A6) e uma página
// para imprimir todas de uma vez (duas por folha A4).
//
// Uso:  flutter test tool/gen_plates_test.dart
// Saída: ../placas/  (um SVG por local, index.html e codigos.csv)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/mvp/data/content.dart';
import 'package:marapass_mapa/mvp/ui/checkin.dart';
import 'package:marapass_mapa/mvp/ui/plates.dart';
import 'package:qr/qr.dart';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Quebra o nome em até duas linhas de ~24 caracteres.
List<String> _lines(String t) {
  final words = t.split(' ');
  final out = <String>[''];
  for (final w in words) {
    if (out.last.isEmpty) {
      out.last = w;
    } else if ('${out.last} $w'.length <= 24) {
      out.last = '${out.last} $w';
    } else if (out.length < 2) {
      out.add(w);
    } else {
      out.last = '${out.last} $w';
    }
  }
  return out;
}

String plateSvg(Item i, String logo) {
  // Página A6 em milímetros: 105 × 148.
  final qr = QrImage(QrCode.fromData(data: plateQr(i), errorCorrectLevel: QrErrorCorrectLevel.M));
  const qrSize = 70.0, qrX = (105 - qrSize) / 2, qrY = 30.0;
  final cell = qrSize / qr.moduleCount;
  final b = StringBuffer();
  for (var y = 0; y < qr.moduleCount; y++) {
    for (var x = 0; x < qr.moduleCount; x++) {
      if (qr.isDark(y, x)) {
        final c = cell.toStringAsFixed(4);
        b.write('M${(qrX + x * cell).toStringAsFixed(4)} ${(qrY + y * cell).toStringAsFixed(4)}h${c}v${c}h-${c}z');
      }
    }
  }
  final mark = logo.replaceFirst(
    RegExp(r'<svg xmlns="http://www.w3.org/2000/svg"'),
    '<svg x="6" y="1.5" width="22" height="21"',
  );
  final name = _lines(i.titulo);
  return '''<svg xmlns="http://www.w3.org/2000/svg" width="105mm" height="148mm" viewBox="0 0 105 148" font-family="Plus Jakarta Sans, Arial, sans-serif">
<rect width="105" height="148" rx="4" fill="#ffffff" stroke="#dce2e8" stroke-width="0.4"/>
<path d="M4 0h97a4 4 0 0 1 4 4v20H0V4a4 4 0 0 1 4-4z" fill="#0b3a66"/>
$mark
<text x="97" y="11.5" font-size="4.2" font-weight="800" fill="#fac61d" text-anchor="end">Registre</text>
<text x="97" y="16.5" font-size="4.2" font-weight="800" fill="#fac61d" text-anchor="end">sua visita</text>
<path fill="#13263d" shape-rendering="crispEdges" d="$b"/>
<text x="52.5" y="${qrY + qrSize + 9}" font-size="7.5" font-weight="800" fill="#13263d" text-anchor="middle" letter-spacing="1.2">${plateCode(i)}</text>
${[for (var k = 0; k < name.length; k++) '<text x="52.5" y="${qrY + qrSize + 18 + k * 6.2}" font-size="5.4" font-weight="800" fill="#0b3a66" text-anchor="middle">${_esc(name[k])}</text>'].join('\n')}
<text x="52.5" y="${qrY + qrSize + 19 + name.length * 6.2}" font-size="3.8" fill="#556677" text-anchor="middle">${_esc(i.cidade)} · Maranhão</text>
<path d="M0 132h105v12a4 4 0 0 1-4 4H4a4 4 0 0 1-4-4z" fill="#f3f5f7"/>
<text x="52.5" y="138.5" font-size="3.3" fill="#2c3e52" text-anchor="middle">Abra o app MaraPass › Registrar visita e aponte a câmera.</text>
<text x="52.5" y="143.2" font-size="3.3" fill="#2c3e52" text-anchor="middle">Ganhe pontos e o carimbo do polo no seu Passaporte.</text>
</svg>
''';
}

void main() {
  test('gera placas para impressão', () {
    final out = Directory('../placas')..createSync(recursive: true);
    final logo = File('assets/brand/logo_white.svg').readAsStringSync();
    final items = Content.items.where((i) => i.cat != Cat.transporte && i.cat != Cat.fotografia).toList();
    final csv = StringBuffer('codigo,local,cidade,qr,latitude,longitude,precisao\n');
    final imgs = StringBuffer();
    for (final i in items) {
      final file = 'placa-${plateCode(i)}.svg';
      File('${out.path}/$file').writeAsStringSync(plateSvg(i, logo));
      csv.writeln('${plateCode(i)},"${i.titulo}","${i.cidade}",${plateQr(i)},${i.lat ?? ''},${i.lng ?? ''},${i.loc.name}');
      imgs.writeln('<img src="$file" alt="${_esc(i.titulo)}">');
    }
    File('${out.path}/codigos.csv').writeAsStringSync(csv.toString());
    File('${out.path}/index.html').writeAsStringSync('''<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8"><title>Placas MaraPass</title>
<style>
@page { size: A4; margin: 10mm; }
body { margin: 0; font-family: Arial, sans-serif; }
.tip { padding: 12px 16px; background: #fff7d6; border-bottom: 1px solid #e5d48a; }
.grid { display: flex; flex-wrap: wrap; gap: 8mm; padding: 8mm; }
img { width: 105mm; height: 148mm; break-inside: avoid; }
@media print { .tip { display: none; } .grid { padding: 0; } }
</style></head><body>
<div class="tip">Placas MaraPass · ${items.length} locais. Use Imprimir (Ctrl+P), papel A4, escala 100%: saem duas placas A6 por folha.</div>
<div class="grid">
$imgs</div>
</body></html>
''');
    expect(File('${out.path}/index.html').existsSync(), isTrue);
    // O QR de cada placa é lido pelo próprio app.
    for (final i in items) {
      expect(itemByPlate(plateCode(i))?.id, i.id);
    }
  });
}
