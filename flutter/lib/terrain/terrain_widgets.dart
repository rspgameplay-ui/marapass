import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/map_state.dart';
import '../domain/tourism.dart';

const topoReference =
    'https://pt-br.topographic-map.com/map-l2c9m/Maranh%C3%A3o/';
const terrainColors = [
  Color(0xffd8ece6),
  Color(0xffd9e7ba),
  Color(0xffefe1b3),
  Color(0xffdec5a4),
  Color(0xffc7b4a6),
];

Future<void> terrainLink(BuildContext context, String url) async {
  try {
    if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication))
      return;
  } catch (_) {}
  if (context.mounted)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível abrir a fonte. Tente novamente com conexão.',
        ),
      ),
    );
}

class PlaceElevation extends ConsumerWidget {
  const PlaceElevation({super.key, required this.place});
  final TourismPlace place;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(repositoryProvider).elevations;
    final altitude = data?.at(place);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: const Icon(Icons.terrain_outlined),
        title: Text(
          altitude == null
              ? 'Altitude ainda não disponível'
              : 'Altitude estimada: ≈ ${altitude.round()} m',
        ),
        subtitle: Text(
          place.category == PlaceCategory.destination
              ? 'No marcador da sede municipal'
              : 'No marcador deste local',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            altitude == null
                ? 'Este local ainda não tem amostra compatível com suas coordenadas. Alterações de posição exigem nova consulta de altitude.'
                : 'SRTM • grade de aproximadamente 30 m • referência vertical EGM96. Consulta em ${data!.queriedAt}. A resolução da grade não é a precisão vertical.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Estimativa do modelo, sem medição em campo. O SRTM foi adquirido em 2000 e pode refletir vegetação e construções. Dunas e acessos podem ter mudado. A altitude não determina a dificuldade ou a segurança do passeio.',
          ),
          TextButton(
            onPressed: () => terrainLink(
              context,
              'https://www.opentopodata.org/datasets/srtm/',
            ),
            child: const Text('Fonte das altitudes · SRTM / Open Topo Data'),
          ),
          TextButton(
            onPressed: () => showTerrainInfo(context),
            child: const Text('Entender altitude e relevo'),
          ),
        ],
      ),
    );
  }
}

void showTerrainInfo(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheet) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(sheet).height * .75,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text(
            'Altitude e relevo',
            style: Theme.of(sheet).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'As cores mostram faixas de altitude e o sombreamento destaca formas do terreno. São informações para planejar e conhecer a paisagem.',
          ),
          const SizedBox(height: 16),
          const TerrainScale(),
          const SizedBox(height: 16),
          const Text(
            'Camada regional: Mapzen Terrain Tiles, com dados globais SRTM/GMTED2010 do USGS. Grade de cerca de 610 m, recortada pelo limite do Maranhão do IBGE. Disponível até o zoom 11; ao aproximar mais, consulte a altitude estimada nas fichas. As cores não são um mapa de risco, alagamento ou acessibilidade.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Fichas: amostras SRTM com grade aproximada de 30 m, consultadas no Open Topo Data. O número se refere ao marcador, sem representar todo o município ou passeio. A data de consulta não torna recente a medição do terreno.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Nos Lençóis Maranhenses, confirme dunas, água nas lagoas, embarque e acesso com prestadores autorizados. Nenhum traçado ou nível de dificuldade foi calculado a partir destas cores.',
          ),
          TextButton(
            onPressed: () => terrainLink(
              sheet,
              'https://registry.opendata.aws/terrain-tiles/',
            ),
            child: const Text('Fontes da camada · Mapzen / USGS'),
          ),
          TextButton(
            onPressed: () => terrainLink(sheet, topoReference),
            child: const Text('Consultar o mapa topográfico de referência'),
          ),
        ],
      ),
    ),
  ),
);

class TerrainScale extends StatelessWidget {
  const TerrainScale({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 10,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(colors: terrainColors),
          ),
        ),
      ),
      const SizedBox(height: 4),
      const Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        children: [
          Text('≤0 m'),
          Text('150'),
          Text('300'),
          Text('600'),
          Text('1.000+ m'),
        ],
      ),
    ],
  );
}

class TerrainLegend extends StatelessWidget {
  const TerrainLegend({super.key, required this.zoom});
  final double zoom;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .96),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: () => showTerrainInfo(context),
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 200,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Relevo regional',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              if (zoom <= 11)
                const DefaultTextStyle(
                  style: TextStyle(fontSize: 10, color: Color(0xff24364b)),
                  child: TerrainScale(),
                )
              else
                const Text(
                  'Aproxime para ver locais; afaste para ver o relevo.',
                  style: TextStyle(fontSize: 11),
                ),
              const Text(
                'Mapzen / USGS · grade ≈ 610 m\nToque para fontes e limites',
                style: TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
