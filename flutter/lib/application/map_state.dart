import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../data/tourism_repository.dart';
import '../data/catalog_workspace.dart';
import '../domain/tourism.dart';
import '../voice/command.dart';
import '../voice/place_resolver.dart';

enum MapEngine { streets, mapLibre, google, essential, terrain }

final repositoryProvider = Provider<TourismRepository>(
  (ref) => throw UnimplementedError(),
);
final mapStateProvider = StateNotifierProvider<MapCoordinator, MapState>(
  (ref) => MapCoordinator(ref.watch(repositoryProvider)),
);

class CameraRequest {
  const CameraRequest(this.target, this.zoom, this.serial);
  final GeoPoint target;
  final double zoom;
  final int serial;
}

class MapState {
  MapState({
    required this.places,
    this.query = '',
    this.selectedId,
    this.category,
    this.area,
    this.city,
    this.couponsOnly = false,
    this.savedOnly = false,
    this.islandsOnly = false,
    this.saved = const {},
    this.bounds = GeoBounds.maranhao,
    this.zoom = 6,
    this.engine = MapEngine.streets,
    this.mapEpoch = 0,
    this.loading = false,
    this.offline = false,
    this.truncated = false,
    this.location,
    this.request = const CameraRequest(GeoPoint(-2.53, -44.3), 12, 0),
  });
  final List<TourismPlace> places;
  final String query;
  final String? selectedId;
  final PlaceCategory? category;
  final String? area, city;
  final bool couponsOnly, savedOnly, islandsOnly, loading, offline, truncated;
  final Set<String> saved;
  final GeoBounds bounds;
  final double zoom;
  final MapEngine engine;
  final int mapEpoch;
  final GeoPoint? location;
  final CameraRequest request;
  List<TourismPlace> get filtered {
    final needle = normalize(query);
    final candidates = places
        .where(
          (p) =>
              (category == null || p.category == category) &&
              (p.category != PlaceCategory.residential ||
                  category == PlaceCategory.residential ||
                  needle.isNotEmpty ||
                  savedOnly) &&
              (!islandsOnly || p.isCoastalIsland) &&
              (area == null || p.area == area) &&
              (city == null ||
                  p.city == city ||
                  (p.isCoastalIsland &&
                      (p.tags?.split(';').contains('municipio:$city') ??
                          false))) &&
              (!couponsOnly || p.hasCoupon) &&
              (!savedOnly || saved.contains(p.id)),
        )
        .toList();
    if (needle.isEmpty) return candidates;
    final target = spokenName(query);
    if (target.isEmpty) return const [];
    final named = candidates
        .where(
          (p) =>
              spokenName(p.name).contains(target) ||
              p.searchAliases.any((a) => spokenName(a) == target),
        )
        .toList();
    if (named.isNotEmpty) {
      named.sort((a, b) {
        int rank(TourismPlace p) {
          final n = spokenName(p.name);
          if (n == target) return 0;
          if (p.searchAliases.any((a) => spokenName(a) == target)) return 1;
          if (p.category == PlaceCategory.nature &&
              (n.startsWith('parque nacional ') || n.startsWith('portal ')))
            return 2;
          return 3;
        }

        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.name.compareTo(b.name);
      });
      return named;
    }
    final exact = candidates
        .where(
          (p) => normalize(
            '${p.name} ${p.city} ${p.description} ${p.area ?? ''} ${p.tags ?? ''} ${p.address ?? ''} ${p.category.label}',
          ).contains(needle),
        )
        .toList();
    if (exact.isNotEmpty) return exact;
    return resolvePlaces(
      MapCommand(term: query),
      candidates,
    ).map((match) => match.place).toList();
  }

  List<TourismPlace> get inView =>
      filtered.where((p) => bounds.contains(p.point)).toList();
  MapState copy({
    List<TourismPlace>? places,
    String? query,
    String? selectedId,
    bool clearSelection = false,
    PlaceCategory? category,
    bool clearCategory = false,
    String? area,
    bool clearArea = false,
    String? city,
    bool clearCity = false,
    bool? couponsOnly,
    bool? savedOnly,
    bool? islandsOnly,
    Set<String>? saved,
    GeoBounds? bounds,
    double? zoom,
    MapEngine? engine,
    int? mapEpoch,
    bool? loading,
    bool? offline,
    bool? truncated,
    GeoPoint? location,
    CameraRequest? request,
  }) => MapState(
    places: places ?? this.places,
    query: query ?? this.query,
    selectedId: clearSelection ? null : selectedId ?? this.selectedId,
    category: clearCategory ? null : category ?? this.category,
    area: clearArea ? null : area ?? this.area,
    city: clearCity ? null : city ?? this.city,
    couponsOnly: couponsOnly ?? this.couponsOnly,
    savedOnly: savedOnly ?? this.savedOnly,
    islandsOnly: islandsOnly ?? this.islandsOnly,
    saved: saved ?? this.saved,
    bounds: bounds ?? this.bounds,
    zoom: zoom ?? this.zoom,
    engine: engine ?? this.engine,
    mapEpoch: mapEpoch ?? this.mapEpoch,
    loading: loading ?? this.loading,
    offline: offline ?? this.offline,
    truncated: truncated ?? this.truncated,
    location: location ?? this.location,
    request: request ?? this.request,
  );
}

class MapCoordinator extends StateNotifier<MapState> {
  void select(String? id) =>
      state = state.copy(selectedId: id, clearSelection: id == null);

