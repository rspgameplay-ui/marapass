import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/map_state.dart';
import '../application/navigation_session.dart';
import '../core/visit_platform_stub.dart'
    if (dart.library.js_interop) '../core/visit_platform_web.dart';
import '../data/beach_visit.dart';
import '../data/routing_repository.dart';
import '../domain/navigation.dart';
import '../domain/tourism.dart';
import '../location/location_service.dart';
import '../maps/reference_roads.dart';
import 'brand.dart';

enum _VisitMode {
  car('Carro', 'de carro', Icons.directions_car_outlined),
  walk('A pé', 'a pé', Icons.directions_walk),
  ride('Por app', 'de carro por app', Icons.local_taxi_outlined);

  const _VisitMode(this.label, this.description, this.icon);
  final String label, description;
  final IconData icon;
  RoutingProfile get profile =>
      this == walk ? RoutingProfile.walking : RoutingProfile.driving;
}

enum _RouteStatus { loading, ready, noLocation, offline, error }

class BeachVisitScreen extends ConsumerStatefulWidget {
  const BeachVisitScreen({
    super.key,
    required this.beach,
    required this.onNavigate,
  });

  final TourismPlace beach;
  final void Function(VisitPlan plan, GeoPoint target, RoutingProfile profile)
  onNavigate;

  @override
  ConsumerState<BeachVisitScreen> createState() => _BeachVisitScreenState();
}

class _BeachVisitScreenState extends ConsumerState<BeachVisitScreen> {
  late final _accesses = beachAccesses(widget.beach);
  late BeachAccess _access = _accesses.first;
  final _location = LocationService();
  _VisitMode _mode = _VisitMode.car;
  _RouteStatus _status = _RouteStatus.loading;
  GeoPoint? _origin;
  VisitPlan? _plan;
  int _revision = 0;
  int _routeIndex = 0;
  bool _savingRoute = false;
  bool _locating = false;
  List<TourismPlace> _partners = [];
  SaoLuisTideForecast? _tides;
  Timer? _conditionsClock;

