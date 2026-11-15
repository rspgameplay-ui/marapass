import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'checkin_screen.dart';
import 'coupons_screen.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'passport_screen.dart';

/// Navegação inferior oficial: Início · Explorar · Check-in · Cupons · Passaporte.
/// O perfil abre pelo avatar da Home.
class MvpShell extends ConsumerWidget {
  const MvpShell({super.key});

  static const _tabs = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'Início'),
    (Icons.search_outlined, Icons.search_rounded, 'Explorar'),
    (Icons.qr_code_scanner_outlined, Icons.qr_code_scanner_rounded, 'Check-in'),
    (Icons.local_activity_outlined, Icons.local_activity_rounded, 'Cupons'),
    (Icons.verified_outlined, Icons.verified_rounded, 'Passaporte'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = ref.watch(shellTabProvider);
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
      bottomNavigationBar: NavigationBar(
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
    );
  }
}
