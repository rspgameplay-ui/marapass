import '../navigation/compass_service.dart';
import '../navigation/traveler_marker.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';

import '../data/routing_repository.dart';
import '../location/location_service.dart';
import '../location/gps_diagnostics.dart';
import '../domain/navigation.dart';
import '../domain/tourism.dart';

enum NavigationPhase { idle, calculating, preview, navigating, arrived }

final routingRepositoryProvider = Provider<RoutingRepository>((ref) {
  final repo = RoutingRepository();
  ref.onDispose(repo.client.close);
  return repo;
});
final navigationProvider =
    ChangeNotifierProvider.autoDispose<NavigationSession>(
      (ref) => NavigationSession(ref.watch(routingRepositoryProvider)),
    );

class NavigationSession extends ChangeNotifier {
  NavigationSession(
    this.repository, {
    LocationService? locationService,
    Stream<double> Function()? headingUpdates,
  }) : locationService = locationService ?? LocationService(),
       headingUpdates = headingUpdates ?? compassUpdates;
  final Stream<double> Function() headingUpdates;
  final LocationService locationService;
  LocationFailure? locationIssue;
  final RoutingRepository repository;
  NavigationPhase phase = NavigationPhase.idle;
  List<RoadRoute> routes = [];
  int selected = 0, stepIndex = 0;
  GeoPoint? origin, destination, location;
  double meters = 0, accuracy = double.infinity, speedKmh = 0, offRoad = 0;
  bool starting = false;
  bool gpsStable = false;
  int _watchEpoch = 0;
  bool get cameraReady => simulating || gpsStable;
  // Fica verdadeiro depois da primeira estabilização desta navegação e só é
  // limpo ao iniciar/encerrar a navegação. Perdas de sinal não o revertem:
  // a vista 3D permanece montada e a câmera continua na última posição.
  bool _cameraArmed = false;
  bool get cameraArmed => simulating || _cameraArmed;
  Timer? _positionTimer;
  Position? _pendingPosition;
  DateTime? _stableSince, _lastAcceptedAt, _stableTimestamp;
  int _stableFixes = 0;

  void _clearPositionQueue() {
    _positionTimer?.cancel();
    _positionTimer = null;
    _pendingPosition = null;
    gpsStable = false;
    _stableFixes = 0;
    _stableSince = _lastAcceptedAt = _stableTimestamp = null;
  }

