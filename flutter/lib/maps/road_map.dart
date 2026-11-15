import 'native_maps.dart' show GoogleCanvas;
import '../navigation/traveler_marker.dart';
import 'place_marker.dart';
import '../environment/map_appearance.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/map_state.dart';
import '../core/config.dart';
import '../domain/navigation.dart';
import '../domain/tourism.dart';
import '../presentation/brand.dart';
import 'reference_roads.dart';
import '../terrain/terrain_widgets.dart';
import '../islands/coastal_island.dart';

class RoadMap extends ConsumerStatefulWidget {
  const RoadMap({
    super.key,
    required this.state,
    this.onFeature,
    this.onViewport,
    this.route,
    this.alternatives = const [],
    this.recordedSegments = const [],
    this.origin,
    this.destination,
    this.live,
    this.follow = false,
    this.followOffset = Offset.zero,
    this.followBearing,
    this.navigationView = false,
    this.pedestrian = false,
    this.reference,
    this.onGesture,
    this.creditTop = 248,
    this.creditBottom,
    this.travelMode = TravelMode.land,
    this.heading = 0,
    this.gpsAccuracy = 12,
    this.imprecise = false,
    this.headingKnown = false,
    this.municipalBoundaries,
    this.terrainManifest,
    this.coastalIslands = const [],
    this.nauticalReference = const [],
    this.nauticalEndpointNames = const [],
  });
  final MapState state;
  final ValueChanged<MapFeature>? onFeature;
  final void Function(GeoBounds, double)? onViewport;
  final RoadRoute? route;
  final List<RoadRoute> alternatives;
  final List<List<GeoPoint>> recordedSegments;
  final GeoPoint? origin, destination, live;
  final bool follow, navigationView, pedestrian;
  final Offset followOffset;
  final ReferenceRoadNetwork? reference;
  final VoidCallback? onGesture;
  final double creditTop;
  final double? creditBottom;
  final TravelMode travelMode;
  final double heading, gpsAccuracy;
  final double? followBearing;
  final bool imprecise, headingKnown;
  final Map<String, dynamic>? municipalBoundaries;
  final Map<String, dynamic>? terrainManifest;
  final List<CoastalIsland> coastalIslands;
  final List<GeoPoint> nauticalReference;
  final List<String> nauticalEndpointNames;
  @override
  ConsumerState<RoadMap> createState() => _RoadMapState();
}

