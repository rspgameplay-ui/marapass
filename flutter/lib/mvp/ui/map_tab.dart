import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../application/map_state.dart';
import '../../application/navigation_session.dart';
import '../../core/config.dart';
import '../../data/tourism_repository.dart';
import '../../domain/navigation.dart';
import '../../islands/coastal_island.dart';
import '../../islands/island_directory.dart';
import '../../islands/nautical_connections.dart';
import '../../islands/nautical_screen.dart';
import '../../domain/tourism.dart';
import '../../location/location_service.dart';
import '../../location/ahead_filter.dart';
import 'package:geolocator/geolocator.dart' show Position;
import '../../presentation/legacy_theme.dart';
import '../../presentation/map_screen.dart';
import '../../presentation/municipal_visit_guide.dart';
import '../../presentation/navigation_screen.dart';
import '../../voice/voice_search_sheet.dart';
import '../data/content.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'common.dart';
import 'itinerary.dart';
import 'nav_screen.dart';
import 'stay.dart';

/// Tipos de ponto no mapa, com cor e ícone próprios.
enum PoiKind {
  cultura('Cultura', Icons.account_balance_rounded, Color(0xff8a5a2b)),
  natureza('Natureza', Icons.forest_rounded, Color(0xff14775a)),
  praias('Praias', Icons.beach_access_rounded, Color(0xff0f8fa8)),
  ilhas('Ilhas', Icons.landscape_rounded, Color(0xff2e7d6f)),
  passeios('Passeios', Icons.hiking_rounded, Color(0xff1f6fd1)),
  gastronomia('Comer', Icons.restaurant_rounded, Color(0xffc53b36)),
  hospedagem('Dormir', Icons.hotel_rounded, Color(0xff6a4fb3)),
  eventos('Eventos', Icons.event_rounded, Color(0xffb0407e)),
  artesanato('Artesanato', Icons.palette_rounded, Color(0xffa87800)),
  destinos('Cidades', Icons.location_city_rounded, Color(0xff0b3a66)),
  outros('Outros', Icons.place_rounded, Color(0xff556677));

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
    PlaceCategory.destination => destinos,
    _ => outros,
  };

  static PoiKind fromCat(Cat c) => switch (c) {
    Cat.cultura => cultura,
    Cat.natureza => natureza,
    Cat.passeio || Cat.fotografia => passeios,
    Cat.gastronomia => gastronomia,
    Cat.hospedagem => hospedagem,
    Cat.evento => eventos,
    Cat.artesanato => artesanato,
    Cat.transporte => outros,
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
          PoiKind.destinos => PlaceCategory.destination,
          PoiKind.outros => PlaceCategory.services,
        },
        description: item?.resumo ?? '',
      );
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

/// Mapa turístico com MapLibre: visão 2D e 3D (inclinação e rotação), prédios
/// em 3D, pontos agrupados por categoria, prévia ao tocar e rota real (OSRM)
/// com distância e tempo. A navegação por voz e os recursos do mapa completo
/// continuam disponíveis.
class MapTab extends ConsumerStatefulWidget {
  const MapTab({super.key});
  @override
  ConsumerState<MapTab> createState() => _MapTabState();
}

class _MapTabState extends ConsumerState<MapTab> {
  MapLibreMapController? _c;
  bool _ready = false;
  bool _threeD = false;
  bool _showIslands = true;
  bool _showFerries = true;
  Map<String, CoastalIsland> _islands = const {};
  NauticalCatalog? _ferries;
  final Set<PoiKind> _kinds = {...PoiKind.values};
  List<Poi> _pois = const [];

  @override
  void initState() {
    super.initState();
    _pois = _buildPois();
    // Lugares e ilhas do catálogo chegam em segundo plano.
    TourismRepository? repo;
    try {
      repo = ref.read(repositoryProvider);
    } catch (_) {
      // sem catálogo do mapa (testes): só os pontos do app
    }
    if (repo != null && !repo.loaded) {
      repo.ensureLoaded().then((_) async {
        if (!mounted) return;
        setState(() => _pois = _buildPois());
        if (_ready) {
          await _c?.setGeoJsonSource('pois', _poiCollection());
          await _c?.setGeoJsonSource('islands', _islandShapes());
        }
      });
    }
  }
  Poi? _selected;
  RoadRoute? _route;
  GeoPoint? _origin;
  String _originLabel = '';
  bool _pickingOrigin = false;
  bool _routing = false;
  String? _routeError;
  DayPlan? _plan;
  RoadRoute? _planRoute;
  bool _planBusy = false;
  String? _planError;

