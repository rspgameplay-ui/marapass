import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/map_state.dart';
import '../domain/tourism.dart';
import '../maps/road_map.dart';
import '../terrain/terrain_widgets.dart' show terrainLink;
import 'nautical_connections.dart';

class NauticalScreen extends ConsumerStatefulWidget {
  const NauticalScreen({
    super.key,
    this.islandId,
    this.loadCatalog = NauticalCatalog.load,
  });
  final String? islandId;
  final Future<NauticalCatalog> Function() loadCatalog;
  @override
  ConsumerState<NauticalScreen> createState() => _NauticalScreenState();
}

class _NauticalScreenState extends ConsumerState<NauticalScreen> {
  late Future<NauticalCatalog> catalog;
  @override
  void initState() {
    super.initState();
    catalog = widget.loadCatalog();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Travessias e embarque')),
    body: FutureBuilder<NauticalCatalog>(
      future: catalog,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Não foi possível abrir as referências de travessia.',
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => catalog = widget.loadCatalog()),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        final routes = data.routes
            .where(
              (r) =>
                  widget.islandId == null ||
                  r.islandIds.contains(widget.islandId),
            )
            .toList();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Planeje o caminho até a ilha',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'A viagem tem três etapas: chegar ao cais, fazer a travessia com o prestador e desembarcar no ponto combinado. O marcador da ilha não é o cais.',
                ),
                const SizedBox(height: 16),
                if (routes.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        widget.islandId == 'osm:relation:10270258'
                            ? 'Carrapatal: embarque e traçado em validação. Um boletim do Tribunal Marítimo publicado em 2024 menciona uma viagem São José de Ribamar–Carrapatal em ocorrência de 2014. Esse registro histórico não confirma serviço turístico atual, cais ou percurso. Confirme o embarque com a comunidade e com o município de Humberto de Campos.'
                            : widget.islandId == 'ilha-lencois'
                            ? 'Lençóis: há estudo publicado que documenta acesso embarcado por Apicum-Açu e Cururupu. Cais exato, operador e traçado ainda precisam de confirmação. Não há rota náutica publicada nesta ficha.'
                            : 'Ainda não há travessia georreferenciada documentada nesta base para esta ilha. O cadastro de um porto próximo não confirma uma ligação com o destino.',
                      ),
                    ),
                  ),
                for (final route in routes)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            route.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Traçado de referência · ANTAQ · maio de 2025',
                          ),
                          Text(
                            '${route.documentedMinutes} min no ato de 2024. ${route.durationNote}',
                          ),
                          const SizedBox(height: 8),
                          Text(route.serviceNote),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => NauticalReferenceMap(
                                  connection: route,
                                  catalog: data,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Ver traçado de referência'),
                          ),
                          TextButton(
                            onPressed: () =>
                                terrainLink(context, route.authorizationUrl),
                            child: const Text(
                              'Consultar registro da travessia',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (widget.islandId == 'osm:relation:10270258')
                  TextButton(
                    onPressed: () => terrainLink(
                      context,
                      'https://www.marinha.mil.br/tm/sites/www.marinha.mil.br.tm/files/boletim-de-acidentes/23.pdf',
                    ),
                    child: const Text(
                      'Fonte histórica · Tribunal Marítimo · 2024',
                    ),
                  ),
                Text(
                  'Portos e cais documentados',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'O DNIT registra obras em Canárias e Carnaubeira (Araioses), Cururupu, Guimarães e Cateauá (Porto Rico do Maranhão). São referências de infraestrutura; as notícias de obras não confirmam horários, linhas para cada ilha ou condições de funcionamento hoje.',
                ),
                TextButton(
                  onPressed: () => terrainLink(
                    context,
                    'https://www.gov.br/dnit/pt-br/assuntos/noticias/dnit-conclui-reforma-dos-atracadouros-hidroviarios-de-canarias-e-carnaubeira-no-maranhao',
                  ),
                  child: const Text('DNIT · Canárias e Carnaubeira · 2025'),
                ),
                TextButton(
                  onPressed: () => terrainLink(
                    context,
                    'https://www.gov.br/dnit/pt-br/assuntos/noticias/no-maranhao-dnit-conclui-recuperacao-de-atracadouros-hidroviarios-em-cururupu-e-palmeirandia',
                  ),
                  child: const Text('DNIT · Cururupu e Palmeirândia · 2026'),
                ),
                TextButton(
                  onPressed: () => terrainLink(
                    context,
                    'https://www.gov.br/dnit/pt-br/assuntos/noticias/ahinor-contrata-obras-em-atracadouros-no-maranhao',
                  ),
                  child: const Text('AHINOR · registro histórico · 2016'),
                ),
                if (widget.islandId == 'ilha-lencois')
                  TextButton(
                    onPressed: () => terrainLink(
                      context,
                      'https://periodicos.unifesp.br/index.php/ecoturismo/article/view/6415',
                    ),
                    child: const Text('Estudo de acesso à Ilha dos Lençóis'),
                  ),
                const Divider(),
                const Text(
                  'Antes de embarcar, confirme ida e retorno, lotação, coletes, condições de maré e tempo, regularidade da embarcação e acesso autorizado ao destino. A decisão de navegar e o percurso operacional cabem ao condutor habilitado.',
                ),
                TextButton(
                  onPressed: () => terrainLink(context, data.sourceUrl),
                  child: const Text(
                    'ANTAQ · bases geográficas de travessias e portos',
                  ),
                ),
                TextButton(
                  onPressed: () => terrainLink(
                    context,
                    'https://www.marinha.mil.br/cpma/node/131',
                  ),
                  child: const Text('Capitania dos Portos · normas locais'),
                ),
                TextButton(
                  onPressed: () => terrainLink(
                    context,
                    'https://www.marinha.mil.br/chm/dados-do-segnav-cartas-nauticas',
                  ),
                  child: const Text('Marinha · cartas e publicações náuticas'),
                ),
                const Text(
                  'Pesquisa conferida em 05/11/2026. Não há confirmação de campo, reserva de transporte ou navegação náutica em tempo real neste módulo.',
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class NauticalReferenceMap extends ConsumerWidget {
  const NauticalReferenceMap({
    super.key,
    required this.connection,
    required this.catalog,
  });
  final NauticalConnection connection;
  final NauticalCatalog catalog;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(connection.name)),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'REFERÊNCIA PARA PLANEJAMENTO — não use este traçado para conduzir uma embarcação. Confirme cais, serviço e condições com o prestador.',
            ),
          ),
          Expanded(
            child: RoadMap(
              state: MapState(
                places: const [],
                zoom: 12,
                request: CameraRequest(
                  connection.points[connection.points.length ~/ 2],
                  12,
                  0,
                ),
              ),
              reference: repo.roads,
              coastalIslands: const [],
              nauticalReference: connection.points,
              nauticalEndpointNames: connection.endpointNames,
              creditTop: 8,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '1 · ${connection.endpointNames.first}\n2 · ${connection.endpointNames.last}',
                  ),
                  const Text(
                    'Extremos do traçado da fonte; precisão do cais e acesso por terra ainda não validados.',
                  ),
                  TextButton(
                    onPressed: () => terrainLink(context, catalog.sourceUrl),
                    child: const Text('Fonte: ANTAQ · edição de maio de 2025'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
