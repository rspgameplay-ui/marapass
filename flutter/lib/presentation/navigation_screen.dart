import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/map_state.dart';
import '../application/navigation_session.dart';
import '../domain/navigation.dart';
import '../data/beach_visit.dart';
import '../data/routing_repository.dart';
import 'beach_visit_screen.dart';
import '../domain/tourism.dart';
import '../maps/pointer_shield.dart';
import '../maps/road_map.dart';
import 'brand.dart';
import '../location/location_service.dart';
import 'location_help.dart';
import 'municipal_visit_guide.dart';
import '../islands/island_directory.dart';
import '../islands/island_land_access.dart';
import 'travel_safety.dart';
import '../journey/journey.dart';
import '../journey/journey_controller.dart';
import '../journey/journey_widgets.dart';
import 'origin_voice_sheet.dart';
import '../voice/command.dart';
import '../voice/drive_voice_controller.dart';
import '../voice/place_resolver.dart';

import '../maps/navigation_3d_stub.dart'
    if (dart.library.js_interop) '../maps/navigation_3d_web.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({
    super.key,
    required this.destination,
    this.autoPlan = false,
    this.roadOnly = false,
    this.preferredIslandAccess,
  });
  final TourismPlace destination;
  final bool autoPlan, roadOnly;
  final IslandLandAccess? preferredIslandAccess;
  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen>
    with WidgetsBindingObserver {
  late final bool supports3d = navigation3dSupported;
  late bool perspective = supports3d;
  bool perspectiveFailed = false, satellite = false;
  bool _showingPerspective = false;
  RoadRoute? _renderedRoute;
  List<List<double>> _coordinates = [];

  List<double> coordinates(GeoPoint p) => [p.lng, p.lat];

  GeoPoint? from;
  late String initialOrigin;
  TextEditingController? originText;
  bool finding = false;
  int originRevision = 0;
  String? originStatus;
  late NavigationSession _observedSession;
  late JourneyController _journey;
  RoadRoute? _journeyRoute;
  GeoBounds routeViewport = GeoBounds.maranhao;
  double routeZoom = 6;
  TourismPlace? focusedDiscovery;
  CameraRequest camera = const CameraRequest(GeoPoint(-4.8, -45), 6, 0);
  NavigationSession get session => ref.read(navigationProvider);
  TourismPlace? _changedDestination;
  TourismPlace? _visitTarget;
  RoutingProfile _visitProfile = RoutingProfile.driving;
  bool get _roadOnly =>
      widget.roadOnly ||
      (_visitTarget != null && _visitProfile == RoutingProfile.driving);
  String? _destinationDiscoveryId;
  TourismPlace get destination =>
      _changedDestination ?? _visitTarget ?? widget.destination;
  late final _driveVoice = DriveVoiceController(
    active: () =>
        mounted && _observedSession.active && !_observedSession.simulating,
    speaking: () => _observedSession.speaking,
    resolve: (term) {
      final command = parseCommand(
        'rota para $term',
        ref.read(repositoryProvider).municipalities,
      );
      if (command.error != null ||
          (command.term.isEmpty && command.city == null))
        return [];
      final matches = resolvePlaces(command, ref.read(mapStateProvider).places);
      if (matches.isEmpty) return [];
      return matches
          .where((m) => matches.first.score - m.score < .08)
          .map((m) => m.place)
          .toList();
    },
    change: _changeDestination,
    speak: (message) => _observedSession.speakAssistant(message),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _observedSession = session;
    _journey = ref.read(journeyProvider);
    _observedSession.addListener(syncJourney);
    from = null;
    initialOrigin = '';
    camera = CameraRequest(destination.point, 11, 0);
    if (!destination.isBeach && !destination.needsVisitPlanning)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (!widget.roadOnly &&
              widget.autoPlan &&
              Uri.base.queryParameters['simulation'] == 'mixed') {
            session.loadMixedSimulation();
          } else {
            gps(automatic: true);
          }
        }
      });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _driveVoice.stop();
      if (session.active) {
        if (kIsWeb || session.simulating) session.pause();
      }
    }
  }

  @override
  void dispose() {
    _driveVoice.dispose();
    if (finding) _observedSession.locationService.cancelPending();
    _observedSession.removeListener(syncJourney);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void syncJourney() {
    if (!_observedSession.active) _driveVoice.stop();
    final route = _observedSession.route;
    if (identical(route, _journeyRoute)) return;
    _journeyRoute = route;
    if (route == null) {
      _journey.clearRoute();
    } else {
      _journey.refresh(route);
    }
  }

  Future<bool> _changeDestination(
    TourismPlace place, {
    String? islandId,
  }) async {
    if (place.id == destination.id || place.needsVisitPlanning) return false;
    if (!await _observedSession.changeDestination(
          place.point,
          roadOnly: islandId != null || _roadOnly,
        ) ||
        !mounted ||
        !_observedSession.active) {
      return false;
    }
    setState(() {
      _changedDestination = place;
      _destinationDiscoveryId = islandId;
      focusedDiscovery = null;
      from = _observedSession.origin;
    });
    _observedSession.setFollow(true);
    return true;
  }

  void discovery(JourneyCandidate entry) {
    final access = entry.islandAccess;
    final target = access?.destination ?? entry.place;
    showJourneyDetails(
      context,
      entry,
      onReroute:
          session.active &&
              target.id != destination.id &&
              !target.needsVisitPlanning
          ? () => _changeDestination(
              target,
              islandId: access == null ? null : entry.place.id,
            )
          : null,
      onFocus: () {
        session.setFollow(false);
        setState(() {
          focusedDiscovery = entry.mapPlace;
          camera = CameraRequest(entry.point, 16, camera.serial + 1);
        });
      },
    );
  }

  void discoveries() => showJourneyPanel(
    context,
    destinationId: _destinationDiscoveryId ?? destination.id,
    onSelect: discovery,
  );

  Future<void> gps({bool automatic = false}) async {
    if (finding) {
      return;
    }
    final revision = ++originRevision;
    setState(() {
      finding = true;
      originStatus = 'Obtendo sua localização…';
    });
    try {
      final p = await session.currentPosition(forNavigation: false);
      if (!mounted || revision != originRevision) {
        return;
      }
      session.resetPlan(profile: _visitProfile);
      setState(() {
        from = GeoPoint(p.latitude, p.longitude);
        originText?.text = 'Minha localização';
        originStatus = null;
      });
      ref.read(mapStateProvider.notifier).setLocation(from!);
      if (widget.autoPlan || !automatic)
        await session.calculate(from!, destination.point, roadOnly: _roadOnly);
    } catch (e) {
      if (mounted && revision == originRevision && !automatic) {
        showLocationHelp(context, failure: locationFailure(e));
      } else if (mounted && revision == originRevision) {
        setState(
          () => originStatus =
              'Localização indisponível. Digite uma origem ou toque no GPS.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => finding = false);
      }
    }
  }

  Future<void> voiceOrigin() async {
    final choice = await showModalBottomSheet<TourismPlace>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          OriginVoiceSheet(places: ref.read(mapStateProvider).places),
    );
    if (!mounted || choice == null) return;
    ++originRevision;
    session.locationService.cancelPending();
    session.resetPlan(profile: _visitProfile);
    setState(() {
      from = choice.point;
      originText?.text = choice.name == choice.city
          ? choice.name
          : '${choice.name} • ${choice.city}';
      originStatus = null;
    });
  }

  Future<void> start() async {
    await session.start();
    if (mounted && session.active) {
      setState(() {
        from = session.origin;
        originText?.text = 'Minha localização';
      });
    }
  }

  void directions(RoadRoute route) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(sheet).height * .7,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Instruções do percurso',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: route.steps.length,
                itemBuilder: (context, i) {
                  final step = route.steps[i];
                  return ListTile(
                    leading: Icon(_maneuverIcon(step)),
                    title: Text(step.instruction),
                    subtitle: Text(formatDistance(step.distance)),
                    onTap: () {
                      Navigator.pop(sheet);
                      session.setFollow(false);
                      setState(
                        () => camera = CameraRequest(
                          step.point,
                          16,
                          camera.serial + 1,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  void _returnToBeachPlan() {
    session.resetPlan();
    setState(() {
      _visitTarget = null;
      _visitProfile = RoutingProfile.driving;
      _changedDestination = null;
      _destinationDiscoveryId = null;
    });
  }

  void _startBeachVisit(
    VisitPlan plan,
    GeoPoint target,
    RoutingProfile profile,
  ) {
    session.prepareVisitRoute(
      plan.route,
      plan.origin,
      target,
      profile: profile,
      downloaded: plan.downloaded,
    );
    setState(() {
      _visitProfile = profile;
      _visitTarget = TourismPlace(
        id: widget.destination.id,
        name: widget.destination.name,
        city: widget.destination.city,
        point: target,
        category: PlaceCategory.transport,
        description: '',
        referenceLocation: false,
      );
      from = plan.origin;
      initialOrigin = 'Minha localização';
      camera = CameraRequest(target, 14, camera.serial + 1);
    });
    unawaited(start());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.destination.isBeach && _visitTarget == null) {
      return BeachVisitScreen(
        beach: widget.destination,
        onNavigate: _startBeachVisit,
      );
    }
    if (destination.needsVisitPlanning) {
      return Scaffold(
        appBar: AppBar(title: const Text('Planejar visita')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                destination.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                destination.isBeach
                    ? 'Este marcador identifica a praia, mas a entrada ainda não foi verificada. Confirme o acesso com informações locais antes de viajar.'
                    : destination.isCoastalIsland
                    ? 'O marcador localiza a ilha; não é um ponto de embarque ou desembarque. Confirme o acesso e o retorno com a comunidade ou prestador local.'
                    : 'O marcador é uma referência do atrativo. Confirme estacionamento, embarque ou ponto de encontro com o prestador local. Nos circuitos do Parque Nacional, o transporte turístico exige credenciamento.',
              ),
              const SizedBox(height: 16),
              Text(destination.description),
              for (final i
                  in ref
                      .watch(repositoryProvider)
                      .coastalIslands
                      .where((i) => i.place.id == destination.id))
                IslandVisitInfo(
                  island: i,
                  preferredAccess: widget.preferredIslandAccess,
                ),
              if (hasMunicipalGuide(destination.city))
                MunicipalVisitGuide(city: destination.city),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar ao mapa'),
              ),
            ],
          ),
        ),
      );
    }

    final n = ref.watch(navigationProvider), map = ref.watch(mapStateProvider);
    final active = n.active, route = n.route;
    final journey = ref.watch(journeyProvider);
    final recommendations = route == null
        ? <JourneyCandidate>[]
        : journey.recommendations(
            route,
            map.places,
            progress: n.meters,
            traveling: active || n.phase == NavigationPhase.arrived,
            saved: map.saved,
            destinationId: _destinationDiscoveryId ?? destination.id,
          );
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final arrival =
        route == null || n.simulating || n.phase == NavigationPhase.arrived
        ? null
        : TimeOfDay.fromDateTime(
            DateTime.now().add(
              Duration(
                seconds: (active ? n.remainingSeconds : route.duration).ceil(),
              ),
            ),
          ).format(context);
    final mapView = map.copy(
      request: camera,
      location: n.location,
      places: {
        for (final entry in journeyHighlights(recommendations))
          entry.place.id: entry.mapPlace,
        if (focusedDiscovery case final p?) p.id: p,
      }.values.toList(),
      zoom: routeZoom,
      bounds: routeViewport,
      query: '',
      clearCategory: true,
      clearCity: true,
      clearArea: true,
      couponsOnly: false,
      savedOnly: false,
    );
    final in3d =
        _visitProfile != RoutingProfile.walking &&
        active &&
        // A estabilidade do GPS libera só a primeira montagem do 3D (cameraArmed,
        // mantido pela sessão). Oscilações de sinal não desmontam o iframe:
        // recriar MapLibre/Three.js gera novos contextos WebGL no Safari/iOS.
        n.cameraArmed &&
        perspective &&
        !perspectiveFailed &&
        (n.follow || _showingPerspective) &&
        route != null;
    _showingPerspective = in3d;
    if (!identical(_renderedRoute, route)) {
      _renderedRoute = route;
      _coordinates = route?.points.map(coordinates).toList() ?? [];
    }
    return Scaffold(
      appBar: active
          ? null
          : AppBar(
              title: const MaraBrand(),
              leading: _visitTarget == null || n.starting
                  ? null
                  : BackButton(onPressed: _returnToBeachPlan),
              backgroundColor: Colors.white,
              foregroundColor: MaraColors.navy,
              actions: [
                if (!active && !n.starting)
                  TravelSafetyButton(
                    iconOnly: true,
                    barreirinhas: destination.city == 'Barreirinhas',
                  ),
                IconButton(
                  tooltip: 'Personalizar descobertas',
                  onPressed: () => showJourneyPreferences(context),
                  icon: const Icon(Icons.tune),
                ),
                if (!active)
                  IconButton(
                    tooltip: n.voice
                        ? 'Silenciar voz'
                        : 'Ativar orientação por voz',
                    onPressed: () => n.setVoice(!n.voice),
                    icon: Icon(
                      n.voice
                          ? Icons.volume_up_outlined
                          : Icons.volume_off_outlined,
                    ),
                  ),
              ],
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, limits) => Column(
            children: [
              if (!active &&
                  route == null &&
                  n.phase != NavigationPhase.arrived)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: limits.maxHeight * .35,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Autocomplete<TourismPlace>(
                            initialValue: TextEditingValue(text: initialOrigin),
                            displayStringForOption: (p) => p.name == p.city
                                ? p.name
                                : '${p.name} • ${p.city}',
                            optionsBuilder: (value) {
                              if (value.text.length < 2) {
                                return const Iterable<TourismPlace>.empty();
                              }
                              final q = normalize(value.text);
                              return map.places
                                  .where(
                                    (p) =>
                                        normalize('${p.name} ${p.city}')
                                            .contains(q),
                                  )
                                  .take(12);
                            },
                            onSelected: (p) {
                              ++originRevision;
                              session.locationService.cancelPending();
                              n.resetPlan(profile: _visitProfile);
                              setState(() {
                                from = p.point;
                                originStatus = null;
                              });
                            },
                            fieldViewBuilder:
                                (context, controller, focus, onSubmit) {
                                  originText = controller;
                                  return TextField(
                                    controller: controller,
                                    focusNode: focus,
                                    enabled:
                                        n.phase != NavigationPhase.calculating,
                                    onChanged: (_) {
                                      ++originRevision;
                                      session.locationService.cancelPending();
                                      n.resetPlan(profile: _visitProfile);
                                      setState(() => from = null);
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'De onde você vai sair?',
                                      hintText:
                                          'Sua localização, cidade ou lugar',
                                      prefixIcon: const Icon(Icons.trip_origin),
                                      border: const OutlineInputBorder(),
                                      suffixIcon: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Buscar origem por voz',
                                            onPressed: voiceOrigin,
                                            icon: const Icon(Icons.mic_none),
                                          ),
                                          IconButton(
                                            tooltip: 'Usar meu GPS como origem',
                                            onPressed: finding ? null : gps,
                                            icon: Icon(
                                              finding
                                                  ? Icons.hourglass_top
                                                  : Icons.my_location,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                          ),
                          if (originStatus != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                originStatus!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: MaraColors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${destination.name} • ${destination.city}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.roadOnly)
                            Text(
                              destination.description,
                              style: const TextStyle(fontSize: 12),
                            ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed:
                                from == null ||
                                    n.phase == NavigationPhase.calculating
                                ? null
                                : () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    n.calculate(
                                      from!,
                                      destination.point,
                                      roadOnly: _roadOnly,
                                    );
                                  },
                            icon: const Icon(Icons.alt_route),
                            label: Text(
                              n.phase == NavigationPhase.calculating
                                  ? 'Calculando rota…'
                                  : 'Calcular rota de carro',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: in3d
                          ? Navigation3DCanvas(
                              frame: {
                                'route': _coordinates,
                                'vehicle': n.location == null
                                    ? null
                                    : coordinates(n.location!),
                                // Sem sinal, cameraBearing é nulo: mantém a última
                                // direção conhecida em vez de virar o carro ao norte.
                                'bearing': n.lowSignal && n.headingKnown
                                    ? n.heading
                                    : n.cameraBearing,
                                // Sem posição nova a câmera fica parada na última
                                // posição; não desligar follow evita saltos de foco.
                                'follow': n.follow && n.cameraArmed,
                                // Posição desatualizada: o 3D mostra o carro em cinza.
                                'stale': n.lowSignal,
                                'satellite': satellite,
                                'nautical': n.travelMode.name == 'nautical',
                                'focus': {
                                  'point': coordinates(camera.target),
                                  'revision': camera.serial,
                                },
                                'places': [
                                  for (final entry in recommendations.take(4))
                                    {
                                      'id': entry.place.id,
                                      'name': entry.place.name,
                                      'category': entry.place.category.name,
                                      'coupon': entry.place.hasCoupon,
                                      'point': coordinates(entry.point),
                                      'ahead':
                                          '${formatDistance(entry.ahead(n.meters))} adiante',
                                    },
                                ],
                              },
                              onGesture: () {
                                if (n.follow) n.setFollow(false);
                              },
                              onPlace: (id) {
                                final entry = recommendations
                                    .where((e) => e.place.id == id)
                                    .firstOrNull;
                                if (entry != null) discovery(entry);
                              },
                              onUnavailable: () =>
                                  setState(() => perspectiveFailed = true),
                            )
                          : RoadMap(
                              state:
                                  active && mapView.engine == MapEngine.google
                                  ? mapView.copy(engine: MapEngine.streets)
                                  : mapView,
                              route: route,
                              alternatives: active ? const [] : n.routes,
                              creditBottom: active ? 147 : null,
                              origin: n.origin ?? from,
                              destination: destination.point,
                              live: n.location,
                              travelMode: n.travelMode,
                              pedestrian:
                                  _visitProfile == RoutingProfile.walking,
                              heading: n.heading,
                              headingKnown: n.headingKnown,
                              followBearing: n.cameraBearing,
                              gpsAccuracy: n.accuracy,
                              imprecise: n.lowSignal,
                              follow: active && n.follow && n.cameraArmed,
                              navigationView: active,
                              creditTop: 8,
                              followOffset: active
                                  ? Offset(0, limits.maxHeight * .19)
                                  : Offset.zero,
                              reference: ref.watch(repositoryProvider).roads,
                              onGesture: active
                                  ? () => n.setFollow(false)
                                  : null,
                              onViewport: (bounds, zoom) {
                                if (mounted)
                                  setState(() {
                                    routeViewport = bounds;
                                    routeZoom = zoom;
                                  });
                              },
                              onFeature: (feature) {
                                if (feature.isCluster) {
                                  n.setFollow(false);
                                  setState(
                                    () => camera = CameraRequest(
                                      feature.point,
                                      (routeZoom + 2).clamp(4, 18),
                                      camera.serial + 1,
                                    ),
                                  );
                                } else {
                                  final entries = recommendations.where(
                                    (e) =>
                                        e.place.id == feature.places.first.id,
                                  );
                                  if (entries.isNotEmpty)
                                    discovery(entries.first);
                                }
                              },
                            ),
                    ),
                    if (active) ...[
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: PointerShield(
                          enabled: in3d,
                          child: Column(
                          children: [
                            Container(
                              width: double.infinity,

                              decoration: BoxDecoration(
                                color: const Color(0xfffcfefe),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33092034),
                                    blurRadius: 16,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: const Color(0xff087f8b),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      n.lowSignal
                                          ? Icons.gps_off
                                          : n.deviated
                                          ? Icons.alt_route
                                          : _maneuverIcon(n.nextStep),
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n.lowSignal
                                              ? 'Localização imprecisa'
                                              : n.rerouting
                                              ? 'Recalculando rota'
                                              : n.deviated
                                              ? 'Fora da rota'
                                              : formatDistance(n.nextDistance),
                                          style: const TextStyle(
                                            color: const Color(0xff067681),
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          n.lowSignal
                                              ? 'Orientação pausada até obter posição precisa'
                                              : n.deviated
                                              ? n.travelMode.name == 'nautical'
                                                    ? 'Confira a travessia com o condutor; a rota foi mantida'
                                                    : 'Aguarde um novo percurso'
                                              : n.nextStep?.instruction ??
                                                    'Continue',
                                          style: const TextStyle(
                                            color: MaraColors.navy,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ListenableBuilder(
                              listenable: _driveVoice,
                              builder: (context, _) {
                                final status = _driveVoice.status;
                                if (status == null)
                                  return const SizedBox.shrink();
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          status,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (_driveVoice.pending != null)
                                          Wrap(
                                            children: [
                                              TextButton(
                                                onPressed:
                                                    _driveVoice.canConfirm
                                                    ? _driveVoice.cancel
                                                    : null,
                                                child: const Text(
                                                  'Manter rota',
                                                ),
                                              ),
                                              TextButton(
                                                onPressed:
                                                    _driveVoice.canConfirm
                                                    ? _driveVoice.confirm
                                                    : null,
                                                child: const Text(
                                                  'Confirmar destino',
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (n.simulating || n.message != null)
                              Material(
                                color: const Color(0xfffff3d0),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  child: Text(
                                    n.message ?? 'Simulação · posição fictícia',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: PointerShield(
                          enabled: in3d,
                          child: Material(
                          color: Colors.white,
                          elevation: 5,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: discoveries,
                                  tooltip: 'Descobertas no caminho',
                                  icon: const Icon(Icons.explore_outlined),
                                ),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${formatDuration(n.remainingSeconds)} • ${formatDistance(n.remainingMeters)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (_changedDestination != null)
                                        Text(
                                          destination.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      if (arrival != null)
                                        Text(
                                          'Chegada às $arrival',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: n.pause,
                                  child: const Text('Encerrar'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        bottom: 76,
                        child: Semantics(
                          label: n.lowSignal
                              ? 'Velocidade indisponível. GPS impreciso'
                              : 'Velocidade ${n.speedKmh.round()} quilômetros por hora',
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xff128795),
                                width: 3,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x18000000),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  n.simulating
                                      ? '—'
                                      : n.lowSignal
                                      ? '—'
                                      : '${n.speedKmh.round()}',
                                  style: const TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xff086b79),
                                  ),
                                ),
                                const Text(
                                  'km/h',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xff086b79),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 76,
                        child: PointerShield(
                          enabled: in3d,
                          child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _NavigationControl(
                              label: n.voice
                                  ? 'Silenciar orientação'
                                  : 'Ativar orientação por voz',
                              icon: n.voice
                                  ? Icons.volume_up_outlined
                                  : Icons.volume_off_outlined,
                              onTap: () => n.setVoice(!n.voice),
                            ),
                            if (!n.simulating) ...[
                              const SizedBox(height: 8),
                              ListenableBuilder(
                                listenable: _driveVoice,
                                builder: (context, _) => _NavigationControl(
                                  label: _driveVoice.enabled
                                      ? 'Desativar Marapés'
                                      : 'Ativar Marapés',
                                  icon: _driveVoice.enabled
                                      ? Icons.mic
                                      : Icons.mic_none,
                                  color: _driveVoice.enabled
                                      ? const Color(0xffa3e8e8)
                                      : Colors.white,
                                  onTap: _driveVoice.toggle,
                                ),
                              ),
                            ],
                            if (in3d) ...[
                              const SizedBox(height: 8),
                              _NavigationControl(
                                label: satellite
                                    ? 'Mapa estilizado'
                                    : 'Satélite regional',
                                icon: satellite
                                    ? Icons.map_outlined
                                    : Icons.satellite_alt_outlined,
                                onTap: () =>
                                    setState(() => satellite = !satellite),
                              ),
                            ],
                            if (supports3d &&
                                !perspectiveFailed &&
                                _visitProfile != RoutingProfile.walking) ...[
                              const SizedBox(height: 8),
                              _NavigationControl(
                                label: perspective ? 'Vista 2D' : 'Vista 3D',
                                icon: perspective
                                    ? Icons.layers_outlined
                                    : Icons.view_in_ar_outlined,
                                onTap: () =>
                                    setState(() => perspective = !perspective),
                              ),
                            ],
                            const SizedBox(height: 8),
                            if (!n.follow)
                              FilledButton.icon(
                                onPressed: () => n.setFollow(true),
                                icon: const Icon(Icons.my_location),
                                label: const Text('Voltar à rota'),
                              )
                            else
                              _NavigationControl(
                                label: 'Seguindo minha posição',
                                icon: Icons.gps_fixed,
                                onTap: () => n.setFollow(true),
                              ),
                          ],
                        ),
                        ),
                      ),
                    ],
                    if (n.phase == NavigationPhase.calculating)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
              if (!active && n.message != null)
                Container(
                  constraints: BoxConstraints(
                    maxHeight: limits.maxHeight * .30,
                  ),
                  width: double.infinity,
                  color: const Color(0xfffff3d0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.message!, style: const TextStyle(fontSize: 12)),
                        if (n.locationIssue != null)
                          TextButton.icon(
                            onPressed: () => showLocationHelp(
                              context,
                              failure: n.locationIssue,
                            ),
                            icon: const Icon(Icons.help_outline),
                            label: const Text('Como liberar a localização'),
                          ),
                      ],
                    ),
                  ),
                ),
              if (!active && route != null && !keyboard)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: limits.maxHeight * .42,
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(color: Color(0x15000000), blurRadius: 12),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            destination.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: MaraColors.navy,
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  n.phase == NavigationPhase.arrived
                                      ? 'Fim do percurso'
                                      : formatDuration(
                                          active
                                              ? n.remainingSeconds
                                              : route.duration,
                                        ),
                                  style: const TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w800,
                                    color: MaraColors.navy,
                                  ),
                                ),
                              ),
                              if (n.phase != NavigationPhase.arrived)
                                Text(
                                  formatDistance(route.distance),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Ver instruções',
                                onPressed: () => directions(route),
                                icon: const Icon(Icons.format_list_numbered),
                              ),
                            ],
                          ),
                          if (arrival != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text(
                                'Chegada estimada às $arrival',
                                style: const TextStyle(
                                  color: MaraColors.navy,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          if (n.phase == NavigationPhase.arrived &&
                              route.destinationSnap > 35)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'O ponto de destino fica a cerca de '
                                '${formatDistance(route.destinationSnap)} em linha reta '
                                'do fim da rota. Confira o acesso final.',
                              ),
                            ),
                          if (!active)
                            JourneyTeaser(
                              count: recommendations.length,
                              first: recommendations.firstOrNull,
                              onOpen: discoveries,
                              onPersonalize: () =>
                                  showJourneyPreferences(context),
                            ),
                          if (!active && n.routes.length > 1)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (var i = 0; i < n.routes.length; i++)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(
                                          '${i == 0 ? 'Principal' : 'Alternativa $i'} • ${formatDuration(n.routes[i].duration)}',
                                        ),
                                        selected: n.selected == i,
                                        onSelected: (_) => n.select(i),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          if (destination.referenceLocation && !active)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 7),
                              child: Text(
                                'Destino de referência: confira a entrada e o acesso final.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          if (route.hasFerry)
                            const Text(
                              'O percurso inclui balsa. Confirme horários e operação da travessia.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (n.phase != NavigationPhase.arrived)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 50),
                                backgroundColor: const Color(0xff175ba9),
                              ),
                              onPressed: n.starting ? null : start,
                              icon: const Icon(Icons.navigation_outlined),
                              label: Text(
                                n.starting
                                    ? n.phase == NavigationPhase.calculating
                                          ? 'Calculando rota a partir do GPS…'
                                          : 'Obtendo GPS…'
                                    : 'Iniciar com meu GPS',
                              ),
                            ),
                          if (!active && n.phase != NavigationPhase.arrived)
                            OutlinedButton.icon(
                              onPressed: n.starting ? null : n.startSimulation,
                              icon: const Icon(Icons.play_circle_outline),
                              label: const Text('Simular percurso sem GPS'),
                            ),
                          if (!active)
                            TextButton(
                              onPressed: n.resetPlan,
                              child: const Text('Alterar origem'),
                            ),
                          const SizedBox(height: 5),
                          const Text(
                            'Rotas: OSRM / FOSSGIS • © OpenStreetMap • estimativa sem trânsito ao vivo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xff607087),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (!active)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: limits.maxHeight * .3),
                  child: SingleChildScrollView(
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: Text(
                        'Escolha a origem e calcule. Ao usar GPS, apenas as posições necessárias ao cálculo serão enviadas ao serviço de rotas FOSSGIS/OSRM. Navegação em primeiro plano.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _maneuverIcon(RoadStep? step) {
  if (step == null) {
    return Icons.navigation;
  }
  if (step.type == 'arrive') {
    return Icons.flag_outlined;
  }
  if (step.type.contains('roundabout') || step.type.contains('rotary')) {
    return Icons.roundabout_right;
  }
  if (step.modifier == 'uturn') {
    return Icons.u_turn_left;
  }
  if (step.modifier.contains('left')) {
    return Icons.turn_left;
  }
  if (step.modifier.contains('right')) {
    return Icons.turn_right;
  }
  return Icons.straight;
}

/// Controles acessíveis de navegação, com área de toque mínima de 48 px.
class _NavigationControl extends StatelessWidget {
  const _NavigationControl({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    elevation: 3,
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: label,
      constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
      onPressed: onTap,
      icon: Icon(icon, color: MaraColors.navy),
    ),
  );
}
