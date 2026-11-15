import '../voice/voice_search_sheet.dart';
import '../environment/environment_control.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../location/location_service.dart';
import '../location/ahead_filter.dart';

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'location_help.dart';
import 'municipal_visit_guide.dart';
import '../recording/recording_screen.dart';
import '../terrain/terrain_widgets.dart';
import '../islands/island_directory.dart';
import '../islands/island_land_access.dart';
import 'travel_safety.dart';

import 'package:url_launcher/url_launcher.dart';

import '../application/map_state.dart';
import '../core/config.dart';
import '../domain/tourism.dart';
import '../maps/native_maps.dart';
import 'control_center.dart';
import 'brand.dart';
import 'city_directory.dart';
import 'navigation_screen.dart';
import '../pilot/barreirinhas.dart';
import '../pilot/barreirinhas_sources.dart';
import '../pilot/google_place_panel.dart';
import '../domain/municipality.dart';

const ink = MaraColors.navy;
const ocean = MaraColors.navy;
const gold = MaraColors.gold;

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Uri.base.queryParameters['layer'] == 'condominios')
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) coordinator.category(PlaceCategory.residential);
      });
    if (Uri.base.queryParameters['route'] == 'barreirinhas')
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final places = ref
            .read(mapStateProvider)
            .places
            .where(
              (p) =>
                  p.category == PlaceCategory.destination &&
                  p.city == 'Barreirinhas',
            );
        if (places.isNotEmpty)
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  NavigationScreen(destination: places.first, autoPlan: true),
            ),
          );
      });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      coordinator.refresh();
      if (automaticLocationRequested && locationStream == null)
        locate(automatic: true);
    } else {
      locationStream?.cancel();
      locationStream = null;
      clearCourse();
    }
  }

  final search = TextEditingController();
  final searchFocus = FocusNode();
  bool automaticLocationRequested = false;
  String? locationStatus;
  StreamSubscription<Position>? locationStream;
  double? heading;
  Position? previousFix;
  Timer? courseExpiry;
  DateTime? lastLocationUpdate;
  bool allNearby = false;
  int tab = 0;
  double sheetFraction = 0;
  double mapBodyHeight = 700;
  static const dockHeight = 132.0;
  static const recentKey = 'map_recent_places';
  final searchBarKey = GlobalKey();
  late List<String> recentIds =
      ref.read(repositoryProvider).preferences.getStringList(recentKey) ?? [];
  double get sheetPixels =>
      sheetFraction == 0 ? dockHeight : sheetFraction * mapBodyHeight;

  void remember(TourismPlace place) {
    setState(() {
      recentIds = [
        place.id,
        ...recentIds.where((id) => id != place.id),
      ].take(5).toList();
    });
    unawaited(
      ref
          .read(repositoryProvider)
          .preferences
          .setStringList(recentKey, recentIds),
    );
  }

  bool locating = false;
  final locationService = LocationService();
  bool showingDetails = false;
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    locationService.cancelPending();
    locationStream?.cancel();
    courseExpiry?.cancel();
    searchFocus.dispose();
    search.dispose();
    super.dispose();
  }

  MapCoordinator get coordinator => ref.read(mapStateProvider.notifier);
  void toast(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
  void feature(MapFeature f) {
    if (f.isCluster) {
      final state = ref.read(mapStateProvider);
      final maxZoom = state.engine == MapEngine.essential ? 14.0 : 18.0;
      if (state.zoom < maxZoom - .1) {
        coordinator.focus(f.point, (state.zoom + 2).clamp(4, maxZoom));
      } else {
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (sheet) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheet).height * .6,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '${f.places.length} lugares nesta área',
                    style: Theme.of(sheet).textTheme.titleLarge,
                  ),
                  for (final place in f.places)
                    ListTile(
                      title: Text(place.name),
                      subtitle: Text(place.category.label),
                      onTap: () {
                        Navigator.pop(sheet);
                        details(place);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      }
    } else {
      details(f.places.first);
    }
  }

  Future<void> details(TourismPlace place, {IslandLandAccess? access}) async {
    if (showingDetails) {
      return;
    }
    showingDetails = true;
    remember(place);
    final location = ref.read(mapStateProvider).location;
    final selectedAccess =
        access ??
        closestIslandAccess(
          ref.read(repositoryProvider).islandAccesses[place.id] ?? const [],
          location,
        );
    final nearbyPoint =
        selectedAccess?.destination.point ??
        (place.isCoastalIsland ? null : place.point);
    coordinator.select(place.id);
    var expanded = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          if (expanded)
            return PlaceDetails(
              place: place,
              access: selectedAccess,
              onNavigate: () {
                Navigator.pop(context);
                Navigator.of(this.context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NavigationScreen(
                      destination: place,
                      autoPlan: true,
                      preferredIslandAccess: selectedAccess,
                    ),
                  ),
                );
              },
              onFocus: () {
                Navigator.pop(context);
                setState(() => tab = 0);
                coordinator.focus(
                  place.point,
                  place.isCoastalIsland
                      ? (place.id == 'osm:relation:10037013' ? 10 : 12)
                      : 16,
                );
              },
            );
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    place.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text('${place.category.label} · ${place.city}'),
                  if (selectedAccess != null)
                    Text('Acesso por ${selectedAccess.destination.name}'),
                  if (location != null && nearbyPoint != null)
                    Text(
                      '${location.distanceKm(nearbyPoint).toStringAsFixed(1)} km em linha reta',
                    ),
                  if (place.hasCoupon)
                    Text(place.offerTitle ?? 'Benefício publicado'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(this.context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => NavigationScreen(
                            destination: place,
                            autoPlan: true,
                            preferredIslandAccess: selectedAccess,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.directions_outlined),
                    label: Text(
                      (place.isBeach || place.needsVisitPlanning)
                          ? 'Planejar visita'
                          : 'Traçar rota',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => setSheet(() => expanded = true),
                    child: const Text('Ver detalhes'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (mounted) coordinator.select(null);
    showingDetails = false;
  }

  Future<void> locate({bool automatic = false}) async {
    if (locating) {
      return;
    }
    setState(() => locating = true);
    try {
      final p = await locationService.acquire();
      if (!mounted) {
        return;
      }
      final point = GeoPoint(p.latitude, p.longitude);
      if (automatic) {
        coordinator.setLocation(point);
      } else {
        coordinator.locate(point);
      }
      updateHeading(p);
      locationStream ??= locationService.updates().listen(
        (position) {
          if (!mounted || !usablePosition(position)) return;
          final now = DateTime.now();
          if (lastLocationUpdate != null &&
              now.difference(lastLocationUpdate!).inSeconds < 5)
            return;
          lastLocationUpdate = now;
          coordinator.setLocation(
            GeoPoint(position.latitude, position.longitude),
          );
          updateHeading(position);
        },
        onError: (Object _) {
          if (mounted) clearCourse();
        },
      );
      setState(() => locationStatus = null);
      if (!GeoBounds.maranhao.contains(GeoPoint(p.latitude, p.longitude))) {
        toast(
          'Sua posição está fora do Maranhão. Use “Ver Maranhão” para voltar aos destinos.',
        );
      }
    } catch (error) {
      if (mounted && !automatic) {
        showLocationHelp(context, failure: locationFailure(error));
      } else if (mounted) {
        setState(
          () => locationStatus =
              'Localização indisponível. Toque no GPS para tentar novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => locating = false);
      }
    }
  }

  void clearCourse() {
    courseExpiry?.cancel();
    previousFix = null;
    lastLocationUpdate = null;
    if (heading != null) setState(() => heading = null);
  }

  void updateHeading(Position p) {
    final next = travelCourse(p, previousFix);
    previousFix = p;
    courseExpiry?.cancel();
    if (heading != next) setState(() => heading = next);
    if (next != null) {
      final remaining = courseValidity - DateTime.now().difference(p.timestamp);
      courseExpiry = Timer(remaining, clearCourse);
    }
  }

  void beginSearch() {
    if (!automaticLocationRequested) {
      automaticLocationRequested = true;
      if (locationStream == null) locate(automatic: true);
    }
    if (tab != 1) {
      coordinator.savedOnly(false);
      setState(() {
        tab = 1;
        sheetFraction = 0;
      });
    }
  }

  void layers() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Escolha seu mapa',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Ruas e estradas'),
                subtitle: const Text(
                  'Ruas, bairros e edifícios • OpenStreetMap',
                ),
                onTap: () {
                  coordinator.engine(MapEngine.streets);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.terrain_outlined),
                title: const Text('Relevo e altitude'),
                subtitle: const Text(
                  'Cores suaves por altitude • visão regional offline',
                ),
                onTap: () {
                  coordinator.engine(MapEngine.terrain);
                  coordinator.focus(const GeoPoint(-5.1, -45.1), 6);
                  Navigator.pop(context);
                },
              ),
              if (AppConfig.supportsVectorMaps)
                ListTile(
                  leading: const Icon(Icons.view_in_ar_outlined),
                  title: const Text('Mapa vetorial detalhado'),
                  subtitle: const Text(
                    'OpenFreeMap • ruas, bairros e edifícios',
                  ),
                  onTap: () {
                    coordinator.engine(MapEngine.mapLibre);
                    Navigator.pop(context);
                  },
                ),
              if (AppConfig.canUseGoogle)
                ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('Google Maps'),
                  onTap: () {
                    coordinator.engine(MapEngine.google);
                    Navigator.pop(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.offline_pin_outlined),
                title: const Text('Mapa essencial do Maranhão'),
                subtitle: const Text(
                  'Destinos e contorno do estado • funciona sem internet',
                ),
                onTap: () {
                  coordinator.engine(MapEngine.essential);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  void filters() {
    final state = ref.read(mapStateProvider);
    String? area = state.area, city = state.city;
    var coupons = state.couponsOnly;
    var islands = state.islandsOnly;
    var selectedCategory = state.category;
    final areas = {
      ...state.places.map((p) => p.area).whereType<String>(),
      'Balaiada',
    }.toList()..sort();
    final cities = state.places.map((p) => p.city).toSet().toList()..sort();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (context, setLocal) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                0,
                22,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Explore do seu jeito',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text('Escolha uma região ou vá direto à cidade.'),
                  const SizedBox(height: 22),
                  DropdownButtonFormField<PlaceCategory>(
                    isExpanded: true,
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<PlaceCategory>(
                        value: null,
                        child: Text('Todas as categorias'),
                      ),
                      for (final c in PlaceCategory.values.where(
                        (c) => c != PlaceCategory.destination,
                      ))
                        DropdownMenuItem(value: c, child: Text(c.label)),
                    ],
                    onChanged: (value) =>
                        setLocal(() => selectedCategory = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: area,
                    decoration: const InputDecoration(
                      labelText: 'Região de exploração',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Todo o Maranhão'),
                      ),
                      for (final a in areas)
                        DropdownMenuItem(
                          value: a,
                          child: Text(
                            a,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setLocal(() => area = v == '' ? null : v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: city,
                    decoration: const InputDecoration(
                      labelText: 'Município',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Todos os municípios'),
                      ),
                      for (final c in cities)
                        DropdownMenuItem(
                          value: c,
                          child: Text(
                            c,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setLocal(() => city = v == '' ? null : v),
                  ),
                  if (area == 'Balaiada')
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'O conteúdo desta região está em preparação.',
                      ),
                    ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Somente ilhas do litoral'),
                    value: islands,
                    onChanged: (v) => setLocal(() => islands = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Com benefício publicado'),
                    value: coupons,
                    onChanged: (v) => setLocal(() => coupons = v),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        coordinator.category(selectedCategory);
                        coordinator.islandsOnly(islands);
                        coordinator.setFilters(
                          area: area,
                          city: city,
                          coupons: coupons,
                        );
                        Navigator.pop(sheet);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Mostrar lugares'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapStateProvider);
    if (search.text != state.query) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && search.text != ref.read(mapStateProvider).query) {
          search.text = ref.read(mapStateProvider).query;
        }
      });
    }

    final repo = ref.watch(repositoryProvider);
    final cities = [...repo.municipalities]
      ..sort(
        (a, b) => a.point
            .distanceKm(
              GeoPoint(
                (state.bounds.south + state.bounds.north) / 2,
                (state.bounds.west + state.bounds.east) / 2,
              ),
            )
            .compareTo(
              b.point.distanceKm(
                GeoPoint(
                  (state.bounds.south + state.bounds.north) / 2,
                  (state.bounds.west + state.bounds.east) / 2,
                ),
              ),
            ),
      );
    final weatherCity =
        cities.where((c) => c.name == state.city).firstOrNull ??
        cities.firstOrNull;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final chromeExtent = (174 + (textScale - 1).clamp(0, 1) * 80).toDouble();
    final results =
        state.query.isNotEmpty ||
            state.area != null ||
            state.city != null ||
            state.islandsOnly ||
            tab != 0
        ? state.filtered
        : state.inView;
    final nearby = tab == 1 && state.query.isEmpty;
    final aheadOnly = nearby && !allNearby;
    final location = state.location;
    final course = heading;
    final directionReady = location != null && course != null;
    bool inFront(GeoPoint point) =>
        directionReady && isAhead(location, point, course);

    final sorted = <TourismPlace>[];
    final accesses = <String, IslandLandAccess>{};
    final distances = <String, double>{};
    if (!aheadOnly || directionReady) {
      for (final place in results) {
        final access = closestIslandAccess(
          repo.islandAccesses[place.id] ?? const [],
          location,
          accepts: aheadOnly ? inFront : null,
        );
        final point =
            access?.destination.point ??
            (place.isCoastalIsland ? null : place.point);
        if (aheadOnly && (point == null || !inFront(point))) continue;
        sorted.add(place);
        if (access != null) accesses[place.id] = access;
        if (point != null && location != null) {
          distances[place.id] = location.distanceKm(point);
        }
      }
    }
    if (state.query.isEmpty) {
      sorted.sort((a, b) {
        if (nearby && !aheadOnly) {
          final saved = (state.saved.contains(b.id) ? 1 : 0).compareTo(
            state.saved.contains(a.id) ? 1 : 0,
          );
          if (saved != 0) return saved;
        }
        final order = (distances[a.id] ?? double.infinity).compareTo(
          distances[b.id] ?? double.infinity,
        );
        return order == 0 ? a.name.compareTo(b.name) : order;
      });
    }
    if (aheadOnly &&
        state.city == null &&
        state.area == null &&
        !state.islandsOnly &&
        sorted.length > 12) {
      sorted.removeRange(12, sorted.length);
    }
    final searchBar = Material(
      key: searchBarKey,
      color: const Color(0xffeef2f7),
      borderRadius: BorderRadius.circular(28),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 15),
            child: Icon(Icons.search, color: ink),
          ),
          Expanded(
            child: TextField(
              controller: search,
              focusNode: searchFocus,
              onTap: () {
                if (tab != 0) return;
                beginSearch();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && tab == 1) searchFocus.requestFocus();
                });
              },
              onChanged: coordinator.query,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                if (state.filtered.length == 1) {
                  coordinator.focus(state.filtered.first.point, 11);
                }
              },
              decoration: InputDecoration(
                hintText: 'Para onde vamos?',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                suffixIcon: state.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        onPressed: () {
                          search.clear();
                          coordinator.query('');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Buscar por voz',
            icon: const Icon(Icons.mic_none, color: ink),
            onPressed: () {
              beginSearch();
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => VoiceSearchSheet(
                  onFocus: (p) {
                    remember(p);
                    coordinator.showVoiceResult(p);
                    setState(() => tab = 0);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            mapBodyHeight = constraints.maxHeight;
            return NotificationListener<DraggableScrollableNotification>(
              onNotification: (n) {
                if ((sheetFraction - n.extent).abs() > .002)
                  setState(() => sheetFraction = n.extent);
                return false;
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: MapCanvas(
                      key: const ValueKey("map-viewport"),
                      overlayBottom: sheetPixels + 8,
                      state: state,
                      boundary: repo.boundary!,
                      municipalBoundaries: repo.municipalBoundaries,
                      reference: repo.roads,
                      terrainManifest: repo.terrainManifest,
                      coastalIslands: repo.coastalIslands,
                      onFeature: feature,
                      onViewport: coordinator.viewport,
                    ),
                  ),
                  if (tab != 0)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Column(
                        children: [
                          Material(
                            key: const ValueKey("map-search-bar"),
                            elevation: 4,
                            shadowColor: Colors.black.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(16),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                const Expanded(child: MaraBrand()),
                                Tooltip(
                                  message: state.islandsOnly
                                      ? 'Mostrar todos os lugares'
                                      : 'Filtrar lugares',
                                  child: SizedBox(
                                    width: 88,
                                    height: 44,
                                    child: TextButton(
                                      onPressed: state.islandsOnly
                                          ? () => coordinator.islandsOnly(false)
                                          : filters,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                      child: Text(
                                        '${state.islandsOnly ? 'Ilhas ×' : '${state.city ?? state.area ?? 'Maranhão'} ▾'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: ink,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Mais opções',
                                  icon: const Icon(
                                    Icons.more_horiz,
                                    color: ink,
                                  ),
                                  onPressed: () => showModalBottomSheet<void>(
                                    context: context,
                                    showDragHandle: true,
                                    builder: (sheet) => SafeArea(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.fromLTRB(
                                          20,
                                          0,
                                          20,
                                          20,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              'Explore o MaraPass',
                                              style: Theme.of(sheet)
                                                  .textTheme
                                                  .titleLarge,
                                            ),
                                            ListTile(
                                              leading: const Icon(
                                                Icons.sailing_outlined,
                                              ),
                                              title: const Text(
                                                'Ilhas do litoral',
                                              ),
                                              onTap: () async {
                                                Navigator.pop(sheet);
                                                final place =
                                                    await Navigator.push<
                                                      TourismPlace
                                                    >(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            const IslandDirectory(),
                                                      ),
                                                    );
                                                if (!mounted) return;
                                                setState(() => tab = 0);
                                                if (place != null) {
                                                  coordinator.resetFilters();
                                                  coordinator.islandsOnly(true);
                                                  coordinator.focus(
                                                    place.point,
                                                    place.id == 'osm:relation:10037013'
                                                        ? 10
                                                        : 12,
                                                  );
                                                  await details(place);
                                                }
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(
                                                Icons.route_outlined,
                                              ),
                                              title: const Text(
                                                'Gravar meu percurso',
                                              ),
                                              onTap: () {
                                                Navigator.pop(sheet);
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute<void>(
                                                    builder: (_) =>
                                                        const RecordingScreen(),
                                                  ),
                                                );
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(
                                                Icons.explore_outlined,
                                              ),
                                              title: const Text(
                                                'Explorar Barreirinhas',
                                              ),
                                              onTap: () {
                                                Navigator.pop(sheet);
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute<void>(
                                                    builder: (_) =>
                                                        const BarreirinhasPilot(),
                                                  ),
                                                );
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(
                                                Icons.location_city_outlined,
                                              ),
                                              title: const Text(
                                                'Explorar os 217 municípios',
                                              ),
                                              onTap: () async {
                                                Navigator.pop(sheet);
                                                final city =
                                                    await Navigator.of(
                                                      context,
                                                    ).push<Municipality>(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            const CityDirectory(),
                                                      ),
                                                    );
                                                if (city != null && mounted) {
                                                  search.clear();
                                                  coordinator.resetFilters();
                                                  coordinator.savedOnly(false);
                                                  coordinator.setFilters(
                                                    city: city.name,
                                                  );
                                                  coordinator.focus(
                                                    city.point,
                                                    12,
                                                  );
                                                  setState(() => tab = 0);
                                                }
                                              },
                                            ),
                                            const TravelSafetyButton(),
                                            const BarreirinhasSourcesButton(),
                                            ListTile(
                                              leading: const Icon(
                                                Icons.layers_outlined,
                                              ),
                                              title: const Text(
                                                'Escolher mapa',
                                              ),
                                              onTap: () {
                                                Navigator.pop(sheet);
                                                layers();
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.public),
                                              title: const Text('Ver Maranhão'),
                                              onTap: () {
                                                Navigator.pop(sheet);
                                                coordinator.focus(
                                                  const GeoPoint(-4.8, -45),
                                                  6,
                                                );
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(
                                                Icons
                                                    .edit_location_alt_outlined,
                                              ),
                                              title: const Text(
                                                'Central de customização',
                                              ),
                                              onTap: () async {
                                                Navigator.pop(sheet);
                                                final showMap =
                                                    await Navigator.of(
                                                      context,
                                                    ).push<bool>(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            const ControlCenter(),
                                                      ),
                                                    );
                                                if (showMap == true &&
                                                    mounted) {
                                                  search.clear();
                                                  setState(() => tab = 0);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                            ),
                          ),
                          if (tab != 0) ...[
                            const SizedBox(height: 8),
                            searchBar,
                            const SizedBox(height: 4),
                            SizedBox(
                              key: const ValueKey("map-category-strip"),
                              height: 44 * textScale.clamp(1, 1.8),
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _categoryChip(
                                    'Todos',
                                    Icons.apps,
                                    state.category == null,
                                    () => coordinator.category(null),
                                  ),
                                  for (final c in {
                                    PlaceCategory.nature,
                                    PlaceCategory.tours,
                                    PlaceCategory.gastronomy,
                                    PlaceCategory.lodging,
                                    if (state.category != null &&
                                        state.category !=
                                            PlaceCategory.destination)
                                      state.category!,
                                  })
                                    _categoryChip(
                                      c.label,
                                      c.icon,
                                      state.category == c,
                                      () => coordinator.category(
                                        state.category == c ? null : c,
                                      ),
                                    ),
                                  ActionChip(
                                    label: const Text('Mais filtros'),
                                    onPressed: filters,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (state.loading)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (tab == 0) ...[
                    if (weatherCity != null)
                      Positioned(
                        top: 64,
                        right: 8,
                        child: EnvironmentControl(
                          key: const ValueKey("map-weather"),
                          city: weatherCity,
                          compact: true,
                        ),
                      ),
                    Positioned(
                      right: 16,
                      bottom: sheetPixels + 8,
                      child: Column(
                        children: [
                          _tool(
                            locating ? Icons.hourglass_top : Icons.my_location,
                            'Minha localização',
                            locate,
                          ),
                        ],
                      ),
                    ),
                    if (state.engine == MapEngine.essential)
                      const Positioned(
                        left: 10,
                        bottom: 182,
                        child: Text(
                          'Contorno de referência • IBGE / MaraPass',
                          style: TextStyle(fontSize: 9, color: ink),
                        ),
                      ),
                    DraggableScrollableSheet(
                      initialChildSize: (dockHeight / mapBodyHeight).clamp(
                        0.0,
                        .5,
                      ),
                      minChildSize: (dockHeight / mapBodyHeight).clamp(0.0, .5),
                      maxChildSize: .88,
                      snap: true,
                      snapSizes: const [.5],
                      builder: (context, scroll) => _resultsPanel(
                        state,
                        sorted,
                        scroll,
                        accesses,
                        distances,
                        directionReady,
                        dock: searchBar,
                      ),
                    ),
                  ],
                  if (tab == 1 || tab == 2)
                    Positioned.fill(
                      top: chromeExtent - 3,
                      child: _resultsPanel(
                        state,
                        sorted,
                        null,
                        accesses,
                        distances,
                        directionReady,
                      ),
                    ),
                  if (tab == 3)
                    Positioned.fill(top: chromeExtent, child: _guides(state)),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: ink.withValues(alpha: .08),
        height: 70,
        selectedIndex: tab,
        onDestinationSelected: (v) {
          if (v == 1) {
            beginSearch();
          } else {
            setState(() {
              tab = v;
              sheetFraction = 0;
            });
          }
          coordinator.savedOnly(v == 2);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.format_list_bulleted),
            label: 'Lugares',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Salvos',
          ),
          NavigationDestination(
            icon: Icon(Icons.offline_pin_outlined),
            label: 'Guias',
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(
    String text,
    IconData icon,
    bool selected,
    VoidCallback tap,
  ) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(text),
      avatar: Icon(icon, size: 17, color: selected ? Colors.white : ocean),
      selected: selected,
      onSelected: (_) => tap(),
      showCheckmark: false,
      selectedColor: ocean,
      labelStyle: TextStyle(
        color: selected ? Colors.white : ink,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      side: BorderSide(color: Colors.grey.withValues(alpha: .18)),
    ),
  );
  Widget _tool(IconData icon, String label, VoidCallback action) => Material(
    elevation: 3,
    shadowColor: Colors.black12,
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(15),
    child: IconButton(
      tooltip: label,
      onPressed: action,
      icon: Icon(icon, color: ocean),
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: const EdgeInsets.all(8),
    ),
  );
  Widget _resultsPanel(
    MapState state,
    List<TourismPlace> places,
    ScrollController? scroll,
    Map<String, IslandLandAccess> accesses,
    Map<String, double> distances,
    bool directionReady, {
    Widget? dock,
  }) {
    final waitingForDirection =
        tab == 1 && state.query.isEmpty && !allNearby && !directionReady;
    final collapsed = dock != null && sheetPixels < dockHeight + 30;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dock != null) ...[
          Center(
            child: Container(
              key: const ValueKey('map-dock-handle'),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xffa3aebb),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          dock,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    allNearby = false;
                    coordinator.query('');
                    beginSearch();
                  },
                  icon: const Icon(Icons.near_me_outlined),
                  label: const Text('À frente'),
                ),
                TextButton.icon(
                  onPressed: () {
                    coordinator.query('');
                    coordinator.savedOnly(true);
                    setState(() {
                      tab = 2;
                      sheetFraction = 0;
                    });
                  },
                  icon: const Icon(Icons.bookmark_border),
                  label: const Text('Lugares salvos'),
                ),
                TextButton.icon(
                  onPressed: filters,
                  icon: const Icon(Icons.tune),
                  label: const Text('Filtros'),
                ),
              ],
            ),
          ),
          if (!collapsed && recentIds.isNotEmpty) ...[
            Text('Recentes', style: Theme.of(context).textTheme.titleSmall),
            for (final id in recentIds)
              if (state.places.where((p) => p.id == id).firstOrNull
                  case final place?)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text(place.name),
                  subtitle: Text(place.city),
                  onTap: () => details(place),
                ),
          ],
        ],
        if (!collapsed) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  tab == 2
                      ? 'Seus lugares salvos'
                      : state.islandsOnly
                      ? 'Ilhas do litoral'
                      : state.query.isEmpty && tab == 1
                      ? 'Para onde vamos?'
                      : 'Explore o Maranhão',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (state.islandsOnly)
                IconButton(
                  tooltip: 'Mostrar todos os lugares',
                  onPressed: () => coordinator.islandsOnly(false),
                  icon: const Icon(Icons.close, size: 20),
                ),
              IconButton(
                tooltip: 'Atualizar catálogo',
                onPressed: coordinator.refresh,
                icon: const Icon(Icons.refresh, size: 21),
              ),
            ],
          ),
          if (tab != 1 || state.query.isNotEmpty)
            Text(
              '${places.length} lugares ${tab == 0 && state.query.isEmpty ? 'nesta área' : 'encontrados'}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          if (tab == 1 && state.query.isEmpty) ...[
            Text(
              allNearby
                  ? 'Lugares próximos em todas as direções.'
                  : directionReady
                  ? 'Sugestões na direção da viagem.'
                  : 'Aguardando o GPS identificar a direção da viagem. Para explorar agora, escolha Todos próximos.',
              style: const TextStyle(fontSize: 12),
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('À frente'),
                  selected: !allNearby,
                  onSelected: (_) => setState(() => allNearby = false),
                ),
                ChoiceChip(
                  label: const Text('Todos próximos'),
                  selected: allNearby,
                  onSelected: (_) => setState(() => allNearby = true),
                ),
              ],
            ),
          ],
          if (locationStatus != null)
            TextButton.icon(
              onPressed: locating ? null : () => locate(automatic: true),
              icon: const Icon(Icons.my_location, size: 17),
              label: Text(
                locating
                    ? 'Buscando localização…'
                    : 'Localização indisponível. Tentar novamente',
              ),
            ),
          if (state.city != null && hasMunicipalGuide(state.city!))
            MunicipalVisitGuide(city: state.city!),
          if (state.offline)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Sem atualização do catálogo. Seus destinos salvos continuam disponíveis.',
              ),
            ),
          if (state.truncated)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Aproxime o mapa para carregar mais lugares desta área.',
              ),
            ),
          if (places.isEmpty && !waitingForDirection)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Column(
                children: [
                  const Icon(Icons.travel_explore, size: 40, color: ocean),
                  const SizedBox(height: 12),
                  Text(
                    tab == 2
                        ? 'Salve lugares para sua viagem'
                        : state.couponsOnly
                        ? 'Ainda não há benefícios publicados nesta seleção'
                        : tab == 1 && state.query.isEmpty && !allNearby
                        ? 'Nenhum lugar à frente nesta seleção'
                        : 'Nenhum lugar nesta seleção',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Experimente outra região ou ajuste os filtros.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () {
                      search.clear();
                      coordinator.resetFilters();
                    },
                    child: const Text('Limpar filtros'),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        itemCount: collapsed ? 1 : places.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return header;
          }
          final place = places[index - 1];
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: PlaceRow(
              place: place,
              saved: state.saved.contains(place.id),
              distance: distances[place.id],
              accessName: accesses[place.id]?.destination.name,
              onTap: () => details(place, access: accesses[place.id]),
              onSave: () => coordinator.toggleSave(place.id),
            ),
          );
        },
      ),
    );
  }

  Widget _guides(MapState state) {
    final areas =
        state.places.map((p) => p.area).whereType<String>().toSet().toList()
          ..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        Card(
          elevation: 0,
          color: const Color(0xffeaf0fa),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dados reais, fontes identificadas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '217 municípios do IBGE • 3.991 pontos do OpenStreetMap • extração de 30/10/2026.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Há pontos nomeados nesta extração em 146 municípios. As outras 71 cidades estão na base, mas precisam de complementação de atrativos e serviços. A ausência de um registro não significa ausência de oferta turística.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ruas e rotas precisam de conexão. Horários, funcionamento e acesso devem ser confirmados. Não há trânsito, bloqueios ou alertas colaborativos em tempo real.',
                  style: TextStyle(fontSize: 13),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                      ),
                      child: const Text('OpenStreetMap / ODbL'),
                    ),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'https://www.ibge.gov.br/geociencias/organizacao-do-territorio/tipologias-do-territorio/27385-localidades.html',
                        ),
                      ),
                      child: const Text('Fonte IBGE'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'O Maranhão vai com você',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const Text(
          'Os guias essenciais já estão neste aplicativo: destinos, descrições e localização de referência, mesmo sem sinal.',
        ),
        const SizedBox(height: 12),
        const Text(
          'O mapa essencial não inclui ruas nem navegação. Benefícios precisam de conexão para confirmar disponibilidade.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 15),
        for (final area in areas)
          Card(
            child: ListTile(
              leading: const Icon(Icons.offline_pin, color: ocean),
              title: Text(area),
              subtitle: Text(
                '${state.places.where((p) => p.area == area).length} referências • disponível neste aparelho',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                coordinator.setFilters(area: area);
                coordinator.engine(MapEngine.essential);
                setState(() => tab = 0);
              },
            ),
          ),
      ],
    );
  }
}

class PlaceRow extends StatelessWidget {
  const PlaceRow({
    super.key,
    required this.place,
    required this.saved,
    required this.onTap,
    required this.onSave,
    this.distance,
    this.accessName,
  });
  final TourismPlace place;
  final bool saved;
  final VoidCallback onTap, onSave;
  final double? distance;
  final String? accessName;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: .12),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 64,
            decoration: BoxDecoration(
              color: place.category.color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              place.category.icon,
              color: place.category.color,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  place.city,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff627c80),
                  ),
                ),
                if (place.hasCoupon)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Benefício publicado',
                      style: TextStyle(
                        color: Color(0xff9b6a18),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (accessName != null)
                  Text(
                    'Acesso por $accessName',
                    style: const TextStyle(fontSize: 12),
                  )
                else if (place.isCoastalIsland)
                  const Text(
                    'Acesso terrestre a verificar',
                    style: TextStyle(fontSize: 12),
                  ),
                if (distance != null)
                  Text(
                    '${distance!.toStringAsFixed(1)} km em linha reta',
                    style: const TextStyle(fontSize: 10),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: saved ? 'Remover dos salvos' : 'Salvar lugar',
            onPressed: onSave,
            icon: Icon(
              saved ? Icons.bookmark : Icons.bookmark_border,
              color: saved ? ocean : Colors.grey,
            ),
          ),
        ],
      ),
    ),
  );
}

