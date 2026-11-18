import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/map_state.dart';

const icmbioMunicipalBase =
    'https://www.gov.br/icmbio/pt-br/assuntos/unidade-de-conservacao/unidades-de-biomas/marinho/lista-de-ucs/parna-dos-lencois-maranhenses/paginas-site-parna-dos-lencois-maranhenses-ma/';

bool hasMunicipalGuide(String city) =>
    city == 'Santo Amaro do Maranhão' || city == 'Primeira Cruz';

class MunicipalVisitGuide extends ConsumerWidget {
  const MunicipalVisitGuide({super.key, required this.city});
  final String city;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!hasMunicipalGuide(city)) return const SizedBox.shrink();
    final santo = city == 'Santo Amaro do Maranhão';
    final circuits = santo
        ? const [
            ('Betânia', 'Comunidade de apoio no rio Alegre.'),
            ('Andorinha', 'Inclui Gaivota e Maçarico; confirme o acesso.'),
            ('Emendadas', 'Caminhada e subida de dunas.'),
            (
              'Lagoa do Junco',
              'Condições de acesso variam por período do dia.',
            ),
            ('Rancharia', 'Circuito de dia inteiro, com bases de apoio.'),
          ]
        : const [
            (
              'Lagoa da Areia',
              'Lagoa perene em Campo Novo; acesso com veículo credenciado.',
            ),
            (
              'Areinha',
              'Acesso por 4×4 credenciado ou barco a partir do porto.',
            ),
            (
              'Pouso dos Guarás',
              'Passeio de barco à tarde, com saída do porto. Avistamentos dependem das condições naturais.',
            ),
            (
              'Mairi',
              'Comunidade pesqueira com acesso à Praia da Barra da Baleia.',
            ),
          ];
    return OutlinedButton.icon(
      icon: const Icon(Icons.menu_book_outlined),
      label: Text('Guia de $city'),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * .8,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                Text(city, style: Theme.of(sheet).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  'Informações do ICMBio atualizadas em 14/08/2026, consultadas em 05/11/2026. Confira as condições locais antes de sair.',
                ),
                const SizedBox(height: 16),
                for (final (title, description) in circuits)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(title),
                    subtitle: Text(description),
                  ),
                const Text(
                  'Os circuitos acima orientam o planejamento. Confirme pontos de acesso e embarque com o prestador antes de traçar a rota.',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    final coordinator = ref.read(mapStateProvider.notifier);
                    coordinator.resetFilters();
                    coordinator.setFilters(city: city);
                    final municipal = ref
                        .read(repositoryProvider)
                        .municipalities
                        .where((m) => m.name == city);
                    if (municipal.isNotEmpty) {
                      coordinator.focus(municipal.first.point, 12);
                    }
                    Navigator.pop(sheet);
                  },
                  child: const Text('Explorar locais deste município'),
                ),
                TextButton(
                  onPressed: () async {
                    final url = Uri.parse(
                      '$icmbioMunicipalBase${santo ? 'santo-amaro' : 'primeira-cruz'}',
                    );
                    if (!await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        ) &&
                        sheet.mounted) {
                      ScaffoldMessenger.of(sheet).showSnackBar(
                        const SnackBar(
                          content: Text('Não foi possível abrir a fonte.'),
                        ),
                      );
                    }
                  },
                  child: const Text('Consultar a página oficial do ICMBio'),
                ),
                const Text(
                  'No Parque Nacional, use prestadores autorizados e confira as regras de visitação. Para travessias com pernoite, consulte as exigências de reserva, registro e condução para a temporada.',
                ),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://www.gov.br/icmbio/pt-br/assuntos/unidade-de-conservacao/unidades-de-biomas/marinho/lista-de-ucs/parna-dos-lencois-maranhenses/trekking-travessia-dos-lencois',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('Travessia dos Lençóis · regras 2026'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
