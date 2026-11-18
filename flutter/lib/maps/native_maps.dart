import '../domain/navigation.dart';
import '../presentation/brand.dart';
import '../navigation/google_traveler_icons.dart';
import '../navigation/traveler_marker.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';

import 'place_marker.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../environment/map_appearance.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart' as g;
import 'package:maplibre_gl/maplibre_gl.dart' as m;

import '../application/map_state.dart';
import '../core/config.dart';
import '../domain/tourism.dart';
import 'essential_map.dart';
import 'road_map.dart';
import 'reference_roads.dart';
import '../islands/coastal_island.dart';

class MapCanvas extends StatelessWidget {
  const MapCanvas({
    super.key,
    required this.state,
    required this.boundary,
    required this.onFeature,
    required this.onViewport,
    this.overlayBottom,
    this.municipalBoundaries,
    this.reference,
    this.terrainManifest,
    this.coastalIslands = const [],
  });
  final double? overlayBottom;
  final MapState state;
  final Map<String, dynamic> boundary;
  final Map<String, dynamic>? municipalBoundaries;
  final ReferenceRoadNetwork? reference;
  final Map<String, dynamic>? terrainManifest;
  final List<CoastalIsland> coastalIslands;
  final ValueChanged<MapFeature> onFeature;
  final void Function(GeoBounds, double) onViewport;
  @override
  Widget build(BuildContext context) => switch (state.engine) {
    MapEngine.streets || MapEngine.terrain => RoadMap(
      creditBottom: overlayBottom,
      state: state,
      onFeature: onFeature,
      onViewport: onViewport,
      municipalBoundaries: municipalBoundaries,
      reference: reference,
      coastalIslands: coastalIslands,
      terrainManifest: terrainManifest,
      creditTop:
          246 +
          (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0, 1) * 80,
    ),
    MapEngine.google => GoogleCanvas(
      state: state,
      onFeature: onFeature,
      onViewport: onViewport,
    ),
    MapEngine.mapLibre => LibreCanvas(
      key: ValueKey(state.mapEpoch),
      state: state,
      boundary: boundary,
      onFeature: onFeature,
      onViewport: onViewport,
    ),
    MapEngine.essential => EssentialMap(
      state: state,
      boundary: boundary,
      onFeature: onFeature,
      onViewport: onViewport,
    ),
  };
}

class LibreCanvas extends ConsumerStatefulWidget {
  const LibreCanvas({
    super.key,
    required this.state,
    required this.boundary,
    required this.onFeature,
    required this.onViewport,
  });
  final MapState state;
  final Map<String, dynamic> boundary;
  final ValueChanged<MapFeature> onFeature;
  final void Function(GeoBounds, double) onViewport;
  @override
  ConsumerState<LibreCanvas> createState() => _LibreCanvasState();
}

class _LibreCanvasState extends ConsumerState<LibreCanvas> {
  m.MapLibreMapController? controller;
  String? style;
  bool ready = false, failed = false;
  Timer? watchdog;
  List<MapFeature> features = [];
  Future<void> updateQueue = Future.value();
  @override
  void initState() {
    super.initState();
    _style();
  }

  Future<void> _style() async {
    try {
      final json = jsonDecode(
        await rootBundle.loadString(
          mapIsNight(ref.read(mapAppearanceProvider))
              ? 'assets/map/style_night.json'
              : 'assets/map/style_day.json',
        ),
      ) as Map<String, dynamic>;
      for (final layer in json['layers'] as List) {
        if (layer['layout']?['text-font'] != null) {
          layer['layout']['text-font'] = ['Noto Sans Regular'];
        }
      }
      if (mounted) {
        setState(() => style = jsonEncode(json));
        watchdog = Timer(const Duration(seconds: 18), () {
          if (mounted && !ready) {
            setState(() => failed = true);
          }
        });
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint("MaraPass MapLibre indisponível: ${error.runtimeType}");
      }
      if (mounted) {
        setState(() => failed = true);
      }
    }
  }