  // At most two UI/projection updates per second; retain only the newest fix.
  void _queuePosition(Position p) {
    _pendingPosition = p;
    if (_positionTimer != null) return;
    final elapsed = _lastAcceptedAt == null
        ? const Duration(milliseconds: 500)
        : DateTime.now().difference(_lastAcceptedAt!);
    final delay = const Duration(milliseconds: 500) - elapsed;
    _positionTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      _positionTimer = null;
      final next = _pendingPosition;
      _pendingPosition = null;
      if (next == null || disposed || !active) return;
      _lastAcceptedAt = DateTime.now();
      if (usablePosition(next, maximumAccuracy: 50)) {
        if (_stableTimestamp == null ||
            next.timestamp.isAfter(_stableTimestamp!)) {
          _stableTimestamp = next.timestamp;
          _stableSince ??= DateTime.now();
          _stableFixes++;
        }
        if (!gpsStable &&
            _stableFixes >= 2 &&
            DateTime.now().difference(_stableSince!).inMilliseconds >= 1000) {
          gpsStable = true;
          _cameraArmed = true;
          gpsStage(GpsStage.cameraReady);
        }
      } else {
        _stableFixes = 0;
        _stableSince = _stableTimestamp = null;
      }
      ingest(
        GeoPoint(next.latitude, next.longitude),
        accuracyMeters: next.accuracy,
        timestamp: next.timestamp,
        speed: next.speed,
        course: next.heading,
      );
    });
  }

  bool simulating = false;
  bool mixedSimulation = false;
  double heading = 0;
  bool headingKnown = false;
  TravelMode get travelMode {
    if (simulating && mixedSimulation && route != null) {
      final progress = meters / route!.geometryLength;
      return progress >= .33 && progress < .66
          ? TravelMode.nautical
          : TravelMode.land;
    }
    return route != null &&
            route!.steps.isNotEmpty &&
            route!.steps[stepIndex].mode == 'ferry'
        ? TravelMode.nautical
        : TravelMode.land;
  }

  void setCompassHeading(double value) {
    if (!active || speedKmh >= 2.88 || !value.isFinite || value < 0) return;
    final delta = headingDelta(heading, value);
    if (headingKnown && delta.abs() < 3) return;
    heading = headingKnown
        ? normalizeHeading(heading + delta * .2)
        : normalizeHeading(value);
    headingKnown = true;
    notifyListeners();
  }

  Timer? _simulation;
  bool follow = true,
      voice = false,
      lowSignal = false,
      disposed = false,
      rerouting = false;
  String? message;
  DateTime? lastFix, lastReroute;
  int _generation = 0, _arrivalFixes = 0;
  DateTime? _previousDeviation;
  bool speaking = false;
  bool _assistantPrompt = false;
  String _spoken = '';
  bool _roadOnly = false;
  RoutingProfile _routingProfile = RoutingProfile.driving;
  bool _downloadedVisitRoute = false;

  void prepareVisitRoute(
    RoadRoute preview,
    GeoPoint from,
    GeoPoint to, {
    required RoutingProfile profile,
    required bool downloaded,
  }) {
    if (active || starting || disposed) return;
    resetPlan();
    routes = [preview];
    origin = from;
    destination = to;
    _routingProfile = profile;
    _roadOnly = profile == RoutingProfile.driving;
    _downloadedVisitRoute = downloaded;
    phase = NavigationPhase.preview;
    notifyListeners();
  }

  StreamSubscription<Position>? _gps;
  StreamSubscription<double>? _compass;
  Timer? _watchdog;
  FlutterTts? _tts;
  Future<void>? _voiceSetup;
  Future<void> _voiceQueue = Future.value();
  int _voiceRevision = 0;
  RoadRoute? get route => routes.isEmpty ? null : routes[selected];
  bool get active => phase == NavigationPhase.navigating;
  RoadStep? get nextStep => route == null
      ? null
      : route!.steps[(stepIndex + 1).clamp(0, route!.steps.length - 1)];
  bool get deviated => offRoad > math.max(32, accuracy * 1.5);
  double? get cameraBearing {
    if (lowSignal) return null;
    if (headingKnown && (simulating || speedKmh >= 2.88 || deviated)) {
      return heading;
    }
    return route?.bearingAt(meters) ?? (headingKnown ? heading : null);
  }

  double get nextDistance =>
      nextStep == null ? 0 : math.max(0, nextStep!.startMeters - meters);
  double get remainingMeters => route == null
      ? 0
      : math.max(0, route!.distance * (1 - meters / route!.geometryLength));
  double get remainingSeconds => route?.remainingDuration(meters) ?? 0;

  Future<bool> changeDestination(
    GeoPoint target, {
    required bool roadOnly,
  }) async {
    final current = location;
    final fix = lastFix;
    if (!active || current == null || rerouting) return false;
    if (!simulating &&
        (lowSignal ||
            fix == null ||
            DateTime.now().difference(fix).inSeconds.abs() > 15)) {
      return false;
    }
    final previousRoute = route;
    await calculate(current, target, recalculate: true, roadOnly: roadOnly);
    if (!active ||
        identical(route, previousRoute) ||
        !identical(destination, target)) {
      return false;
    }
    lastReroute = null;
    return true;
  }

  Future<void> calculate(
    GeoPoint from,
    GeoPoint to, {
    bool recalculate = false,
    bool? roadOnly,
    bool keepPreviewOnFailure = false,
  }) async {
    if (phase == NavigationPhase.calculating ||
        rerouting ||
        (recalculate && !active)) {
      return;
    }
    final generation = ++_generation;
    message = null;
    if (recalculate) {
      rerouting = true;
    } else {
      if (!keepPreviewOnFailure) {
        routes = [];
        selected = 0;
        meters = 0;
        stepIndex = 0;
      }
      phase = NavigationPhase.calculating;
    }
    notifyListeners();
    gpsStage(GpsStage.routeStart);
    try {
      final result = await repository.routes(
        from,
        to,
        profile: _routingProfile,
      );
      if (disposed || generation != _generation) {
        return;
      }
      final drivingOnly = roadOnly ?? _roadOnly;
      final usableRoutes = _routingProfile == RoutingProfile.walking
          ? result
                .where(
                  (route) =>
                      !route.hasFerry &&
                      route.steps.every((step) => step.mode == 'walking'),
                )
                .toList()
          : drivingOnly
          ? result
                .where(
                  (route) =>
                      route.steps.every((step) => step.mode == 'driving'),
                )
                .toList()
          : result;
      if (usableRoutes.isEmpty) {
        throw FormatException(
          drivingOnly
              ? 'Nenhuma rota só por terra encontrada. Tente outro ponto de partida.'
              : 'Não foi encontrada uma rota rodoviária.',
        );
      }
      _roadOnly = drivingOnly;
      routes = usableRoutes;
      _downloadedVisitRoute = false;
      gpsStage(GpsStage.routeReady);
      selected = 0;
      origin = from;
      destination = to;
      meters = 0;
      stepIndex = 0;
      _previousDeviation = null;
      _arrivalFixes = 0;
      _spoken = '';
      offRoad = 0;
      if (!recalculate) lastReroute = null;
      phase = recalculate
          ? NavigationPhase.navigating
          : NavigationPhase.preview;
      if (route!.originSnap > 75 || route!.destinationSnap > 75) {
        message =
            'A rota termina na via mapeada mais próxima. Confira o acesso final: ${formatDistance(route!.destinationSnap)} do ponto informado.';
      }
    } catch (error) {
      if (disposed || generation != _generation) {
        return;
      }
      message = error is FormatException
          ? error.message
          : 'Falha de conexão com o serviço de rotas. Tente novamente.';
      if (!recalculate) {
        phase = routes.isEmpty ? NavigationPhase.idle : NavigationPhase.preview;
      }
    } finally {
      if (!disposed && generation == _generation) {
        rerouting = false;
        notifyListeners();
      }
    }
  }

  void resetPlan({RoutingProfile profile = RoutingProfile.driving}) {
    if (active) {
      return;
    }
    ++_generation;
    locationService.cancelPending();
    locationIssue = null;
    routes = [];
    origin = destination = location = null;
    selected = stepIndex = 0;
    meters = 0;
    _roadOnly = false;
    _routingProfile = profile;
    _downloadedVisitRoute = false;
    phase = NavigationPhase.idle;
    message = null;
    notifyListeners();
  }

  void select(int index) {
    if (active || index < 0 || index >= routes.length) {
      return;
    }
    selected = index;
    meters = 0;
    stepIndex = 0;
    notifyListeners();
  }

  void setFollow(bool value) {
    follow = value;
    notifyListeners();
  }

  Future<Position> currentPosition({bool forNavigation = true}) =>
      locationService.acquire(navigation: forNavigation);

  Future<void> start() async {
    if (starting ||
        route == null ||
        active ||
        phase == NavigationPhase.calculating) {
      return;
    }
    starting = true;
    gpsStage(GpsStage.start);
    _clearPositionQueue();
    _previousDeviation = null;
    _cameraArmed = false;
    locationIssue = null;
    message = null;
    var generation = _generation;
    notifyListeners();
    try {
      final p = await currentPosition();
      if (disposed || generation != _generation) {
        return;
      }
      final actual = GeoPoint(p.latitude, p.longitude);
      gpsStage(GpsStage.initialFix);
      final onDownloadedRoute =
          _downloadedVisitRoute &&
          projectOnRoute(actual, route!).distanceToRoad <= 60;
      if (origin!.distanceKm(actual) > .10 && !onDownloadedRoute) {
        final expectedRevision = _generation + 1;
        final target = destination!;
        await calculate(actual, target, keepPreviewOnFailure: true);
        if (disposed ||
            _generation != expectedRevision ||
            phase != NavigationPhase.preview ||
            origin != actual ||
            destination != target) {
          return;
        }
      }
      generation = _generation;
      phase = NavigationPhase.navigating;
      gpsStage(GpsStage.navigationReady);
      follow = true;
      lastFix = null;
      ingest(
        actual,
        accuracyMeters: p.accuracy,
        timestamp: p.timestamp,
        speed: p.speed,
        course: p.heading,
      );
      await _gps?.cancel();
      if (disposed || generation != _generation || !active) {
        return;
      }
      await _compass?.cancel();
      if (disposed || generation != _generation || !active) return;
      _compass = headingUpdates().listen(
        setCompassHeading,
        onError: (Object _) {},
      );
      final watchGeneration = ++_watchEpoch;
      gpsStage(GpsStage.watchStart);
      var firstWatchFix = true;
      _gps = locationService.navigationUpdates().listen(
        (p) {
          if (disposed || watchGeneration != _watchEpoch || !active) return;
          if (firstWatchFix) {
            firstWatchFix = false;
            gpsStage(GpsStage.watchFix);
          }
          _queuePosition(p);
        },
        onError: (Object error) {
          if (!disposed && watchGeneration == _watchEpoch && active) {
            _clearPositionQueue();
            lowSignal = true;
            locationIssue = locationFailure(error);
            _recordFailure(locationIssue!);
            message = locationIssue!.message;
            if (locationIssue!.problem == LocationProblem.denied ||
                locationIssue!.problem == LocationProblem.disabled) {
              ++_generation;
              rerouting = false;
              _gps?.cancel();
              _compass?.cancel();
              _watchdog?.cancel();
              phase = NavigationPhase.preview;
            }
            notifyListeners();
          }
        },
        onDone: () {
          if (!disposed && watchGeneration == _watchEpoch && active) {
            ++_generation;
            rerouting = false;
            _clearPositionQueue();
            lowSignal = true;
            gpsStage(GpsStage.signalLost);
            locationIssue = locationFailure(StateError('stream ended'));
            message = locationIssue!.message;
            _compass?.cancel();
            _watchdog?.cancel();
            phase = NavigationPhase.preview;
            notifyListeners();
          }
        },
      );
      _watchdog?.cancel();
      _watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!disposed &&
            active &&
            lastFix != null &&
            DateTime.now().difference(lastFix!).inSeconds > 15) {
          lowSignal = true;
          _clearPositionQueue();
          gpsStage(GpsStage.signalLost);
          notifyListeners();
        }
      });
      notifyListeners();
    } catch (error) {
      if (!disposed && generation == _generation) {
        _clearPositionQueue();
        await _gps?.cancel();
        await _compass?.cancel();
        _watchdog?.cancel();
        if (disposed || generation != _generation) return;
        locationIssue = locationFailure(error);
        _recordFailure(locationIssue!);
        message = locationIssue!.message;
        if (phase == NavigationPhase.navigating) {
          phase = NavigationPhase.preview;
        }
        notifyListeners();
      }
    } finally {
      if (!disposed) {
        starting = false;
        notifyListeners();
      }
    }
  }

  void _recordFailure(LocationFailure failure) {
    gpsStage(switch (failure.problem) {
      LocationProblem.denied || LocationProblem.policy => GpsStage.denied,
      LocationProblem.timeout => GpsStage.timeout,
      LocationProblem.cancelled => GpsStage.cancelled,
      _ => GpsStage.unavailable,
    });
  }

  // Testável sem GPS físico: posições antigas ou imprecisas nunca avançam manobras.
  void ingest(
    GeoPoint p, {
    required double accuracyMeters,
    required DateTime timestamp,
    double speed = 0,
    double? course,
  }) {
    if (disposed || !active || simulating || route == null) {
      return;
    }
    if (accuracyMeters.isFinite &&
        accuracyMeters >= 0 &&
        DateTime.now().difference(timestamp).inSeconds.abs() <= 15) {
      accuracy = accuracyMeters;
    }
    if (!p.lat.isFinite ||
        !p.lng.isFinite ||
        p.lat.abs() > 90 ||
        p.lng.abs() > 180 ||
        !accuracyMeters.isFinite ||
        DateTime.now().difference(timestamp).inSeconds.abs() > 15 ||
        accuracyMeters > 50 ||
        accuracyMeters < 0 ||
        (lastFix != null &&
            timestamp.isBefore(
              lastFix!.subtract(const Duration(seconds: 1)),
            ))) {
      lowSignal = true;
      _previousDeviation = null;
      notifyListeners();
      return;
    }
    final gap = lastFix == null
        ? 1
        : DateTime.now().difference(lastFix!).inSeconds.clamp(1, 30);
    lastFix = timestamp;
    accuracy = accuracyMeters;
    location = p;
    if (speed >= .8 && course != null && course.isFinite && course >= 0) {
      heading = headingKnown
          ? normalizeHeading(heading + headingDelta(heading, course) * .35)
          : normalizeHeading(course);
      headingKnown = true;
    }
    speedKmh = speed.isFinite ? math.max(0, speed * 3.6) : 0;
    if (locationIssue != null) {
      locationIssue = null;
      message = null;
    }
    lowSignal = false;
    final projection = projectOnRoute(
      p,
      route!,
      minimum: math.max(0, meters - 75),
      maximum: meters + math.max(500, math.max(0, speed) * gap + 150),
    );
    offRoad = projection.distanceToRoad;
    if (deviated) {
      _arrivalFixes = 0;
      final previous = _previousDeviation;
      if (previous == null || timestamp.isAfter(previous)) {
        _previousDeviation = timestamp;
      }
      final target = destination;
      final now = DateTime.now();
      if (previous != null &&
          timestamp.isAfter(previous) &&
          timestamp.difference(previous) <= const Duration(seconds: 8) &&
          target != null &&
          travelMode == TravelMode.land &&
          !rerouting &&
          (lastReroute == null ||
              now.difference(lastReroute!) >= const Duration(seconds: 6))) {
        lastReroute = now;
        unawaited(calculate(p, target, recalculate: true));
      }
      notifyListeners();
      return;
    }
    _previousDeviation = null;
    if (!rerouting) {
      meters = math
          .max(meters, projection.meters)
          .clamp(0, route!.geometryLength);
      while (stepIndex + 1 < route!.steps.length &&
          route!.steps[stepIndex + 1].startMeters <= meters + 8) {
        stepIndex++;
      }
      final remainingGeometry = route!.geometryLength - meters;
      final roadEndDistance = p.distanceKm(route!.points.last) * 1000;
      if (remainingGeometry < 35 &&
          roadEndDistance < 35 &&
          accuracyMeters <= 30) {
        _arrivalFixes++;
      } else {
        _arrivalFixes = 0;
      }
      if (_arrivalFixes >= 2) {
        phase = NavigationPhase.arrived;
        ++_watchEpoch;
        _clearPositionQueue();
        _gps?.cancel();
        _compass?.cancel();
        _watchdog?.cancel();
        unawaited(
          _say('Você chegou ao fim da rota. Confira o acesso ao destino.'),
        );
      } else if (nextStep != null) {
        final bucket = nextDistance < 45
            ? 'now'
            : nextDistance < 250
            ? 'soon'
            : 'later';
        final token = '$stepIndex:$bucket';
        if (token != _spoken && bucket != 'later') {
          _spoken = token;
          unawaited(
            _say(
              '${bucket == 'soon' ? 'Em ${nextDistance.round()} metros, ' : ''}${nextStep!.instruction}',
            ),
          );
        }
      }
    }
    notifyListeners();
  }

  /// Bundled, deterministic fixture. No GPS/network and never used for guidance.
  Future<void> loadMixedSimulation({bool autoStart = true}) async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/data/simulation_route.json'),
    ) as Map<String, dynamic>;
    if (disposed || active) return;
    final full = RoadRoute.fromOsrm(data, 0);
    final points = <GeoPoint>[];
    for (var i = 0; i < full.points.length && full.cumulative[i] <= 1800; i++) {
      points.add(full.points[i]);
    }
    final steps = full.steps.where((s) => s.startMeters < 1800).toList();
    final demo = RoadRoute(
      points: points,
      steps: steps,
      distance: 0,
      duration: 180,
      summary: 'Demonstração de marcadores',
      originSnap: 0,
      destinationSnap: 0,
    );
    routes = [
      RoadRoute(
        points: points,
        steps: steps,
        distance: demo.geometryLength,
        duration: 180,
        summary: demo.summary,
        originSnap: 0,
        destinationSnap: 0,
      ),
    ];
    selected = 0;
    origin = route!.points.first;
    destination = route!.points.last;
    phase = NavigationPhase.preview;
    if (autoStart) {
      startSimulation(mixed: true);
    }
  }

  void startSimulation({bool mixed = false}) {
    mixedSimulation =
        mixed || Uri.base.queryParameters["simulation"] == "mixed";
    if (route == null || active || disposed || starting) return;
    locationIssue = null;
    message = null;
    simulating = true;
    phase = NavigationPhase.navigating;
    follow = true;
    meters = 0;
    stepIndex = 0;
    offRoad = 0;
    lowSignal = false;
    location = route!.points.first;
    _simulation?.cancel();
    _simulation = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (disposed || !active || !simulating || rerouting) return;
      final r = route!;
      meters = math.min(
        r.geometryLength,
        meters + math.max(20, r.geometryLength / (mixedSimulation ? 60 : 180)),
      );
      var i = 1;
      while (i < r.cumulative.length - 1 && r.cumulative[i] < meters) {
        i++;
      }
      final a = r.points[i - 1], b = r.points[i];
      final length = r.cumulative[i] - r.cumulative[i - 1];
      final t = length == 0
          ? 1.0
          : ((meters - r.cumulative[i - 1]) / length).clamp(0.0, 1.0);
      final dy = b.lat - a.lat,
          dx = (b.lng - a.lng) * math.cos(a.lat * math.pi / 180);
      if (dx != 0 || dy != 0) {
        heading = (math.atan2(dx, dy) * 180 / math.pi + 360) % 360;
      }
      headingKnown = true;
      accuracy = 12;
      location = GeoPoint(
        a.lat + (b.lat - a.lat) * t,
        a.lng + (b.lng - a.lng) * t,
      );
      while (stepIndex + 1 < r.steps.length &&
          r.steps[stepIndex + 1].startMeters <= meters + 8) {
        stepIndex++;
      }
      if (meters >= r.geometryLength) {
        _simulation?.cancel();
        simulating = false;
        location = null;
        phase = NavigationPhase.arrived;
        message =
            'Simulação concluída. Nenhum deslocamento real foi registrado.';
      }
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> setVoice(bool value) async {
    if (voice == value || disposed) return;
    voice = value;
    notifyListeners();
    if (!value) {
      await _stopVoice();
    } else {
      await _say(
        active
            ? 'Orientação por voz ativada.'
            : 'Prévia da navegação. Em duzentos metros, vire à direita.',
      );
    }
  }

  Future<void> _configureVoice(FlutterTts tts) async {
    await tts.setLanguage('pt-BR');
    // Web Speech uses 1.0 for normal speech. The mobile plugin uses 0.5.
    await tts.setSpeechRate(kIsWeb ? 1.15 : .56);
    try {
      final voices = await tts.getVoices;
      if (voices is! List) return;
      Map<String, String>? preferred;
      var bestScore = 0;
      for (final candidate in voices.whereType<Map>()) {
        final name = candidate['name'];
        final locale = candidate['locale'];
        if (name is! String ||
            locale is! String ||
            locale.toLowerCase().replaceAll('_', '-') != 'pt-br') {
          continue;
        }
        final quality =
            '${candidate['quality'] ?? ''} ${candidate['identifier'] ?? ''} $name'
                .toLowerCase();
        final score = quality.contains('premium')
            ? 3
            : quality.contains('enhanced') || quality.contains('aprimorada')
            ? 2
            : 0;
        if (score <= bestScore) continue;
        bestScore = score;
        final identifier = candidate['identifier'];
        preferred = {
          'name': name,
          'locale': locale,
          if (identifier is String) 'identifier': identifier,
        };
      }
      if (preferred != null) await tts.setVoice(preferred);
    } catch (_) {
      // Voice enumeration and selection are optional on some engines.
    }
  }

  Future<void> speakAssistant(String text) async {
    _assistantPrompt = true;
    try {
      await _say(text, assistant: true);
    } finally {
      _assistantPrompt = false;
    }
  }

  Future<void> _say(String text, {bool assistant = false}) {
    if ((!assistant && (!voice || _assistantPrompt)) || disposed) {
      return Future.value();
    }
    final revision = ++_voiceRevision;
    return _voiceQueue = _voiceQueue.then((_) async {
      if ((!voice && !assistant) || disposed || revision != _voiceRevision) {
        return;
      }
      try {
        final tts = _tts ??= FlutterTts();
        await (_voiceSetup ??= _configureVoice(tts));
        if ((!voice && !assistant) || disposed || revision != _voiceRevision) {
          return;
        }
        await tts.stop();
        if ((!voice && !assistant) || disposed || revision != _voiceRevision) {
          return;
        }
        await tts.awaitSpeakCompletion(true);
        if (disposed || revision != _voiceRevision) return;
        speaking = true;
        if (await tts.speak(text).timeout(const Duration(seconds: 12)) == 0) {
          throw StateError('O sintetizador não iniciou a fala.');
        }
      } catch (_) {
        _voiceSetup = null;
        if (disposed || revision != _voiceRevision) return;
        if (assistant) return;
        voice = false;
        message =
            'Voz indisponível neste aparelho. As instruções continuam na tela.';
        notifyListeners();
      } finally {
        speaking = false;
      }
    });
  }

  Future<void> _stopVoice() async {
    ++_voiceRevision;
    try {
      await _tts?.stop();
    } catch (_) {
      // Navigation continues when the speech engine has stopped responding.
    }
  }

  Future<void> pause() async {
    ++_generation;
    ++_watchEpoch;
    _clearPositionQueue();
    _cameraArmed = false;
    gpsStage(GpsStage.stopped);
    final stoppingVoice = _stopVoice();
    locationService.cancelPending();
    _simulation?.cancel();
    if (simulating) location = null;
    simulating = false;
    final gps = _gps;
    final compass = _compass;
    _gps = null;
    _compass = null;
    _watchdog?.cancel();
    _watchdog = null;
    if (!disposed) {
      phase = route == null ? NavigationPhase.idle : NavigationPhase.preview;
      rerouting = false;
      notifyListeners();
    }
    await Future.wait<void>([
      if (gps != null) gps.cancel(),
      if (compass != null) compass.cancel(),
      stoppingVoice,
    ]);
  }

  @override
  void dispose() {
    disposed = true;
    ++_watchEpoch;
    _clearPositionQueue();
    locationService.cancelPending();
    _simulation?.cancel();
    ++_generation;
    _gps?.cancel();
    _compass?.cancel();
    _watchdog?.cancel();
    unawaited(_stopVoice());
    super.dispose();
  }
}