  List<Poi> _buildPois() {
    final out = <Poi>[];
    for (final i in Content.items) {
      if (!_cityCenters.containsKey(i.cidade)) continue;
      out.add(
        Poi(
          id: i.id,
          name: i.titulo,
          city: i.cidade,
          kind: PoiKind.fromCat(i.cat),
          point: itemPoint(i),
          item: i,
          featured: true,
        ),
      );
    }
    try {
      final repo = ref.read(repositoryProvider);
      if (!repo.loaded) return out;
      _islands = {for (final i in repo.coastalIslands) i.place.id: i};
      for (final p in repo.basePlaces) {
        if (p.category == PlaceCategory.residential) continue;
        out.add(
          Poi(
            id: p.id,
            name: p.name,
            city: p.city,
            kind: _islands.containsKey(p.id)
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
    } catch (_) {
      // sem o catálogo do mapa (testes): só os pontos do app
    }
    return out;
  }

  Map<String, dynamic> _poiCollection() => {
    'type': 'FeatureCollection',
    'features': [
      for (final p in _pois)
        if (_kinds.contains(p.kind))
          {
            'type': 'Feature',
            'id': p.id.hashCode & 0x7fffffff,
            'properties': {
              'id': p.id,
              'name': p.name,
              'k': p.kind.name,
              'f': p.featured ? 1 : 0,
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [p.point.lng, p.point.lat],
            },
          },
    ],
  };

  static Map<String, dynamic> _line(List<GeoPoint> pts) => {
    'type': 'FeatureCollection',
    'features': [
      if (pts.length > 1)
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final p in pts) [p.lng, p.lat],
            ],
          },
        },
    ],
  };

  static Map<String, dynamic> _point(GeoPoint? p) => {
    'type': 'FeatureCollection',
    'features': [
      if (p != null)
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'Point',
            'coordinates': [p.lng, p.lat],
          },
        },
    ],
  };

  /// Marcador vetorial desenhado em alta resolução (2x) para cada categoria.
  Future<Uint8List> _markerPng(PoiKind k, {required bool featured}) async {
    const s = 96.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final center = const Offset(s / 2, s / 2);
    final r = featured ? 40.0 : 34.0;
    canvas.drawCircle(
      center + const Offset(0, 3),
      r,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    canvas.drawCircle(center, r - 5, Paint()..color = k.color);
    if (featured) {
      canvas.drawCircle(
        center,
        r - 1.5,
        Paint()
          ..color = MP.yellow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(k.icon.codePoint),
        style: TextStyle(
          fontFamily: k.icon.fontFamily,
          package: k.icon.fontPackage,
          fontSize: featured ? 40 : 34,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    final img = await rec.endRecording().toImage(s.toInt(), s.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _onStyleLoaded() async {
    final c = _c;
    if (c == null) return;
    for (final k in PoiKind.values) {
      await c.addImage('poi-${k.name}', await _markerPng(k, featured: false));
      await c.addImage('poi-${k.name}-f', await _markerPng(k, featured: true));
    }
    await c.addSource(
      'islands',
      GeojsonSourceProperties(data: _islandShapes()),
    );
    await c.addFillLayer(
      'islands',
      'islands-fill',
      const FillLayerProperties(fillColor: '#0f8fa8', fillOpacity: .12),
    );
    await c.addLineLayer(
      'islands',
      'islands-line',
      const LineLayerProperties(
        lineColor: '#0f8fa8',
        lineWidth: 1.6,
        lineOpacity: .8,
      ),
    );
    await c.addSource(
      'ferries',
      GeojsonSourceProperties(data: _line(const [])),
    );
    await c.addLineLayer(
      'ferries',
      'ferries-line',
      const LineLayerProperties(
        lineColor: '#0b6e99',
        lineWidth: 3.5,
        lineDasharray: [2, 1.5],
        lineCap: 'round',
      ),
    );
    unawaited(_loadFerries());
    await c.addSource('route', GeojsonSourceProperties(data: _line(const [])));
    await c.addLineLayer(
      'route',
      'route-casing',
      const LineLayerProperties(
        lineColor: '#ffffff',
        lineWidth: 11,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
    await c.addLineLayer(
      'route',
      'route-line',
      const LineLayerProperties(
        lineColor: '#1a73e8',
        lineWidth: 7,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
    await c.addSource('stops', GeojsonSourceProperties(data: _stops(null)));
    await c.addCircleLayer(
      'stops',
      'stops-dot',
      const CircleLayerProperties(
        circleColor: [
          'case',
          ['==', ['get', 'a'], 1],
          '#fac61d',
          '#0b3a66',
        ],
        circleRadius: 15,
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 3,
      ),
    );
    await c.addSymbolLayer(
      'stops',
      'stops-num',
      const SymbolLayerProperties(
        textField: ['get', 'n'],
        textFont: ['Noto Sans Bold'],
        textSize: 14,
        textColor: [
          'case',
          ['==', ['get', 'a'], 1],
          '#13263d',
          '#ffffff',
        ],
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
    );
    await c.addSource('origin', GeojsonSourceProperties(data: _point(null)));
    await c.addCircleLayer(
      'origin',
      'origin-halo',
      const CircleLayerProperties(
        circleColor: '#1a73e8',
        circleOpacity: .2,
        circleRadius: 18,
      ),
    );
    await c.addCircleLayer(
      'origin',
      'origin-dot',
      const CircleLayerProperties(
        circleColor: '#1a73e8',
        circleRadius: 8,
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 3,
      ),
    );
    await c.addSource(
      'pois',
      GeojsonSourceProperties(
        data: _poiCollection(),
        cluster: true,
        clusterRadius: 48,
        clusterMaxZoom: 12,
      ),
    );
    await c.addCircleLayer(
      'pois',
      'clusters',
      const CircleLayerProperties(
        circleColor: '#0b3a66',
        circleOpacity: .92,
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 3,
        circleRadius: [
          'step',
          ['get', 'point_count'],
          18,
          20,
          23,
          100,
          29,
          500,
          36,
        ],
      ),
      filter: ['has', 'point_count'],
    );
    await c.addSymbolLayer(
      'pois',
      'cluster-count',
      const SymbolLayerProperties(
        textField: ['get', 'point_count_abbreviated'],
        textFont: ['Noto Sans Bold'],
        textSize: 15,
        textColor: '#ffffff',
        textAllowOverlap: true,
      ),
      filter: ['has', 'point_count'],
    );
    await c.addSymbolLayer(
      'pois',
      'poi-icons',
      const SymbolLayerProperties(
        iconImage: [
          'case',
          [
            '==',
            ['get', 'f'],
            1,
          ],
          [
            'concat',
            'poi-',
            ['get', 'k'],
            '-f',
          ],
          [
            'concat',
            'poi-',
            ['get', 'k'],
          ],
        ],
        iconSize: [
          'interpolate',
          ['linear'],
          ['zoom'],
          8,
          .42,
          14,
          .6,
        ],
        iconAllowOverlap: true,
        symbolSortKey: [
          '-',
          0,
          ['get', 'f'],
        ],
        textField: [
          'step',
          ['zoom'],
          '',
          12,
          ['get', 'name'],
        ],
        textFont: ['Noto Sans Bold'],
        textSize: 13,
        textOffset: [0, 1.9],
        textAnchor: 'top',
        textColor: '#13263d',
        textHaloColor: '#ffffff',
        textHaloWidth: 2,
        textOptional: true,
      ),
      filter: [
        '!',
        ['has', 'point_count'],
      ],
    );
    if (mounted) setState(() => _ready = true);
    _consumePlan();
  }

  Map<String, dynamic> _stops(DayPlan? plan) => {
    'type': 'FeatureCollection',
    'features': [
      if (plan != null)
        for (var k = 0; k < plan.stops.length; k++)
          {
            'type': 'Feature',
            'properties': {'n': '${k + 1}', 'a': plan.stops[k].anchor ? 1 : 0},
            'geometry': {
              'type': 'Point',
              'coordinates': [
                itemPoint(plan.stops[k].item).lng,
                itemPoint(plan.stops[k].item).lat,
              ],
            },
          },
    ],
  };

  /// Roteiro pedido pela tela "Roteiro do dia".
  void _consumePlan() {
    if (!_ready) return;
    final plan = ref.read(itineraryRequestProvider);
    if (plan == null) return;
    Future.microtask(() => ref.read(itineraryRequestProvider.notifier).state = null);
    _tracePlan(plan);
  }

  Future<void> _tracePlan(DayPlan plan) async {
    final pts = [for (final s in plan.stops) itemPoint(s.item)];
    setState(() {
      _selected = null;
      _route = null;
      _plan = plan;
      _planRoute = null;
      _planBusy = true;
      _planError = null;
    });
    await _c?.setGeoJsonSource('stops', _stops(plan));
    await _c?.setGeoJsonSource('route', _line(const []));
    await _fitPoints(pts);
    try {
      final r = await ref.read(routingRepositoryProvider).routeThrough(pts);
      if (!mounted || _plan != plan) return;
      setState(() => _planRoute = r);
      await _c?.setGeoJsonSource('route', _line(r.points));
      await _fitPoints(r.points);
    } catch (_) {
      if (mounted) setState(() => _planError = 'Não foi possível traçar o percurso agora. As paradas estão marcadas no mapa.');
    } finally {
      if (mounted) setState(() => _planBusy = false);
    }
  }

  Future<void> _fitPoints(List<GeoPoint> pts) async {
    if (pts.isEmpty) return;
    final lats = pts.map((e) => e.lat), lngs = pts.map((e) => e.lng);
    await _c?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
          northeast: LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
        ),
        left: 56,
        right: 72,
        top: 190,
        bottom: 330,
      ),
      duration: const Duration(milliseconds: 900),
    );
  }

  Future<void> _closePlan() async {
    setState(() {
      _plan = null;
      _planRoute = null;
      _planError = null;
    });
    await _c?.setGeoJsonSource('stops', _stops(null));
    await _c?.setGeoJsonSource('route', _line(const []));
  }

  void _navigate({required String name, required GeoPoint dest, required GeoPoint origin, required RoadRoute route, required String originLabel}) {
    push<void>(
      context,
      RouteNavScreen(destinationName: name, destination: dest, origin: origin, route: route, originLabel: originLabel),
    );
  }

  Map<String, dynamic> _islandShapes() => {
    'type': 'FeatureCollection',
    'features': [
      if (_showIslands)
        for (final i in _islands.values)
          if (i.rings.isNotEmpty)
            {
              'type': 'Feature',
              'properties': {'id': i.place.id},
              'geometry': {
                'type': 'Polygon',
                'coordinates': [
                  for (final ring in i.rings)
                    [
                      for (final g in ring) [g.lng, g.lat],
                    ],
                ],
              },
            },
    ],
  };

  Map<String, dynamic> _ferryLines() => {
    'type': 'FeatureCollection',
    'features': [
      if (_showFerries)
        for (final r in _ferries?.routes ?? const <NauticalConnection>[])
          if (r.points.length > 1)
            {
              'type': 'Feature',
              'properties': {
                'ferry': r.id,
                'island': r.islandIds.isEmpty ? '' : r.islandIds.first,
              },
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  for (final g in r.points) [g.lng, g.lat],
                ],
              },
            },
    ],
  };

  Future<void> _loadFerries() async {
    try {
      _ferries = await NauticalCatalog.load();
      await _c?.setGeoJsonSource('ferries', _ferryLines());
    } catch (_) {
      // sem o catálogo náutico: o mapa segue sem as travessias
    }
  }

  void _openLayers() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s5),
            child: Column(
              key: const Key('layers-sheet'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Camadas do mapa',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: MP.s2),
                SwitchListTile(
                  key: const Key('layer-islands'),
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.landscape_rounded,
                    color: Color(0xff2e7d6f),
                  ),
                  title: const Text(
                    'Ilhas do litoral',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  subtitle: Text(
                    '${_islands.length} ilhas com contorno e ficha de visita',
                  ),
                  value: _showIslands,
                  onChanged: (v) {
                    setSheet(() {});
                    setState(() => _showIslands = v);
                    _c?.setGeoJsonSource('islands', _islandShapes());
                  },
                ),
                SwitchListTile(
                  key: const Key('layer-ferries'),
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.directions_boat_rounded,
                    color: Color(0xff0b6e99),
                  ),
                  title: const Text(
                    'Travessias de barco',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  subtitle: Text(
                    _ferries == null
                        ? 'Carregando…'
                        : '${_ferries!.routes.length} rotas náuticas documentadas',
                  ),
                  value: _showFerries,
                  onChanged: (v) {
                    setSheet(() {});
                    setState(() => _showFerries = v);
                    _c?.setGeoJsonSource('ferries', _ferryLines());
                  },
                ),
                SwitchListTile(
                  key: const Key('layer-beaches'),
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.beach_access_rounded,
                    color: Color(0xff0f8fa8),
                  ),
                  title: const Text(
                    'Praias',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  subtitle: const Text(
                    'Com planejamento de visita, maré e acesso',
                  ),
                  value: _kinds.contains(PoiKind.praias),
                  onChanged: (v) {
                    setSheet(() {});
                    setState(
                      () => v
                          ? _kinds.add(PoiKind.praias)
                          : _kinds.remove(PoiKind.praias),
                    );
                    _refreshPois();
                  },
                ),
                const Divider(height: MP.s5),
                ListTile(
                  key: const Key('layer-classic'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.tune_rounded,
                    color: MP.textSecondary,
                  ),
                  title: const Text(
                    'Ferramentas avançadas',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  subtitle: const Text(
                    'Gravação de trilha, relevo e simulação de rota',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(ref.read(repositoryProvider).loadRoads());
                    push<void>(
                      this.context,
                      Theme(data: legacyMapTheme(), child: const MapScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openVoice() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Theme(
        data: legacyMapTheme(),
        child: VoiceSearchSheet(
          onFocus: (place) {
            Navigator.of(context).maybePop();
            final hit = _pois.where((e) => e.id == place.id).firstOrNull;
            _select(
              hit ??
                  Poi(
                    id: place.id,
                    name: place.name,
                    city: place.city,
                    kind: PoiKind.fromPlace(place.category),
                    point: place.point,
                    place: place,
                  ),
            );
          },
        ),
      ),
    );
  }

  /// Recursos que vinham do mapa antigo, agora na prévia do ponto.
  List<(IconData, String, VoidCallback)> _extrasFor(Poi p) {
    final island = _islands[p.id];
    return [
      if (p.kind == PoiKind.praias)
        (
          Icons.beach_access_rounded,
          'Planejar visita à praia',
          () => push<void>(
            context,
            Theme(
              data: legacyMapTheme(),
              child: NavigationScreen(destination: p.asPlace),
            ),
          ),
        ),
      if (island != null) ...[
        (
          Icons.info_outline_rounded,
          'Sobre a ilha',
          () => push<void>(
            context,
            _LegacyPage(
              title: p.name,
              child: IslandVisitInfo(island: island),
            ),
          ),
        ),
        (
          Icons.directions_boat_rounded,
          'Travessias de barco',
          () => push<void>(
            context,
            Theme(
              data: legacyMapTheme(),
              child: NauticalScreen(islandId: island.place.id),
            ),
          ),
        ),
      ],
      if (hasMunicipalGuide(p.city))
        (
          Icons.menu_book_rounded,
          'Guia de ${p.city}',
          () => push<void>(
            context,
            _LegacyPage(
              title: 'Guia de ${p.city}',
              child: MunicipalVisitGuide(city: p.city),
            ),
          ),
        ),
    ];
  }

  Future<void> _refreshPois() async {
    if (!_ready) return;
    await _c?.setGeoJsonSource('pois', _poiCollection());
  }

  Future<void> _onMapClick(math.Point<double> pt, LatLng latLng) async {
    final c = _c;
    if (c == null || !_ready) return;
    if (_pickingOrigin) {
      final o = GeoPoint(latLng.latitude, latLng.longitude);
      setState(() {
        _pickingOrigin = false;
        _origin = o;
        _originLabel = 'Ponto escolhido no mapa';
      });
      await c.setGeoJsonSource('origin', _point(o));
      if (_selected != null) await _traceRoute();
      return;
    }
    // Área de toque de 48x48 px ao redor do dedo. Na web, a consulta volta
    // vazia enquanto o mapa ainda carrega blocos (logo após um zoom): tenta de
    // novo por alguns instantes antes de concluir que o toque foi no vazio.
    final rect = Rect.fromCenter(
      center: Offset(pt.x, pt.y),
      width: 48,
      height: 48,
    );
    var hits = <dynamic>[];
    for (var attempt = 0; attempt < 6; attempt++) {
      hits = await c.queryRenderedFeaturesInRect(rect, [
        'clusters',
        'poi-icons',
        'ferries-line',
      ], null);
      if (hits.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    // Prefere o agrupamento ou o ponto mais próximo do centro do toque.
    hits.sort((x, y) => _distTo(x, latLng).compareTo(_distTo(y, latLng)));
    if (hits.isEmpty) {
      if (_selected != null && _route == null) setState(() => _selected = null);
      return;
    }
    final f = Map<String, dynamic>.from(hits.first as Map);
    final props = Map<String, dynamic>.from(
      (f['properties'] as Map?) ?? const {},
    );
    if (props.containsKey('point_count')) {
      final coords = ((f['geometry'] as Map)['coordinates'] as List)
          .cast<num>();
      await c.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(coords[1].toDouble(), coords[0].toDouble()),
          (c.cameraPosition?.zoom ?? 8) + 2,
        ),
      );
      return;
    }
    if (props.containsKey('ferry')) {
      final island = '${props['island'] ?? ''}';
      await push<void>(
        context,
        Theme(
          data: legacyMapTheme(),
          child: NauticalScreen(islandId: island.isEmpty ? null : island),
        ),
      );
      return;
    }
    final id = props['id'] as String?;
    final p = _pois.where((e) => e.id == id).firstOrNull;
    if (p != null) _select(p, fly: false);
  }

  static double _distTo(Object? f, LatLng t) {
    try {
      final c = (((f as Map)['geometry'] as Map)['coordinates'] as List)
          .cast<num>();
      final dx = c[0] - t.longitude, dy = c[1] - t.latitude;
      return (dx * dx + dy * dy).toDouble();
    } catch (_) {
      return double.infinity;
    }
  }

  Future<void> _select(Poi p, {bool fly = true}) async {
    if (_plan != null) await _closePlan();
    setState(() {
      _selected = p;
      _route = null;
      _routeError = null;
    });
    await _c?.setGeoJsonSource('route', _line(const []));
    if (fly) {
      await _c?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(p.point.lat, p.point.lng), 14),
        duration: const Duration(milliseconds: 900),
      );
    }
  }

  /// Véu em fade durante a troca 2D/3D (a câmera também anima, sem corte).
  bool _veil = false;

  Future<void> _toggle3d() async {
    final c = _c;
    if (c == null) return;
    // Na web, a posição acompanhada pode vir vazia: pergunta ao mapa.
    final cam = await c.queryCameraPosition() ?? c.cameraPosition;
    final next = !_threeD;
    final target = next && _selected != null
        ? LatLng(_selected!.point.lat, _selected!.point.lng)
        : (cam?.target ?? _maranhao);
    final zoom = cam?.zoom ?? 6;
    setState(() {
      _threeD = next;
      _veil = true;
    });
    await c.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          // Prédios em volume só aparecem de perto: o 3D aproxima até a rua.
          zoom: next ? math.max(zoom, 15.5) : math.min(zoom, 14),
          tilt: next ? 60 : 0,
          bearing: next ? (cam?.bearing ?? 0) - 20 : 0,
        ),
      ),
      duration: const Duration(milliseconds: 1400),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _veil = false);
  }

  Future<void> _resetNorth() async {
    final cam = await _c?.queryCameraPosition() ?? _c?.cameraPosition;
    setState(() => _threeD = false);
    await _c?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: cam?.target ?? _maranhao, zoom: cam?.zoom ?? 6),
      ),
      duration: const Duration(milliseconds: 1000),
    );
  }

  /// GPS primeiro; se for negado ou falhar, pergunta de onde a pessoa sai.
  Future<GeoPoint?> _findOrigin() async {
    try {
      final pos = await LocationService().acquire().timeout(
        const Duration(seconds: 8),
      );
      _originLabel = 'Sua localização';
      return GeoPoint(pos.latitude, pos.longitude);
    } catch (_) {
      if (!mounted) return null;
      return _pickOrigin(gpsFailed: true);
    }
  }

  Future<GeoPoint?> _pickOrigin({bool gpsFailed = false}) async {
    final choice = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OriginSheet(gpsFailed: gpsFailed),
    );
    if (choice == 'gps') return _findOrigin();
    if (choice == 'map') {
      setState(() => _pickingOrigin = true);
      if (mounted) showMpSnack(context, 'Toque no mapa no ponto de partida.');
      return null;
    }
    if (choice is MapEntry<String, GeoPoint>) {
      _originLabel = choice.key;
      return choice.value;
    }
    return null;
  }

  Future<void> _locate() async {
    final o = await _findOrigin();
    if (o == null) return;
    setState(() => _origin = o);
    await _c?.setGeoJsonSource('origin', _point(o));
    await _c?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(o.lat, o.lng), 13),
      duration: const Duration(milliseconds: 800),
    );
  }

  Future<void> _changeOrigin() async {
    final o = await _pickOrigin();
    if (o == null) return;
    setState(() => _origin = o);
    await _traceRoute();
  }

  Future<void> _traceRoute() async {
    final dest = _selected;
    if (dest == null) return;
    setState(() {
      _routing = true;
      _routeError = null;
    });
    try {
      final o = _origin ?? await _findOrigin();
      if (o == null) return;
      final routes = await ref
          .read(routingRepositoryProvider)
          .routes(o, dest.point);
      if (routes.isEmpty) throw StateError('sem rota');
      final r = routes.first;
      ref.read(appStoreProvider).addRoute();
      setState(() {
        _origin = o;
        _route = r;
      });
      await _c?.setGeoJsonSource('origin', _point(o));
      await _c?.setGeoJsonSource('route', _line(r.points));
      final lats = r.points.map((e) => e.lat),
          lngs = r.points.map((e) => e.lng);
      await _c?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
            northeast: LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
          ),
          left: 48,
          right: 48,
          top: 160,
          bottom: 300,
        ),
        duration: const Duration(milliseconds: 900),
      );
    } catch (_) {
      setState(
        () => _routeError = 'Não foi possível traçar a rota agora. Confira a internet e tente de novo.',
      );
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  /// Visão de navegação 3D: câmera inclinada na partida, olhando a rota.
  Future<void> _followRoute3d() async {
    final r = _route;
    if (r == null || r.points.length < 2) return;
    final a = r.points.first, b = r.points[math.min(8, r.points.length - 1)];
    final bearing =
        (math.atan2(b.lng - a.lng, b.lat - a.lat) * 180 / math.pi + 360) % 360;
    setState(() => _threeD = true);
    await _c?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(a.lat, a.lng),
          zoom: 16.5,
          tilt: 62,
          bearing: bearing,
        ),
      ),
      duration: const Duration(milliseconds: 1200),
    );
  }

  Future<void> _clearRoute() async {
    setState(() {
      _route = null;
      _routeError = null;
    });
    await _c?.setGeoJsonSource('route', _line(const []));
  }

  void _openSearch() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PoiSearchSheet(
        pois: _pois,
        onPick: (p) {
          Navigator.of(context).pop();
          _select(p);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sem WebGL o MapLibre não abre: usa o mapa completo, que funciona em qualquer navegador.
    if (kIsWeb && !AppConfig.supportsVectorMaps) {
      return Theme(data: legacyMapTheme(), child: const MapScreen());
    }
    final pad = MediaQuery.paddingOf(context);
    ref.listen<DayPlan?>(itineraryRequestProvider, (_, next) {
      if (next != null) _consumePlan();
    });
    return Stack(
      children: [
        MapLibreMap(
          styleString: AppConfig.onlineStyle,
          initialCameraPosition: const CameraPosition(
            target: _maranhao,
            zoom: 5.6,
          ),
          onMapCreated: (c) => _c = c,
          onStyleLoadedCallback: _onStyleLoaded,
          onMapClick: _onMapClick,
          featureTapsTriggersMapClick: true,
          trackCameraPosition: true,
          compassEnabled: false,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          attributionButtonPosition: AttributionButtonPosition.bottomRight,
          minMaxZoomPreference: const MinMaxZoomPreference(4, 19),
        ),
        // Busca e filtros
        Positioned(
          left: 0,
          right: 0,
          top: pad.top + MP.s3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
                child: Material(
                elevation: 3,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(MP.rMedium),
                color: MP.card,
                child: InkWell(
                  key: const Key('map-search'),
                  borderRadius: BorderRadius.circular(MP.rMedium),
                  onTap: _openSearch,
                  child: SizedBox(
                    height: 54,
                    child: Row(
                      children: [
                        const SizedBox(width: MP.s4),
                        const Icon(
                          Icons.search_rounded,
                          color: MP.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: MP.s3),
                        const Expanded(
                          child: Text(
                            'Buscar no mapa',
                            style: TextStyle(
                              fontSize: 17,
                              color: MP.textSecondary,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('map-voice'),
                          tooltip: 'Buscar falando',
                          onPressed: _openVoice,
                          icon: const Icon(Icons.mic_rounded, color: MP.navy),
                        ),
                        const SizedBox(width: MP.s1),
                      ],
                    ),
                  ),
                ),
              ),
              ),
              const SizedBox(height: MP.s2),
              SizedBox(
                height: 48,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                    stops: [0, .05, .93, 1],
                  ).createShader(r),
                  child: ListView.separated(
                  key: const Key('map-kinds'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: MP.pageH, vertical: 2),
                  itemCount: PoiKind.values.length - 1,
                  separatorBuilder: (_, _) => const SizedBox(width: MP.s2),
                  itemBuilder: (_, i) {
                    final k = PoiKind.values[i];
                    final on = _kinds.contains(k);
                    return FilterChip(
                      key: Key('map-kind-${k.name}'),
                      selected: on,
                      showCheckmark: false,
                      avatar: Icon(
                        k.icon,
                        size: 18,
                        color: on ? Colors.white : k.color,
                      ),
                      label: Text(k.label),
                      labelStyle: TextStyle(
                        fontFamily: mpFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: on ? Colors.white : MP.ink,
                      ),
                      selectedColor: k.color,
                      backgroundColor: MP.card,
                      elevation: 2,
                      shadowColor: Colors.black26,
                      side: BorderSide(color: on ? k.color : MP.border),
                      onSelected: (v) {
                        setState(() => v ? _kinds.add(k) : _kinds.remove(k));
                        _refreshPois();
                      },
                    );
                  },
                ),
                ),
              ),
            ],
          ),
        ),
        // Controles do mapa
        Positioned(
          right: MP.pageH,
          top: pad.top + 132,
          child: Column(
            children: [
              _MapButton(
                key: const Key('map-3d'),
                label: '3D',
                tooltip: _threeD
                    ? 'Ver de cima (2D)'
                    : 'Ver em perspectiva (3D)',
                onTap: _toggle3d,
                active: _threeD,
              ),
              const SizedBox(height: MP.s2),
              _MapButton(
                icon: Icons.explore_rounded,
                tooltip: 'Apontar para o norte',
                onTap: _resetNorth,
              ),
              const SizedBox(height: MP.s2),
              _MapButton(
                key: const Key('map-locate'),
                icon: Icons.my_location_rounded,
                tooltip: 'Minha localização',
                onTap: _locate,
              ),
              const SizedBox(height: MP.s2),
              _MapButton(
                key: const Key('map-layers'),
                icon: Icons.layers_rounded,
                tooltip: 'Camadas: ilhas, travessias e praias',
                onTap: _openLayers,
              ),
            ],
          ),
        ),
        // Crédito dos dados do mapa (exigido pelo OpenStreetMap).
        Positioned(
          left: MP.s3,
          bottom: _selected == null ? MP.s2 : 4,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap · OpenFreeMap',
                style: TextStyle(fontSize: 11, color: MP.textSecondary),
              ),
            ),
          ),
        ),
        // Fade suave por cima do mapa enquanto a câmera troca 2D/3D.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _veil ? .22 : 0,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeInOut,
              child: const ColoredBox(color: Colors.white),
            ),
          ),
        ),
        if (!_ready)
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Color(0x66ffffff), child: MpLoading()),
            ),
          ),
        // Prévia do ponto / rota (16 px acima da barra inferior)
        if (_selected != null && _plan == null)
          Positioned(
            left: MP.s3,
            right: MP.s3,
            bottom: MP.s4,
            child: _PoiCard(
              poi: _selected!,
              route: _route,
              routing: _routing,
              error: _routeError,
              originLabel: _originLabel,
              onChangeOrigin: _changeOrigin,
              onClose: () {
                _clearRoute();
                setState(() => _selected = null);
              },
              onRoute: _traceRoute,
              onClearRoute: _clearRoute,
              onFollow3d: _followRoute3d,
              onNavigate: () => _navigate(
                name: _selected!.name,
                dest: _selected!.point,
                origin: _origin!,
                route: _route!,
                originLabel: _originLabel,
              ),
              onDetails: _selected!.item == null
                  ? null
                  : () => openItem(context, _selected!.item!),
              extras: _extrasFor(_selected!),
            ),
          ),
        if (_plan != null)
          Positioned(
            left: MP.s3,
            right: MP.s3,
            bottom: MP.s4,
            child: _PlanCard(
              plan: _plan!,
              route: _planRoute,
              busy: _planBusy,
              error: _planError,
              onClose: _closePlan,
              onStop: (k) => _c?.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(itemPoint(_plan!.stops[k].item).lat, itemPoint(_plan!.stops[k].item).lng),
                  15,
                ),
                duration: const Duration(milliseconds: 800),
              ),
              onFollow3d: () async {
                final r = _planRoute;
                if (r == null) return;
                final keep = _route;
                _route = r;
                await _followRoute3d();
                _route = keep;
              },
              onNavigate: () {
                final r = _planRoute;
                if (r == null) return;
                final first = _plan!.stops.first.item, last = _plan!.stops.last.item;
                _navigate(
                  name: last.titulo,
                  dest: itemPoint(last),
                  origin: itemPoint(first),
                  route: r,
                  originLabel: first.titulo,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    super.key,
    required this.tooltip,
    required this.onTap,
    this.icon,
    this.label,
    this.active = false,
  });
  final String tooltip;
  final VoidCallback onTap;
  final IconData? icon;
  final String? label;
  final bool active;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      elevation: 6,
      shadowColor: Colors.black54,
      color: active ? MP.navy : MP.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MP.rMedium),
        side: BorderSide(color: active ? MP.navy : MP.border, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(MP.rMedium),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: label != null
                ? Text(
                    label!,
                    style: TextStyle(
                      fontFamily: mpFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: active ? Colors.white : MP.ink,
                    ),
                  )
                : Icon(
                    icon,
                    color: active ? Colors.white : MP.ink,
                    size: 24,
                    semanticLabel: tooltip,
                  ),
          ),
        ),
      ),
    ),
  );
}

