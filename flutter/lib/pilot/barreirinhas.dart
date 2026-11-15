import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/map_state.dart';
import '../domain/tourism.dart';
import '../presentation/brand.dart';
import '../presentation/travel_safety.dart';
import '../presentation/map_screen.dart';
import '../presentation/navigation_screen.dart';
import 'google_place_panel.dart';
import 'barreirinhas_sources.dart';

const pilotSelection = {
  'osm:way:14436547',
  'osm:node:5024408266',
  'cabure',
  'osm:way:531151261',
  'osm:way:548784390',
  'osm:node:5921624110',
  'osm:way:550870850',
  'osm:node:9066802817',
  'osm:node:4311211288',
};
String? pilotVisitNote(String id) => switch (id) {
  'osm:way:14436547' => 'Circuito de lagoas sazonais. Consulte uma agência e um prestador autorizado para planejar a visita em veículo credenciado. A referência no mapa não é uma entrada rodoviária.',
  'osm:node:5024408266' => 'O acesso ao circuito envolve transporte credenciado por estradas de areia e uma escadaria para chegar às dunas. Planeje o passeio com um prestador autorizado.',
  'cabure' => 'Paisagem entre o rio Preguiças e o mar. Confirme transporte, marés e ponto de embarque com o prestador local. Esta referência não garante acesso de carro.',
  _ => null,
};

class BarreirinhasPilot extends ConsumerStatefulWidget {
  const BarreirinhasPilot({super.key});
  @override
  ConsumerState<BarreirinhasPilot> createState() => _BarreirinhasPilotState();
}

