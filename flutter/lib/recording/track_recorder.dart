import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/tourism.dart';
import '../location/location_service.dart';

class RecordedTrack {
  RecordedTrack({
    required this.id,
    required this.started,
    this.name = '',
    this.mode = 'Caminhada',
    this.seconds = 0,
    List<List<GeoPoint>>? segments,
  }) : segments = segments ?? [];
  final String id;
  final DateTime started;
  String name, mode;
  int seconds;
  final List<List<GeoPoint>> segments;
  Iterable<GeoPoint> get points => segments.expand((s) => s);
  double get kilometers {
    var sum = 0.0;
    for (final segment in segments) {
      for (var i = 1; i < segment.length; i++) {
        sum += segment[i - 1].distanceKm(segment[i]);
      }
    }
    return sum;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'started': started.toIso8601String(),
    'name': name,
    'mode': mode,
    'seconds': seconds,
    'segments': [
      for (final segment in segments)
        [
          for (final p in segment) [p.lat, p.lng],
        ],
    ],
  };
  factory RecordedTrack.fromJson(Map<String, dynamic> json) => RecordedTrack(
    id: json['id'] as String,
    started: DateTime.parse(json['started'] as String),
    name: json['name'] as String,
    mode: json['mode'] as String,
    seconds: json['seconds'] as int,
    segments: [
      for (final segment in json['segments'] as List)
        [
          for (final p in segment as List)
            GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
    ],
  );
}

class TrackRecorder extends ChangeNotifier {
  TrackRecorder(this.preferences, {LocationService? location})
    : location = location ?? LocationService() {
    final raw = preferences.getString(storageKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      saved.addAll(
        (data['saved'] as List).map(
          (p) => RecordedTrack.fromJson(Map<String, dynamic>.from(p as Map)),
        ),
      );
      if (data['draft'] != null) {
        draft = RecordedTrack.fromJson(
          Map<String, dynamic>.from(data['draft'] as Map),
        );
        _baseSeconds = draft!.seconds;
        message =
            'Percurso recuperado em pausa. Confira o GPS antes de continuar.';
      }
    } catch (_) {
      damaged = true;
      message = 'Não foi possível ler os percursos deste aparelho. O conteúdo armazenado foi preservado.';
    }
  }

  static const storageKey = 'marapass_recorded_tracks_v1';
  final SharedPreferences preferences;
  final LocationService location;
  final saved = <RecordedTrack>[];
  RecordedTrack? draft;
  GeoPoint? position;
  double? accuracy;
  bool active = false, busy = false, damaged = false, _disposed = false;
  String? message;
  int _generation = 0, _baseSeconds = 0;
  DateTime? _lastSample, _lastSeen;
  Stopwatch _clock = Stopwatch();
  StreamSubscription<Position>? _subscription;
  Timer? _timer;
  Future<void> _writes = Future.value();

