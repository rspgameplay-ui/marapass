import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/brand.dart';
import '../../presentation/legacy_theme.dart';
import '../../presentation/map_screen.dart';
import '../auth/auth.dart';
import '../data/models.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'cards.dart';
import 'experience_screens.dart';
import 'login_screen.dart';
import 'offer_screens.dart';
import 'profile_screen.dart';

void openMap(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Theme(data: legacyMapTheme(), child: const MapScreen()),
    ),
  );
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final profile = ref.watch(profileProvider).asData?.value;
    final name = (profile?.displayName?.trim().isNotEmpty ?? false)
        ? profile!.displayName!.trim().split(' ').first
        : (user?.email?.split('@').first);
    final exps = ref.watch(experiencesProvider((query: '', category: '')));
    final offers = ref.watch(offersProvider(''));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: MP.green,
          onRefresh: () async {
            ref.invalidate(experiencesProvider);
            ref.invalidate(offersProvider);
            await ref.read(
              experiencesProvider((query: '', category: '')).future,
            );
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              MP.pageH,
              MP.s3,
              MP.pageH,
              MP.s8,
            ),
            children: [
              Row(
                children: [
                  const MaraBrand(compact: true),
                  const SizedBox(width: MP.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name == null
                              ? '${_greeting()}!'
                              : '${_greeting()}, $name',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: MP.navy,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          user == null
                              ? 'Você está como visitante'
                              : 'Bom te ver por aqui',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Perfil',
                    child: InkWell(
                      key: const Key('home-avatar'),
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ProfileScreen(),
                        ),
                      ),
                      child: Container(
                        width: MP.minTap,
                        height: MP.minTap,
                        decoration: const BoxDecoration(
                          color: MP.navy,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          user == null ? Icons.person_outline : Icons.person,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MP.s5),
              Text(
                'Maranhão infinito.',
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(fontSize: 30),
              ),
              const SizedBox(height: MP.s4),
              TextField(
                key: const Key('home-search'),
                readOnly: false,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  ref.read(exploreSeedProvider.notifier).set(v.trim());
                  ref.read(shellTabProvider.notifier).go(1);
                },
                decoration: const InputDecoration(
                  hintText: 'Buscar passeios, ofertas e lugares',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: MP.s4),
              _QuickActions(),
              if (user == null) ...[
                const SizedBox(height: MP.s5),
                MpCard(
                  color: MP.navy,
                  onTap: () => requireLogin(
                    context,
                    ref,
                    reason: 'Entre para ativar cupons e pedir reservas.',
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.card_giftcard_rounded,
                        color: MP.gold,
                        size: 30,
                      ),
                      SizedBox(width: MP.s3),
                      Expanded(
                        child: Text(
                          'Entre para ativar cupons e pedir reservas',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: MP.sectionGap),
              MpSectionTitle(
                'Passeios em destaque',
                action: 'Ver todos',
                onAction: () => ref.read(shellTabProvider.notifier).go(1),
              ),
              const SizedBox(height: MP.s3),
              exps.when(
                loading: () => const SizedBox(height: 120, child: MpLoading()),
                error: (e, _) => MpError(
                  message: '$e',
                  onRetry: () => ref.invalidate(experiencesProvider),
                ),
                data: (list) => list.isEmpty
                    ? const MpEmpty(
                        icon: Icons.explore_outlined,
                        title: 'Estamos cadastrando os parceiros',
                        message: 'Em breve os primeiros passeios da região aparecem aqui.',
                      )
                    : SizedBox(
                        height: 270,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: list.length.clamp(0, 8),
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: MP.s3),
                          itemBuilder: (_, i) => ExperienceCard(
                            compact: true,
                            experience: list[i],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    ExperienceDetailScreen(experience: list[i]),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: MP.sectionGap),
              MpSectionTitle(
                'Cupons e ofertas',
                action: 'Ver mais',
                onAction: () {
                  ref.read(exploreSeedProvider.notifier).set('');
                  ref.read(shellTabProvider.notifier).go(1);
                },
              ),
              const SizedBox(height: MP.s3),
              offers.when(
                loading: () => const SizedBox(height: 80, child: MpLoading()),
                error: (e, _) => MpError(
                  message: '$e',
                  onRetry: () => ref.invalidate(offersProvider),
                ),
                data: (list) => list.isEmpty
                    ? const MpEmpty(
                        icon: Icons.local_activity_outlined,
                        title: 'Nenhuma oferta no momento',
                        message: 'Quando um parceiro publicar uma oferta, ela aparece aqui.',
                      )
                    : Column(
                        children: [
                          for (final o in list.take(3)) ...[
                            OfferCard(
                              offer: o,
                              onTap: () => openOffer(context, o),
                            ),
                            const SizedBox(height: MP.s3),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: MP.s2),
              MpCard(
                key: const Key('home-map-card'),
                onTap: () => openMap(context),
                child: const Row(
                  children: [
                    Icon(Icons.map_rounded, color: MP.green, size: 32),
                    SizedBox(width: MP.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mapa turístico',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: MP.navy,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '217 municípios, rotas e navegação com voz',
                            style: TextStyle(
                              color: MP.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: MP.textMuted),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void tab(int i) => ref.read(shellTabProvider.notifier).go(i);
    final items = <(IconData, String, VoidCallback, Key)>[
      (Icons.map_rounded, 'Mapa', () => openMap(context), const Key('qa-map')),
      (
        Icons.explore_rounded,
        'Explorar',
        () => tab(1),
        const Key('qa-explore'),
      ),
      (
        Icons.local_activity_rounded,
        'Cupons',
        () => tab(3),
        const Key('qa-coupons'),
      ),
      (
        Icons.verified_rounded,
        'Passaporte',
        () => tab(4),
        const Key('qa-passport'),
      ),
    ];
    return Row(
      children: [
        for (final it in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Semantics(
                button: true,
                label: it.$2,
                child: InkWell(
                  key: it.$4,
                  borderRadius: BorderRadius.circular(MP.rMedium),
                  onTap: it.$3,
                  child: Container(
                    height: 76,
                    decoration: BoxDecoration(
                      color: MP.card,
                      borderRadius: BorderRadius.circular(MP.rMedium),
                      border: Border.all(color: MP.borderSubtle),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(it.$1, color: MP.green, size: 26),
                        const SizedBox(height: 6),
                        Text(
                          it.$2,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: MP.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Abre a oferta; a ficha, o catálogo e a emissão usam a mesma oferta.
void openOffer(BuildContext context, Offer offer) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => OfferDetailScreen(offer: offer)),
  );
}
