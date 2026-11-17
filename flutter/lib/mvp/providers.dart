import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth.dart';
import 'data/models.dart';
import 'data/repository.dart';

final mvpRepositoryProvider = Provider<MvpRepository>(
  (ref) =>
      throw UnimplementedError('mvpRepositoryProvider precisa de override'),
);

/// Consulta da aba Explorar. Registro com igualdade estrutural: o cache do
/// provider só muda quando texto ou categoria mudam.
typedef ExploreQuery = ({String query, String category});

final experiencesProvider = FutureProvider.autoDispose
    .family<List<Experience>, ExploreQuery>(
      (ref, q) => ref
          .watch(mvpRepositoryProvider)
          .experiences(query: q.query, category: q.category),
    );

final offersProvider = FutureProvider.autoDispose.family<List<Offer>, String>(
  (ref, query) => ref.watch(mvpRepositoryProvider).offers(query: query),
);

final slotsProvider = FutureProvider.autoDispose.family<List<Slot>, String>(
  (ref, experienceId) => ref.watch(mvpRepositoryProvider).slots(experienceId),
);

final myCouponsProvider = FutureProvider.autoDispose<List<CouponInstance>>((
  ref,
) {
  if (ref.watch(authProvider) == null) return const [];
  return ref.watch(mvpRepositoryProvider).myCoupons();
});

final myReservationsProvider = FutureProvider.autoDispose<List<Reservation>>((
  ref,
) {
  if (ref.watch(authProvider) == null) return const [];
  return ref.watch(mvpRepositoryProvider).myReservations();
});

final passportProductsProvider =
    FutureProvider.autoDispose<List<PassportProduct>>(
      (ref) => ref.watch(mvpRepositoryProvider).passportProducts(),
    );

final myEntitlementsProvider =
    FutureProvider.autoDispose<List<PassportEntitlement>>((ref) {
      if (ref.watch(authProvider) == null) return const [];
      return ref.watch(mvpRepositoryProvider).myEntitlements();
    });

final profileProvider = FutureProvider.autoDispose<Profile?>((ref) {
  if (ref.watch(authProvider) == null) return null;
  return ref.watch(mvpRepositoryProvider).myProfile();
});

/// Aba atual do shell (permite que a Home abra a aba Explorar já com busca).
final shellTabProvider = NotifierProvider<ShellTab, int>(ShellTab.new);

class ShellTab extends Notifier<int> {
  @override
  int build() => 0;
  void go(int i) => state = i;
}

/// Texto digitado na Home e levado para Explorar.
final exploreSeedProvider = NotifierProvider<ExploreSeed, String>(
  ExploreSeed.new,
);

class ExploreSeed extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}