String _km(double m) => m >= 1000
    ? '${(m / 1000).toStringAsFixed(m >= 10000 ? 0 : 1).replaceAll('.', ',')} km'
    : '${m.round()} m';
String _time(double s) {
  final min = (s / 60).round();
  if (min < 60) return '$min min';
  return '${min ~/ 60} h ${(min % 60).toString().padLeft(2, '0')} min';
}

/// Botão compacto quadrado (ações secundárias como 3D).
class _SquareAction extends StatelessWidget {
  const _SquareAction({super.key, required this.label, required this.tooltip, required this.onTap});
  final String label, tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(MP.buttonHeight, MP.buttonHeight),
        maximumSize: const Size(72, MP.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: MP.s3),
        side: const BorderSide(color: MP.border, width: 1.5),
        foregroundColor: MP.navy,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
    ),
  );
}

/// Cabeçalho comum dos cards do mapa: foto (ou capa da categoria), título e X.
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.poi, required this.onX, required this.xTooltip, this.xKey});
  final Poi poi;
  final VoidCallback onX;
  final String xTooltip;
  final Key? xKey;
  @override
  Widget build(BuildContext context) {
    final it = poi.item;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: MpPhoto(
            key: const Key('poi-photo'),
            photo: it?.foto ?? _covers[poi.kind],
            height: 72,
            radius: MP.rMedium,
            icon: poi.kind.icon,
          ),
        ),
        const SizedBox(width: MP.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(poi.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(poi.kind.icon, size: 16, color: poi.kind.color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${poi.kind.label} · ${poi.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (it != null && it.loc != Loc.exato) ...[
                const SizedBox(height: 2),
                Row(
                  key: const Key('poi-precision'),
                  children: [
                    Icon(
                      it.loc == Loc.aproximado ? Icons.blur_circular_rounded : Icons.place_rounded,
                      size: 14,
                      color: MP.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(it.loc.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: MP.textSecondary)),
                    ),
                  ],
                ),
              ],
              if (it?.nota != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    RatingLine(item: it!, size: 14),
                    const SizedBox(width: MP.s2),
                    Text(it.faixaLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: MP.green)),
                  ],
                ),
              ],
            ],
          ),
        ),
        IconButton(
          key: xKey,
          tooltip: xTooltip,
          onPressed: onX,
          style: IconButton.styleFrom(backgroundColor: MP.soft, minimumSize: const Size(44, 44)),
          icon: const Icon(Icons.close_rounded, color: MP.ink),
        ),
      ],
    );
  }
}

