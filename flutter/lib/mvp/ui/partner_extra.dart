part of 'partner.dart';

/// MP-P23 · Central operacional de reservas + agenda e capacidade.
class PartnerReservationsScreen extends ConsumerStatefulWidget {
  const PartnerReservationsScreen({super.key});
  @override
  ConsumerState<PartnerReservationsScreen> createState() => _PartnerResState();
}

class _PartnerResState extends ConsumerState<PartnerReservationsScreen> {

  Future<void> _useVoucher(String code) async {
    try {
      final r = await ref.read(appStoreProvider).useReservationAsync(code);
      if (mounted) showMpSnack(context, 'Comprovante validado: ${r.item?.titulo ?? 'reserva'}, ${r.people} ${r.people == 1 ? 'pessoa' : 'pessoas'}.');
    } on MvpException catch (e) {
      if (mounted) showMpSnack(context, e.message);
    }
  }

  Future<void> _typeVoucher() async {
    final c = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Código do comprovante')),
        content: TextField(key: const Key('res-code'), controller: c, autofocus: true, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(hintText: tr('R-XXXXXXXX'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancelar'))),
          FilledButton(key: const Key('res-code-ok'), onPressed: () => Navigator.pop(ctx, c.text), child: Text(tr('Validar'))),
        ],
      ),
    );
    if (code != null && code.trim().isNotEmpty) await _useVoucher(code);
  }

  Future<void> _scanVoucher() async {
    var read = false;
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: Text(tr('Ler comprovante'))),
          body: MobileScanner(
            onDetect: (capture) {
              if (read) return;
              for (final b in capture.barcodes) {
                final v = b.rawValue ?? '';
                if (v.startsWith('MARAPASS-RES:')) {
                  read = true;
                  Navigator.of(ctx).pop(v);
                  break;
                }
              }
            },
          ),
        ),
      ),
    );
    if (code != null) await _useVoucher(code);
  }
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
            MpHeader(
              tr('Central de reservas'),
              subtitle: tr('Responda os pedidos e controle a capacidade.'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MpCard(
                    key: const Key('res-validate-card'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(tr('Comprovante do turista'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(tr('Leia o QR ou digite o código R-XXXXXXXX no dia do passeio.'), style: TextStyle(color: MP.textSecondary)),
                        const SizedBox(height: MP.s2),
                        Row(children: [
                          Expanded(child: OutlinedButton.icon(key: const Key('res-scan'), onPressed: _scanVoucher, icon: const Icon(Icons.qr_code_scanner_rounded), label: Text(tr('Ler QR')))),
                          const SizedBox(width: MP.s2),
                          Expanded(child: OutlinedButton.icon(key: const Key('res-type'), onPressed: _typeVoucher, icon: const Icon(Icons.keyboard_rounded), label: Text(tr('Digitar')))),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: MP.s3),
                  MpListTile(
                    key: const Key('res-slots'),
                    icon: Icons.schedule_rounded,
                    title: tr('Horários e vagas'),
                    subtitle: '$people ${people == 1 ? tr('pessoa confirmada') : tr('pessoas confirmadas')} · defina turnos e limite por dia',
                    onTap: () => push<void>(context, const PartnerSlotsScreen()),
                  ),
                  const SizedBox(height: MP.s4),
                  MpSectionTitle('Aguardando resposta (${pending.length})'),
                  const SizedBox(height: MP.s2),
                  if (pending.isEmpty)
                    MpCard(
                      color: MP.soft,
                      child: Text(
                        tr('Nenhum pedido pendente.'),
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
                                  child: Text(tr('Recusar')),
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
                                  child: Text(tr('Confirmar')),
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
            MpHeader(tr('Eventos e ingressos')),
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
                    label: Text(tr('Criar evento')),
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
                      decoration: InputDecoration(
                        labelText: tr('Nome do evento'),
                      ),
                    ),
                  if (_step == 1) ...[
                    if (!widget.eventMode)
                      TextField(
                        controller: _name,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText: tr('Nome do serviço'),
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
                      title: Text(
                        tr('Acessível para pessoas com mobilidade reduzida'),
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
                            MpBadge(tr('Acessível'), fg: MP.info),
                        ],
                      ),
                    ),
                  const SizedBox(height: MP.s6),
                  if (_step < 3)
                    FilledButton(
                      onPressed: ok ? () => setState(() => _step++) : null,
                      child: Text(tr('Continuar')),
                    )
                  else
                    MpCtaButton(
                      label: tr('Enviar para análise'),
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => MpStatusScreen(
                            icon: Icons.hourglass_top_rounded,
                            color: MP.info,
                            bg: MP.infoBg,
                            title: widget.eventMode
                                ? 'Evento em análise'
                                : 'Serviço em análise',
                            message: tr('A equipe MaraPass confere as informações e publica em breve.'),
                            primaryLabel: tr('Concluir'),
                            onPrimary: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),
                  if (_step > 0) ...[
                    const SizedBox(height: MP.s3),
                    OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      child: Text(tr('Voltar etapa')),
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