  String get _routeKey =>
      '${widget.beach.id}|${_access.id}|${_mode.profile.name}';
  GeoPoint get _target => _plan?.route.points.last ?? _access.point;
  DownloadedVisitRoutes get _downloads =>
      DownloadedVisitRoutes(ref.read(repositoryProvider).preferences);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_load());
      if (widget.beach.city == 'São Luís') {
        unawaited(
          SaoLuisTideForecast.load().then((events) {
            if (mounted) setState(() => _tides = events);
          }),
        );
        _conditionsClock = Timer.periodic(const Duration(minutes: 1), (_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  @override
  void dispose() {
    _conditionsClock?.cancel();
    _location.cancelPending();
    super.dispose();
  }

  Future<void> _load({bool refreshLocation = false}) async {
    if (_locating) return;
    final revision = ++_revision;
    final access = _access;
    final profile = _mode.profile;
    final routing = ref.read(routingRepositoryProvider);
    final downloads = _downloads;
    final key = _routeKey;
    setState(() {
      _status = _RouteStatus.loading;
      _plan = null;
      _partners = [];
    });
    unawaited(_loadPartners(access.point, revision));
    var start = refreshLocation
        ? null
        : _origin ?? ref.read(mapStateProvider).location;
    if (start == null) {
      setState(() => _locating = true);
      try {
        final position = await _location.acquire(navigation: false);
        start = GeoPoint(position.latitude, position.longitude);
      } catch (_) {
        if (mounted) start = _origin ?? ref.read(mapStateProvider).location;
      } finally {
        if (!mounted || revision != _revision) return;
        setState(() => _locating = false);
      }
    }
    if (!mounted || revision != _revision) return;
    _origin = start;
    if (start == null) {
      setState(() => _status = _RouteStatus.noLocation);
      return;
    }
    if (visitNetworkOffline) {
      setState(() {
        _plan = downloads.load(key, start!);
        _status = _RouteStatus.offline;
      });
      return;
    }
    try {
      final (plan, index) = await calculateVisitRoute(
        routing,
        start,
        access,
        profile,
      );
      if (!mounted || revision != _revision) return;
      setState(() {
        _plan = plan;
        _routeIndex = index;
        _status = _RouteStatus.ready;
      });
    } catch (error) {
      if (!mounted || revision != _revision) return;
      final networkUnavailable =
          error is http.ClientException || error is TimeoutException;
      final fallback = networkUnavailable ? downloads.load(key, start) : null;
      setState(() {
        _plan = fallback;
        _status = networkUnavailable
            ? _RouteStatus.offline
            : _RouteStatus.error;
      });
    }
  }

  Future<void> _loadPartners(GeoPoint point, int revision) async {
    final result = await ref
        .read(repositoryProvider)
        .fetchVisible(
          GeoBounds(
            point.lat - .015,
            point.lng - .015,
            point.lat + .015,
            point.lng + .015,
          ),
        );
    if (mounted && _revision == revision) {
      setState(() => _partners = result.places);
    }
  }

  void _selectMode(_VisitMode mode) {
    if (mode == _mode) return;
    final profileChanged = mode.profile != _mode.profile;
    setState(() => _mode = mode);
    if (profileChanged) unawaited(_load());
  }

  Future<void> _chooseOrigin() async {
    final places = ref.read(mapStateProvider).places;
    final chosen = await showDialog<TourismPlace>(
      context: context,
      builder: (sheet) => _VisitOriginDialog(places: places),
    );
    if (!mounted || chosen == null) return;
    setState(() => _origin = chosen.point);
    await _load();
  }

  Future<void> _download() async {
    final plan = _plan;
    if (plan == null || plan.downloaded || _savingRoute) return;
    setState(() => _savingRoute = true);
    var saved = false;
    try {
      saved = await _downloads.save(_routeKey, plan, _routeIndex);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _savingRoute = false);
    _notice(
      saved ? 'Rota salva neste aparelho.' : 'Não foi possível salvar a rota.',
    );
  }

  void _notice(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _open(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) _notice('Não foi possível abrir o link.');
  }

  String get _coordinates => '${_target.lat},${_target.lng}';
  String get _destinationQuery => _plan != null || _access.verified
      ? _coordinates
      : '${_accesses.length > 1 ? _access.name.replaceFirst(RegExp(r'^Entorno d[oa] '), '') : widget.beach.name}, ${widget.beach.city}, Maranhão';
  Uri get _googleMaps => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': _destinationQuery,
    'travelmode': _mode == _VisitMode.walk ? 'walking' : 'driving',
  });
  Uri get _waze => Uri.https('waze.com', '/ul', {
    if (_plan != null || _access.verified)
      'll': _coordinates
    else
      'q': _destinationQuery,
    'navigate': 'yes',
  });

  Future<void> _share() async {
    final url = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': _destinationQuery,
    });
    if (await shareVisit(widget.beach.name, url.toString())) return;
    if (!mounted) return;
    try {
      await Clipboard.setData(
        ClipboardData(text: '${widget.beach.name} • ${_access.name}\n$url'),
      );
      if (mounted) _notice('Link copiado para compartilhar.');
    } catch (_) {
      if (mounted) _notice('Não foi possível copiar o link.');
    }
  }

  Future<void> _feedback() async {
    final access = _access;
    final answer = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(access.name, style: Theme.of(sheet).textTheme.titleLarge),
              const Text(
                'Registre neste aparelho se o ponto de chegada está correto.',
              ),
              ListTile(
                title: const Text('Sim, a chegada está correta'),
                onTap: () => Navigator.pop(sheet, true),
              ),
              ListTile(
                title: const Text('Não, a chegada precisa de ajuste'),
                onTap: () => Navigator.pop(sheet, false),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || answer == null) return;
    var saved = false;
    try {
      saved = await ref
          .read(repositoryProvider)
          .preferences
          .setBool(
            'visit_access_feedback:${widget.beach.id}:${access.id}',
            answer,
          );
    } catch (_) {}
    if (mounted) {
      _notice(
        saved
            ? 'Resposta registrada neste aparelho.'
            : 'Não foi possível registrar a resposta.',
      );
    }
  }

  void _accessInfo() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Text(
          _access.verified
              ? 'Este ponto de chegada foi conferido no catálogo do MaraPass.'
              : 'O percurso leva à via mais próxima, e a entrada para a praia ainda precisa ser confirmada.',
        ),
      ),
    ),
  );

  void _navigate() {
    final plan = _plan;
    if (plan != null) {
      widget.onNavigate(plan, _target, _mode.profile);
      return;
    }
    final target = _target;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AccessOrientation(
          target: target,
          origin: _origin,
          maps: _googleMaps,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final map = ref.watch(mapStateProvider);
    final roads = ref.watch(repositoryProvider).roads;
    final saved = map.saved.contains(widget.beach.id);
    final nearby =
        {
              for (final place in map.places.where((p) => !p.isPartner))
                place.id: place,
              for (final partner in _partners) partner.id: partner,
            }.values
            .map((p) => (place: p, distance: p.point.distanceKm(_target)))
            .where(
              (p) =>
                  p.distance <= 1.5 &&
                  (p.place.category == PlaceCategory.gastronomy ||
                      p.place.hasCoupon),
            )
            .toList()
          ..sort((a, b) {
            final priority =
                (b.place.hasCoupon ? 1 : 0) - (a.place.hasCoupon ? 1 : 0);
            return priority == 0 ? a.distance.compareTo(b.distance) : priority;
          });
    final uniqueNearby = <({TourismPlace place, double distance})>[];
    for (final candidate in nearby) {
      final name = normalize(candidate.place.name);
      if (uniqueNearby.any(
        (existing) =>
            normalize(existing.place.name) == name &&
            existing.place.point.distanceKm(candidate.place.point) <= .08,
      )) {
        continue;
      }
      uniqueNearby.add(candidate);
      if (uniqueNearby.length == 4) break;
    }
    final plan = _plan;
    final position = _origin;
    final now = DateTime.now();
    final tide = _tides?.at(now);
    final sample = recentBathingResult(_access, now);
    final isSaoLuis = widget.beach.city == 'São Luís';
    return Scaffold(
      backgroundColor: const Color(0xfff4f7f9),
      appBar: AppBar(title: const Text('Planejar visita')),
      bottomNavigationBar: Material(
        color: Colors.white,
        elevation: 3,
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: FilledButton.icon(
            onPressed: _navigate,
            icon: Icon(
              plan == null ? Icons.explore_outlined : Icons.navigation_outlined,
            ),
            label: Text(
              plan == null ? 'Orientação até o acesso' : 'Iniciar navegação',
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              children: [
                Text(
                  widget.beach.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: MaraColors.navy,
                  ),
                ),
                Text(
                  widget.beach.city,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                _VisitMap(
                  origin: position,
                  target: _target,
                  route: plan?.route,
                  roads: roads,
                ),
                _VisitSection(
                  children: [
                    if (_status == _RouteStatus.loading) ...[
                      const LinearProgressIndicator(),
                      Text(
                        _locating
                            ? 'Buscando sua localização…'
                            : 'Calculando rota até o acesso…',
                      ),
                    ] else if (plan != null) ...[
                      _SectionTitle(
                        '${formatDistance(plan.route.distance)} · ${formatDuration(plan.route.duration)} ${_mode.description} até o acesso',
                      ),
                      const Text('Roteamento OSRM • dados do OpenStreetMap'),
                      if (plan.downloaded)
                        const Text('Offline · rota baixada neste aparelho'),
                      if (_mode == _VisitMode.ride)
                        const Text(
                          'Estimativa do trajeto, sem tarifa ou espera pelo carro.',
                        ),
                      if (_access.verified)
                        const Text(
                          'Distância do acesso até a areia · sem medição',
                        )
                      else if (_access.samplingPoint != null)
                        Text(
                          'Areia sem distância confirmada · ~${formatDistance(_target.distanceKm(_access.point) * 1000)} até o ponto de coleta da SEMA',
                        )
                      else if (!_access.verified)
                        Text(
                          'Distância até a areia sem confirmação · ~${formatDistance(_target.distanceKm(_access.point) * 1000)} até a referência da praia',
                        ),
                    ] else ...[
                      _SectionTitle(switch (_status) {
                        _RouteStatus.offline => 'Conexão indisponível',
                        _RouteStatus.noLocation => 'Localização indisponível',
                        _ => 'Rota indisponível para este acesso',
                      }),
                      if (position != null)
                        Text(
                          '${formatDistance(position.distanceKm(_target) * 1000)} em linha reta (aproximada) · ${compassDirection(visitBearing(position, _target))}',
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () =>
                              _load(refreshLocation: position == null),
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            position == null
                                ? 'Usar minha localização'
                                : 'Tentar novamente',
                          ),
                        ),
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _status == _RouteStatus.loading
                            ? null
                            : _chooseOrigin,
                        icon: const Icon(Icons.trip_origin),
                        label: Text(
                          position == null
                              ? 'Escolher origem'
                              : 'Alterar origem',
                        ),
                      ),
                    ),
                    Text(
                      'Como chegar',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final mode in _VisitMode.values)
                          ChoiceChip(
                            avatar: Icon(mode.icon, size: 18),
                            label: Text(
                              mode.label,
                              semanticsLabel: mode == _VisitMode.ride
                                  ? 'Transporte por app'
                                  : mode.label,
                            ),
                            selected: mode == _mode,
                            onSelected: _status == _RouteStatus.loading
                                ? null
                                : (_) => _selectMode(mode),
                          ),
                      ],
                    ),
                  ],
                ),
                _VisitSection(
                  children: [
                    const _SectionTitle('Ponto de chegada'),
                    if (_accesses.length == 1)
                      Text(_access.name)
                    else
                      RadioGroup<BeachAccess>(
                        groupValue: _access,
                        onChanged: (value) {
                          if (value == null || value == _access) return;
                          setState(() => _access = value);
                          unawaited(_load());
                        },
                        child: Column(
                          children: [
                            for (final access in _accesses)
                              RadioListTile<BeachAccess>(
                                contentPadding: EdgeInsets.zero,
                                value: access,
                                enabled: _status != _RouteStatus.loading,
                                title: Text(access.name),
                                subtitle: access == _accesses.first
                                    ? const Text(
                                        'Recomendado · rampa identificada pela SEMA',
                                      )
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ActionChip(
                        backgroundColor: _access.verified
                            ? const Color(0xffdef4e6)
                            : const Color(0xffffedc7),
                        avatar: Icon(
                          _access.verified
                              ? Icons.verified_outlined
                              : Icons.info_outline,
                          size: 18,
                        ),
                        label: Text(
                          _access.verified ? 'Verificado' : 'Não verificado',
                        ),
                        onPressed: _accessInfo,
                      ),
                    ),
                  ],
                ),
                _VisitSection(
                  children: [
                    const _SectionTitle('Condições do dia'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.waves, size: 18),
                          label: Text(
                            !isSaoLuis || tide == null
                                ? 'Maré · sem dados'
                                : 'Maré prevista · ~${tide.height.toStringAsFixed(1).replaceAll('.', ',')} m',
                          ),
                          onPressed: () => _open(Uri.parse(saoLuisTides)),
                        ),
                        if (isSaoLuis && tide != null)
                          Chip(
                            label: Text(
                              '${tide.next.high ? 'Próxima alta' : 'Próxima baixa'} • ${_tideLabel(tide.next)}',
                            ),
                          ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.water_drop_outlined,
                            size: 18,
                          ),
                          label: Text(
                            sample == null
                                ? 'Balneabilidade · sem dados recentes'
                                : 'Banho • $sample · ${_access.samplingPoint}',
                          ),
                          onPressed: () => _open(
                            Uri.parse(
                              sample == null ? semaReports : semaPontaAreia,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (tide != null)
                      const Text('Previsão CHM/REMO · estação São Luís'),
                    if (sample != null)
                      const Text(
                        'SEMA · coleta de 09/11/2026 · resultado do ponto indicado',
                      ),
                  ],
                ),
                _VisitSection(
                  children: [
                    const _SectionTitle('Onde comer e cupons por perto'),
                    if (nearby.isEmpty)
                      const Text(
                        'Sem restaurantes, barracas ou cupons listados perto deste acesso.',
                      ),
                    for (final candidate in uniqueNearby)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          candidate.place.hasCoupon
                              ? Icons.local_offer_outlined
                              : Icons.restaurant_outlined,
                        ),
                        title: Text(candidate.place.name),
                        subtitle: Text(
                          '${formatDistance(candidate.distance * 1000)} em linha reta${candidate.place.hasCoupon ? '\n${candidate.place.offerTitle}' : ''}',
                        ),
                        onTap: () => _open(
                          Uri.https('www.google.com', '/maps/search/', {
                            'api': '1',
                            'query':
                                '${candidate.place.point.lat},${candidate.place.point.lng}',
                          }),
                        ),
                      ),
                  ],
                ),
                _VisitSection(
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _open(_googleMaps),
                          child: const Text('Abrir no Google Maps'),
                        ),
                        if (_mode != _VisitMode.walk)
                          OutlinedButton(
                            onPressed: () => _open(_waze),
                            child: const Text('Abrir no Waze'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => ref
                              .read(mapStateProvider.notifier)
                              .toggleSave(widget.beach.id),
                          icon: Icon(
                            saved ? Icons.bookmark : Icons.bookmark_outline,
                          ),
                          label: Text(saved ? 'Salvo' : 'Salvar'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _share,
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Compartilhar'),
                        ),
                        if (plan != null && !plan.downloaded)
                          OutlinedButton.icon(
                            onPressed: _savingRoute ? null : _download,
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Baixar rota'),
                          ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _feedback,
                        child: const Text('Este acesso está correto?'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _tideLabel(TideEvent event) {
    final local = saoLuisLocalTime(event.time);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: local.hour, minute: local.minute),
      alwaysUse24HourFormat: true,
    );
    return '$time · ${event.height.toStringAsFixed(2).replaceAll('.', ',')} m';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w800, color: MaraColors.navy),
  );
}

class _VisitSection extends StatelessWidget {
  const _VisitSection({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: children,
        ),
      ),
    ),
  );
}

class _VisitMap extends StatelessWidget {
  const _VisitMap({
    required this.origin,
    required this.target,
    this.route,
    this.roads,
  });
  final GeoPoint? origin;
  final GeoPoint target;
  final RoadRoute? route;
  final ReferenceRoadNetwork? roads;

  LatLng _latLng(GeoPoint point) => LatLng(point.lat, point.lng);

  @override
  Widget build(BuildContext context) {
    final start = origin;
    final points =
        route?.points.map(_latLng).toList() ??
        [if (start != null) _latLng(start), _latLng(target)];
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 188,
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey((
                route,
                start?.lat,
                start?.lng,
                target.lat,
                target.lng,
              )),
              options: MapOptions(
                initialCenter: _latLng(target),
                initialZoom: 14,
                initialCameraFit: points.length < 2
                    ? null
                    : CameraFit.coordinates(
                        coordinates: [...points, _latLng(target)],
                        padding: const EdgeInsets.all(30),
                        maxZoom: 16,
                      ),
                backgroundColor: const Color(0xffcce6e7),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                if (roads != null) ReferenceRoadLayer(network: roads!),
                if (points.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        strokeWidth: route == null ? 3 : 5,
                        color: route == null
                            ? MaraColors.blue
                            : const Color(0xff008b93),
                        pattern: route == null
                            ? StrokePattern.dashed(segments: [6, 5])
                            : const StrokePattern.solid(),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (start != null)
                      Marker(
                        point: _latLng(start),
                        child: const Icon(
                          Icons.my_location,
                          color: MaraColors.blue,
                        ),
                      ),
                    Marker(
                      point: _latLng(target),
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xffa44238),
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Positioned(
              right: 6,
              bottom: 4,
              child: ColoredBox(
                color: Colors.white,
                child: Text(
                  ' © OpenStreetMap ',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessOrientation extends StatefulWidget {
  const _AccessOrientation({
    required this.target,
    required this.origin,
    required this.maps,
  });
  final GeoPoint target;
  final GeoPoint? origin;
  final Uri maps;

  @override
  State<_AccessOrientation> createState() => _AccessOrientationState();
}

class _AccessOrientationState extends State<_AccessOrientation> {
  final service = LocationService();
  late GeoPoint? position = widget.origin;
  bool busy = false;

  @override
  void dispose() {
    service.cancelPending();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => busy = true);
    try {
      final fix = await service.acquire(navigation: false);
      if (mounted) {
        setState(() => position = GeoPoint(fix.latitude, fix.longitude));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS indisponível no momento.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = position;
    final bearing = start == null ? null : visitBearing(start, widget.target);
    return Scaffold(
      appBar: AppBar(title: const Text('Orientação até o acesso')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (start != null && bearing != null) ...[
              const Center(child: Text('N')),
              Transform.rotate(
                angle: bearing * 0.017453292519943295,
                child: const Icon(
                  Icons.navigation,
                  size: 68,
                  color: MaraColors.blue,
                ),
              ),
              Center(
                child: Text(
                  '${compassDirection(bearing)} · ${bearing.round() % 360}°',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${formatDistance(start.distanceKm(widget.target) * 1000)} em linha reta (aproximada)',
                textAlign: TextAlign.center,
              ),
              const Text(
                'A seta indica a direção em relação ao norte. Siga pelas vias disponíveis.',
                textAlign: TextAlign.center,
              ),
            ] else
              const Text('Use o GPS para saber a direção até o acesso.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : _locate,
              icon: const Icon(Icons.gps_fixed),
              label: Text(
                busy ? 'Obtendo localização…' : 'Atualizar localização',
              ),
            ),
            OutlinedButton(
              onPressed: () =>
                  launchUrl(widget.maps, mode: LaunchMode.externalApplication),
              child: const Text('Abrir no Google Maps'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitOriginDialog extends StatefulWidget {
  const _VisitOriginDialog({required this.places});
  final List<TourismPlace> places;

  @override
  State<_VisitOriginDialog> createState() => _VisitOriginDialogState();
}

class _VisitOriginDialogState extends State<_VisitOriginDialog> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final term = normalize(query);
    final results = term.length < 2
        ? const <TourismPlace>[]
        : widget.places
              .where((place) => normalize(place.name).contains(term))
              .take(8)
              .toList();
    return AlertDialog(
      title: const Text('Escolher origem'),
      scrollable: true,
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome do local de partida',
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            for (final place in results)
              ListTile(
                title: Text(place.name),
                subtitle: Text(place.city),
                onTap: () => Navigator.pop(context, place),
              ),
            if (term.length >= 2 && results.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Nenhum local encontrado no catálogo.'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
