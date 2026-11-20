part of 'partner.dart';

/// MP-P23 · Central operacional de reservas + agenda e capacidade.
class PartnerReservationsScreen extends ConsumerStatefulWidget {
  const PartnerReservationsScreen({super.key});
  @override
  ConsumerState<PartnerReservationsScreen> createState() => _PartnerResState();
}

class _PartnerResState extends ConsumerState<PartnerReservationsScreen> {
  int _capacity = 12;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    final list = s.reservations.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final pending = list
        .where((r) => r.status == ResStatus.solicitada)
        .toList();
    final confirmed = list
        .where((r) => r.status == ResStatus.confirmada)
        .toList();
    final people = confirmed.fold<int>(0, (a, r) => a + r.people);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            const MpHeader(
              'Central de reservas',
              subtitle: 'Responda os pedidos e controle a capacidade.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MpCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Capacidade por saída',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            MpStepper(
                              value: _capacity,
                              min: 2,
                              max: 30,
                              keyPrefix: 'cap',
                              onChanged: (v) => setState(() => _capacity = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: MP.s2),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(MP.rPill),
                          child: LinearProgressIndicator(
                            value: (people / _capacity).clamp(0, 1),
                            minHeight: 10,
                            color: people > _capacity ? MP.error : MP.green,
                            backgroundColor: MP.soft,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$people de $_capacity lugares ocupados nas confirmadas',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MP.s4),
                  MpSectionTitle('Aguardando resposta (${pending.length})'),
                  const SizedBox(height: MP.s2),
                  if (pending.isEmpty)
                    const MpCard(
                      color: MP.soft,
                      child: Text(
                        'Nenhum pedido pendente.',
                        style: TextStyle(fontSize: 16, color: MP.textSecondary),
                      ),
                    ),
                  for (final r in pending) ...[
                    MpCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${r.customer} · ${r.people} ${r.people == 1 ? 'pessoa' : 'pessoas'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${r.item?.titulo ?? ''}\n${fmtLong(r.date)} · ${r.period}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: MP.s3),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  key: Key('decline-${r.id}'),
                                  onPressed: () =>
                                      _decide(context, s, r.id, false),
                                  child: const Text('Recusar'),
                                ),
                              ),
                              const SizedBox(width: MP.s2),
                              Expanded(
                                child: FilledButton(
                                  key: Key('accept-${r.id}'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: MP.green,
                                  ),
                                  onPressed: () =>
                                      _decide(context, s, r.id, true),
                                  child: const Text('Confirmar'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: MP.s3),
                  ],
                  const SizedBox(height: MP.s3),
                  MpSectionTitle('Confirmadas (${confirmed.length})'),
                  const SizedBox(height: MP.s2),
                  for (final r in confirmed) ...[
                    MpListTile(
                      icon: Icons.event_available_rounded,
                      tint: MP.successBg,
                      color: MP.success,
                      title: '${r.customer} · ${r.people}p',
                      subtitle: '${fmtLong(r.date)} · ${r.period}',
                    ),
                    const SizedBox(height: MP.s2),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// MP-P10 → P14 · Eventos: lista e criação simples.
class PartnerEventsScreen extends StatelessWidget {
  const PartnerEventsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final events = Content.byCat(Cat.evento);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            const MpHeader('Eventos e ingressos'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: () => push<void>(
                      context,
                      const ServiceWizardScreen(eventMode: true),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Criar evento'),
                  ),
                  const SizedBox(height: MP.s4),
                  for (final e in events) ...[
                    MpListTile(
                      icon: Icons.event_rounded,
                      tint: MP.tintRed,
                      color: MP.error,
                      title: e.titulo,
                      subtitle: '${fmtLong(e.data!)} · Publicado',
                      onTap: () => openItem(context, e),
                    ),
                    const SizedBox(height: MP.s2),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// MP-P20 · Cadastro guiado em 4 etapas (serviço ou evento).
class ServiceWizardScreen extends StatefulWidget {
  const ServiceWizardScreen({super.key, this.eventMode = false});
  final bool eventMode;
  @override
  State<ServiceWizardScreen> createState() => _ServiceWizardState();
}

class _ServiceWizardState extends State<ServiceWizardScreen> {
  int _step = 0;
  String _kind = 'Passeio';
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  bool _accessible = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = widget.eventMode
        ? ['Informações', 'Data e local', 'Benefício', 'Revisão']
        : ['Tipo', 'Descrição', 'Preço e acesso', 'Revisão'];
    final ok = switch (_step) {
      0 => widget.eventMode ? _name.text.trim().length >= 4 : true,
      1 => _desc.text.trim().length >= 10 || widget.eventMode,
      _ => true,
    };
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            MpHeader(
              widget.eventMode ? 'Criar evento' : 'Cadastrar serviço',
              subtitle: 'Etapa ${_step + 1} de 4 · ${titles[_step]}',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      for (var k = 0; k < 4; k++)
                        Expanded(
                          child: Container(
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: k <= _step ? MP.green : MP.soft,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: MP.s5),
                  if (_step == 0 && !widget.eventMode)
RadioGroup<String>(
 groupValue: _kind,
 onChanged: (v) => setState(() => _kind = v!),
 child: Column(children: [
 for (final k in const [
                      'Passeio',
                      'Experiência',
                      'Artesanato',
                      'Fotografia',
                    ]) RadioListTile<String>(
                        value: k,
                        activeColor: MP.green,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          k,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
 ]),
 ),
                  if (_step == 0 && widget.eventMode)
                    TextField(
                      controller: _name,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        labelText: 'Nome do evento',
                      ),
                    ),
                  if (_step == 1) ...[
                    if (!widget.eventMode)
                      TextField(
                        controller: _name,
                        style: const TextStyle(fontSize: 18),
                        decoration: const InputDecoration(
                          labelText: 'Nome do serviço',
                        ),
                      ),
                    const SizedBox(height: MP.s3),
                    TextField(
                      controller: _desc,
                      onChanged: (_) => setState(() {}),
                      minLines: 3,
                      maxLines: 6,
                      style: const TextStyle(fontSize: 17),
                      decoration: InputDecoration(
                        labelText: widget.eventMode
                            ? 'Local e horário'
                            : 'Descrição para o turista',
                      ),
                    ),
                  ],
                  if (_step == 2) ...[
                    TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18),
                      decoration: InputDecoration(
                        labelText: widget.eventMode
                            ? 'Benefício (ex.: 2x1 no prato típico)'
                            : 'Preço por pessoa',
                        prefixText: widget.eventMode ? null : r'R$ ',
                      ),
                    ),
                    SwitchListTile(
                      value: _accessible,
                      onChanged: (v) => setState(() => _accessible = v),
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Acessível para pessoas com mobilidade reduzida',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (_step == 3)
                    MpCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name.text.isEmpty ? '(sem nome)' : _name.text,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (!widget.eventMode) MpBadge(_kind, fg: MP.navy),
                          const SizedBox(height: MP.s2),
                          Text(_desc.text),
                          if (_price.text.isNotEmpty)
                            Text(
                              widget.eventMode
                                  ? _price.text
                                  : 'R\$ ${_price.text}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: MP.green,
                                fontSize: 18,
                              ),
                            ),
                          if (_accessible)
                            const MpBadge('Acessível', fg: MP.info),
                        ],
                      ),
                    ),
                  const SizedBox(height: MP.s6),
                  if (_step < 3)
                    FilledButton(
                      onPressed: ok ? () => setState(() => _step++) : null,
                      child: const Text('Continuar'),
                    )
                  else
                    MpCtaButton(
                      label: 'Enviar para análise',
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => MpStatusScreen(
                            icon: Icons.hourglass_top_rounded,
                            color: MP.info,
                            bg: MP.infoBg,
                            title: widget.eventMode
                                ? 'Evento em análise'
                                : 'Serviço em análise',
                            message: 'A equipe MaraPass confere as informações e publica em breve.',
                            primaryLabel: 'Concluir',
                            onPrimary: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),
                  if (_step > 0) ...[
                    const SizedBox(height: MP.s3),
                    OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Voltar etapa'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
