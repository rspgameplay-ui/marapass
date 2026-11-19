part of 'map_tab.dart';

/// Tipos de ponto no mapa, com cor e ícone próprios.
enum PoiKind {
  cultura('Cultura', Icons.account_balance_rounded, MP.poiCulture),
  natureza('Natureza', Icons.forest_rounded, MP.green),
  praias('Praias', Icons.beach_access_rounded, MP.poiBeach),
  ilhas('Ilhas', Icons.landscape_rounded, MP.poiIsland),
  passeios('Passeios', Icons.hiking_rounded, MP.poiTour),
  gastronomia('Comer', Icons.restaurant_rounded, MP.error),
  hospedagem('Dormir', Icons.hotel_rounded, MP.poiStay),
  eventos('Eventos', Icons.event_rounded, MP.poiEvent),
  artesanato('Artesanato', Icons.palette_rounded, MP.poiCraft),
  fotografia('Fotografia', Icons.photo_camera_rounded, MP.poiEvent),
  transporte('Transporte', Icons.directions_bus_rounded, MP.navy),
  destinos('Cidades', Icons.location_city_rounded, MP.navy),
  outros('Outros', Icons.place_rounded, MP.textSecondary);

  const PoiKind(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  static PoiKind fromPlace(PlaceCategory c) => switch (c) {
    PlaceCategory.culture => cultura,
    PlaceCategory.nature => natureza,
    PlaceCategory.tours => passeios,
    PlaceCategory.gastronomy => gastronomia,
    PlaceCategory.lodging => hospedagem,
    PlaceCategory.events => eventos,
    PlaceCategory.crafts => artesanato,
    PlaceCategory.photography => fotografia,
    PlaceCategory.transport => transporte,
    PlaceCategory.destination => destinos,
    _ => outros,
  };

  static PoiKind fromCat(Cat c) => switch (c) {
    Cat.cultura => cultura,
    Cat.natureza => natureza,
    Cat.passeio => passeios,
    Cat.fotografia => fotografia,
    Cat.gastronomia => gastronomia,
    Cat.hospedagem => hospedagem,
    Cat.evento => eventos,
    Cat.artesanato => artesanato,
    Cat.transporte => transporte,
  };
}

class Poi {
  const Poi({
    required this.id,
    required this.name,
    required this.city,
    required this.kind,
    required this.point,
    this.item,
    this.place,
    this.featured = false,
  });
  final String id;
  final String name;
  final String city;
  final PoiKind kind;
  final GeoPoint point;
  final Item? item;
  final TourismPlace? place;
  final bool featured;

  /// Tem cupom ou oferta ativa (experiência do app ou parceiro com oferta fresca).
  bool get hasCoupon =>
      item?.cupom != null ||
      (place != null &&
          place!.isPartner &&
          place!.offersFresh &&
          (place!.offerTitle?.trim().isNotEmpty ?? false));

  /// Empresa cadastrada como parceira na plataforma.
  bool get isPartner => place?.isPartner == true;

