import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import '../data/store.dart';
import '../providers.dart';
import 'checkin.dart';
import 'coupons.dart';
import 'explore.dart';
import 'home.dart';
import 'passport.dart';

/// Navegação inferior oficial do Design Master:
/// Início · Explorar · Check-in · Cupons · Passaporte (perfil pelo avatar).
class MvpShell extends ConsumerWidget {
  const MvpShell({super.key});

  static const _tabs = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'Início'),
    (Icons.explore_outlined, Icons.explore_rounded, 'Explorar'),
    (Icons.qr_code_scanner_rounded, Icons.qr_code_scanner_rounded, 'Check-in'),
    (Icons.local_activity_outlined, Icons.local_activity_rounded, 'Cupons'),
    (Icons.badge_outlined, Icons.badge_rounded, 'Passaporte'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = ref.watch(shellTabProvider);
    // Ao entrar na conta, traz cupons, reservas e check-ins do banco.
    ref.listen(authProvider, (prev, next) {
      if (next != null && prev?.id != next.id)
        ref.read(appStoreProvider).syncFromServer();
    });
    return Scaffold(
      body: IndexedStack(
        index: i,
        children: const [
          HomeScreen(),
          ExploreScreen(),
          CheckinScreen(),
          CouponsScreen(),
          PassportScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NavigationBar(
            selectedIndex: i,
            onDestinationSelected: ref.read(shellTabProvider.notifier).go,
            destinations: [
              for (final t in _tabs)
                NavigationDestination(
                  icon: Icon(t.$1),
                  selectedIcon: Icon(t.$2),
                  label: t.$3,
                ),
            ],
          ),
          // Faixa com as cores da marca (protótipo aprovado).
          const SizedBox(
            height: 5,
            child: Row(
              children: [
                Expanded(child: ColoredBox(color: Color(0xff176b54))),
                Expanded(child: ColoredBox(color: Color(0xfffac61d))),
                Expanded(child: ColoredBox(color: Color(0xffc53b36))),
                Expanded(child: ColoredBox(color: Color(0xff1a3a5c))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