class _PoiCard extends StatelessWidget {
  const _PoiCard({
    required this.poi,
    required this.route,
    required this.routing,
    required this.error,
    required this.originLabel,
    required this.onChangeOrigin,
    required this.onClose,
    required this.onRoute,
    required this.onClearRoute,
    required this.onFollow3d,
    required this.onNavigate,
    required this.onDetails,
    this.extras = const [],
  });
  final Poi poi;
  final RoadRoute? route;
  final bool routing;
  final String? error;
  final String originLabel;
  final VoidCallback onChangeOrigin;
  final VoidCallback onClose, onRoute, onClearRoute, onFollow3d, onNavigate;
  final VoidCallback? onDetails;
  final List<(IconData, String, VoidCallback)> extras;

  @override
  Widget build(BuildContext context) {
    final r = route;
    final it = poi.item;
    final stay = it != null && (it.cat == Cat.hospedagem || it.cat == Cat.gastronomia);
    return Material(
      key: const Key('map-poi-card'),
      elevation: 10,
      shadowColor: Colors.black45,
      color: MP.card,
      borderRadius: BorderRadius.circular(MP.rXl),
      child: Padding(
        padding: const EdgeInsets.all(MP.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardHeader(
              poi: poi,
              onX: r != null ? onClearRoute : onClose,
              xTooltip: r != null ? 'Limpar rota' : 'Fechar',
              xKey: Key(r != null ? 'route-clear' : 'poi-close'),
            ),
            if (r != null) ...[
              const SizedBox(height: MP.s3),
              // Linha de informações da rota
              Container(
                key: const Key('route-info'),
                padding: const EdgeInsets.fromLTRB(MP.s3, MP.s3, MP.s1, MP.s2),
                decoration: BoxDecoration(color: const Color(0xffeef4fd), borderRadius: BorderRadius.circular(MP.rMedium)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _time(r.duration),
                          key: const Key('route-time'),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xff0b57d0)),
                        ),
                        const SizedBox(width: MP.s2),
                        Expanded(
                          child: Text(
                            '${_km(r.distance)}${r.summary.isEmpty ? '' : ' · via ${r.summary}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, color: MP.text, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.trip_origin_rounded, size: 16, color: Color(0xff1a73e8)),
                        const SizedBox(width: MP.s1),
                        Expanded(
                          child: Text(
                            'Partida: $originLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, color: MP.textSecondary),
                          ),
                        ),
                        IconButton(
                          key: const Key('route-origin'),
                          tooltip: 'Alterar partida',
                          onPressed: onChangeOrigin,
                          icon: const Icon(Icons.edit_location_alt_rounded, color: MP.navy),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MP.s3),
              // Linha de ações: 1 primária + 1 compacta
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('route-go'),
                      onPressed: onNavigate,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(MP.buttonHeight)),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Iniciar navegação'),
                    ),
                  ),
                  const SizedBox(width: MP.s2),
                  _SquareAction(key: const Key('route-3d'), label: '3D', tooltip: 'Ver a partida em 3D', onTap: onFollow3d),
                ],
              ),
            ] else ...[
              if (stay) ...[
                const SizedBox(height: MP.s3),
                StayFacts(item: it, compact: true),
              ],
              if (extras.isNotEmpty) ...[
                const SizedBox(height: MP.s3),
                Wrap(
                  spacing: MP.s2,
                  runSpacing: MP.s2,
                  children: [
                    for (final e in extras)
                      ActionChip(
                        key: Key('poi-extra-${e.$2}'),
                        avatar: Icon(e.$1, size: 18, color: MP.navy),
                        label: Text(e.$2),
                        onPressed: e.$3,
                      ),
                  ],
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: MP.s3),
                MpNotice(error!, icon: Icons.wifi_off_rounded, fg: MP.error, bg: MP.errorBg),
              ],
              const SizedBox(height: MP.s3),
              Row(
                children: [
                  if (onDetails != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('poi-details'),
                        onPressed: onDetails,
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(MP.buttonHeight)),
                        child: Text(it?.cat == Cat.hospedagem ? 'Disponibilidade' : 'Ver detalhes'),
                      ),
                    ),
                    const SizedBox(width: MP.s2),
                  ],
                  Expanded(
                    child: MpPrimaryButton(
                      key: const Key('route-trace'),
                      label: 'Traçar rota',
                      icon: Icons.directions_rounded,
                      busy: routing,
                      onPressed: onRoute,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card do roteiro do dia no mapa: paradas numeradas, tempo total e navegação.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.route,
    required this.busy,
    required this.error,
    required this.onClose,
    required this.onStop,
    required this.onFollow3d,
    required this.onNavigate,
  });
  final DayPlan plan;
  final RoadRoute? route;
  final bool busy;
  final String? error;
  final VoidCallback onClose, onFollow3d, onNavigate;
  final ValueChanged<int> onStop;

  @override
  Widget build(BuildContext context) {
    final r = route;
    return Material(
      key: const Key('map-plan-card'),
      elevation: 10,
      shadowColor: Colors.black45,
      color: MP.card,
      borderRadius: BorderRadius.circular(MP.rXl),
      child: Padding(
        padding: const EdgeInsets.all(MP.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: MP.tintGreen, borderRadius: BorderRadius.circular(MP.rMedium)),
                  child: const Icon(Icons.route_rounded, color: MP.green),
                ),
                const SizedBox(width: MP.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Roteiro do dia · ${plan.city}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        busy
                            ? 'Traçando o percurso…'
                            : r == null
                            ? '${plan.stops.length} paradas'
                            : '${_time(r.duration)} de carro · ${_km(r.distance)} · ${plan.stops.length} paradas',
                        key: const Key('plan-summary'),
                        style: const TextStyle(fontSize: 14, color: MP.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('plan-close'),
                  tooltip: 'Fechar roteiro',
                  onPressed: onClose,
                  style: IconButton.styleFrom(backgroundColor: MP.soft, minimumSize: const Size(44, 44)),
                  icon: const Icon(Icons.close_rounded, color: MP.ink),
                ),
              ],
            ),
            const SizedBox(height: MP.s3),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: plan.stops.length,
                separatorBuilder: (_, _) => const SizedBox(width: MP.s2),
                itemBuilder: (_, k) {
                  final st = plan.stops[k];
                  return ActionChip(
                    key: Key('plan-stop-$k'),
                    avatar: CircleAvatar(
                      backgroundColor: st.anchor ? MP.yellow : MP.navy,
                      child: Text('${k + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: st.anchor ? MP.ink : Colors.white)),
                    ),
                    label: Text('${st.time} · ${st.item.titulo}'),
                    onPressed: () => onStop(k),
                  );
                },
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: MP.s3),
              MpNotice(error!, icon: Icons.wifi_off_rounded, fg: MP.warning, bg: MP.warningBg),
            ],
            const SizedBox(height: MP.s3),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('plan-go'),
                    onPressed: r == null ? null : onNavigate,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(MP.buttonHeight)),
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text('Iniciar navegação'),
                  ),
                ),
                const SizedBox(width: MP.s2),
                _SquareAction(key: const Key('plan-3d'), label: '3D', tooltip: 'Ver a partida em 3D', onTap: onFollow3d),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PoiSearchSheet extends StatefulWidget {
  const _PoiSearchSheet({required this.pois, required this.onPick});
  final List<Poi> pois;
  final ValueChanged<Poi> onPick;
  @override
  State<_PoiSearchSheet> createState() => _PoiSearchSheetState();
}

