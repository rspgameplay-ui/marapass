import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../application/navigation_session.dart';
import '../../core/config.dart';
import '../../data/routing_repository.dart';
import '../../domain/navigation.dart';
import '../../domain/tourism.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'scan.dart';

/// Navegação passo a passo no visual do MaraPass: mapa claro com a rota em
/// destaque, manobra em cartão azul no topo e painel inferior com tempo,
/// distância e chegada. Reaproveita o motor de navegação do app (GPS,
/// simulação, voz e recálculo quando sai da rota).
class RouteNavScreen extends ConsumerStatefulWidget {
  const RouteNavScreen({
    super.key,
    required this.destinationName,
    required this.destination,
    required this.origin,
    required this.route,
    this.originLabel = '',
  });
  final String destinationName;
  final GeoPoint destination, origin;
  final RoadRoute route;
  final String originLabel;

  @override
  ConsumerState<RouteNavScreen> createState() => _RouteNavScreenState();
}

class _RouteNavScreenState extends ConsumerState<RouteNavScreen> {
  MapLibreMapController? _c;
  bool _ready = false;
  late final NavigationSession _s;
  RoadRoute? _drawn;
  GeoPoint? _lastCam;
  DateTime _lastCamAt = DateTime(2000);

  @override
  void initState() {
    super.initState();
    // Sessão própria desta tela: vive enquanto a navegação estiver aberta.
    _s = NavigationSession(ref.read(routingRepositoryProvider));
    _s.prepareVisitRoute(
      widget.route,
      widget.origin,
      widget.destination,
      profile: RoutingProfile.driving,
      downloaded: false,
    );
    _s.addListener(_sync);
  }

  @override
  void dispose() {
    _s.removeListener(_sync);
    _s.dispose();
    super.dispose();
  }

  Future<void> _onStyle() async {
    final c = _c;
    if (c == null) return;
    await c.addSource('nav-route', GeojsonSourceProperties(data: _line(const [])));
    await c.addLineLayer(
      'nav-route',
      'nav-route-casing',
      const LineLayerProperties(lineColor: '#0b57d0', lineWidth: 13, lineCap: 'round', lineJoin: 'round'),
    );
    await c.addLineLayer(
      'nav-route',
      'nav-route-line',
      const LineLayerProperties(lineColor: '#4c8df6', lineWidth: 8, lineCap: 'round', lineJoin: 'round'),
    );
    await c.addSource('nav-done', GeojsonSourceProperties(data: _line(const [])));
    await c.addLineLayer(
      'nav-done',
      'nav-done-line',
      const LineLayerProperties(lineColor: '#9aa7b4', lineWidth: 8, lineCap: 'round', lineJoin: 'round'),
    );
    await c.addSource('nav-dest', GeojsonSourceProperties(data: _pt(widget.destination)));
    await c.addCircleLayer(
      'nav-dest',
      'nav-dest-halo',
      const CircleLayerProperties(circleColor: '#c53b36', circleOpacity: .18, circleRadius: 20),
    );
    await c.addCircleLayer(
      'nav-dest',
      'nav-dest-dot',
      const CircleLayerProperties(circleColor: '#c53b36', circleRadius: 9, circleStrokeColor: '#ffffff', circleStrokeWidth: 3),
    );
    await c.addSource('nav-me', GeojsonSourceProperties(data: _pt(widget.origin)));
    await c.addCircleLayer(
      'nav-me',
      'nav-me-halo',
      const CircleLayerProperties(circleColor: '#1a73e8', circleOpacity: .2, circleRadius: 22),
    );
    await c.addCircleLayer(
      'nav-me',
      'nav-me-dot',
      const CircleLayerProperties(circleColor: '#1a73e8', circleRadius: 10, circleStrokeColor: '#ffffff', circleStrokeWidth: 4),
    );
    if (mounted) setState(() => _ready = true);
    await _sync(force: true);
    await _overview();
  }