  TourismPlace get asPlace =>
      place ??
      TourismPlace(
        id: 'mvp-$id',
        name: name,
        city: city,
        point: point,
        category: switch (kind) {
          PoiKind.cultura => PlaceCategory.culture,
          PoiKind.natureza ||
          PoiKind.praias ||
          PoiKind.ilhas => PlaceCategory.nature,
          PoiKind.passeios => PlaceCategory.tours,
          PoiKind.gastronomia => PlaceCategory.gastronomy,
          PoiKind.hospedagem => PlaceCategory.lodging,
          PoiKind.eventos => PlaceCategory.events,
          PoiKind.artesanato => PlaceCategory.crafts,
          PoiKind.fotografia => PlaceCategory.photography,
          PoiKind.transporte => PlaceCategory.transport,
          PoiKind.destinos => PlaceCategory.destination,
          PoiKind.outros => PlaceCategory.services,
        },
        description: item?.resumo ?? '',
      );
}

/// Chave de ligação entre um item editorial (Content) e um lugar do
/// catálogo do mapa: mesmo nome e mesma cidade, sem acento nem caixa.
String poiLinkKey(String name, String city) =>
    '${normalize(name)}|${normalize(city)}';

/// Junta os itens editoriais e o catálogo do mapa em uma lista sem
/// duplicados: o item recebe o lugar equivalente e o lugar deixa de
/// aparecer sozinho. Só entram itens das [cities] e lugares não residenciais.
List<Poi> linkPois({
  required Iterable<Item> items,
  required Iterable<TourismPlace> places,
  required Set<String> islandIds,
  required Set<String> cities,
}) {
  final catalog = [
    for (final p in places)
      if (p.category != PlaceCategory.residential) p,
  ];
  final byKey = <String, TourismPlace>{};
  for (final p in catalog) {
    byKey.putIfAbsent(poiLinkKey(p.name, p.city), () => p);
  }
  final out = <Poi>[];
  final linked = <String>{};
  for (final i in items) {
    if (!cities.contains(i.cidade)) continue;
    final match = byKey[poiLinkKey(i.titulo, i.cidade)];
    if (match != null) linked.add(match.id);
    out.add(
      Poi(
        id: i.id,
        name: i.titulo,
        city: i.cidade,
        kind: PoiKind.fromCat(i.cat),
        point: itemPoint(i),
        item: i,
        place: match,
        featured: true,
      ),
    );
  }
  for (final p in catalog) {
    if (linked.contains(p.id)) continue;
    out.add(
      Poi(
        id: p.id,
        name: p.name,
        city: p.city,
        kind: islandIds.contains(p.id)
            ? PoiKind.ilhas
            : p.isBeach
            ? PoiKind.praias
            : PoiKind.fromPlace(p.category),
        point: p.point,
        place: p,
        featured: p.category == PlaceCategory.culture || p.isBeach,
      ),
    );
  }
  return out;
}

/// Sedes das cidades do catálogo (IBGE, Localidades 2022; Atins pelo OpenStreetMap).
const _cityCenters = <String, GeoPoint>{
  'Barreirinhas': GeoPoint(-2.7502, -42.8270988),
  'Santo Amaro': GeoPoint(-2.5002, -43.2538986),
  'Atins': GeoPoint(-2.57, -42.7445),
  'São Luís': GeoPoint(-2.5274, -44.3060989),
  'Axixá': GeoPoint(-2.8381, -44.0519981),
  'Carolina': GeoPoint(-7.3347998, -47.4734001),
  'Cururupu': GeoPoint(-1.8256, -44.8671989),
  'Tutóia': GeoPoint(-2.7632, -42.2742004),
  'Rosário': GeoPoint(-2.9372001, -44.2450981),
  'Codó': GeoPoint(-4.4527998, -43.8875999),
  'Fernando Falcão': GeoPoint(-6.1508002, -44.9011002),
};

const _maranhao = LatLng(-3.9, -44.8);

/// Capa em alta resolução por categoria, para nenhum card ficar sem foto.
const _covers = <PoiKind, String>{
  PoiKind.cultura: 'p2',
  PoiKind.natureza: 'lagoa_boat',
  PoiKind.praias: 'p1',
  PoiKind.ilhas: 'p3',
  PoiKind.passeios: 'sunset',
  PoiKind.gastronomia: 'rest',
  PoiKind.hospedagem: 'p4',
  PoiKind.eventos: 'p2',
  PoiKind.artesanato: 'ceramica',
  PoiKind.fotografia: 'sunset',
  PoiKind.transporte: 'p3',
  PoiKind.destinos: 'lagoa_boat',
  PoiKind.outros: 'p3',
};

/// Posição de um item no mapa: a coordenada real do catálogo (OpenStreetMap
/// ou sede do IBGE). Pontos exatos e atrações ficam onde estão; pontos de
/// saída e aproximados, que muitas vezes caem na mesma sede, ganham um pequeno
/// afastamento fixo (até ~450 m) para os marcadores não se sobreporem.
GeoPoint itemPoint(Item i) {
  final base = i.lat != null && i.lng != null
      ? GeoPoint(i.lat!, i.lng!)
      : (_cityCenters[i.cidade] ?? const GeoPoint(-2.5297, -44.3028));
  if (i.lat != null && (i.loc == Loc.exato || i.loc == Loc.atracao)) {
    return base;
  }
  var h = 2166136261;
  for (final u in i.id.codeUnits) {
    h = ((h ^ u) * 16777619) % 4294967296;
  }
  final a = (h % 65536) / 65536 * math.pi * 2;
  final r = .0015 + ((h ~/ 65536) % 65536) / 65536 * .0025;
  return GeoPoint(base.lat + math.sin(a) * r, base.lng + math.cos(a) * r);
}
