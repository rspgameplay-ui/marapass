import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repository.dart';

final mvpRepositoryProvider = Provider<MvpRepository>(
  (ref) =>
      throw UnimplementedError('mvpRepositoryProvider precisa de override'),
);

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