  MapCoordinator(this.repo)
    : super(
        MapState(
          places: repo.publishedCatalog.merge(
            _merge([
              ...repo.basePlaces,
              ...repo.cachedPartners(),
            ], CatalogWorkspace(repo.preferences).entries),
          ),
          saved: repo.preferences.getStringList('saved_places')?.toSet() ?? {},
          engine: AppConfig.canUseGoogle ? MapEngine.google : MapEngine.streets,
        ),
      ) {
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        state = state.copy(places: [...state.places]);
        refresh();
      }
    });
    refresh();
  }
  final TourismRepository repo;
  CatalogWorkspace get workspace => CatalogWorkspace(repo.preferences);
  List<CatalogEntry> get entries => workspace.entries;
  static List<TourismPlace> _merge(
    List<TourismPlace> base,
    List<CatalogEntry> entries,
  ) {
    final overridden = entries.map((e) => e.place.id).toSet();
    return [
      ...base.where((p) => !overridden.contains(p.id)),
      ...entries
          .where((e) => e.status == CatalogStatus.visible)
          .map((e) => e.place),
    ];
  }

  bool _writing = false;
  Future<void> writeEntries(List<CatalogEntry> next) async {
    if (_writing) {
      throw const FormatException('Aguarde a gravação anterior.');
    }
    _writing = true;
    try {
      await workspace.write(next);
      if (!mounted) {
        return;
      }
      final localIds = {
        ...entries.map((e) => e.place.id),
        ...next.map((e) => e.place.id),
      };
      final remote = state.places.where(
        (p) => p.isPartner && !localIds.contains(p.id),
      );
      state = state.copy(
        places: repo.publishedCatalog.merge(
          _merge([...repo.basePlaces, ...remote], next),
        ),
      );
    } finally {
      _writing = false;
    }
  }

  Future<void> saveEntry(CatalogEntry entry) => writeEntries([
    ...entries.where((e) => e.place.id != entry.place.id),
    entry,
  ]);
  Future<void> removeEntry(String id) =>
      writeEntries(entries.where((e) => e.place.id != id).toList());
  Future<int> importEntries(String json) async {
    final incoming = CatalogWorkspace.decode(json);
    final next = {
      for (final e in entries) e.place.id: e,
      for (final e in incoming) e.place.id: e,
    };
    await writeEntries(next.values.toList());
    return incoming.length;
  }

  Timer? _debounce;
  Timer? _clock;
  int _generation = 0;
  void showVoiceResult(TourismPlace p) {
    resetFilters();
    state = state.copy(
      places: [...state.places.where((old) => old.id != p.id), p],
      query: p.name,
      selectedId: p.id,
    );
    focus(p.point, 16);
  }

  void query(String value) => state = state.copy(query: value);
  void category(PlaceCategory? value) =>
      state = state.copy(category: value, clearCategory: value == null);
  void setFilters({String? area, String? city, bool coupons = false}) {
    state = state.copy(
      area: area,
      clearArea: area == null,
      city: city,
      clearCity: city == null,
      couponsOnly: coupons,
    );
    final result = state.filtered;
    if (result.isNotEmpty && (area != null || city != null)) {
      final municipal = repo.municipalities.where((m) => m.name == city);
      focus(
        municipal.isNotEmpty ? municipal.first.point : result.first.point,
        city != null ? 12 : 8,
      );
    }
  }

  void islandsOnly(bool value) {
    state = state.copy(
      islandsOnly: value,
      engine: value && state.engine != MapEngine.terrain
          ? MapEngine.streets
          : state.engine,
    );
  }

  void resetFilters() => state = state.copy(
    islandsOnly: false,
    query: '',
    clearCategory: true,
    clearArea: true,
    clearCity: true,
    couponsOnly: false,
  );
  void savedOnly(bool value) => state = state.copy(savedOnly: value);
  Future<void> toggleSave(String id) async {
    final next = {...state.saved};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = state.copy(saved: next);
    await repo.preferences.setStringList('saved_places', next.toList());
  }

  void focus(GeoPoint target, double zoom) => state = state.copy(
    request: CameraRequest(target, zoom.clamp(4, 18), state.request.serial + 1),
  );
  void locate(GeoPoint p) {
    state = state.copy(location: p);
    focus(p, 13);
  }

  void setLocation(GeoPoint p) => state = state.copy(location: p);

  void engine(MapEngine value) {
    if (value == MapEngine.mapLibre && !AppConfig.supportsVectorMaps) {
      value = MapEngine.streets;
    }
    state = state.copy(engine: value, mapEpoch: state.mapEpoch + 1);
  }

  void viewport(GeoBounds bounds, double zoom) {
    ++_generation; // Invalida imediatamente uma resposta da câmera anterior.
    state = state.copy(bounds: bounds, zoom: zoom);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), refresh);
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    final requestedBounds = state.bounds;
    state = state.copy(loading: true);
    final catalogUpdate = repo.publishedCatalog.refresh();
    final r = await repo.fetchVisible(requestedBounds);
    await catalogUpdate;
    if (!mounted || generation != _generation) {
      return;
    }
    // O resultado atual substitui parceiros da área; evita manter oferta removida como ativa.
    final outside = state.places.where(
      (p) => p.isPartner && !requestedBounds.contains(p.point),
    );
    final partners = r.error
        ? state.places
              .where((p) => p.isPartner)
              .map((p) => TourismPlace.fromJson(p.toJson()))
        : [...outside, ...r.places];
    state = state.copy(
      places: repo.publishedCatalog.merge(
        _merge([...repo.basePlaces, ...partners], entries),
      ),
      loading: false,
      offline: r.error || repo.publishedCatalog.offline,
      truncated: r.truncated,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    repo.client.close();
    _clock?.cancel();
    super.dispose();
  }
}
