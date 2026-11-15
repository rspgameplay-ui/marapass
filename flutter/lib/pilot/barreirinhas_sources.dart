import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const icmbioBarreirinhas =
    'https://www.gov.br/icmbio/pt-br/assuntos/biodiversidade/unidade-de-conservacao/unidades-de-biomas/marinho/lista-de-ucs/parna-dos-lencois-maranhenses/paginas-site-parna-dos-lencois-maranhenses-ma/barreirinhas';

const _park = (
  title: 'ICMBio · Circuitos de Barreirinhas',
  url: icmbioBarreirinhas,
);
const _resort = (
  title: 'Porto Preguiças Resort · Contato e localização',
  url: 'https://portopreguicas.com.br/contato',
);

class BarreirinhasSourceLink extends StatelessWidget {
  const BarreirinhasSourceLink({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context) {
    final source = switch (placeId) {
      'osm:way:14436547' || 'osm:node:5024408266' => _park,
      'osm:way:548784390' => _resort,
      _ => null,
    };
    return source == null ? const SizedBox.shrink() : _SourceLink(source);
  }
}

class BarreirinhasSourcesButton extends StatelessWidget {
  const BarreirinhasSourcesButton({super.key});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .82,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text(
                'Fontes de Barreirinhas',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Consulte as fontes para planejar a visita e confira horários, acesso e disponibilidade antes de sair.',
              ),
              for (final group in _groups) ...[
                const SizedBox(height: 20),
                Text(
                  group.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Text(group.description),
                ),
                for (final source in group.links) _SourceLink(source),
              ],
              const Divider(height: 32),
              const Text(
                '© 2026 David Felipe Amorim Pereira. Todos os direitos reservados sobre o código e o conteúdo original do MaraPass. Dados e conteúdos de terceiros seguem suas respectivas licenças.',
              ),
            ],
          ),
        ),
      ),
    ),
    icon: const Icon(Icons.menu_book_outlined),
    label: const Text('Fontes de Barreirinhas'),
  );
}

class _SourceLink extends StatelessWidget {
  const _SourceLink(this.source);

  final ({String title, String url}) source;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(source.title),
    trailing: const Icon(Icons.open_in_new, size: 18),
    onTap: () async {
      if (!await launchUrl(
            Uri.parse(source.url),
            mode: LaunchMode.externalApplication,
          ) &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir a fonte.')),
        );
      }
    },
  );
}

const _groups = [
  (
    title: 'Inventário e visitação',
    description: 'O inventário da UFMA é um retrato de 2021. Para acesso ao parque, consulte as orientações atuais do ICMBio.',
    links: [
      (
        title: 'UFMA · Inventário da oferta turística (2021)',
        url: 'https://sites.google.com/ufma.br/gptcp/publica%C3%A7%C3%B5es/invent%C3%A1rios',
      ),
      _park,
      (
        title: 'Setur-MA · Polos turísticos',
        url:
            'https://turismo.ma.gov.br/programas-ou-campanhas/polos-turisticos',
      ),
      (
        title: 'Setur-MA · Cadastur em Barreirinhas',
        url: 'https://turismo.ma.gov.br/noticias/cadastur-promove-e-fortalece-o-turismo-em-barreirinhas',
      ),
    ],
  ),
  (
    title: 'Vivências e roteiros',
    description: 'No Tapuio, a casa de farinha apresenta técnicas tradicionais de beneficiamento da mandioca. O Sebrae também documenta uma visita técnica ao povoado Bar da Hora. Confirme a possibilidade de visita com a comunidade antes de sair.',
    links: [
      (
        title:
            'Sebrae Maranhão · Lançamento do Catálogo de Vivências Turísticas',
        url: 'https://ma.agenciasebrae.com.br/cultura-empreendedora/maranhao-se-destaca-na-51a-expo-abav-com-apoio-do-sebrae/',
      ),
      (
        title: 'Sebrae · Casa de farinha do povoado Tapuio',
        url: 'https://agenciasebrae.com.br/cultura-empreendedora/povoado-no-maranhao-turbina-turismo-com-resgate-de-saberes/',
      ),
      (
        title: 'Sebrae Maranhão · Povoado Bar da Hora',
        url: 'https://ma.agenciasebrae.com.br/cultura-empreendedora/visita-tecnica-ao-povoado-bar-da-hora-encerra-encontro-nacional-da-rede-de-turismo-do-sebrae-no-maranhao/',
      ),
      (
        title: 'Sesc Maranhão · Turismo Social',
        url: 'https://www.sescma.com.br/lazer/turismo-social/',
      ),
    ],
  ),
  (
    title: 'Agências e iniciativas do setor',
    description: 'O diretório da ABAV informa associação à entidade. Credenciamento e parceria MaraPass têm verificação própria.',
    links: [
      (
        title: 'ABAV · Agência associada em Barreirinhas',
        url: 'https://abav.com.br/associado-abav/?agencia=DANCELIZ+ADVENTURE&id=2911',
      ),
      (title: 'Embratur · Desbrava', url: 'https://desbrava.embratur.com.br/'),
      (
        title: 'Sebrae Maranhão · Apresentação do LIVE Maranhão',
        url: 'https://ma.agenciasebrae.com.br/cultura-empreendedora/digitrade-leva-inovacao-e-estrategias-digitais-aos-negocios-de-turismo-dos-lencois-maranhenses/',
      ),
    ],
  ),
  (
    title: 'Hospedagem · consulta externa',
    description: 'Compare opções diretamente nas plataformas. Preços, avaliações e disponibilidade são consultados na origem.',
    links: [
      _resort,
      (
        title: 'Booking.com · Barreirinhas',
        url: 'https://www.booking.com/accommodation/city/br/barreirinhas.pt-br.html',
      ),
      (
        title: 'Tripadvisor · Barreirinhas',
        url: 'https://www.tripadvisor.com.br/Hotels-g671558-Barreirinhas_State_of_Maranhao-Hotels.html',
      ),
      (
        title: 'Airbnb · Barreirinhas',
        url: 'https://www.airbnb.com.br/barreirinhas-brazil/stays',
      ),
      (
        title: 'Hoteis.com · Barreirinhas',
        url: 'https://www.hoteis.com/de135855/hoteis-em-barreirinhas-brasil/',
      ),
    ],
  ),
];