class _BarreirinhasPilotState extends ConsumerState<BarreirinhasPilot> {
  String query = '';
  PlaceCategory? category;
  bool selection = true, savedOnly = false;
  @override
  Widget build(BuildContext context) {
    final map = ref.watch(mapStateProvider);
    final all = map.places
        .where(
          (p) =>
              p.city == 'Barreirinhas' &&
              p.category != PlaceCategory.destination,
        )
        .toList();
    final entries =
        all
            .where(
              (p) =>
                  (!selection || pilotSelection.contains(p.id)) &&
                  (category == null || p.category == category) &&
                  (!savedOnly || map.saved.contains(p.id)) &&
                  normalize('${p.name} ${p.category.label} ${p.address ?? ''}')
                      .contains(normalize(query)),
            )
            .toList()
          ..sort((a, b) {
            final saved = (map.saved.contains(b.id) ? 1 : 0).compareTo(
              map.saved.contains(a.id) ? 1 : 0,
            );
            return saved == 0 ? a.name.compareTo(b.name) : saved;
          });
    return Scaffold(
      appBar: AppBar(
        title: const MaraBrand(),
        actions: [
          IconButton(
            tooltip: 'Abrir mapa do Maranhão',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const MapScreen()),
            ),
            icon: const Icon(Icons.map_outlined),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: TextField(
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      labelText: 'Pesquisar em Barreirinhas',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xffeaf4fc), Color(0xfffff4d9)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PILOTO · LENÇÓIS MARANHENSES',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                                color: MaraColors.blue,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Barreirinhas,\ndo seu jeito.',
                              style: TextStyle(
                                fontSize: 30,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                color: MaraColors.navy,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Descubra lagoas, sabores e lugares para ficar. Salve suas escolhas e confira as informações antes de sair.',
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  label: Text(
                                    '${all.length} referências locais',
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    'Seleção inicial: ${all.where((p) => pilotSelection.contains(p.id)).length} locais',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const TravelSafetyButton(
                        barreirinhas: true,
                        stage: SafetyStage.arrival,
                      ),
                      const SizedBox(height: 12),
                      const BarreirinhasSourcesButton(),
                      const SizedBox(height: 12),
                      const Text(
                        'Os dados locais já estão disponíveis. As fichas complementares do Google aguardam ativação. Estabelecimento mapeado não recebe selo de parceiro nem desconto automaticamente.',
                        style: TextStyle(fontSize: 12, color: MaraColors.navy),
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Seleção inicial'),
                            selected: selection,
                            onSelected: (_) => setState(() => selection = true),
                          ),
                          ChoiceChip(
                            label: const Text('Todos os locais'),
                            selected: !selection,
                            onSelected: (_) =>
                                setState(() => selection = false),
                          ),
                          FilterChip(
                            label: const Text('Meus salvos'),
                            selected: savedOnly,
                            onSelected: (v) => setState(() => savedOnly = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: const Text('Todas as categorias'),
                                selected: category == null,
                                onSelected: (_) =>
                                    setState(() => category = null),
                              ),
                            ),
                            for (final c in [
                              PlaceCategory.nature,
                              PlaceCategory.tours,
                              PlaceCategory.gastronomy,
                              PlaceCategory.lodging,
                              PlaceCategory.crafts,
                              PlaceCategory.culture,
                              PlaceCategory.services,
                              PlaceCategory.transport,
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  avatar: Icon(c.icon, size: 16),
                                  label: Text(c.label),
                                  selected: category == c,
                                  onSelected: (_) =>
                                      setState(() => category = c),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${entries.length} locais nesta seleção',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              if (entries.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Nenhum local corresponde a esta seleção. Experimente outras categorias ou Todos os locais.',
                    ),
                  ),
                ),
              SliverLayoutBuilder(
                builder: (context, limits) => SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: limits.crossAxisExtent >= 760 ? 2 : 1,
                    mainAxisExtent:
                        280.0 *
                        MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final p = entries[index];
                    return Card(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      elevation: 0,
                      color: Colors.white,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => details(p),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: p.category.color
                                        .withValues(alpha: .12),
                                    child: Icon(
                                      p.category.icon,
                                      color: p.category.color,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: map.saved.contains(p.id)
                                        ? 'Remover dos salvos'
                                        : 'Salvar local',
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
                                p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: MaraColors.navy,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                p.category.label,
                                style: TextStyle(
                                  color: p.category.color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                p.googlePlaceId == null
                                    ? 'Referência local • vínculo Google a conferir'
                                    : 'Referência local • ID Google associado',
                                maxLines: 2,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xff63728a),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Conhecer este lugar  →',
                                style: TextStyle(
                                  color: MaraColors.blue,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Referências: OpenStreetMap / ODbL e conteúdo editorial MaraPass. Localizações de referência não substituem a confirmação da entrada, do funcionamento ou das condições de visitação.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void details(TourismPlace place) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => Consumer(
      builder: (context, ref, _) {
        final current = ref
            .watch(mapStateProvider)
            .places
            .where((p) => p.id == place.id);
        if (current.isEmpty)
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Este local não está mais disponível. Atualize a seleção.',
            ),
          );
        final p = current.first, note = pilotVisitNote(p.id);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheet).height * .84,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: MaraColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${p.category.label} • Barreirinhas'),
                  const SizedBox(height: 16),
                  Text(
                    note ?? p.description,
                    style: const TextStyle(height: 1.5),
                  ),
                  BarreirinhasSourceLink(placeId: p.id),
                  if (p.address != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(p.address!),
                    ),
                  if (p.hours != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('Horários na fonte local: ${p.hours}'),
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Confira funcionamento, acesso e condições de visitação com o responsável. Ofertas MaraPass dependem de publicação e confirmação no cadastro comercial.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const TravelSafetyButton(
                    barreirinhas: true,
                    stage: SafetyStage.activity,
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheet);
                      showGooglePlace(this.context, p);
                    },
                    icon: const Icon(Icons.travel_explore),
                    label: const Text('Consultar informações no Google'),
                  ),
                  if (note == null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheet);
                        Navigator.push(
                          this.context,
                          MaterialPageRoute<void>(
                            builder: (_) => NavigationScreen(destination: p),
                          ),
                        );
                      },
                      icon: const Icon(Icons.directions_outlined),
                      label: const Text('Planejar trajeto no MaraPass'),
                    ),
                  if (note != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Para este atrativo, planeje o acesso com um prestador local. O piloto não indica rota de carro particular até dunas ou ponto de desembarque.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