  @override
  void dispose() {
    watchdog?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(LibreCanvas old) {
    super.didUpdateWidget(old);
    if (old.state.request.serial != widget.state.request.serial) {
      final r = widget.state.request;
      controller?.animateCamera(
        m.CameraUpdate.newLatLngZoom(
          m.LatLng(r.target.lat, r.target.lng),
          r.zoom,
        ),
      );
    }
    _scheduleUpdate();
  }

  Map<String, dynamic> _data() {
    features = clusterPlaces(
      widget.state.inView,
      widget.state.zoom,
      selectedId: widget.state.selectedId,
    );
    return {
      'type': 'FeatureCollection',
      'features': [
        for (final f in features)
          {
            'type': 'Feature',
            'id': f.id,
            'properties': {
              'id': f.id,
              'color': f.isCluster
                  ? '#223449'
                  : '#${f.places.first.category.argb.toRadixString(16).substring(2)}',
              'count': f.isCluster ? '${f.places.length}' : '',
              'radius': f.isCluster
                  ? 17
                  : f.id == widget.state.selectedId
                  ? 15
                  : 7,
              'icon': f.isCluster || f.id != widget.state.selectedId
                  ? ''
                  : '${f.places.first.category.name}${f.places.first.hasCoupon}',
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [f.point.lng, f.point.lat],
            },
          },
        if (widget.state.location case final p?)
          {
            'type': 'Feature',
            'id': '__user',
            'properties': {
              'id': '__user',
              'color': '#2d81d5',
              'count': '',
              'radius': 8,
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [p.lng, p.lat],
            },
          },
      ],
    };
  }

  void _scheduleUpdate() {
    if (!ready) {
      return;
    }
    final data = _data();
    updateQueue = updateQueue
        .then((_) async {
          if (mounted && ready) {
            await controller?.setGeoJsonSource('marapass', data);
          }
        })
        .catchError((Object _) {});
  }

  Future<void> _loaded() async {
    final c = controller;
    if (c == null) {
      return;
    }
    try {
      for (final category in PlaceCategory.values) {
        for (final coupon in [false, true]) {
          await c.addImage(
            '${category.name}$coupon',
            await markerArtwork(category, coupon),
          );
        }
      }
      await c.addGeoJsonSource('marapass', _data(), promoteId: 'id');
      await c.addCircleLayer(
        'marapass',
        'marapass-pins',
        const m.CircleLayerProperties(
          circleColor: ['get', 'color'],
          circleRadius: ['get', 'radius'],
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 2,
        ),
      );
      await c.addSymbolLayer(
        'marapass',
        'marapass-icons',
        const m.SymbolLayerProperties(
          iconImage: ['get', 'icon'],
          iconSize: .68,
          iconAllowOverlap: true,
        ),
        enableInteraction: true,
      );
      await c.addSymbolLayer(
        'marapass',
        'marapass-counts',
        const m.SymbolLayerProperties(
          textField: ['get', 'count'],
          textFont: ['Noto Sans Bold'],
          textSize: 13,
          textColor: '#ffffff',
          textAllowOverlap: true,
        ),
        enableInteraction: false,
      );
      ready = true;
      _scheduleUpdate();
    } catch (error) {
      if (kDebugMode) {
        debugPrint("MaraPass MapLibre indisponível: ${error.runtimeType}");
      }
      if (mounted) {
        setState(() => failed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mapAppearanceProvider, (_, mode) {
      ready = false;
      watchdog?.cancel();
      _style();
    });
    if (failed || style == null) {
      return Stack(
        children: [
          EssentialMap(
            state: widget.state,
            boundary: widget.boundary,
            onFeature: widget.onFeature,
            onViewport: widget.onViewport,
          ),
          if (failed)
            const Positioned(
              left: 16,
              bottom: 170,
              child: Chip(label: Text('Mapa essencial • ruas indisponíveis')),
            ),
        ],
      );
    }
    return m.MapLibreMap(
      styleString: style!,
      initialCameraPosition: m.CameraPosition(
        target: m.LatLng(
          widget.state.request.target.lat,
          widget.state.request.target.lng,
        ),
        zoom: widget.state.request.zoom,
      ),
      onMapCreated: (c) {
        controller = c;
        c.onFeatureTapped.add((point, coords, id, layer, annotation) {
          for (final f in features) {
            if (f.id == id) {
              widget.onFeature(f);
              break;
            }
          }
        });
      },
      onStyleLoadedCallback: _loaded,
      trackCameraPosition: true,
      onCameraIdle: () async {
        final c = controller;
        if (c == null) {
          return;
        }
        try {
          final b = await c.getVisibleRegion();
          if (!mounted) {
            return;
          }
          widget.onViewport(
            GeoBounds(
              b.southwest.latitude,
              b.southwest.longitude,
              b.northeast.latitude,
              b.northeast.longitude,
            ),
            c.cameraPosition?.zoom ?? 6,
          );
        } catch (_) {}
      },
      compassEnabled: false,
      myLocationEnabled: false,
      attributionButtonMargins: const math.Point(8, 190),
      attributionButtonPosition: m.AttributionButtonPosition.bottomLeft,
      minMaxZoomPreference: const m.MinMaxZoomPreference(4, 18),
    );
  }
}

final _artworkCache = <String, Uint8List>{};
Future<Uint8List> markerArtwork(PlaceCategory category, bool coupon) async {
  final key = '${category.name}$coupon';
  if (_artworkCache[key] case final bytes?) {
    return bytes;
  }
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawCircle(const Offset(28, 28), 25, Paint()..color = Colors.white);
  canvas.drawCircle(
    const Offset(28, 28),
    22,
    Paint()..color = markerColor(category),
  );
  canvas.save();
  canvas.translate(15, 15);
  TourismGlyph(category).paint(canvas, const Size(26, 26));
  canvas.restore();
  if (coupon) {
    canvas.drawCircle(const Offset(46, 9), 8, Paint()..color = Colors.white);
    canvas.drawCircle(
      const Offset(46, 9),
      6,
      Paint()..color = const Color(0xffe9ad42),
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(56, 56);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  final bytes = data!.buffer.asUint8List();
  _artworkCache[key] = bytes;
  return bytes;
}

class GoogleCanvas extends StatefulWidget {
  const GoogleCanvas({
    super.key,
    required this.state,
    required this.onFeature,
    required this.onViewport,
    this.route,
    this.alternatives = const [],
    this.live,
    this.follow = false,
    this.travelMode = TravelMode.land,
    this.heading = 0,
    this.gpsAccuracy = 12,
    this.imprecise = false,
    this.headingKnown = false,
    this.onGesture,
  });
  final RoadRoute? route;
  final List<RoadRoute> alternatives;
  final GeoPoint? live;
  final bool follow, imprecise, headingKnown;
  final TravelMode travelMode;
  final double heading, gpsAccuracy;
  final VoidCallback? onGesture;
  final MapState state;
  final ValueChanged<MapFeature> onFeature;
  final void Function(GeoBounds, double) onViewport;
  @override
  State<GoogleCanvas> createState() => _GoogleCanvasState();
}

class _GoogleCanvasState extends State<GoogleCanvas> {
  g.GoogleMapController? controller;
  Set<g.Marker> markers = {};
  Set<g.Polyline> routeLines = {};
  final icons = <String, g.BitmapDescriptor>{};
  int generation = 0;
  double zoom = 6, visualHeading = 0;
  GeoPoint? visualPosition, fromPosition, targetPosition;
  Timer? animation;
  DateTime animationStart = DateTime.now(), modeStart = DateTime.now();
  double fromHeading = 0, targetHeading = 0;
  TravelMode? previousMode;
  final travelerIcons = <String, g.BitmapDescriptor>{};
  void moveTraveler() {
    fromPosition = visualPosition ?? widget.live;
    targetPosition = widget.live;
    fromHeading = visualHeading;
    targetHeading = visualHeading + headingDelta(visualHeading, widget.heading);
    animationStart = DateTime.now();
    animation ??= Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted) return;
      final t = (DateTime.now().difference(animationStart).inMilliseconds / 800)
          .clamp(0.0, 1.0);
      final a = fromPosition, b = targetPosition;
      if (a != null && b != null) {
        visualPosition = GeoPoint(
          a.lat + (b.lat - a.lat) * t,
          a.lng + (b.lng - a.lng) * t,
        );
      }
      visualHeading = fromHeading + (targetHeading - fromHeading) * t;
      if (DateTime.now().difference(modeStart).inMilliseconds >= 250) {
        previousMode = null;
      }
      setState(() {});
      if (t >= 1 && previousMode == null) {
        animation?.cancel();
        animation = null;
      }
    });
  }

  Future<void> prepareTraveler() async {
    for (final mode in TravelMode.values) {
      for (final weak in [false, true]) {
        travelerIcons['$mode:$weak'] = await GoogleTravelerIcons.forMode(
          mode,
          imprecise: weak,
        );
      }
    }
    if (mounted) setState(() {});
  }

  Set<g.Marker> traveler() {
    final p = visualPosition ?? widget.live ?? widget.state.location;
    if (p == null) return {};
    final result = <g.Marker>{};
    final fade = (DateTime.now().difference(modeStart).inMilliseconds / 250)
        .clamp(0.0, 1.0);
    for (final mode in [
      ?previousMode,
      widget.travelMode,
    ]) {
      final icon = travelerIcons['$mode:${widget.imprecise}'];
      if (icon == null) continue;
      result.add(
        GoogleTravelerIcons.marker(
          icon: icon,
          position: g.LatLng(p.lat, p.lng),
          heading: visualHeading,
          imprecise: widget.imprecise,
          id: 'traveler:$mode',
          headingKnown: widget.headingKnown,
        ).copyWith(
          alphaParam:
              (widget.imprecise ? .55 : 1) *
              (previousMode == null
                  ? 1
                  : mode == widget.travelMode
                  ? fade
                  : 1 - fade),
        ),
      );
    }
    return result;
  }

  void updateRouteLines() {
    routeLines = {
      for (final r in widget.alternatives.where((r) => r != widget.route))
        g.Polyline(
          polylineId: g.PolylineId(
            'alternative:${widget.alternatives.indexOf(r)}',
          ),
          points: r.points.map((p) => g.LatLng(p.lat, p.lng)).toList(),
          color: const Color(0xff94a3b8),
          width: 5,
        ),
      if (widget.route case final r?)
        g.Polyline(
          polylineId: const g.PolylineId('route'),
          points: r.points.map((p) => g.LatLng(p.lat, p.lng)).toList(),
          color: MaraColors.blue,
          width: 6,
        ),
    };
  }

  void fitJourney() {
    final c = controller, r = widget.route;
    if (c == null || r == null) return;
    if (widget.follow && widget.live != null) {
      c.animateCamera(
        g.CameraUpdate.newLatLngZoom(
          g.LatLng(widget.live!.lat, widget.live!.lng),
          16,
        ),
      );
      return;
    }
    final south = r.points.map((p) => p.lat).reduce(math.min),
        north = r.points.map((p) => p.lat).reduce(math.max);
    final west = r.points.map((p) => p.lng).reduce(math.min),
        east = r.points.map((p) => p.lng).reduce(math.max);
    c.animateCamera(
      g.CameraUpdate.newLatLngBounds(
        g.LatLngBounds(
          southwest: g.LatLng(south, west),
          northeast: g.LatLng(north, east),
        ),
        42,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    visualPosition = widget.live;
    visualHeading = widget.heading;
    updateRouteLines();
    prepareTraveler();
    _markers();
  }

  @override
  void dispose() {
    animation?.cancel();
    controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GoogleCanvas old) {
    super.didUpdateWidget(old);
    if (old.route != widget.route || old.alternatives != widget.alternatives) {
      updateRouteLines();
      if (!widget.follow) fitJourney();
    }
    if (old.state.request.serial != widget.state.request.serial) {
      final r = widget.state.request;
      controller?.animateCamera(
        g.CameraUpdate.newLatLngZoom(
          g.LatLng(r.target.lat, r.target.lng),
          r.zoom,
        ),
      );
    }
    if (old.travelMode != widget.travelMode) {
      previousMode = old.travelMode;
      modeStart = DateTime.now();
    }
    if (old.live != widget.live ||
        old.heading != widget.heading ||
        old.travelMode != widget.travelMode) {
      moveTraveler();
    }
    if (widget.follow && widget.live != null && old.live != widget.live) {
      controller?.animateCamera(
        g.CameraUpdate.newLatLngZoom(
          g.LatLng(widget.live!.lat, widget.live!.lng),
          16,
        ),
      );
    }
    if (old.state.inView != widget.state.inView ||
        old.state.zoom != widget.state.zoom ||
        old.state.selectedId != widget.state.selectedId) {
      _markers();
    }
  }

  Future<g.BitmapDescriptor> _icon(MapFeature f) async {
    final selected = f.id == widget.state.selectedId;
    final hasCoupon = f.places.any((p) => p.hasCoupon);
    final key = f.isCluster
        ? 'c${f.places.length}:$hasCoupon'
        : '${f.places.first.category.name}$hasCoupon:$selected';
    if (icons[key] case final icon?) {
      return icon;
    }
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final cat = f.places.first.category;
    c.drawCircle(
      const Offset(28, 28),
      f.isCluster || selected ? 24 : 11,
      Paint()..color = Colors.white,
    );
    c.drawCircle(
      const Offset(28, 28),
      f.isCluster || selected ? 21 : 8,
      Paint()..color = f.isCluster ? const Color(0xff223449) : cat.color,
    );
    final text = f.isCluster
        ? '${f.places.length}'
        : selected
        ? String.fromCharCode(cat.icon.codePoint)
        : '';
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: f.isCluster ? null : cat.icon.fontFamily,
          package: cat.icon.fontPackage,
          fontSize: 24,
          color: Colors.white,
          fontWeight: f.isCluster ? FontWeight.bold : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(c, Offset(28 - painter.width / 2, 28 - painter.height / 2));
    if (hasCoupon) {
      c.drawCircle(
        selected || f.isCluster ? const Offset(46, 9) : const Offset(36, 20),
        5,
        Paint()..color = const Color(0xffe9af45),
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(56, 56);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    final result = g.BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: 44,
      height: 44,
    );
    icons[key] = result;
    return result;
  }

  Future<void> _markers() async {
    final token = ++generation;
    final result = <g.Marker>{};
    for (final f in clusterPlaces(
      widget.state.inView,
      widget.state.zoom,
      selectedId: widget.state.selectedId,
    )) {
      final icon = await _icon(f);
      result.add(
        g.Marker(
          markerId: g.MarkerId(f.id),
          position: g.LatLng(f.point.lat, f.point.lng),
          icon: icon,
          consumeTapEvents: true,
          onTap: () => widget.onFeature(f),
        ),
      );
    }
    if (mounted && token == generation) {
      setState(() => markers = result);
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerMove: (_) => widget.onGesture?.call(),
    child: Semantics(
      label: widget.live == null
          ? null
          : 'Você está aqui${widget.headingKnown ? ', seguindo para ${directionLabel(visualHeading)}' : ', rumo indisponível'}${widget.imprecise ? ', Localização imprecisa' : ''}',
      child: g.GoogleMap(
        initialCameraPosition: g.CameraPosition(
          target: g.LatLng(
            widget.state.request.target.lat,
            widget.state.request.target.lng,
          ),
          zoom: widget.state.request.zoom,
        ),
        mapId: AppConfig.googleMapId,
        markers: {...markers, ...traveler()},
        polylines: routeLines,
        circles: {
          if (widget.live != null &&
              widget.travelMode == TravelMode.land &&
              widget.gpsAccuracy.isFinite)
            g.Circle(
              circleId: const g.CircleId('accuracy'),
              center: g.LatLng(
                (visualPosition ?? widget.live!).lat,
                (visualPosition ?? widget.live!).lng,
              ),
              radius: widget.gpsAccuracy.clamp(0, 500),
              strokeWidth: 0,
              fillColor: (widget.imprecise ? Colors.grey : MaraColors.blue)
                  .withValues(alpha: .15),
            ),
        },
        onTap: (_) => widget.onGesture?.call(),
        style: AppConfig.googleMapId == null
            ? '[{"featureType":"poi","stylers":[{"visibility":"off"}]}]'
            : null,
        onMapCreated: (c) {
          controller = c;
          fitJourney();
        },
        onCameraMove: (p) => zoom = p.zoom,
        onCameraIdle: () async {
          final c = controller;
          if (c == null) {
            return;
          }
          final b = await c.getVisibleRegion();
          if (!mounted) {
            return;
          }
          widget.onViewport(
            GeoBounds(
              b.southwest.latitude,
              b.southwest.longitude,
              b.northeast.latitude,
              b.northeast.longitude,
            ),
            zoom,
          );
        },
        myLocationButtonEnabled: false,
        myLocationEnabled: false,
        zoomControlsEnabled: false,
        compassEnabled: false,
        mapToolbarEnabled: false,
        padding: const EdgeInsets.only(top: 180, bottom: 180),
        minMaxZoomPreference: const g.MinMaxZoomPreference(4, 18),
      ),
    ),
  );
}
