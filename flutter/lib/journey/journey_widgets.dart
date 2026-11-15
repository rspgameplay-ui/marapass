import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/map_state.dart';
import '../application/navigation_session.dart';
import '../domain/navigation.dart';
import '../domain/tourism.dart';
import '../presentation/brand.dart';
import 'journey.dart';
import 'journey_controller.dart';
import '../pilot/google_place_panel.dart';

Future<void> showJourneyPreferences(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _JourneyPreferencesSheet(),
    );

class JourneyTeaser extends StatelessWidget {
  const JourneyTeaser({
    super.key,
    required this.count,
    required this.first,
    required this.onOpen,
    required this.onPersonalize,
  });
  final int count;
  final JourneyCandidate? first;
  final VoidCallback onOpen, onPersonalize;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Material(
      color: const Color(0xfff1f6fc),
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 12, right: 2),
        leading: const Icon(Icons.travel_explore, color: MaraColors.blue),
        title: const Text(
          'Descobertas no caminho',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          first == null
              ? 'Ajuste seus interesses para explorar'
              : '$count sugestões • ${first!.place.name}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        onTap: onOpen,
        trailing: IconButton(
          tooltip: 'Personalizar descobertas',
          onPressed: onPersonalize,
          icon: const Icon(Icons.tune),
        ),
      ),
    ),
  );
}

