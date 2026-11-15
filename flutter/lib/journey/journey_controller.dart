import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/map_state.dart';
import '../data/tourism_repository.dart';
import '../domain/navigation.dart';
import '../domain/tourism.dart';
import 'journey.dart';

final journeyProvider = ChangeNotifierProvider.autoDispose<JourneyController>((
  ref,
) {
  return JourneyController(ref.watch(repositoryProvider));
});

class JourneyController extends ChangeNotifier {
  JourneyController(this.repository) {
    try {
      preferences = JourneyPreferences.fromJson(
        jsonDecode(repository.preferences.getString(key) ?? '{}')
            as Map<String, dynamic>,
      );
    } catch (_) {}
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_route != null) {
        refresh(_route!);
      } else {
        notifyListeners();
      }
    });
  }
  static const key = 'tourist_journey_preferences_v1';
  final TourismRepository repository;
  final index = JourneyIndex();
  JourneyPreferences preferences = const JourneyPreferences();
  JourneyMode mode = JourneyMode.interests;
  List<TourismPlace> partners = [];
  bool loading = false, offline = false, truncated = false, disposed = false;
  DateTime? checkedAt;
  RoadRoute? _route;
  int _revision = 0;
  Timer? _clock;
  bool _saving = false;

  Future<void> personalize(JourneyPreferences next) async {
    if (_saving) return;
    _saving = true;
    try {
      if (!await repository.preferences.setString(
        key,
        jsonEncode(next.toJson()),
      )) {
        throw const FormatException(
          'Não foi possível salvar suas preferências. Tente novamente.',
        );
      }
      if (disposed) return;
      preferences = next;
      notifyListeners();
    } finally {
      _saving = false;
    }
  }

  void filter(JourneyMode next) {
    mode = next;
    notifyListeners();
  }

  void clearRoute() {
    ++_revision;
    _route = null;
    loading = false;
    partners = [];
    if (!disposed) notifyListeners();
  }

  Future<void> refresh(RoadRoute route) async {
    if (disposed || (loading && identical(route, _route))) return;
    final changed = !identical(route, _route);
    _route = route;
    final revision = ++_revision;
    if (changed) partners = [];
    loading = true;
    notifyListeners();
    final result = await repository.fetchVisible(journeyBounds(route));
    if (disposed || revision != _revision) return;
    partners = result.error
        ? partners.map((p) => TourismPlace.fromJson(p.toJson())).toList()
        : result.places;
    loading = false;
    offline = result.error;
    truncated = result.truncated;
    if (!result.error) checkedAt = DateTime.now();
    notifyListeners();
  }

  List<TourismPlace> catalog(List<TourismPlace> base) => {
    for (final p in base.where((p) => !p.isPartner)) p.id: p,
    for (final p in partners) p.id: p,
  }.values.toList();
  List<JourneyCandidate> recommendations(
    RoadRoute route,
    List<TourismPlace> base, {
    double progress = 0,
    bool traveling = false,
    Set<String> saved = const {},
    String? destinationId,
  }) => recommendJourney(
    index.candidates(
      route,
      catalog(base),
      islandAccesses: repository.islandAccesses,
    ),
    preferences,
    progress: progress,
    traveling: traveling,
    mode: mode,
    saved: saved,
    destinationId: destinationId,
  );
  @override
  void dispose() {
    disposed = true;
    ++_revision;
    _clock?.cancel();
    super.dispose();
  }
}
