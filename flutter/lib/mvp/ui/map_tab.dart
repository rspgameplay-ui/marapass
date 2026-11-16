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
import '../../domain/navigation.dart';
import '../../domain/tourism.dart';
import '../../location/location_service.dart';
import '../../presentation/legacy_theme.dart';
import '../../presentation/map_screen.dart';
import '../../presentation/navigation_screen.dart';
import '../data/content.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'common.dart';

/// Tipos de ponto no mapa, com cor e ícone próprios.
enum PoiKind {
  cultura('Cultura', Icons.account_balance_rounded, Color(0xff8a5a2b)),
  natureza('Natureza', Icons.forest_rounded, Color(0xff14775a)),
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
          PoiKind.natureza => PlaceCategory.nature,
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

/// Sedes aproximadas das cidades do catálogo editorial (pontos de demonstração).
const _cityCenters = <String, GeoPoint>{
  'Barreirinhas': GeoPoint(-2.7547, -42.8269),
  'Santo Amaro': GeoPoint(-2.5033, -43.2558),
  'Atins': GeoPoint(-2.5773, -42.7434),
  'São Luís': GeoPoint(-2.5297, -44.3028),
  'Axixá': GeoPoint(-2.8394, -44.0619),
  'Carolina': GeoPoint(-7.3325, -47.4689),
  'Cururupu': GeoPoint(-1.8289, -44.8686),
  'Tutóia': GeoPoint(-2.7617, -42.2742),
  'Rosário': GeoPoint(-2.9342, -44.2342),
  'Codó': GeoPoint(-4.4553, -43.8856),
  'Fernando Falcão': GeoPoint(-6.1617, -44.8975),
};

const _maranhao = LatLng(-3.9, -44.8);
const _barreirinhas = GeoPoint(-2.7547, -42.8269);

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
  final Set<PoiKind> _kinds = {...PoiKind.values};
  late final List<Poi> _pois = _buildPois();
  Poi? _selected;
  RoadRoute? _route;
  GeoPoint? _origin;
  bool _originIsGps = false;
  bool _routing = false;
  String? _routeError;

  List<Poi> _buildPois() {
    final out = <Poi>[];
    final rnd = math.Random(7);
    for (final i in Content.items) {
      final c = _cityCenters[i.cidade];
      if (c == null) continue;
      // Espalha os pontos da mesma cidade para não ficarem sobrepostos.
      final a = rnd.nextDouble() * math.pi * 2,
          r = .004 + rnd.nextDouble() * .012;
      out.add(
        Poi(
          id: i.id,
          name: i.titulo,
          city: i.cidade,
          kind: PoiKind.fromCat(i.cat),
          point: GeoPoint(c.lat + math.sin(a) * r, c.lng + math.cos(a) * r),
          item: i,
          featured: true,
        ),
      );
    }
    try {
      final repo = ref.read(repositoryProvider);
      for (final p in repo.basePlaces) {
        if (p.category == PlaceCategory.residential) continue;
        out.add(
          Poi(
            id: p.id,
            name: p.name,
            city: p.city,
            kind: PoiKind.fromPlace(p.category),
            point: p.point,
            place: p,
            featured: p.category == PlaceCategory.culture,
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
  }

  Future<void> _refreshPois() async {
    if (!_ready) return;
    await _c?.setGeoJsonSource('pois', _poiCollection());
  }

  Future<void> _onMapClick(math.Point<double> pt, LatLng latLng) async {
    final c = _c;
    if (c == null || !_ready) return;
    final hits = await c.queryRenderedFeatures(pt, [
      'poi-icons',
      'clusters',
    ], null);
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

  Future<void> _select(Poi p, {bool fly = true}) async {
    setState(() {
      _selected = p;
      _route = null;
      _routeError = null;
    });
    await _c?.setGeoJsonSource('route', _line(const []));
    if (fly)
      await _c?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(p.point.lat, p.point.lng), 14),
        duration: const Duration(milliseconds: 900),
      );
  }

  Future<void> _toggle3d() async {
    final c = _c;
    if (c == null) return;
    final cam = c.cameraPosition;
    final next = !_threeD;
    setState(() => _threeD = next);
    await c.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: next && _selected != null
              ? LatLng(_selected!.point.lat, _selected!.point.lng)
              : (cam?.target ?? _maranhao),
          zoom: next && _selected != null
              ? math.max(cam?.zoom ?? 6, 15)
              : (cam?.zoom ?? 6),
          tilt: next ? 60 : 0,
          bearing: next ? (cam?.bearing ?? 0) + 25 : 0,
        ),
      ),
      duration: const Duration(milliseconds: 900),
    );
  }

