import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/map_state.dart';
import '../domain/tourism.dart';
import '../terrain/terrain_widgets.dart' show terrainLink;
import '../presentation/navigation_screen.dart';
import 'coastal_island.dart';
import 'island_land_access.dart';
import 'nautical_screen.dart';

class IslandDirectory extends ConsumerStatefulWidget {
  const IslandDirectory({super.key});
  @override
  ConsumerState<IslandDirectory> createState() => _IslandDirectoryState();
}

class _IslandDirectoryState extends ConsumerState<IslandDirectory> {
  String query = '';
  String? region;
  @override
  Widget build(BuildContext context) {
    final all = ref.watch(repositoryProvider).coastalIslands;
    final found = all
        .where(
          (i) => (region == null || i.region == region) && i.matches(query),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Ilhas do litoral')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar ilha, outro nome ou município',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => query = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                itemHeight: null,
                initialValue: region ?? '',
                decoration: const InputDecoration(
                  labelText: 'Região',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Todas as regiões'),
                  ),
                  for (final r in all.map((i) => i.region).toSet())
                    DropdownMenuItem(
                      value: r,
                      child: Text(
                        r,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => region = v == '' ? null : v),
              ),
              const SizedBox(height: 12),
              if (query.isEmpty) ...[
                Text(
                  'Conheça o Maranhão insular',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${all.length} referências costeiras e estuarinas. Base inicial, sem representar todas as ilhas do estado.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Ver ilhas no mapa'),
                  onPressed: () {
                    final map = ref.read(mapStateProvider.notifier);
                    map.resetFilters();
                    map.islandsOnly(true);
                    map.focus(const GeoPoint(-2.2, -44.0), 6);
                    Navigator.pop(context);
                  },
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const NauticalScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.directions_boat_outlined),
                  label: const Text('Travessias e pontos de embarque'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'O marcador localiza a ilha; não indica desembarque ou acesso liberado. Combine a visita com a comunidade ou prestador local e confira maré, tempo, embarcação e coletes.',
                ),
                const SizedBox(height: 16),
              ],
              Text(
                '${found.length} referências nesta seleção',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (found.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Não encontramos esta ilha nesta base inicial. Tente outro nome ou município.',
                  ),
                ),
              for (final i in found)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sailing_outlined),
                  title: Text(i.place.name),
                  subtitle: Text(
                    '${i.place.city} · ${i.region}${i.aliases.isEmpty ? '' : '\nOutras referências: ${i.aliases.join(', ')}'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, i.place),
                ),
              const Divider(),
              const Text(
                'Cartografia: © OpenStreetMap contributors (ODbL), conferida em 05/11/2026; municípios: IBGE. Contornos de referência, sem levantamento de campo ou validação de rotas náuticas.',
              ),
              TextButton(
                onPressed: () => terrainLink(
                  context,
                  'https://www.openstreetmap.org/copyright',
                ),
                child: const Text('Fonte cartográfica e licença'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IslandVisitInfo extends ConsumerWidget {
  const IslandVisitInfo({
    super.key,
    required this.island,
    this.preferredAccess,
  });
  final CoastalIsland island;
  final IslandLandAccess? preferredAccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accesses =
        ref.watch(repositoryProvider).islandAccesses[island.place.id] ??
        const [];
    final origin = ref.watch(mapStateProvider.select((m) => m.location));
    final nearest = preferredAccess ?? closestIslandAccess(accesses, origin);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Visitar esta ilha',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => NauticalScreen(islandId: island.place.id),
                ),
              ),
              icon: const Icon(Icons.directions_boat_outlined),
              label: const Text('Travessias e embarque'),
            ),
            Text(
              island.place.id == 'osm:relation:10037013'
                  ? 'Upaon-Açu também é conhecida como Ilha do Maranhão ou Ilha de São Luís. Abrange São Luís, São José de Ribamar, Paço do Lumiar e Raposa. Para chegar de carro, escolha um endereço ou estabelecimento específico.'
                  : nearest == null
                  ? 'Acesso terrestre a verificar. Confirme o ponto de partida com a comunidade ou prestador local.'
                  : 'Escolha o acesso ao embarque para planejar o trecho de carro.',
            ),
            if (nearest != null)
              for (final access in [
                nearest,
                ...accesses.where(
                  (a) => a.destination.id != nearest.destination.id,
                ),
              ]) ...[
                const SizedBox(height: 12),
                Text(
                  '${access.destination.name} · ${access.destination.city}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(access.destination.description),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => NavigationScreen(
                        destination: access.destination,
                        autoPlan: true,
                        roadOnly: true,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.directions_car_outlined),
                  label: Text('Rota de carro até ${access.destination.name}'),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () =>
                          terrainLink(context, access.destination.sourceUrl!),
                      child: const Text('Acesso no OpenStreetMap'),
                    ),
                    TextButton(
                      onPressed: () =>
                          terrainLink(context, access.crossingSource),
                      child: const Text('Fonte da travessia'),
                    ),
                  ],
                ),
              ],
            if (island.aliases.isNotEmpty)
              Text(
                'Outros nomes e referências de busca: ${island.aliases.join(', ')}.',
              ),
            if (island.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(island.note),
              ),
            const SizedBox(height: 8),
            const Text(
              'Em passeios embarcados, confira a regularidade do serviço e use colete apropriado. Respeite áreas protegidas, propriedades e os acordos da comunidade. A ilha no mapa não significa autorização de visita.',
            ),
            for (var n = 0; n < island.sources.length; n++)
              TextButton(
                onPressed: () => terrainLink(context, island.sources[n]),
                child: Text(
                  n == 0
                      ? 'Consultar cartografia de origem'
                      : 'Fonte complementar $n',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