class _RoadMapState extends ConsumerState<RoadMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController movement;
  final displayedLive = ValueNotifier<GeoPoint?>(null);
  GeoPoint? moveFrom, moveTo;
  final controller = MapController();
  bool ready = false, failed = false;
  final _cameraClock = Stopwatch()..start();
  int _lastCameraMove = -100;
  Timer? viewportTimer, appearanceTimer;
  bool night = false;
  int styleGeneration = 0;
  vt.Style? style;
  static final sharedStyles = <bool, Future<vt.Style>>{};
  @override
  void initState() {
    super.initState();
    displayedLive.value = widget.live;
    movement =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 800),
        )..addListener(() {
          final a = moveFrom, b = moveTo;
          if (a == null || b == null || !mounted) return;
          final t = Curves.easeOut.transform(movement.value);
          displayedLive.value = GeoPoint(
            a.lat + (b.lat - a.lat) * t,
            a.lng + (b.lng - a.lng) * t,
          );
          if (ready &&
              widget.follow &&
              _cameraClock.elapsedMilliseconds - _lastCameraMove >= 100 &&
              !(widget.state.engine == MapEngine.google &&
                  AppConfig.canUseGoogle)) {
            _lastCameraMove = _cameraClock.elapsedMilliseconds;
            _followVehicle(displayedLive.value!);
          }
        });
    night = mapIsNight(ref.read(mapAppearanceProvider));
    if (widget.reference == null || AppConfig.supabaseUrl.isNotEmpty) _style();
    appearanceTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final next = mapIsNight(ref.read(mapAppearanceProvider));
      if (next != night && mounted) {
        night = next;
        _style();
      }
    });
  }

  Future<void> _style() async {
    final generation = ++styleGeneration;
    try {
      sharedStyles[night] ??= vt.StyleReader(
        uri: 'asset://assets/map/style_${night ? 'night' : 'day'}.json',
        language: 'pt',
        headers: kIsWeb
            ? const <String, String>{}
            : {'User-Agent': 'MaraPass/0.2 (+https://marapass.com)'},
      ).read();
      final loaded = await sharedStyles[night]!.timeout(
        const Duration(seconds: 18),
      );
      if (mounted && generation == styleGeneration) {
        setState(() {
          style = loaded;
          failed = false;
        });
      }
    } catch (_) {
      sharedStyles.remove(night);
      if (mounted) {
        setState(() => failed = true);
      }
    }
  }

  LatLng ll(GeoPoint p) => LatLng(p.lat, p.lng);
  @override
  void dispose() {
    viewportTimer?.cancel();
    appearanceTimer?.cancel();
    movement.dispose();
    displayedLive.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RoadMap old) {
    super.didUpdateWidget(old);
    if (widget.live != old.live) {
      if (widget.live == null) {
        movement.stop();
        displayedLive.value = null;
      } else {
        moveFrom = displayedLive.value ?? widget.live;
        moveTo = widget.live;
        movement.forward(from: 0);
      }
    }
    if (!ready) {
      return;
    }
    if (old.navigationView && !widget.navigationView) controller.rotate(0);
    if (widget.route != old.route &&
        widget.route != null &&
        !widget.follow &&
        !widget.navigationView) {
      _fitRoute();
    } else if (widget.follow &&
        widget.live != null &&
        (!old.follow ||
            old.live == null ||
            (old.live == widget.live &&
                old.followBearing != widget.followBearing))) {
      _followVehicle(displayedLive.value ?? widget.live!);
    } else if (widget.state.request.serial != old.state.request.serial) {
      controller.move(
        ll(widget.state.request.target),
        widget.state.request.zoom,
      );
    }
  }

  void _followVehicle(GeoPoint location) {
    if (widget.navigationView && widget.followBearing != null) {
      controller.rotate(-widget.followBearing!);
    }
    controller.move(ll(location), 16, offset: widget.followOffset);
  }

  void _fitRoute() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ready && widget.route != null) {
        controller.fitCamera(
          CameraFit.coordinates(
            coordinates: widget.route!.points.map(ll).toList(),
            padding: const EdgeInsets.all(42),
            maxZoom: 16,
          ),
        );
      }
    });
  }

  void _fitNauticalReference() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ready || widget.nauticalReference.length < 2) return;
      controller.fitCamera(
        CameraFit.coordinates(
          coordinates: widget.nauticalReference.map(ll).toList(),
          padding: const EdgeInsets.all(48),
          maxZoom: 14,
        ),
      );
    });
  }

  void _scheduleViewport() {
    if (widget.onViewport == null) {
      return;
    }
    viewportTimer?.cancel();
    viewportTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || !ready) {
        return;
      }
      final camera = controller.camera, b = camera.visibleBounds;
      widget.onViewport?.call(
        GeoBounds(b.south, b.west, b.north, b.east),
        camera.zoom,
      );
    });
  }

  List<Polyline> _borders() {
    if (widget.state.zoom < 8 ||
        widget.state.city == null ||
        widget.municipalBoundaries == null) {
      return [];
    }
    final polygons = <Polyline>[];
    for (final f in widget.municipalBoundaries!['features'] as List) {
      if (widget.state.city != null &&
          f['properties']['name'] != widget.state.city) {
        continue;
      }
      final g = f['geometry'];
      final coords = g['coordinates'] as List;
      for (final polygon in g['type'] == 'MultiPolygon' ? coords : [coords]) {
        final ring = (polygon as List).first as List;
        polygons.add(
          Polyline(
            points: ring
                .map(
                  (p) => LatLng(
                    (p[1] as num).toDouble(),
                    (p[0] as num).toDouble(),
                  ),
                )
                .toList(),
            color: const Color(0xffaaa99a).withValues(alpha: .26),
            strokeWidth: .75,
          ),
        );
      }
    }
    return polygons;
  }

  int get navigationFlags => widget.navigationView
      ? InteractiveFlag.all
      : InteractiveFlag.all & ~InteractiveFlag.rotate;

  @override
  Widget build(BuildContext context) {
    ref.listen(mapAppearanceProvider, (_, mode) {
      final next = mapIsNight(mode);
      if (next != night) {
        night = next;
        _style();
      }
    });
    if (widget.state.engine == MapEngine.google && AppConfig.canUseGoogle) {
      return GoogleCanvas(
        state: widget.state,
        route: widget.route,
        alternatives: widget.alternatives,
        live: widget.live,
        follow: widget.follow,
        travelMode: widget.travelMode,
        heading: widget.heading,
        headingKnown: widget.headingKnown,
        gpsAccuracy: widget.gpsAccuracy,
        imprecise: widget.imprecise,
        onGesture: widget.onGesture,
        onFeature: widget.onFeature ?? (_) {},
        onViewport: widget.onViewport ?? (_, __) {},
      );
    }
    final features = clusterPlaces(
      widget.state.inView,
      widget.state.zoom,
      selectedId: widget.state.selectedId,
    );

    final islandIds = widget.state.filtered
        .where((p) => p.isCoastalIsland)
        .map((p) => p.id)
        .toSet();
    return Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: ll(widget.state.request.target),
            initialZoom: widget.state.request.zoom,
            minZoom: 4,
            maxZoom: 19,
            backgroundColor: night
                ? const Color(0xff243e47)
                : const Color(0xffd5e5e4),
            interactionOptions: InteractionOptions(flags: navigationFlags),
            onMapEvent: (event) {
              if (widget.navigationView &&
                  widget.follow &&
                  (event is MapEventRotateStart ||
                      event is MapEventDoubleTapZoom ||
                      event is MapEventScrollWheelZoom))
                widget.onGesture?.call();
            },
            onMapReady: () {
              ready = true;
              if (widget.follow && widget.live != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && widget.follow && widget.live != null) {
                    _followVehicle(widget.live!);
                  }
                });
              } else if (widget.route != null) {
                _fitRoute();
              }
              if (widget.nauticalReference.isNotEmpty) _fitNauticalReference();
              _scheduleViewport();
            },
            onPositionChanged: (camera, gesture) {
              if (gesture && widget.follow) {
                widget.onGesture?.call();
              }
              _scheduleViewport();
            },
          ),
          children: [
            if (widget.reference != null &&
                (style == null || widget.navigationView))
              ReferenceRoadLayer(network: widget.reference!, night: night),
            if (style case final loaded?)
              vt.VectorTileLayer(
                theme: loaded.theme,
                tileProviders: loaded.providers,
                rasterSources: loaded.rasterSources,
                sprites: loaded.sprites,
                memoryCacheMaxBytes: 24 * 1024 * 1024,
                rasterCacheMaxBytes: 64 * 1024 * 1024,
                concurrency: 2,
              ),
            if (widget.terrainManifest != null)
              Builder(
                builder: (context) {
                  if (MapCamera.of(context).zoom > 11)
                    return const SizedBox.shrink();
                  final b = widget.terrainManifest!['bounds'] as Map;
                  return OverlayImageLayer(
                    overlayImages: [
                      OverlayImage(
                        bounds: LatLngBounds(
                          LatLng(
                            (b['south'] as num).toDouble(),
                            (b['west'] as num).toDouble(),
                          ),
                          LatLng(
                            (b['north'] as num).toDouble(),
                            (b['east'] as num).toDouble(),
                          ),
                        ),
                        imageProvider: const AssetImage(
                          'assets/map/terrain_ma.png',
                        ),
                        opacity: widget.state.engine == MapEngine.terrain
                            ? .28
                            : night
                            ? .06
                            : .12,
                      ),
                    ],
                  );
                },
              ),
            PolylineLayer(
              polylines: [
                ..._borders(),
                if (widget.nauticalReference.length > 1)
                  Polyline(
                    points: widget.nauticalReference.map(ll).toList(),
                    color: const Color(0xff177d8d),
                    strokeWidth: 4,
                    pattern: StrokePattern.dashed(segments: [8, 6]),
                  ),
                if (widget.state.zoom >= 8 || widget.state.islandsOnly)
                  for (final i in widget.coastalIslands.where(
                    (i) => islandIds.contains(i.place.id),
                  ))
                    for (final ring in i.rings)
                      Polyline(
                        points: ring.map(ll).toList(),
                        color: widget.state.selectedId == i.place.id
                            ? MaraColors.gold
                            : const Color(0xff8c9c8b),
                        strokeWidth: widget.state.selectedId == i.place.id
                            ? 3
                            : .65,
                      ),
                for (final segment in widget.recordedSegments.where(
                  (s) => s.length > 1,
                ))
                  Polyline(
                    points: segment.map(ll).toList(),
                    color: MaraColors.blue,
                    strokeWidth: 5,
                    borderColor: Colors.white,
                    borderStrokeWidth: 2,
                  ),
                for (final r in widget.alternatives.where(
                  (r) => r != widget.route,
                ))
                  Polyline(
                    points: r.points.map(ll).toList(),
                    color: const Color(0xffa8b9d3),
                    strokeWidth: 5,
                    borderColor: Colors.white,
                    borderStrokeWidth: 2,
                  ),
                if (widget.route case final r?)
                  Polyline(
                    points: r.points.map(ll).toList(),
                    color: widget.navigationView
                        ? const Color(0xff06cfdf)
                        : MaraColors.blue,
                    strokeWidth: widget.navigationView ? 8 : 6,
                    borderColor: widget.navigationView
                        ? const Color(0xff103649)
                        : Colors.white,
                    borderStrokeWidth: widget.navigationView ? 3 : 2,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                if (widget.nauticalReference.length > 1)
                  for (var n = 0; n < 2; n++)
                    Marker(
                      point: ll(
                        n == 0
                            ? widget.nauticalReference.first
                            : widget.nauticalReference.last,
                      ),
                      width: 40,
                      height: 40,
                      child: Tooltip(
                        message: widget.nauticalEndpointNames.length > n
                            ? widget.nauticalEndpointNames[n]
                            : 'Extremo ${n + 1}',
                        child: Semantics(
                          label: widget.nauticalEndpointNames.length > n
                              ? widget.nauticalEndpointNames[n]
                              : 'Extremo ${n + 1}',
                          child: CircleAvatar(
                            backgroundColor: const Color(0xff177d8d),
                            foregroundColor: Colors.white,
                            child: Text('${n + 1}'),
                          ),
                        ),
                      ),
                    ),
                if (widget.onFeature != null)
                  for (final f in features)
                    Marker(
                      point: ll(f.point),
                      width: 44,
                      height: 44,
                      child: Semantics(
                        button: true,
                        label: f.isCluster
                            ? '${f.places.length} lugares'
                            : '${f.places.first.name}${f.places.first.hasCoupon ? ', com oferta publicada' : ''}',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onFeature!(f),
                          child: PlaceMarker(
                            feature: f,
                            detailed: widget.state.zoom >= 15,
                            selected: widget.state.selectedId == f.id,
                          ),
                        ),
                      ),
                    ),
                if (widget.origin case final p?)
                  Marker(
                    point: ll(p),
                    width: 30,
                    height: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: MaraColors.navy, width: 6),
                      ),
                    ),
                  ),
                if (widget.destination case final p?)
                  Marker(
                    point: ll(p),
                    width: 42,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on,
                      color: MaraColors.red,
                      size: 42,
                    ),
                  ),
              ],
            ),
            ValueListenableBuilder<GeoPoint?>(
              valueListenable: displayedLive,
              builder: (context, p, _) {
                final location = p ?? widget.state.location;
                return MarkerLayer(
                  markers: [
                    if (location != null)
                      Marker(
                        point: ll(location),
                        width: 64,
                        height: 64,
                        rotate: widget.navigationView && widget.follow,
                        child: TravelerMarker(
                          driving:
                              widget.navigationView &&
                              !widget.pedestrian &&
                              p != null,
                          mode: widget.travelMode,
                          heading: widget.navigationView && widget.follow
                              ? 0
                              : widget.followBearing ?? widget.heading,
                          headingKnown: widget.headingKnown,
                          accuracy: widget.gpsAccuracy,
                          imprecise: widget.imprecise,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        Positioned(
          left: 12,
          bottom:
              widget.creditBottom ??
              MediaQuery.sizeOf(context).height * .25 + 6,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            elevation: 2,
            child: IconButton(
              tooltip: 'Fontes e atribuição do mapa',
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              icon: const Icon(Icons.info_outline, size: 18),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (context) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fontes do mapa',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          style == null
                              ? '© OpenStreetMap · IBGE · base de referência'
                              : 'OpenFreeMap · © OpenMapTiles · © OpenStreetMap',
                        ),
                        TextButton(
                          onPressed: () => launchUrl(
                            Uri.parse(
                              'https://www.openstreetmap.org/copyright',
                            ),
                          ),
                          child: const Text(
                            'OpenStreetMap · direitos e licença',
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              launchUrl(Uri.parse('https://openmaptiles.org/')),
                          child: const Text('OpenMapTiles'),
                        ),
                        TextButton(
                          onPressed: () =>
                              launchUrl(Uri.parse('https://openfreemap.org/')),
                          child: const Text('OpenFreeMap'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.terrainManifest != null &&
            widget.state.engine == MapEngine.terrain)
          Positioned(
            top: widget.creditTop + 36,
            right: 8,
            child: TerrainLegend(
              zoom: ready ? controller.camera.zoom : widget.state.zoom,
            ),
          ),
        if (widget.reference == null && style == null && !failed)
          const Positioned(
            right: 16,
            top: 120,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (failed)
          Positioned(
            bottom: MediaQuery.sizeOf(context).height * .25 + 38,
            left: 12,
            right: 12,
            child: const Card(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Base local ativa · ruas online indisponíveis.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