  Future<void> _resetNorth() async {
    final cam = _c?.cameraPosition;
    setState(() => _threeD = false);
    await _c?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: cam?.target ?? _maranhao, zoom: cam?.zoom ?? 6),
      ),
      duration: const Duration(milliseconds: 600),
    );
  }

  Future<GeoPoint> _findOrigin() async {
    try {
      final pos = await LocationService().acquire().timeout(
        const Duration(seconds: 8),
      );
      _originIsGps = true;
      return GeoPoint(pos.latitude, pos.longitude);
    } catch (_) {
      _originIsGps = false;
      return _barreirinhas;
    }
  }

  Future<void> _locate() async {
    final o = await _findOrigin();
    setState(() => _origin = o);
    await _c?.setGeoJsonSource('origin', _point(o));
    await _c?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(o.lat, o.lng), 13),
      duration: const Duration(milliseconds: 800),
    );
    if (!_originIsGps && mounted)
      showMpSnack(
        context,
        'Sem acesso ao GPS: usando Barreirinhas como ponto de partida.',
      );
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
          left: MP.pageH,
          right: MP.pageH,
          top: pad.top + MP.s3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                elevation: 3,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(MP.rMedium),
                color: MP.card,
                child: InkWell(
                  key: const Key('map-search'),
                  borderRadius: BorderRadius.circular(MP.rMedium),
                  onTap: _openSearch,
                  child: const SizedBox(
                    height: 54,
                    child: Row(
                      children: [
                        SizedBox(width: MP.s4),
                        Icon(
                          Icons.search_rounded,
                          color: MP.textSecondary,
                          size: 24,
                        ),
                        SizedBox(width: MP.s3),
                        Expanded(
                          child: Text(
                            'Buscar no mapa',
                            style: TextStyle(
                              fontSize: 17,
                              color: MP.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MP.s2),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: PoiKind.values.length - 1,
                  separatorBuilder: (_, __) => const SizedBox(width: MP.s2),
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
                      onSelected: (v) {
                        setState(() => v ? _kinds.add(k) : _kinds.remove(k));
                        _refreshPois();
                      },
                    );
                  },
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
                label: _threeD ? '2D' : '3D',
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
                icon: Icons.layers_rounded,
                tooltip: 'Mapa completo: praias, ilhas, guia municipal e voz',
                onTap: () => push<void>(
                  context,
                  Theme(data: legacyMapTheme(), child: const MapScreen()),
                ),
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
        if (!_ready)
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Color(0x66ffffff), child: MpLoading()),
            ),
          ),
        // Prévia do ponto / rota
        if (_selected != null)
          Positioned(
            left: MP.s3,
            right: MP.s3,
            bottom: MP.s6,
            child: _PoiCard(
              poi: _selected!,
              route: _route,
              routing: _routing,
              error: _routeError,
              originIsGps: _originIsGps,
              onClose: () {
                _clearRoute();
                setState(() => _selected = null);
              },
              onRoute: _traceRoute,
              onClearRoute: _clearRoute,
              onFollow3d: _followRoute3d,
              onNavigate: () => push<void>(
                context,
                Theme(
                  data: legacyMapTheme(),
                  child: NavigationScreen(
                    destination: _selected!.asPlace,
                    autoPlan: true,
                  ),
                ),
              ),
              onDetails: _selected!.item == null
                  ? null
                  : () => openItem(context, _selected!.item!),
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
      elevation: 3,
      shadowColor: Colors.black26,
      color: active ? MP.navy : MP.card,
      borderRadius: BorderRadius.circular(MP.rMedium),
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

class _PoiCard extends StatelessWidget {
  const _PoiCard({
    required this.poi,
    required this.route,
    required this.routing,
    required this.error,
    required this.originIsGps,
    required this.onClose,
    required this.onRoute,
    required this.onClearRoute,
    required this.onFollow3d,
    required this.onNavigate,
    required this.onDetails,
  });
  final Poi poi;
  final RoadRoute? route;
  final bool routing;
  final String? error;
  final bool originIsGps;
  final VoidCallback onClose, onRoute, onClearRoute, onFollow3d, onNavigate;
  final VoidCallback? onDetails;

  static String _km(double m) => m >= 1000
      ? '${(m / 1000).toStringAsFixed(m >= 10000 ? 0 : 1).replaceAll('.', ',')} km'
      : '${m.round()} m';
  static String _time(double s) {
    final min = (s / 60).round();
    if (min < 60) return '$min min';
    return '${min ~/ 60} h ${(min % 60).toString().padLeft(2, '0')} min';
  }

  @override
  Widget build(BuildContext context) {
    final r = route;
    return Material(
      key: const Key('map-poi-card'),
      elevation: 8,
      shadowColor: Colors.black38,
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
                SizedBox(
                  width: 64,
                  height: 64,
                  child: poi.item?.foto != null
                      ? MpPhoto(
                          photo: poi.item!.foto,
                          height: 64,
                          radius: MP.rMedium,
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: poi.kind.color.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(MP.rMedium),
                          ),
                          child: Icon(
                            poi.kind.icon,
                            color: poi.kind.color,
                            size: 32,
                          ),
                        ),
                ),
                const SizedBox(width: MP.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poi.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${poi.kind.label} · ${poi.city}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: MP.s3),
            if (r != null) ...[
              Container(
                padding: const EdgeInsets.all(MP.s3),
                decoration: BoxDecoration(
                  color: const Color(0xffe8f0fe),
                  borderRadius: BorderRadius.circular(MP.rMedium),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_car_rounded,
                      color: Color(0xff1a73e8),
                      size: 28,
                    ),
                    const SizedBox(width: MP.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _time(r.duration),
                            key: const Key('route-time'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff0b57d0),
                            ),
                          ),
                          Text(
                            '${_km(r.distance)}${r.summary.isEmpty ? '' : ' · via ${r.summary}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: MP.text,
                            ),
                          ),
                          if (!originIsGps)
                            const Text(
                              'Partida: Barreirinhas (sem GPS)',
                              style: TextStyle(
                                fontSize: 13,
                                color: MP.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MP.s3),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('route-3d'),
                      onPressed: onFollow3d,
                      icon: const Icon(Icons.view_in_ar_rounded),
                      label: const Text('Ver em 3D'),
                    ),
                  ),
                  const SizedBox(width: MP.s2),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('route-go'),
                      onPressed: onNavigate,
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Iniciar'),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: onClearRoute,
                child: const Text('Limpar rota'),
              ),
            ] else ...[
              if (error != null) ...[
                MpNotice(
                  error!,
                  icon: Icons.wifi_off_rounded,
                  fg: MP.error,
                  bg: MP.errorBg,
                ),
                const SizedBox(height: MP.s3),
              ],
              Row(
                children: [
                  if (onDetails != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDetails,
                        child: const Text('Ver detalhes'),
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

class _PoiSearchSheet extends StatefulWidget {
  const _PoiSearchSheet({required this.pois, required this.onPick});
  final List<Poi> pois;
  final ValueChanged<Poi> onPick;
  @override
  State<_PoiSearchSheet> createState() => _PoiSearchSheetState();
}

class _PoiSearchSheetState extends State<_PoiSearchSheet> {
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
    final list = q.length < 2
        ? widget.pois
              .where((p) => p.featured && p.item != null)
              .take(12)
              .toList()
        : widget.pois
              .where((p) => _n('${p.name} ${p.city}').contains(q))
              .take(40)
              .toList();
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
              const Padding(
                padding: EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Destaques',
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
                      separatorBuilder: (_, __) => const Divider(indent: 76),
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
