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
import '../../domain/tourism.dart';
import '../../location/location_service.dart';
import '../../presentation/legacy_theme.dart';
import '../../presentation/municipal_visit_guide.dart';
import '../../voice/voice_search_sheet.dart';
import '../data/content.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'common.dart';
import 'itinerary.dart';
import 'nav_screen.dart';
import 'stay.dart';

part 'map_tab_poi.dart';
part 'map_tab_widgets.dart';

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
  static const _barH = 52.0;
  MapLibreMapController? _c;
  bool _ready = false;
  bool _threeD = false;
  bool _showIslands = true;
  bool _showFerries = true;
  Map<String, CoastalIsland> _islands = const {};
  NauticalCatalog? _ferries;
  final Set<PoiKind> _kinds = {...PoiKind.values};
  /// Categoria escolhida na barra inferior (null = todas).
  PoiKind? _cat;
  final _searchCtl = TextEditingController();
  final _searchFocus = FocusNode();
  List<Poi> _pois = const [];

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
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
  @override
  void dispose() {
    _searchCtl.dispose();
    _searchFocus.dispose();
    super.dispose();
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
    // Catálogo do mapa primeiro, para ligar cada item editorial ao lugar
    // correspondente em vez de desenhar dois pontos para o mesmo lugar.
    final places = <TourismPlace>[];
    try {
      final repo = ref.read(repositoryProvider);
      if (repo.loaded) {
        _islands = {for (final i in repo.coastalIslands) i.place.id: i};
        places.addAll(repo.basePlaces);
      }
    } catch (_) {
      // sem o catálogo do mapa (testes): só os pontos do app
    }
    return linkPois(
      items: Content.items,
      places: places,
      islandIds: _islands.keys.toSet(),
      cities: _cityCenters.keys.toSet(),
    );
  }

  Map<String, dynamic> _poiCollection() => {
    'type': 'FeatureCollection',
    'features': [
      for (final p in _pois)
        if (_kinds.contains(p.kind) && (_cat == null || p.kind == _cat))
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
                    color: MP.poiIsland,
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
                    color: MP.poiBeach,
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
    // O toque no resultado da busca também chega ao mapa por baixo: ignora.
    if (DateTime.now().difference(_lastPick).inMilliseconds < 1200) return;
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

  static String _norm(String s) {
    const a = 'áàâãéêíóôõúüçÁÀÂÃÉÊÍÓÔÕÚÜÇ', b = 'aaaaeeiooouucAAAAEEIOOOUUC';
    final o = StringBuffer();
    for (final ch in s.split('')) {
      final k = a.indexOf(ch);
      o.write(k >= 0 ? b[k] : ch);
    }
    return o.toString().toLowerCase();
  }

  /// Resultados da busca unificada, em três grupos, já filtrados pela categoria.
  List<(String, List<Poi>)> _results() {
    final q = _norm(_searchCtl.text.trim());
    Iterable<Poi> base = _pois.where((p) => _cat == null || p.kind == _cat);
    if (q.length >= 2) {
      base = base.where(
        (p) => _norm('${p.name} ${p.city} ${p.kind.label} ${p.item?.titulo ?? ''} ${p.place?.offerTitle ?? ''}').contains(q),
      );
    } else {
      base = base.where((p) => p.hasCoupon || p.featured);
    }
    final all = base.toList();
    final partners = all.where((p) => p.isPartner || p.hasCoupon).toList()
      ..sort((a, b) => (b.hasCoupon ? 1 : 0).compareTo(a.hasCoupon ? 1 : 0));
    final taken = {...partners.map((p) => p.id)};
    final tours = all.where((p) => !taken.contains(p.id) && p.item != null).toList();
    taken.addAll(tours.map((p) => p.id));
    final places = all.where((p) => !taken.contains(p.id)).toList();
    return [
      if (partners.isNotEmpty) ('Parceiros e ofertas', partners.take(8).toList()),
      if (tours.isNotEmpty) ('Passeios e experiências', tours.take(8).toList()),
      if (places.isNotEmpty) ('Pontos turísticos', places.take(10).toList()),
    ];
  }

  DateTime _lastPick = DateTime(2000);

  void _pickResult(Poi p) {
    _lastPick = DateTime.now();
    _searchFocus.unfocus();
    _searchCtl.text = p.name;
    _select(p);
  }

  Future<void> _clearSearch() async {
    _searchCtl.clear();
    _searchFocus.unfocus();
    final had = _selected != null;
    _clearRoute();
    setState(() => _selected = null);
    if (had) {
      await _c?.animateCamera(
        CameraUpdate.newLatLngZoom(_maranhao, 5.6),
        duration: const Duration(milliseconds: 700),
      );
    }
  }

  void _setCat(PoiKind k) {
    setState(() => _cat = _cat == k ? null : k);
    _refreshPois();
  }

  @override
  Widget build(BuildContext context) {
    // Sem WebGL o MapLibre não abre: avisa e oferece o mapa do aparelho.
    if (kIsWeb && !AppConfig.supportsVectorMaps) {
      return const _MapUnsupported();
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
        // Busca unificada
        Positioned(
          left: 0,
          right: 0,
          top: pad.top + MP.s3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  elevation: 3,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(MP.rMedium),
                  color: MP.card,
                  child: SizedBox(
                    height: 54,
                    child: Row(
                      children: [
                        const SizedBox(width: MP.s4),
                        const Icon(Icons.search_rounded, color: MP.textSecondary, size: 24),
                        const SizedBox(width: MP.s3),
                        Expanded(
                          child: TextField(
                            key: const Key('map-search'),
                            controller: _searchCtl,
                            focusNode: _searchFocus,
                            onChanged: (_) => setState(() {}),
                            textInputAction: TextInputAction.search,
                            style: const TextStyle(fontSize: 17),
                            decoration: const InputDecoration(
                              hintText: 'Buscar parceiros, cupons e passeios',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_searchCtl.text.isNotEmpty || _selected != null)
                          IconButton(
                            key: const Key('map-search-clear'),
                            tooltip: 'Limpar busca',
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close_rounded, color: MP.textSecondary),
                          )
                        else
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
                if (_searchFocus.hasFocus) ...[
                  const SizedBox(height: MP.s2),
                  _SearchResults(
                    key: const Key('map-results'),
                    groups: _results(),
                    maxHeight: MediaQuery.sizeOf(context).height * .5,
                    onPick: _pickResult,
                  ),
                ],
              ],
            ),
          ),
        ),
        // Controles do mapa (somem enquanto os resultados da busca estão abertos)
        if (!_searchFocus.hasFocus)
        Positioned(
          right: MP.pageH,
          top: pad.top + 84,
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
        // Categorias na base
        Positioned(
          left: 0,
          right: 0,
          bottom: MP.s3,
          child: SizedBox(
            height: _barH,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => const LinearGradient(
                colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                stops: [0, .04, .94, 1],
              ).createShader(r),
              child: ListView.separated(
                key: const Key('map-kinds'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: MP.pageH, vertical: 4),
                itemCount: PoiKind.values.length - 1,
                separatorBuilder: (_, _) => const SizedBox(width: MP.s2),
                itemBuilder: (_, i) {
                  final k = PoiKind.values[i];
                  final on = _cat == k;
                  return FilterChip(
                    key: Key('map-kind-${k.name}'),
                    selected: on,
                    showCheckmark: false,
                    avatar: Icon(k.icon, size: 20, color: on ? Colors.white : k.color),
                    label: Text(k.label),
                    labelStyle: TextStyle(
                      fontFamily: mpFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: on ? Colors.white : MP.ink,
                    ),
                    selectedColor: k.color,
                    backgroundColor: MP.card,
                    elevation: 3,
                    shadowColor: Colors.black26,
                    side: BorderSide(color: on ? k.color : MP.border),
                    onSelected: (_) => _setCat(k),
                  );
                },
              ),
            ),
          ),
        ),
        // Crédito dos dados do mapa (exigido pelo OpenStreetMap).
        Positioned(
          left: MP.s3,
          bottom: _barH + MP.s3 + 2,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap · OpenFreeMap',
                style: TextStyle(fontSize: 13, color: MP.textSecondary),
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
            bottom: _barH + MP.s3 + MP.s2,
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
            bottom: _barH + MP.s3 + MP.s2,
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
