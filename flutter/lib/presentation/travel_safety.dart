import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum SafetyStage { road, arrival, activity }

class TravelSafetyButton extends StatelessWidget {
  const TravelSafetyButton({
    super.key,
    this.stage = SafetyStage.road,
    this.barreirinhas = false,
    this.iconOnly = false,
  });

  final SafetyStage stage;
  final bool barreirinhas;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    void open() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _TravelSafetySheet(initialStage: stage, barreirinhas: barreirinhas),
    );

    const icon = Icon(Icons.health_and_safety_outlined);
    const label = 'Segurança na viagem';
    return iconOnly
        ? IconButton(tooltip: label, onPressed: open, icon: icon)
        : OutlinedButton.icon(
            onPressed: open,
            icon: icon,
            label: const Text(label),
          );
  }
}

class _TravelSafetySheet extends StatefulWidget {
  const _TravelSafetySheet({
    required this.initialStage,
    required this.barreirinhas,
  });

  final SafetyStage initialStage;
  final bool barreirinhas;

  @override
  State<_TravelSafetySheet> createState() => _TravelSafetySheetState();
}

class _TravelSafetySheetState extends State<_TravelSafetySheet> {
  late var stage = widget.initialStage;

  @override
  Widget build(BuildContext context) {
    final tips = switch (stage) {
      SafetyStage.road => const [
        'De carro, van ou ônibus, afivele o cinto antes de sair e mantenha-o preso até a parada. Use também no banco traseiro.',
        'No cinto de três pontos, passe a faixa diagonal pelo ombro e peito. A faixa inferior fica baixa, sobre o quadril. Use um cinto por pessoa.',
        'Ao contratar transporte, confirme a empresa, o local de embarque e se há assento com cinto funcionando para cada passageiro.',
      ],
      SafetyStage.arrival => [
        'Confirme com o operador o ponto de encontro, os horários de saída e retorno, as condições de acesso e a previsão do tempo.',
        'Pergunte sobre a dificuldade, a duração, as restrições de participação e como a equipe age em uma emergência. Informe ao operador alergias ou necessidades de acessibilidade relevantes.',
        if (widget.barreirinhas) 'Para visitar os circuitos da Lagoa Azul e da Lagoa Bonita com transporte contratado, confira o credenciamento e a validade das autorizações do ICMBio para o serviço.',
      ],
      SafetyStage.activity => [
        'Antes de sair, leia o termo de conhecimento de riscos, tire dúvidas e acompanhe as instruções do condutor. Confira o ajuste do equipamento indicado, como capacete ou colete.',
        'No 4×4, viaje sentado com o cinto afivelado e mantenha braços e cabeça dentro do veículo. Na embarcação, use colete salva-vidas ajustado durante todo o trajeto.',
        'Na caminhada, siga a trilha indicada, leve água e proteção solar e respeite a sinalização. Entre na água apenas em local indicado pelo condutor e evite mergulhar de cabeça.',
        if (widget.barreirinhas) 'Nos passeios pelo rio Preguiças, confirme o local de embarque e as condições do percurso com o operador. Nas dunas, permaneça com o grupo.',
        'Se houver incidente ou equipamento com defeito, avise a equipe e siga as instruções antes de retomar o passeio.',
      ],
    };
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: ListView(
          primary: false,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          shrinkWrap: true,
          children: [
            Text(
              'Segurança na viagem',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              widget.barreirinhas
                  ? 'Barreirinhas · Lençóis Maranhenses'
                  : 'Da saída ao passeio',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final option in SafetyStage.values)
                  ChoiceChip(
                    label: Text(switch (option) {
                      SafetyStage.road => 'No transporte',
                      SafetyStage.arrival => 'No destino',
                      SafetyStage.activity => 'No passeio',
                    }),
                    selected: stage == option,
                    onSelected: (_) => setState(() => stage = option),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final tip in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('•  $tip'),
              ),
            ExpansionTile(
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              tilePadding: EdgeInsets.zero,
              title: const Text('Normas e fontes'),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                const Text(
                  'As referências ABNT NBR ISO da cartilha abordam a gestão da segurança do operador (21101), a competência de quem conduz (21102) e as informações ao participante antes, durante e após a atividade (21103). As dicas são orientações ao viajante. A certificação do prestador exige verificação própria.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cartilha do Turista — Rota Mais Segura (Sebrae CE, MA e PI).',
                ),
                _source(
                  context,
                  'Programa Aventura Segura · ABETA e Sebrae',
                  'https://abeta.tur.br/programa-aventura-segura/',
                ),
                _source(
                  context,
                  'ANTT · Segurança no ônibus fretado',
                  'https://www.gov.br/antt/pt-br/assuntos/passageiros/empresas/copy_of_transporte-interestadual-de-fretamento/seus-direitos-ao-viajar-em-onibus-fretado-regras-sobre-seguranca-conforto-e-atendimento-ao-passageiro/',
                ),
                _source(
                  context,
                  'Marinha · Transporte de passageiros',
                  'https://www.marinha.mil.br/cpm/transporte-de-passageiros',
                ),
                _source(
                  context,
                  'ISO 21101 · Gestão da segurança',
                  'https://www.iso.org/standard/54857.html',
                ),
                _source(
                  context,
                  'ISO 21102 · Competência dos condutores',
                  'https://www.iso.org/standard/76475.html',
                ),
                _source(
                  context,
                  'ISO 21103 · Informação ao participante',
                  'https://www.iso.org/standard/54861.html',
                ),
                if (widget.barreirinhas)
                  _source(
                    context,
                    'ICMBio · Orientações ao visitante',
                    'https://www.gov.br/icmbio/pt-br/assuntos/unidade-de-conservacao/unidades-de-biomas/marinho/lista-de-ucs/parna-dos-lencois-maranhenses/paginas-site-parna-dos-lencois-maranhenses-ma/orientacoes-ao-visitante',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _source(BuildContext context, String title, String url) => TextButton(
    onPressed: () async {
      if (!await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          ) &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir a fonte.')),
        );
      }
    },
    child: Text(title),
  );
}
