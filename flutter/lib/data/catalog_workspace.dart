import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/tourism.dart';

enum CatalogKind {
  point('Ponto de interesse'),
  attraction('Atrativo'),
  company('Empresa');

  const CatalogKind(this.label);
  final String label;
}

enum CatalogStatus {
  draft('Rascunho'),
  visible('Visível no meu mapa'),
  archived('Arquivado');

  const CatalogStatus(this.label);
  final String label;
}

class CatalogEntry {
  const CatalogEntry({
    required this.place,
    required this.kind,
    required this.status,
    required this.updatedAt,
  });
  final TourismPlace place;
  final CatalogKind kind;
  final CatalogStatus status;
  final DateTime updatedAt;
  Map<String, dynamic> toJson() => {
    'place': place.toJson(),
    'kind': kind.name,
    'status': status.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
  factory CatalogEntry.fromJson(Map<String, dynamic> j) {
    final rawPlace = Map<String, dynamic>.from(j['place'] as Map);
    final validCategories = {
      ...PlaceCategory.values.map((c) => c.name),
      'tourist_transport',
    };
    if (!validCategories.contains(rawPlace['cat'])) {
      throw const FormatException('Categoria não reconhecida.');
    }
    final place = TourismPlace.fromJson(
      Map<String, dynamic>.from(j['place'] as Map),
    );
    final entry = CatalogEntry(
      place: place,
      kind: CatalogKind.values.byName(j['kind'] as String),
      status: CatalogStatus.values.byName(j['status'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
    validatePlace(place);
    if (place.isPartner || place.offerTitle != null || place.offersFresh) {
      throw const FormatException(
        'Um cadastro local não pode conceder parceria ou oferta.',
      );
    }
    return entry;
  }
}

void validatePlace(TourismPlace p) {
  if (p.id.trim().isEmpty ||
      p.id.length > 180 ||
      p.name.trim().length < 3 ||
      p.name.length > 160 ||
      p.city.trim().length < 2 ||
      p.city.length > 100 ||
      p.description.length > 5000 ||
      (p.tags?.length ?? 0) > 500 ||
      (p.address?.length ?? 0) > 300 ||
      (p.hours?.length ?? 0) > 500 ||
      (p.area?.length ?? 0) > 120 ||
      !p.point.lat.isFinite ||
      !p.point.lng.isFinite ||
      !GeoBounds.maranhao.contains(p.point)) {
    throw const FormatException(
      'Revise nome, município e coordenadas na área do Maranhão.',
    );
  }
  for (final url in [p.sourceUrl, p.photoUrl, p.website]) {
    if (url == null || url.isEmpty) {
      continue;
    }
    final uri = Uri.tryParse(url);
    if (url.length > 2000 ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      throw const FormatException(
        'Os links devem ser endereços HTTPS válidos.',
      );
    }
  }
  for (final phone in [p.phone, p.whatsapp]) {
    if (phone != null &&
        phone.isNotEmpty &&
        !RegExp(r'^\+?[0-9 ()-]{8,25}$').hasMatch(phone)) {
      throw const FormatException('Revise o telefone e o WhatsApp.');
    }
  }
}

class CatalogWorkspace {
  CatalogWorkspace(this.preferences);
  final SharedPreferences preferences;
  static const key = 'map_catalog_workspace_v1';
  List<CatalogEntry> get entries {
    final stored = preferences.getString(key);
    if (stored == null) {
      return [];
    }
    return decode(stored);
  }

  static List<CatalogEntry> decode(String input) {
    if (input.length > 2000000) {
      throw const FormatException('O arquivo excede 2 MB.');
    }
    try {
      final data = jsonDecode(input) as Map<String, dynamic>;
      if (data['schema'] != 'marapass.map.catalog' || data['version'] != 1) {
        throw const FormatException('Formato de catálogo não reconhecido.');
      }
      final raw = data['entries'] as List;
      if (raw.length > 1000) {
        throw const FormatException(
          'O limite é de 1.000 cadastros por arquivo.',
        );
      }
      final result = raw
          .map(
            (j) => CatalogEntry.fromJson(Map<String, dynamic>.from(j as Map)),
          )
          .toList();
      if (result.map((e) => e.place.id).toSet().length != result.length) {
        throw const FormatException('Há identificadores repetidos no arquivo.');
      }
      return result;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Arquivo inválido ou com campos incompletos.',
      );
    }
  }

  String encode(List<CatalogEntry> entries) =>
      const JsonEncoder.withIndent('  ').convert({
        'schema': 'marapass.map.catalog',
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'entries': entries.map((e) => e.toJson()).toList(),
      });
  Future<void> write(List<CatalogEntry> entries) async {
    final json = encode(entries);
    decode(json); // Validação completa antes de qualquer gravação.
    if (!await preferences.setString(key, json)) {
      throw const FormatException(
        'Não foi possível salvar. Exporte um backup e tente novamente.',
      );
    }
  }
}
