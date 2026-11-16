import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import '../data/store.dart';
import '../providers.dart';
import 'coupons.dart';
import 'home.dart';
import 'map_tab.dart';
import 'passport.dart';

/// Abas da barra inferior, na ordem do protótipo aprovado.
abstract final class Tabs {
  static const inicio = 0;
  static const mapa = 1;
  static const cupons = 2;
  static const passaporte = 3;
}

/// Barra inferior do primeiro design: Início · Mapa · Cupons · Passaporte.
/// Explorar (busca e categorias) abre pela busca da Início; Check-in pelo
/// atalho da Início e pelo botão "Registrar visita" do Passaporte.
class MvpShell extends ConsumerStatefulWidget {
  const MvpShell({super.key});
  @override
  ConsumerState<MvpShell> createState() => _MvpShellState();
}

class _MvpShellState extends ConsumerState<MvpShell> {
  bool _mapOpened = false;

  static const _tabs = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'Início'),
    (Icons.map_outlined, Icons.map_rounded, 'Mapa'),
    (Icons.local_activity_outlined, Icons.local_activity_rounded, 'Cupons'),
    (Icons.menu_book_outlined, Icons.menu_book_rounded, 'Passaporte'),
  ];

  @override
  Widget build(BuildContext context) {
    final i = ref.watch(shellTabProvider).clamp(0, _tabs.length - 1);
    if (i == Tabs.mapa) _mapOpened = true;
    // Ao entrar na conta, traz cupons, reservas e check-ins do banco.
    ref.listen(authProvider, (prev, next) {
      if (next != null && prev?.id != next.id)
        ref.read(appStoreProvider).syncFromServer();
    });
    return Scaffold(
      body: IndexedStack(
        index: i,
        children: [
          const HomeScreen(),
          // O mapa é pesado: só monta na primeira vez que a aba é aberta.
          _mapOpened ? const MapTab() : const SizedBox.shrink(),
          const CouponsScreen(),
          const PassportScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, thickness: 1, color: Color(0xffe6eaee)),
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
                Expanded(child: ColoredBox(color: Color(0xff14775a))),
                Expanded(child: ColoredBox(color: Color(0xfffac61d))),
                Expanded(child: ColoredBox(color: Color(0xffc53b36))),
                Expanded(child: ColoredBox(color: Color(0xff0b3a66))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
