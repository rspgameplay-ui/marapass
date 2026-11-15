import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MapAppearance { automatic, day, night }

final mapAppearanceProvider = StateProvider<MapAppearance>(
  (ref) => MapAppearance.automatic,
);
bool mapIsNight(MapAppearance mode, [DateTime? now]) {
  if (mode != MapAppearance.automatic) return mode == MapAppearance.night;
  final hour = (now ?? DateTime.now())
      .toUtc()
      .subtract(const Duration(hours: 3))
      .hour;
  return hour < 6 || hour >= 18;
}