class _PoiSearchSheetState extends State<_PoiSearchSheet> {
  StreamSubscription<Position>? updates;
  Timer? expiry;
  Position? fix;
  double? course;

  @override
  void initState() {
    super.initState();
    watchLocation();
  }

  Future<void> watchLocation() async {
    final gateway = LocationService().gateway;
    try {
      await gateway.authorize();
      if (!mounted) return;
      updates = gateway.updates().listen((p) {
        if (!mounted || !usablePosition(p, maximumAccuracy: 50)) return;
        expiry?.cancel();
        setState(() { course = travelCourse(p, fix); fix = p; });
        expiry = Timer(courseValidity - DateTime.now().difference(p.timestamp), () {
          if (mounted) setState(() { course = null; fix = null; });
        });
      }, onError: (Object _) {});
    } on Exception { /* A pesquisa textual continua disponível. */ }
  }

  @override
  void dispose() {
    updates?.cancel();
    expiry?.cancel();
    super.dispose();
  }

  String _q = '';
  static String _n(String s) {
    const a = 'áàâãéêíóôõúüçÁÀÂÃÉÊÍÓÔÕÚÜÇ', b = 'aaaaeeiooouucAAAAEEIOOOUUC';
    final o = StringBuffer();
    for (final ch in s.split('')) {
      final k = a.indexOf(ch);
      o.write(k >= 0 ? b[k] : ch);
    }
    return o.toString().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final q = _n(_q.trim());
    final position = fix;
    final origin = position == null ? null : GeoPoint(position.latitude, position.longitude);
    final candidates = widget.pois.where((p) => q.length < 2
        ? origin != null || (p.featured && p.item != null)
        : _n([p.name, p.city, ...?p.place?.searchAliases].join(' ')).contains(q)).toList();
    if (origin != null) {
      final heading = course;
      final ahead = {if (heading != null) for (final p in candidates) if (isAhead(origin,p.point,heading)) p.id};
      final km = {for (final p in candidates) p.id: origin.distanceKm(p.point)};
      candidates.sort((a,b) {
        if (ahead.contains(a.id) != ahead.contains(b.id)) return ahead.contains(a.id) ? -1 : 1;
        final distance = km[a.id]!.compareTo(km[b.id]!);
        return distance != 0 ? distance : a.name.compareTo(b.name);
      });
    }
    final list = candidates.take(q.length < 2 ? 12 : 40).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s3),
              child: TextField(
                key: const Key('map-search-field'),
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'Lugar, cidade ou ponto cultural',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            if (q.length < 2)
              Padding(
                padding: EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    origin == null ? 'Destaques' : 'Lugares próximos',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
            Expanded(
              child: list.isEmpty
                  ? const MpEmpty(
                      icon: Icons.search_off_rounded,
                      title: 'Nada encontrado',
                      message: 'Tente o nome da cidade ou do lugar.',
                    )
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(indent: 76),
                      itemBuilder: (_, i) {
                        final p = list[i];
                        return ListTile(
                          minTileHeight: 64,
                          leading: CircleAvatar(
                            backgroundColor: p.kind.color.withValues(
                              alpha: .14,
                            ),
                            child: Icon(p.kind.icon, color: p.kind.color),
                          ),
                          title: Text(
                            p.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text('${p.kind.label} · ${p.city}'),
                          onTap: () => widget.onPick(p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Folha de ponto de partida: GPS de novo, uma cidade ou um toque no mapa.
class _OriginSheet extends StatelessWidget {
  const _OriginSheet({required this.gpsFailed});
  final bool gpsFailed;
  @override
  Widget build(BuildContext context) {
    final cities = _cityCenters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: ListView(
          key: const Key('origin-sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s5),
          children: [
            Text(
              'De onde você sai?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (gpsFailed) ...[
              const SizedBox(height: MP.s2),
              const MpNotice(
                'Não conseguimos sua localização. Verifique se o navegador tem permissão de localização, ou escolha o ponto de partida.',
                icon: Icons.location_off_rounded,
                fg: MP.warning,
                bg: MP.warningBg,
              ),
            ],
            const SizedBox(height: MP.s3),
            ListTile(
              key: const Key('origin-gps'),
              minTileHeight: 60,
              leading: const CircleAvatar(
                backgroundColor: Color(0xffe8f0fe),
                child: Icon(
                  Icons.my_location_rounded,
                  color: Color(0xff1a73e8),
                ),
              ),
              title: const Text(
                'Usar minha localização',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              subtitle: const Text('Tentar o GPS de novo'),
              onTap: () => Navigator.of(context).pop('gps'),
            ),
            ListTile(
              key: const Key('origin-map'),
              minTileHeight: 60,
              leading: const CircleAvatar(
                backgroundColor: MP.soft,
                child: Icon(Icons.touch_app_rounded, color: MP.navy),
              ),
              title: const Text(
                'Tocar no mapa',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              subtitle: const Text('Escolha o ponto exato'),
              onTap: () => Navigator.of(context).pop('map'),
            ),
            const Divider(height: MP.s5),
            const Text(
              'Ou saia de uma cidade',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: MP.textSecondary,
              ),
            ),
            for (final c in cities)
              ListTile(
                key: Key('origin-city-${c.key}'),
                minTileHeight: 56,
                leading: const Icon(
                  Icons.location_city_rounded,
                  color: MP.navy,
                ),
                title: Text(
                  c.key,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(c),
              ),
          ],
        ),
      ),
    );
  }
}

/// Página no padrão do app para fichas reaproveitadas do mapa antigo.
class _LegacyPage extends StatelessWidget {
  const _LegacyPage({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s8),
        children: [
          MpHeader(title),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Theme(data: legacyMapTheme(), child: child),
          ),
        ],
      ),
    ),
  );
}