class PlaceDetails extends ConsumerWidget {
  const PlaceDetails({
    super.key,
    required this.place,
    required this.onFocus,
    required this.onNavigate,
    this.access,
  });
  final TourismPlace place;
  final IslandLandAccess? access;
  final VoidCallback onFocus, onNavigate;
  Future<void> open(BuildContext context, Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível abrir o aplicativo. Tente novamente com conexão.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mapStateProvider);
    final saved = state.saved.contains(place.id);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .84,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (place.photoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    place.photoUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    avatar: Icon(place.category.icon, size: 17),
                    label: Text(place.category.label),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: saved ? 'Remover dos salvos' : 'Salvar lugar',
                    onPressed: () => ref
                        .read(mapStateProvider.notifier)
                        .toggleSave(place.id),
                    icon: Icon(
                      saved ? Icons.bookmark : Icons.bookmark_border,
                      color: ocean,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                place.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                place.city,
                style: const TextStyle(fontSize: 16, color: Color(0xff627c80)),
              ),
              if (!place.isCoastalIsland && state.location != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${state.location!.distanceKm(place.point).toStringAsFixed(1)} km da sua posição • em linha reta',
                  ),
                ),
              for (final i
                  in ref
                      .watch(repositoryProvider)
                      .coastalIslands
                      .where((i) => i.place.id == place.id))
                IslandVisitInfo(island: i, preferredAccess: access),
              PlaceElevation(place: place),
              if (place.dataSource != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${place.dataSource}${place.checkedAt == null ? '' : ' • conferência ${place.checkedAt}'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff63728a),
                    ),
                  ),
                ),
              if (place.category == PlaceCategory.destination)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(mapStateProvider.notifier).resetFilters();
                      ref
                          .read(mapStateProvider.notifier)
                          .setFilters(city: place.city);
                      onFocus();
                    },
                    icon: const Icon(Icons.travel_explore),
                    label: Text('Explorar ${place.city}'),
                  ),
                ),
              if (place.city == 'Barreirinhas')
                TravelSafetyButton(
                  barreirinhas: true,
                  stage: place.category == PlaceCategory.destination
                      ? SafetyStage.arrival
                      : SafetyStage.activity,
                ),
              if (place.city == 'Barreirinhas')
                OutlinedButton.icon(
                  onPressed: () => showGooglePlace(context, place),
                  icon: const Icon(Icons.travel_explore),
                  label: const Text('Consultar informações no Google'),
                ),
              const SizedBox(height: 22),
              Text(
                place.description,
                style: const TextStyle(height: 1.55, fontSize: 15),
              ),
              if (place.city == 'Barreirinhas')
                BarreirinhasSourceLink(placeId: place.id),
              if (hasMunicipalGuide(place.city))
                MunicipalVisitGuide(city: place.city),
              if (place.referenceLocation)
                Container(
                  margin: const EdgeInsets.only(top: 18),
                  constraints: place.category == PlaceCategory.residential
                      ? const BoxConstraints(minHeight: 44)
                      : const BoxConstraints.tightFor(width: 44, height: 44),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    place.category == PlaceCategory.residential
                        ? 'Área residencial privada. Referência cartográfica, não portaria confirmada. Combine o acesso com o responsável. Não indica hospedagem ou parceiro MaraPass.'
                        : 'Localização de referência. Confirme o ponto de acesso, horários e condições de visitação antes de sair.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              if (place.hasCoupon)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xfffff3d9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Benefício publicado',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ink,
                        ),
                      ),
                      Text(
                        place.offerTitle!,
                        style: const TextStyle(color: ink),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Disponibilidade e limite precisam ser confirmados na emissão do cupom.',
                        style: TextStyle(fontSize: 11, color: ink),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.directions_outlined),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(
                      (place.isBeach || place.needsVisitPlanning)
                          ? 'Planejar visita'
                          : 'Navegar no MaraPass',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onFocus,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Ver no mapa'),
                    ),
                  ),
                  if (!place.needsVisitPlanning) const SizedBox(width: 8),
                  if (!place.needsVisitPlanning)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => open(
                          context,
                          Uri.https('waze.com', '/ul', {
                            if (place.referenceLocation)
                              'q': '${place.name}, ${place.city}, Maranhão'
                            else
                              'll': '${place.point.lat},${place.point.lng}',
                            'navigate': 'yes',
                          }),
                        ),
                        child: const Text('Abrir Waze'),
                      ),
                    ),
                ],
              ),
              if (place.dataSource != null &&
                  place.category != PlaceCategory.destination &&
                  (place.address == null ||
                      place.hours == null ||
                      place.phone == null))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    [
                      if (place.address == null)
                        'Endereço não informado na fonte',
                      if (place.hours == null) 'Horário não informado na fonte',
                      if (place.phone == null)
                        'Telefone não informado na fonte',
                    ].join(' • '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff63728a),
                    ),
                  ),
                ),
              if (place.address != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(place.address!),
                ),
              if (place.hours != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(place.hours!),
                ),
              if (place.tags != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    place.tags!,
                    style: const TextStyle(color: ocean),
                  ),
                ),
              if (place.website != null)
                OutlinedButton.icon(
                  onPressed: () => open(context, Uri.parse(place.website!)),
                  icon: const Icon(Icons.language),
                  label: const Text('Site oficial'),
                ),
              if (place.phone != null)
                TextButton.icon(
                  onPressed: () => open(
                    context,
                    Uri(
                      scheme: 'tel',
                      path: place.phone!
                          .split(';')
                          .first
                          .replaceAll(RegExp(r'[^+0-9]'), ''),
                    ),
                  ),
                  icon: const Icon(Icons.phone_outlined),
                  label: const Text('Ligar'),
                ),
              if (place.whatsapp != null)
                TextButton.icon(
                  onPressed: () => open(
                    context,
                    Uri.https(
                      'wa.me',
                      '/${place.whatsapp!.replaceAll(RegExp(r'\D'), '')}',
                    ),
                  ),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
              if (place.sourceUrl != null)
                TextButton(
                  onPressed: () => open(context, Uri.parse(place.sourceUrl!)),
                  child: const Text('Consultar informações do destino'),
                ),
              const SizedBox(height: 5),
              Text(
                '${place.point.lat.toStringAsFixed(5)}, ${place.point.lng.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
