import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/brand.dart';
import '../../presentation/legacy_theme.dart';
import '../../presentation/map_screen.dart';
import '../auth/auth.dart';
import '../data/content.dart';
import '../data/store.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'booking.dart';
import 'catalog.dart';
import 'common.dart';
import 'profile.dart';

void openMap(BuildContext context) => push<void>(
  context,
  Theme(data: legacyMapTheme(), child: const MapScreen()),
);

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
    final lv = store.level;
    final progress = lv.$4 == null
        ? 1.0
        : ((store.points - lv.$2) / (lv.$4! - lv.$2)).clamp(0.0, 1.0);
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
    void tab(int i) => ref.read(shellTabProvider.notifier).go(i);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s10),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s3, MP.s3, 0),
            child: Row(
              children: [
                const MaraBrand(),
                const Spacer(),
                Badge(
                  isLabelVisible: store.unreadAvisos > 0,
                  label: Text('${store.unreadAvisos}'),
                  backgroundColor: MP.error,
                  child: IconButton(
                    key: const Key('home-bell'),
                    tooltip: 'Avisos',
                    iconSize: 28,
                    onPressed: () => push<void>(context, const AvisosScreen()),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: MP.ink,
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Perfil',
                  child: InkWell(
                    key: const Key('home-avatar'),
                    customBorder: const CircleBorder(),
                    onTap: () => push<void>(context, const ProfileScreen()),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: MP.yellow,
                      child: Text(
                        (name ?? 'V').substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
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
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  'Para onde você quer ir?',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: MP.textSecondary),
                ),
                const SizedBox(height: MP.s4),
                Semantics(
                  button: true,
                  label: 'Buscar lugares e passeios',
                  child: InkWell(
                    key: const Key('home-search'),
                    borderRadius: BorderRadius.circular(MP.rMedium),
                    onTap: () => tab(1),
                    child: Container(
                      height: 58,
                      padding: const EdgeInsets.symmetric(horizontal: MP.s4),
                      decoration: BoxDecoration(
                        color: MP.soft,
                        borderRadius: BorderRadius.circular(MP.rMedium),
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
                const SizedBox(height: MP.s4),
                Row(
                  children: [
                    Expanded(
                      child: MpShortcut(
                        key: const Key('qa-map'),
                        icon: Icons.map_outlined,
                        label: 'Mapa',
                        tint: MP.tintBlue,
                        color: MP.navy,
                        onTap: () => openMap(context),
                      ),
                    ),
                    const SizedBox(width: MP.s2),
                    Expanded(
                      child: MpShortcut(
                        key: const Key('qa-coupons'),
                        icon: Icons.local_activity_outlined,
                        label: 'Cupons',
                        tint: MP.tintYellow,
                        color: const Color(0xffa87b00),
                        onTap: () => tab(3),
                      ),
                    ),
                    const SizedBox(width: MP.s2),
                    Expanded(
                      child: MpShortcut(
                        key: const Key('qa-checkin'),
                        icon: Icons.qr_code_2_rounded,
                        label: 'Check-in',
                        tint: MP.tintGreen,
                        color: MP.green,
                        onTap: () => tab(2),
                      ),
                    ),
                    const SizedBox(width: MP.s2),
                    Expanded(
                      child: MpShortcut(
                        key: const Key('qa-reservas'),
                        icon: Icons.event_note_outlined,
                        label: 'Reservas',
                        tint: MP.tintPurple,
                        color: const Color(0xff5b3fa8),
                        onTap: () =>
                            push<void>(context, const ReservationsScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MP.s4),
                // Cartão do passaporte (protótipo aprovado)
                Semantics(
                  button: true,
                  label: 'Meu passaporte: ${store.points} pontos',
                  child: InkWell(
                    key: const Key('home-passport'),
                    borderRadius: BorderRadius.circular(MP.rXl),
                    onTap: () => tab(4),
                    child: Container(
                      padding: const EdgeInsets.all(MP.s5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [MP.navy, MP.green],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(MP.rXl),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Meu passaporte',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${store.points}',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                  text: ' pontos · ${lv.$1}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: MP.s2),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(MP.rPill),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: progress),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, __) => LinearProgressIndicator(
                                value: v,
                                minHeight: 10,
                                color: MP.yellow,
                                backgroundColor: Colors.white24,
                              ),
                            ),
                          ),
                          const SizedBox(height: MP.s2),
                          Text(
                            lv.$4 == null
                                ? 'Você está no nível máximo!'
                                : 'Faltam ${lv.$4! - store.points} pontos para ${lv.$3}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
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
          const SizedBox(height: MP.sectionGap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: MpSectionTitle(
              'Passeios em destaque',
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
              separatorBuilder: (_, __) => const SizedBox(width: MP.s3),
              itemBuilder: (_, i) => ItemMiniCard(item: destaques[i]),
            ),
          ),
          const SizedBox(height: MP.sectionGap),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: MP.pageH),
            child: MpSectionTitle('O que você procura?'),
          ),
          const SizedBox(height: MP.s3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: MP.s2,
              crossAxisSpacing: MP.s2,
              childAspectRatio: 1.05,
              children: [
                for (final c in Cat.values)
                  MpShortcut(
                    key: Key('cat-${c.name}'),
                    icon: c.icon,
                    label: c.label,
                    tint: c.tint.bg,
                    color: c.tint.fg,
                    onTap: () => push<void>(context, CategoryScreen(cat: c)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: MP.sectionGap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: MpCard(
              color: MP.goldBg,
              onTap: () {
                final it = Content.item(dica.itemId);
                if (it != null) openItem(context, it);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MpBadge(
                    'Dica de quem conhece · edição da semana',
                    fg: Color(0xff8a6500),
                    bg: Colors.white,
                  ),
                  const SizedBox(height: MP.s3),
                  Text(
                    '“${dica.titulo}”',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: MP.s2),
                  Text(
                    dica.texto,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: MP.s2),
                  Text(
                    '${dica.autor} · ${dica.papel}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
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
                  action: 'Os 11 polos',
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
              ],
            ),
          ),
          const SizedBox(height: MP.s4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: MpSectionTitle(
              'Próximos eventos',
              action: 'Agenda',
              onAction: () =>
                  push<void>(context, const CategoryScreen(cat: Cat.evento)),
            ),
          ),
          const SizedBox(height: MP.s3),
          for (final e in eventos.take(2))
            Padding(
              padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s3),
              child: ItemRow(item: e),
            ),
        ],
      ),
    );
  }
}

/// Central de avisos (ofertas, lembretes, épocas).
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
      ref.read(shellTabProvider.notifier).go(3);
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