  int get seconds => _baseSeconds + _clock.elapsed.inSeconds;
  bool get canSave => draft?.segments.any((s) => s.length > 1) ?? false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _persist() {
    draft?.seconds = seconds;
    final encoded = jsonEncode({
      'draft': draft?.toJson(),
      'saved': saved.map((p) => p.toJson()).toList(),
    });
    final operation = _writes.then((_) async {
      if (!await preferences.setString(storageKey, encoded)) {
        throw StateError('storage');
      }
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> start({String mode = 'Caminhada'}) async {
    if (active || busy || damaged) return;
    busy = true;
    message = null;
    final token = ++_generation;
    _notify();
    try {
      final fix = await location.acquire(navigation: true);
      if (_disposed || token != _generation) return;
      draft ??= RecordedTrack(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        started: DateTime.now(),
        mode: mode,
      );
      _baseSeconds = draft!.seconds;
      _clock = Stopwatch()..start();
      draft!.segments.add([]);
      active = true;
      _lastSample = null;
      _lastSeen = DateTime.now();
      _accept(fix);
      await _persist();
      if (_disposed || token != _generation) return;
      _subscription = location.updates().listen(
        _accept,
        onError: (Object error) =>
            pause(reason: locationFailure(error).message),
        onDone: () =>
            pause(reason: 'O GPS foi interrompido. Percurso em pausa.'),
      );
      _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (!active) return;
        if (DateTime.now().difference(_lastSeen!).inSeconds > 40) {
          await pause(
            reason: 'Sem atualização do GPS. Retome em local aberto.',
          );
          return;
        }
        await _checkpoint();
      });
    } catch (error) {
      if (token == _generation && !_disposed) {
        await pause(
          reason: error is LocationFailure ? error.message : 'Não foi possível salvar no aparelho. Mantenha a tela aberta e tente novamente.',
        );
      }
    } finally {
      if (token == _generation) busy = false;
      _notify();
    }
  }

  void _accept(Position fix) {
    if (!active || !usablePosition(fix, maximumAccuracy: 50)) return;
    _lastSeen = DateTime.now();
    if (_lastSample != null && !fix.timestamp.isAfter(_lastSample!)) return;
    final p = GeoPoint(fix.latitude, fix.longitude);
    final segment = draft!.segments.last;
    if (segment.isNotEmpty) {
      final meters = segment.last.distanceKm(p) * 1000;
      final elapsed =
          fix.timestamp.difference(_lastSample!).inMilliseconds / 1000;
      final maxSpeed = draft!.mode == 'Passeio'
          ? 60.0
          : draft!.mode == 'Bicicleta'
          ? 30.0
          : 12.0;
      if (elapsed < 1 || meters / elapsed > maxSpeed) return;
      if (meters < math.max(5, fix.accuracy)) {
        accuracy = fix.accuracy;
        _notify();
        return;
      }
    }
    if (draft!.points.length >= 20000) {
      unawaited(
        pause(
          reason: 'Limite deste percurso atingido. Salve e inicie um novo.',
        ),
      );
      return;
    }
    if (_lastSample != null &&
        fix.timestamp.difference(_lastSample!).inSeconds > 30) {
      draft!.segments.add([]);
    }
    draft!.segments.last.add(p);
    _lastSample = fix.timestamp;
    position = p;
    accuracy = fix.accuracy;
    unawaited(_checkpoint());
    _notify();
  }

  Future<void> _checkpoint() async {
    try {
      await _persist();
    } catch (_) {
      await pause(reason: 'Armazenamento indisponível. Percurso em pausa.');
    }
    _notify();
  }

  Future<void> pause({String? reason}) async {
    ++_generation;
    busy = false;
    active = false;
    _clock.stop();
    _baseSeconds = seconds;
    _clock.reset();
    location.cancelPending();
    _timer?.cancel();
    _timer = null;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    if (reason != null) message = reason;
    if (draft != null && !damaged) {
      try {
        await _persist();
      } catch (_) {
        message = 'Não foi possível gravar no aparelho. Mantenha esta tela aberta e tente salvar novamente.';
      }
    }
    _notify();
  }

  Future<bool> save(String name) async {
    if (busy || active || !canSave || damaged) return false;
    busy = true;
    _notify();
    final track = draft!;
    track.name = name.trim().isEmpty ? 'Meu percurso' : name.trim();
    draft = null;
    saved.insert(0, track);
    try {
      await _persist();
      _baseSeconds = 0;
      _clock.reset();
      message = 'Percurso salvo neste navegador/aparelho.';
      return true;
    } catch (_) {
      saved.remove(track);
      draft = track;
      message = 'Falha ao salvar. O rascunho continua disponível para tentar novamente.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> discard() async {
    if (active || busy || damaged || draft == null) return;
    busy = true;
    final previous = draft;
    draft = null;
    _notify();
    try {
      await _persist();
      _baseSeconds = 0;
      _clock.reset();
      position = null;
      accuracy = null;
      message = 'Rascunho descartado.';
    } catch (_) {
      draft = previous;
      message = 'Falha ao descartar. O rascunho foi mantido.';
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    unawaited(pause());
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
