import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import '../data/content.dart';
import '../data/store.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'booking.dart';
import 'catalog.dart';
import 'scan.dart';
import '../theme/brand.dart';
import 'common.dart';
import 'itinerary.dart';
import 'explore.dart';
import 'profile.dart';
import 'passport.dart';
import 'season_calendar.dart';
import 'shell.dart' show Tabs;

/// Leva para a aba Mapa (usado em telas internas).
void openMap(BuildContext context) {
  ProviderScope.containerOf(context).read(shellTabProvider.notifier).go(Tabs.mapa);
  Navigator.of(context).popUntil((r) => r.isFirst);
}

/// Início no formato do protótipo aprovado: logo, saudação, busca, quatro
/// atalhos, cartão do passaporte, passeios em destaque e destinos.
/// As funções novas entram sem poluir: categorias numa linha de chips,
/// eventos e a dica da semana no fim.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _onlyFav = false;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(appStoreProvider);
    final user = ref.watch(authProvider);
    final name = store.name ?? user?.email?.split('@').first;
    final polos = Content.polos
        .where((p) => p.destaque || store.isFav(p.id))
        .where((p) => !_onlyFav || store.isFav(p.id))
        .toList();
    final destaques = Content.items
        .where((i) => i.cat == Cat.passeio || i.cat == Cat.natureza)
        .toList();
    final eventos = Content.byCat(Cat.evento)
      ..sort((a, b) => a.data!.compareTo(b.data!));
    final dica = Content.dicas[DateTime.now().day % Content.dicas.length];

    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: MP.soft,
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s10),
        children: [
          // Topo de app: bloco azul em degradê, saudação e busca flutuante.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MP.navy, Color(0xff0e4f80), MP.green],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            padding: const EdgeInsets.only(bottom: MP.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          Padding(
            padding: EdgeInsets.fromLTRB(MP.pageH, top + MP.s3, MP.s3, 0),
            child: Row(
              children: [
                // Logo horizontal: símbolo e nome lado a lado (ocupa menos altura).
                const MpLogoHorizontal(height: 46, white: true),
                const Spacer(),
                Badge(
                  isLabelVisible: store.unreadAvisos > 0,
                  smallSize: 10,
                  backgroundColor: MP.error,
                  child: IconButton(
                    key: const Key('home-bell'),
                    tooltip: 'Avisos',
                    iconSize: 26,
                    style: IconButton.styleFrom(backgroundColor: const Color(0x26ffffff)),
                    onPressed: () => push<void>(context, const AvisosScreen()),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: MP.s2),
                Semantics(
                  button: true,
                  label: 'Perfil',
                  child: InkWell(
                    key: const Key('home-avatar'),
                    customBorder: const CircleBorder(),
                    onTap: () => push<void>(context, const ProfileScreen()),
                    child: CircleAvatar(
                      radius: 23,
                      backgroundColor: MP.yellow,
                      child: Text(
                        (name ?? 'V').substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                          color: MP.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s4, MP.pageH, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name == null
                      ? '${_greeting()}, viajante!'
                      : '${_greeting()}, ${name[0].toUpperCase()}${name.substring(1)}!',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: Colors.white),
                ),
                Text(
                  'Para onde você quer ir?',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: const Color(0xd9ffffff)),
                ),
                const SizedBox(height: MP.s4),
                Semantics(
                  button: true,
                  label: 'Buscar lugares e passeios',
                  child: InkWell(
                    key: const Key('home-search'),
                    borderRadius: BorderRadius.circular(MP.rMedium),
                    onTap: () => push<void>(context, const ExploreScreen()),
                    child: Container(
                      height: 58,
                      padding: const EdgeInsets.symmetric(horizontal: MP.s4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(MP.rLarge),
                        boxShadow: const [BoxShadow(color: Color(0x33061a2e), blurRadius: 18, offset: Offset(0, 8))],
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: MP.textSecondary,
                            size: 26,
                          ),
                          SizedBox(width: MP.s3),
                          Flexible(
                            child: Text(
                              'Digite um lugar ou passeio',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                color: MP.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s4, MP.pageH, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (final (k, icon, label, tint, color, go) in <(String, IconData, String, Color, Color, Widget Function())>[
                      ('qa-rota', Icons.route_rounded, 'Sua Rota', MP.tintGreen, MP.green, () => const ItineraryScreen()),
                      ('qa-hospedagem', Icons.hotel_rounded, 'Hospedagem', MP.tintBlue, MP.navy, () => const CategoryScreen(cat: Cat.hospedagem)),
                      ('qa-passeios', Icons.hiking_rounded, 'Passeios', MP.tintYellow, MP.goldText, () => const CategoryScreen(cat: Cat.passeio)),
                      ('qa-eventos', Icons.event_rounded, 'Eventos', MP.tintPurple, const Color(0xff5b3fa8), () => const CategoryScreen(cat: Cat.evento)),
                    ]) ...[
                      if (k != 'qa-rota') const SizedBox(width: MP.s2),
                      Expanded(
                        child: MpShortcut(
                          key: Key(k),
                          icon: icon,
                          label: label,
                          tint: tint,
                          color: color,
                          onTap: () => push<void>(context, go()),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: MP.s4),
                const ItineraryShortcut(),
                const SizedBox(height: MP.s3),
                MpCard(
                  key: const Key('home-passport'),
                  onTap: () => push<void>(context, const PassportScreen()),
                  padding: const EdgeInsets.all(MP.s4),
                  child: Row(
                    children: [
                      const Icon(Icons.badge_rounded, color: MP.navy, size: 34),
                      const SizedBox(width: MP.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Meu passaporte', style: Theme.of(context).textTheme.titleMedium),
                            Text(
                              '${store.points} pontos · ${store.stampedPolos.length} carimbos',
                              style: const TextStyle(fontSize: 15, color: MP.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        key: const Key('qa-checkin'),
                        onPressed: () => push<void>(context, const ScanScreen()),
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: const Text('Check-in'),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MP.s3),
                const SeasonCalendarCard(),
              ],
            ),
          ),
          const SizedBox(height: MP.s4),
          // Categorias numa única linha (antes: grade de 9 blocos).
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              itemCount: Cat.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: MP.s2),
              itemBuilder: (_, k) {
                final c = Cat.values[k];
                return ActionChip(
                  key: Key('cat-${c.name}'),
                  avatar: Icon(c.icon, size: 20, color: c.tint.fg),
                  label: Text(c.label),
                  backgroundColor: MP.soft,
                  onPressed: () => push<void>(context, CategoryScreen(cat: c)),
                );
              },
            ),
          ),
          const SizedBox(height: MP.sectionGap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: MpSectionTitle(
              'Passeios',
              action: 'Ver todos',
              onAction: () =>
                  push<void>(context, const CategoryScreen(cat: Cat.passeio)),
            ),
          ),
          const SizedBox(height: MP.s3),
          SizedBox(
            height: 262,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              itemCount: destaques.length,
              separatorBuilder: (_, _) => const SizedBox(width: MP.s3),
              itemBuilder: (_, i) => ItemMiniCard(item: destaques[i]),
            ),
          ),
          const SizedBox(height: MP.sectionGap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MpSectionTitle(
                  'Destinos',
                  action: 'Ver os 11',
                  onAction: () => push<void>(context, const PolosScreen()),
                ),
                const SizedBox(height: MP.s3),
                Row(
                  children: [
                    ChoiceChip(
                      key: const Key('dest-all'),
                      label: const Text('Todos'),
                      selected: !_onlyFav,
                      labelStyle: TextStyle(
                        color: !_onlyFav ? Colors.white : MP.ink,
                        fontWeight: FontWeight.w800,
                        fontFamily: mpFont,
                      ),
                      onSelected: (_) => setState(() => _onlyFav = false),
                    ),
                    const SizedBox(width: MP.s2),
                    ChoiceChip(
                      key: const Key('dest-fav'),
                      avatar: Icon(
                        Icons.favorite_rounded,
                        size: 18,
                        color: _onlyFav ? Colors.white : MP.ink,
                      ),
                      label: const Text('Favoritos'),
                      selected: _onlyFav,
                      labelStyle: TextStyle(
                        color: _onlyFav ? Colors.white : MP.ink,
                        fontWeight: FontWeight.w800,
                        fontFamily: mpFont,
                      ),
                      onSelected: (_) => setState(() => _onlyFav = true),
                    ),
                  ],
                ),
                const SizedBox(height: MP.s3),
                if (polos.isEmpty)
                  const MpCard(
                    color: MP.soft,
                    child: Text(
                      'Toque no coração de um destino para guardá-lo aqui.',
                      style: TextStyle(fontSize: 16, color: MP.textSecondary),
                    ),
                  ),
                for (final p in polos) ...[
                  PhotoCard(
                    title: p.nome,
                    subtitle: p.resumo,
                    photo: p.foto,
                    favId: p.id,
                    onTap: () => openPolo(context, p),
                    seed: p.id.hashCode,
                  ),
                  const SizedBox(height: MP.s3),
                ],
                const SizedBox(height: MP.s3),
                MpSectionTitle(
                  'Eventos',
                  action: 'Agenda',
                  onAction: () => push<void>(
                    context,
                    const CategoryScreen(cat: Cat.evento),
                  ),
                ),
                const SizedBox(height: MP.s2),
                for (final e in eventos.take(2)) ...[
                  ItemRow(item: e),
                  const SizedBox(height: MP.s2),
                ],
                const SizedBox(height: MP.s4),
                MpCard(
                  color: MP.soft,
                  border: false,
                  onTap: () {
                    final it = Content.item(dica.itemId);
                    if (it != null) openItem(context, it);
                  },
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tips_and_updates_rounded,
                        color: MP.goldText,
                        size: 30,
                      ),
                      const SizedBox(width: MP.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dica de quem conhece',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: MP.textSecondary,
                              ),
                            ),
                            Text(
                              dica.titulo,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              dica.autor,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: MP.textMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AvisosScreen extends ConsumerWidget {
  const AvisosScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            const MpHeader(
              'Avisos',
              subtitle: 'Novidades, lembretes e ofertas.',
            ),
            if (!store.offerAlerts)
              const Padding(
                padding: EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s3),
                child: MpNotice(
                  'Os avisos de ofertas estão desligados. Você pode ligar em Perfil.',
                ),
              ),
            for (final a in Content.avisos)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MP.pageH,
                  0,
                  MP.pageH,
                  MP.s3,
                ),
                child: MpListTile(
                  icon: a.icon,
                  title: a.titulo,
                  subtitle: a.texto,
                  tint: store.readAvisos.contains(a.id)
                      ? MP.soft
                      : MP.tintYellow,
                  onTap: () {
                    store.markAvisoRead(a.id);
                    _go(context, ref, a.destino);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, WidgetRef ref, String dest) {
    if (dest == 'cupons') {
      ref.read(shellTabProvider.notifier).go(Tabs.cupons);
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else if (dest == 'reservas') {
      push<void>(context, const ReservationsScreen());
    } else if (dest.startsWith('polo:')) {
      openPolo(context, Content.polo(dest.substring(5)));
    } else if (dest.startsWith('item:')) {
      final it = Content.item(dest.substring(5));
      if (it != null) openItem(context, it);
    }
  }
}