  Future<void> _sync({bool force = false}) async {
    if (!mounted) return;
    setState(() {});
    final c = _c;
    final r = _s.route;
    if (c == null || !_ready || r == null) return;
    if (force || !identical(r, _drawn)) {
      _drawn = r;
      await c.setGeoJsonSource('nav-route', _line(r.points));
    }
    final me = _s.location;
    if (me != null) {
      await c.setGeoJsonSource('nav-me', _pt(me));
      await c.setGeoJsonSource('nav-done', _line(_donePart(r, _s.meters)));
    }
    if (_s.active && _s.follow && me != null) {
      final now = DateTime.now();
      if (_lastCam == null || now.difference(_lastCamAt).inMilliseconds > 600 || force) {
        _lastCam = me;
        _lastCamAt = now;
        await c.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(me.lat, me.lng),
              zoom: 17,
              tilt: 58,
              bearing: _s.cameraBearing ?? 0,
            ),
          ),
          duration: const Duration(milliseconds: 750),
        );
      }
    }
  }

  List<GeoPoint> _donePart(RoadRoute r, double meters) {
    final out = <GeoPoint>[];
    for (var i = 0; i < r.points.length && r.cumulative[i] <= meters; i++) {
      out.add(r.points[i]);
    }
    if (_s.location != null && out.isNotEmpty) out.add(_s.location!);
    return out;
  }

  Future<void> _overview() async {
    final r = _s.route;
    if (r == null) return;
    _s.setFollow(false);
    final lats = r.points.map((e) => e.lat), lngs = r.points.map((e) => e.lng);
    await _c?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
          northeast: LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
        ),
        left: 56,
        right: 56,
        top: 200,
        bottom: 300,
      ),
      duration: const Duration(milliseconds: 800),
    );
  }

  void _recenter() {
    _s.setFollow(true);
    _sync(force: true);
  }

  Future<void> _startGps() async {
    await _s.start();
    if (!mounted) return;
    if (!_s.active && _s.locationIssue != null) {
      showMpSnack(context, 'Não conseguimos sua localização. Você pode simular o percurso.');
    } else if (_s.active) {
      _s.setFollow(true);
    }
  }

  void _simulate() {
    _s.startSimulation();
    _s.setFollow(true);
  }

  Future<void> _end() async {
    await _s.pause();
    if (mounted) Navigator.of(context).maybePop();
  }

  void _steps() {
    final r = _s.route;
    if (r == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .75),
        child: ListView(
          key: const Key('nav-steps'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s6),
          children: [
            Text('Passo a passo', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: MP.s1),
            Text('${formatDistance(r.distance)} · ${formatDuration(r.duration)}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: MP.s3),
            for (var i = 0; i < r.steps.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: 56,
                selected: _s.active && i == _s.stepIndex + 1,
                selectedTileColor: MP.infoBg,
                leading: CircleAvatar(
                  backgroundColor: MP.soft,
                  child: Icon(maneuverIcon(r.steps[i]), color: MP.navy),
                ),
                title: Text(r.steps[i].instruction, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                trailing: Text(formatDistance(r.steps[i].distance), style: const TextStyle(color: MP.textSecondary)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final r = s.route;
    final pad = MediaQuery.paddingOf(context);
    final navigating = s.active;
    final arrived = s.phase == NavigationPhase.arrived;
    return Scaffold(
      backgroundColor: MP.soft,
      body: Stack(
        children: [
          MapLibreMap(
            styleString: AppConfig.onlineStyle,
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.origin.lat, widget.origin.lng),
              zoom: 13,
            ),
            onMapCreated: (c) => _c = c,
            onStyleLoadedCallback: _onStyle,
            compassEnabled: false,
            trackCameraPosition: true,
            attributionButtonPosition: AttributionButtonPosition.bottomRight,
          ),
          // Topo: manobra (navegando) ou destino (prévia)
          Positioned(
            left: MP.s3,
            right: MP.s3,
            top: pad.top + MP.s3,
            child: navigating && r != null
                ? _ManeuverCard(session: s)
                : _PreviewHeader(
                    title: widget.destinationName,
                    origin: widget.originLabel,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
          ),
          // Controles flutuantes
          if (_ready)
            Positioned(
              right: MP.s3,
              bottom: (navigating ? 196 : 250) + pad.bottom,
              child: Column(
                children: [
                  if (navigating) ...[
                    _RoundButton(
                      key: const Key('nav-voice'),
                      icon: s.voice ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      tooltip: s.voice ? 'Desligar voz' : 'Ligar voz',
                      active: s.voice,
                      onTap: () => s.setVoice(!s.voice),
                    ),
                    const SizedBox(height: MP.s2),
                  ],
                  _RoundButton(
                    key: const Key('nav-overview'),
                    icon: Icons.alt_route_rounded,
                    tooltip: 'Ver a rota inteira',
                    onTap: _overview,
                  ),
                  if (navigating && !s.follow) ...[
                    const SizedBox(height: MP.s2),
                    _RoundButton(
                      key: const Key('nav-recenter'),
                      icon: Icons.navigation_rounded,
                      tooltip: 'Voltar a seguir',
                      active: true,
                      onTap: _recenter,
                    ),
                  ],
                ],
              ),
            ),
          Positioned(
            left: MP.s3,
            bottom: (navigating ? 180 : 234) + pad.bottom,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xd9ffffff), borderRadius: BorderRadius.all(Radius.circular(4))),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text('© OpenStreetMap · OpenFreeMap', style: TextStyle(fontSize: 11, color: MP.textSecondary)),
                ),
              ),
            ),
          ),
          if (!_ready) const Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Color(0x88ffffff), child: MpLoading()))),
          // Painel inferior
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPanel(
              session: s,
              arrived: arrived,
              destinationName: widget.destinationName,
              onStartGps: _startGps,
              onSimulate: _simulate,
              onSteps: _steps,
              onEnd: _end,
              onCheckin: () => push<void>(context, const ScanScreen()),
            ),
          ),
        ],
      ),
    );
  }

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

  static Map<String, dynamic> _pt(GeoPoint p) => {
    'type': 'FeatureCollection',
    'features': [
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
}

/// Ícone da manobra a partir do tipo e da direção do OSRM.
IconData maneuverIcon(RoadStep s) {
  if (s.mode == 'ferry') return Icons.directions_boat_rounded;
  if (s.type == 'arrive') return Icons.sports_score_rounded;
  if (s.type == 'roundabout' || s.type == 'rotary' || s.type.startsWith('exit ')) {
    return Icons.roundabout_right_rounded;
  }
  return switch (s.modifier) {
    'left' => Icons.turn_left_rounded,
    'right' => Icons.turn_right_rounded,
    'slight left' => Icons.turn_slight_left_rounded,
    'slight right' => Icons.turn_slight_right_rounded,
    'sharp left' => Icons.turn_sharp_left_rounded,
    'sharp right' => Icons.turn_sharp_right_rounded,
    'uturn' => Icons.u_turn_left_rounded,
    _ => s.type == 'merge' ? Icons.merge_rounded : Icons.straight_rounded,
  };
}

String _eta(double seconds) {
  final t = DateTime.now().add(Duration(seconds: seconds.round()));
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _ManeuverCard extends StatelessWidget {
  const _ManeuverCard({required this.session});
  final NavigationSession session;
  @override
  Widget build(BuildContext context) {
    final r = session.route!;
    final next = session.nextStep ?? r.steps.last;
    final i = r.steps.indexOf(next);
    final after = i >= 0 && i + 1 < r.steps.length ? r.steps[i + 1] : null;
    return Column(
      key: const Key('nav-maneuver'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: MP.navy,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(MP.rXl),
              bottom: Radius.circular(after == null ? MP.rXl : 0),
            ),
            boxShadow: MP.shadowFloat,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(MP.s4, MP.s4, MP.s4, MP.s4),
            child: Row(
              children: [
                Icon(maneuverIcon(next), color: Colors.white, size: 52),
                const SizedBox(width: MP.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatDistance(session.nextDistance),
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        next.instruction,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, height: 1.25),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (after != null)
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xff082c4e),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(MP.rXl)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.s4, vertical: MP.s2),
              child: Row(
                children: [
                  const Text('Depois', style: TextStyle(color: Color(0xffb9c8d8), fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(width: MP.s2),
                  Icon(maneuverIcon(after), color: Colors.white, size: 22),
                  const SizedBox(width: MP.s2),
                  Expanded(
                    child: Text(
                      after.instruction,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (session.rerouting || session.deviated && !session.simulating) ...[
          const SizedBox(height: MP.s2),
          const MpNotice('Recalculando a rota…', icon: Icons.sync_rounded, fg: MP.warning, bg: MP.warningBg),
        ],
      ],
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.title, required this.origin, required this.onBack});
  final String title, origin;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Material(
    color: MP.card,
    elevation: 3,
    shadowColor: Colors.black26,
    borderRadius: BorderRadius.circular(MP.rLarge),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(MP.s1, MP.s2, MP.s4, MP.s2),
      child: Row(
        children: [
          IconButton(
            key: const Key('nav-back'),
            tooltip: 'Voltar ao mapa',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: MP.s1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  origin.isEmpty ? 'Rota até' : 'De $origin',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: MP.textSecondary),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Icon(Icons.place_rounded, color: MP.error),
        ],
      ),
    ),
  );
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.session,
    required this.arrived,
    required this.destinationName,
    required this.onStartGps,
    required this.onSimulate,
    required this.onSteps,
    required this.onEnd,
    required this.onCheckin,
  });
  final NavigationSession session;
  final bool arrived;
  final String destinationName;
  final VoidCallback onStartGps, onSimulate, onSteps, onEnd, onCheckin;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final r = s.route;
    final pad = MediaQuery.paddingOf(context).bottom;
    final remainingS = s.active ? s.remainingSeconds : (r?.duration ?? 0);
    final remainingM = s.active ? s.remainingMeters : (r?.distance ?? 0);
    return Container(
      key: const Key('nav-panel'),
      decoration: const BoxDecoration(
        color: MP.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(MP.rXl)),
        boxShadow: [BoxShadow(color: Color(0x2613263d), blurRadius: 24, offset: Offset(0, -4))],
      ),
      padding: EdgeInsets.fromLTRB(MP.pageH, MP.s3, MP.pageH, MP.s4 + pad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: MP.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: MP.s3),
          if (arrived) ...[
            Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: MP.greenBg,
                  child: Icon(Icons.sports_score_rounded, color: MP.green, size: 28),
                ),
                const SizedBox(width: MP.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Você chegou!', style: Theme.of(context).textTheme.titleLarge),
                      Text(destinationName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: MP.textSecondary, fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
            if (s.message != null) ...[
              const SizedBox(height: MP.s3),
              MpNotice(s.message!, icon: Icons.info_outline_rounded, fg: MP.info, bg: MP.infoBg),
            ],
            const SizedBox(height: MP.s4),
            MpPrimaryButton(
              key: const Key('nav-checkin'),
              label: 'Registrar visita no Passaporte',
              icon: Icons.verified_rounded,
              onPressed: onCheckin,
            ),
            const SizedBox(height: MP.s2),
            TextButton(onPressed: onEnd, child: const Text('Voltar ao mapa')),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatDuration(remainingS),
                        key: const Key('nav-time'),
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: MP.green, height: 1.1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatDistance(remainingM)} · chegada às ${_eta(remainingS)}',
                        style: const TextStyle(fontSize: 16, color: MP.text, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  key: const Key('nav-steps-btn'),
                  tooltip: 'Passo a passo',
                  onPressed: onSteps,
                  style: IconButton.styleFrom(minimumSize: const Size(52, 52), backgroundColor: MP.soft),
                  icon: const Icon(Icons.format_list_bulleted_rounded, color: MP.navy),
                ),
              ],
            ),
            if (!s.active && r != null && r.summary.isNotEmpty) ...[
              const SizedBox(height: MP.s1),
              Text('via ${r.summary}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: MP.textSecondary, fontSize: 14)),
            ],
            if (s.message != null && !s.active) ...[
              const SizedBox(height: MP.s3),
              MpNotice(s.message!, icon: Icons.info_outline_rounded, fg: MP.warning, bg: MP.warningBg),
            ],
            const SizedBox(height: MP.s4),
            if (s.active)
              OutlinedButton.icon(
                key: const Key('nav-end'),
                onPressed: onEnd,
                style: OutlinedButton.styleFrom(
                  foregroundColor: MP.error,
                  side: const BorderSide(color: MP.error, width: 1.5),
                  minimumSize: const Size.fromHeight(MP.buttonHeight),
                ),
                icon: const Icon(Icons.close_rounded),
                label: Text(s.simulating ? 'Encerrar simulação' : 'Encerrar navegação'),
              )
            else ...[
              MpPrimaryButton(
                key: const Key('nav-start'),
                label: 'Iniciar navegação',
                icon: Icons.navigation_rounded,
                busy: s.starting || s.phase == NavigationPhase.calculating,
                onPressed: onStartGps,
              ),
              const SizedBox(height: MP.s1),
              TextButton.icon(
                key: const Key('nav-simulate'),
                onPressed: onSimulate,
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('Simular percurso sem GPS'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.tooltip, required this.onTap, this.active = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: active ? MP.navy : MP.card,
      shape: CircleBorder(side: BorderSide(color: active ? MP.navy : MP.border)),
      elevation: 4,
      shadowColor: Colors.black38,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: active ? Colors.white : MP.ink, semanticLabel: tooltip),
        ),
      ),
    ),
  );
}