Future<void> showJourneyPanel(
  BuildContext context, {
  required String destinationId,
  required ValueChanged<JourneyCandidate> onSelect,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      _JourneyPanel(destinationId: destinationId, onSelect: onSelect),
);

class _JourneyPanel extends ConsumerWidget {
  const _JourneyPanel({required this.destinationId, required this.onSelect});
  final String destinationId;
  final ValueChanged<JourneyCandidate> onSelect;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(journeyProvider);
    final navigation = ref.watch(navigationProvider);
    final map = ref.watch(mapStateProvider);
    final route = navigation.route;
    final entries = route == null
        ? <JourneyCandidate>[]
        : journey.recommendations(
            route,
            map.places,
            progress: navigation.meters,
            traveling:
                navigation.active ||
                navigation.phase == NavigationPhase.arrived,
            saved: map.saved,
            destinationId: destinationId,
          );
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Seu caminho, suas descobertas',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: MaraColors.navy,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fechar descobertas',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      navigation.simulating
                          ? 'Prévia em simulação • sem deslocamento real'
                          : navigation.active
                          ? 'Sugestões atualizadas conforme você avança'
                          : 'Explore o percurso antes de sair',
                      style: const TextStyle(
                        color: MaraColors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Até ${formatDistance(journey.preferences.corridorMeters)} da rota${navigation.active ? ' • próximos ${formatDistance(journey.preferences.aheadMeters)}' : ''}. Proximidade lateral em linha reta; acesso rodoviário não calculado.',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => showJourneyPreferences(context),
                      icon: const Icon(Icons.tune),
                      label: const Text('Meus interesses e proximidade'),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final mode in JourneyMode.values)
                          ChoiceChip(
                            label: Text(switch (mode) {
                              JourneyMode.interests => 'Para você',
                              JourneyMode.coupons => 'Cupons',
                              JourneyMode.saved => 'Salvos',
                            }),
                            selected: journey.mode == mode,
                            onSelected: (_) => journey.filter(mode),
                          ),
                      ],
                    ),
                    if (journey.loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: LinearProgressIndicator(),
                      ),
                    if (journey.offline)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'Sem confirmação das ofertas. Os atrativos continuam disponíveis; descontos não confirmados ficam ocultos.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    if (journey.truncated)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'A consulta de parceiros retornou uma lista parcial. Nem todos os benefícios podem estar nesta seleção.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    if (entries.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          '${entries.length} lugares nesta seleção',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (entries.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        journey.mode == JourneyMode.coupons
                            ? Icons.local_offer_outlined
                            : Icons.explore_outlined,
                        size: 40,
                        color: MaraColors.blue,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        journey.mode == JourneyMode.coupons
                            ? 'Nenhum cupom publicado e confirmado nesta seleção.'
                            : journey.mode == JourneyMode.saved
                            ? 'Nenhum lugar salvo corresponde a este trecho e aos seus interesses.'
                            : 'Nenhuma descoberta corresponde a este trecho e aos seus interesses.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Você pode ampliar a proximidade da rota ou escolher outras categorias.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            SliverList.builder(
              itemCount: entries.length.clamp(0, 80),
              itemBuilder: (context, i) {
                final entry = entries[i], p = entry.place;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        onSelect(entry);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: p.category.color.withValues(
                                    alpha: .12,
                                  ),
                                  child: Icon(
                                    p.category.icon,
                                    color: p.category.color,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: MaraColors.navy,
                                        ),
                                      ),
                                      Text(
                                        '${p.category.label} • ${p.city}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: map.saved.contains(p.id)
                                      ? 'Remover dos salvos'
                                      : 'Salvar descoberta',
                                  onPressed: () => ref
                                      .read(mapStateProvider.notifier)
                                      .toggleSave(p.id),
                                  icon: Icon(
                                    map.saved.contains(p.id)
                                        ? Icons.bookmark
                                        : Icons.bookmark_outline,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${formatDistance(entry.ahead(navigation.meters))} ${navigation.active ? 'à frente na rota' : 'na rota'} • ${formatDistance(entry.projection.distanceToRoad)} lateral',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (entry.islandAccess case final access?)
                              Text(
                                'Acesso por ${access.destination.name}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            const SizedBox(height: 5),
                            Text(
                              entry.reason(map.saved),
                              style: const TextStyle(
                                fontSize: 12,
                                color: MaraColors.blue,
                              ),
                            ),
                            if (p.isPartner)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Parceiro MaraPass',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (p.hasCoupon)
                              Container(
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.all(10),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xfffff3d9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Oferta publicada • ${p.offerTitle}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            const Text(
                              'Conhecer este lugar  →',
                              style: TextStyle(
                                color: MaraColors.blue,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (entries.length > 80)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Mostrando as primeiras 80 sugestões. Refine seus interesses para encontrar outros lugares.',
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _JourneyPreferencesSheet extends ConsumerStatefulWidget {
  const _JourneyPreferencesSheet();
  @override
  ConsumerState<_JourneyPreferencesSheet> createState() =>
      _JourneyPreferencesSheetState();
}

class _JourneyPreferencesSheetState
    extends ConsumerState<_JourneyPreferencesSheet> {
  late Set<PlaceCategory> interests;
  late double corridor, ahead;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final p = ref.read(journeyProvider).preferences;
    interests = {...p.interests};
    corridor = p.corridorMeters;
    ahead = p.aheadMeters;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .84,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sua viagem, do seu jeito',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: MaraColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Escolha o que gostaria de descobrir. As preferências ficam salvas neste navegador ou aparelho.',
            ),
            const SizedBox(height: 20),
            const Text(
              'Meus interesses',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in PlaceCategory.values.where(
                  (c) =>
                      c != PlaceCategory.destination &&
                      c != PlaceCategory.residential,
                ))
                  FilterChip(
                    avatar: Icon(c.icon, size: 17),
                    label: Text(c.label),
                    selected: interests.contains(c),
                    onSelected: saving
                        ? null
                        : (value) => setState(() {
                            value ? interests.add(c) : interests.remove(c);
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Proximidade da rota',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Distância lateral em linha reta. Não representa o desvio por ruas ou estradas.',
              style: TextStyle(fontSize: 12),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final value in JourneyPreferences.corridorOptions)
                  ChoiceChip(
                    label: Text(formatDistance(value)),
                    selected: corridor == value,
                    onSelected: saving
                        ? null
                        : (_) => setState(() => corridor = value),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Durante a navegação, olhar à frente',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final value in JourneyPreferences.aheadOptions)
                  ChoiceChip(
                    label: Text(formatDistance(value)),
                    selected: ahead == value,
                    onSelected: saving
                        ? null
                        : (_) => setState(() => ahead = value),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Lugares que você salvou ganham prioridade. Ofertas só aparecem quando publicadas e confirmadas. Não usamos um perfil inferido para escolher as sugestões.',
              style: TextStyle(fontSize: 12),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: saving || interests.isEmpty
                  ? null
                  : () async {
                      setState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await ref
                            .read(journeyProvider)
                            .personalize(
                              JourneyPreferences(
                                interests: {...interests},
                                corridorMeters: corridor,
                                aheadMeters: ahead,
                              ),
                            );
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        if (mounted)
                          setState(
                            () => error =
                                'Não foi possível salvar. Tente novamente.',
                          );
                      } finally {
                        if (mounted) setState(() => saving = false);
                      }
                    },
              child: Text(saving ? 'Salvando…' : 'Aplicar preferências'),
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () => setState(() {
                      const p = JourneyPreferences();
                      interests = {...p.interests};
                      corridor = p.corridorMeters;
                      ahead = p.aheadMeters;
                    }),
              child: const Text('Restaurar sugestões iniciais'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showJourneyDetails(
  BuildContext context,
  JourneyCandidate entry, {
  required VoidCallback onFocus,
  Future<bool> Function()? onReroute,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      _JourneyDetails(entry: entry, onFocus: onFocus, onReroute: onReroute),
);

class _JourneyDetails extends ConsumerStatefulWidget {
  const _JourneyDetails({
    required this.entry,
    required this.onFocus,
    this.onReroute,
  });
  final JourneyCandidate entry;
  final VoidCallback onFocus;
  final Future<bool> Function()? onReroute;

  @override
  ConsumerState<_JourneyDetails> createState() => _JourneyDetailsState();
}

class _JourneyDetailsState extends ConsumerState<_JourneyDetails> {
  bool rerouting = false;
  bool rerouteFailed = false;

  Future<void> reroute() async {
    if (rerouting) return;
    setState(() {
      rerouting = true;
      rerouteFailed = false;
    });
    final sheet = ModalRoute.of(context);
    final changed = await widget.onReroute!();
    if (!mounted) return;
    if (changed && sheet?.isCurrent == true) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      rerouting = false;
      rerouteFailed = !changed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final journey = ref.watch(journeyProvider),
        map = ref.watch(mapStateProvider);
    final current = journey
        .catalog(map.places)
        .where((p) => p.id == entry.place.id);
    if (current.isEmpty)
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Este ponto não está mais disponível no catálogo. Volte às descobertas para atualizar a seleção.',
          ),
        ),
      );
    final p = current.first;
    final saved = map.saved.contains(p.id);
    final localizations = MaterialLocalizations.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .84,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(p.category.icon, color: p.category.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${p.category.label} • ${p.city}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar lugar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                p.name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: MaraColors.navy,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                p.description.isEmpty
                    ? 'Informações detalhadas ainda não disponíveis.'
                    : p.description,
                style: const TextStyle(height: 1.5),
              ),
              if (p.address != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(p.address!),
                ),
              if (p.hours != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(p.hours!),
                ),
              if (p.isPartner)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Parceiro MaraPass',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              if (p.hasCoupon)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xfffff3d9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.local_offer_outlined),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Oferta publicada',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.offerTitle!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (p.offerEndsAt != null)
                        Text(
                          'Término informado: ${localizations.formatMediumDate(p.offerEndsAt!.toLocal())}',
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Confirme estoque, elegibilidade e condições com o parceiro. Visualizar esta oferta não emite nem reserva um cupom.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                )
              else if (p.isPartner)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nenhuma oferta vigente confirmada para este parceiro nesta consulta.',
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                '${formatDistance(entry.projection.distanceToRoad)} da rota em linha reta. O acesso e o desvio rodoviário precisam ser conferidos.',
                style: const TextStyle(fontSize: 12),
              ),
              if (entry.islandAccess case final access?) ...[
                const SizedBox(height: 8),
                Text(
                  'Acesso por ${access.destination.name} · ${access.destination.city}',
                ),
                Text(access.destination.description),
              ] else if (p.referenceLocation)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Localização de referência: confirme a entrada e as condições de visitação.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              if (p.dataSource != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Fonte: ${p.dataSource}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              const SizedBox(height: 20),
              if (widget.onReroute != null) ...[
                FilledButton.icon(
                  onPressed: rerouting ? null : reroute,
                  icon: rerouting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.alt_route),
                  label: Text(
                    rerouting
                        ? 'Calculando nova rota…'
                        : entry.islandAccess != null
                        ? 'Recalcular rota até o embarque'
                        : 'Recalcular rota para este local',
                  ),
                ),
                if (rerouteFailed)
                  Semantics(
                    liveRegion: true,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Não foi possível traçar a nova rota. Confira a localização e a conexão, e tente novamente.',
                      ),
                    ),
                  ),
              ],
              OutlinedButton.icon(
                onPressed: rerouting
                    ? null
                    : () {
                        Navigator.pop(context);
                        widget.onFocus();
                      },
                icon: const Icon(Icons.map_outlined),
                label: const Text('Ver ponto no mapa da rota'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(mapStateProvider.notifier).toggleSave(p.id),
                icon: Icon(saved ? Icons.bookmark : Icons.bookmark_outline),
                label: Text(
                  saved ? 'Remover dos salvos' : 'Salvar para visitar',
                ),
              ),
              if (p.city == 'Barreirinhas')
                OutlinedButton.icon(
                  onPressed: () => showGooglePlace(context, p),
                  icon: const Icon(Icons.travel_explore),
                  label: const Text('Consultar informações no Google'),
                ),
              Text(
                widget.onReroute == null
                    ? 'A descoberta não altera automaticamente seu percurso.'
                    : entry.islandAccess != null
                    ? 'A nova rota terrestre termina no ponto de embarque.'
                    : 'Ao recalcular, este local passa a ser o destino da viagem.',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
