import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content.dart';
import '../data/models.dart' show formatBrl;
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'common.dart';
import 'login_screen.dart';
import 'support.dart';

/// Artesanato · compra simples: sem estoque no app, limite de 3 peças e
/// contato direto com o artesão (regra do Design Master).
class CraftPurchaseScreen extends ConsumerStatefulWidget {
  const CraftPurchaseScreen({super.key, required this.item});
  final Item item;
  @override
  ConsumerState<CraftPurchaseScreen> createState() => _CraftState();
}

class _CraftState extends ConsumerState<CraftPurchaseScreen> {
  int _qty = 1;

  Future<void> _send() async {
    final ok = await requireLogin(
      context,
      ref,
      reason: 'Entre para enviar o pedido ao artesão.',
    );
    if (!ok || !mounted) return;
    final i = widget.item;
    final t = await ref
        .read(appStoreProvider)
        .openTicketAsync(
          kind: 'Artesanato',
          subject: i.titulo,
          body: 'Quero $_qty ${_qty == 1 ? 'peça' : 'peças'} de ${i.titulo}.',
        );
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MpStatusScreen(
          title: 'Solicitação enviada',
          message:
              '${i.artesao ?? 'O artesão'} recebeu o seu interesse e vai combinar entrega e pagamento com você. Protocolo ${t.id}.',
          primaryLabel: 'Falar com o artesão',
          onPrimary: () => openWhatsApp(
            context,
            i.telefone ?? '',
            'Olá! Vi ${i.titulo} no MaraPass e quero $_qty ${_qty == 1 ? 'peça' : 'peças'}. Protocolo ${t.id}.',
          ),
          secondaryLabel: 'Voltar',
          onSecondary: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    final total = (i.precoCents ?? 0) * _qty;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            MpHeader('Quero comprar', subtitle: i.titulo),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MpPhoto(
                    photo: i.foto,
                    height: 180,
                    icon: Icons.palette_rounded,
                    seed: i.id.hashCode,
                  ),
                  const SizedBox(height: MP.s5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Quantidade',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      MpStepper(
                        value: _qty,
                        min: 1,
                        max: 3,
                        keyPrefix: 'qty',
                        onChanged: (v) => setState(() => _qty = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: MP.s2),
                  const Text(
                    'Até 3 peças por pedido. As peças são feitas à mão e podem variar um pouco.',
                    style: TextStyle(color: MP.textSecondary, fontSize: 15),
                  ),
                  const SizedBox(height: MP.s4),
                  MpCard(
                    color: MP.soft,
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Valor estimado',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          formatBrl(total),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: MP.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MP.s4),
                  const MpNotice(
                    'O MaraPass não cobra nem guarda estoque. Você combina entrega e pagamento direto com o artesão.',
                  ),
                  const SizedBox(height: MP.s5),
                  MpCtaButton(
                    key: const Key('craft-send'),
                    label: 'Enviar pedido ao artesão',
                    onPressed: _send,
                  ),
                  if (i.telefone != null) ...[
                    const SizedBox(height: MP.s3),
                    OutlinedButton.icon(
                      onPressed: () => callPhone(context, i.telefone!),
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('Ligar para o artesão'),
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

/// Fotografia profissional · contratar.
class PhotoHireScreen extends ConsumerStatefulWidget {
  const PhotoHireScreen({super.key, required this.item});
  final Item item;
  @override
  ConsumerState<PhotoHireScreen> createState() => _PhotoHireState();
}

class _PhotoHireState extends ConsumerState<PhotoHireScreen> {
  DateTime? _day;
  String _period = 'Nascer do sol';
  int _people = 2;

  Future<void> _send() async {
    final ok = await requireLogin(
      context,
      ref,
      reason: 'Entre para contratar o fotógrafo.',
    );
    if (!ok || !mounted || _day == null) return;
    final t = await ref
        .read(appStoreProvider)
        .openTicketAsync(
          kind: 'Fotografia',
          subject: widget.item.titulo,
          body: '${fmtLong(_day!)}, $_period, $_people pessoas.',
        );
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MpStatusScreen(
          title: 'Pedido enviado ao fotógrafo',
          message:
              'Ele confirma o horário e o ponto de encontro. As fotos chegam em Minhas galerias. Protocolo ${t.id}.',
          primaryLabel: 'Ver minhas galerias',
          onPrimary: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const GalleriesScreen()),
          ),
          secondaryLabel: 'Voltar',
          onSecondary: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = DateTime.now();
    final days = [
      for (var d = 1; d <= 10; d++) DateTime(n.year, n.month, n.day + d),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            MpHeader('Contratar fotógrafo', subtitle: widget.item.titulo),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Dia', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: MP.s2),
                  Wrap(
                    spacing: MP.s2,
                    runSpacing: MP.s2,
                    children: [
                      for (final d in days)
                        ChoiceChip(
                          label: Text('${d.day}/${d.month}'),
                          selected: _day == d,
                          labelStyle: TextStyle(
                            color: _day == d ? Colors.white : MP.ink,
                            fontWeight: FontWeight.w800,
                            fontFamily: mpFont,
                          ),
                          onSelected: (_) => setState(() => _day = d),
                        ),
                    ],
                  ),
                  const SizedBox(height: MP.s5),
                  Text(
                    'Momento',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: MP.s2),
                  Wrap(
                    spacing: MP.s2,
                    children: [
                      for (final p in const [
                        'Nascer do sol',
                        'Meio do dia',
                        'Pôr do sol',
                      ])
                        ChoiceChip(
                          label: Text(p),
                          selected: _period == p,
                          labelStyle: TextStyle(
                            color: _period == p ? Colors.white : MP.ink,
                            fontWeight: FontWeight.w800,
                            fontFamily: mpFont,
                          ),
                          onSelected: (_) => setState(() => _period = p),
                        ),
                    ],
                  ),
                  const SizedBox(height: MP.s5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pessoas na foto',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      MpStepper(
                        value: _people,
                        min: 1,
                        max: 10,
                        keyPrefix: 'photo-people',
                        onChanged: (v) => setState(() => _people = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: MP.s5),
                  MpCtaButton(
                    label: _day == null ? 'Escolha o dia' : 'Enviar pedido',
                    onPressed: _day == null ? null : _send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fotografia · minhas galerias, nuvem pessoal, álbum e impressas.
class GalleriesScreen extends ConsumerWidget {
  const GalleriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final orders = store.tickets.where((t) => t.kind == 'Fotografia').toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            const MpHeader(
              'Minhas galerias',
              subtitle: 'Fotos dos seus ensaios e o álbum da viagem.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (orders.isEmpty)
                    const MpCard(
                      color: MP.soft,
                      child: Text(
                        'Quando você contratar um fotógrafo, a galeria aparece aqui.',
                        style: TextStyle(fontSize: 16, color: MP.textSecondary),
                      ),
                    ),
                  for (final o in orders) ...[
                    MpListTile(
                      icon: Icons.photo_library_rounded,
                      title: o.subject,
                      subtitle: 'Aguardando a sessão · ${o.body}',
                      tint: MP.tintPurple,
                      color: const Color(0xff5b3fa8),
                    ),
                    const SizedBox(height: MP.s2),
                  ],
                  const SizedBox(height: MP.s4),
                  SwitchListTile(
                    key: const Key('cloud-album'),
                    value: store.fotoAlbum,
                    onChanged: store.setFotoAlbum,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Guardar na minha nuvem',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    subtitle: const Text(
                      'Envia as fotos para o Google Fotos ou iCloud que você escolher.',
                    ),
                  ),
                  const SizedBox(height: MP.s4),
                  Text(
                    'Álbum da viagem',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: MP.s2),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (final p in const [
                        'p1',
                        'p2',
                        'p3',
                        'p4',
                        'sunset',
                        'lagoas',
                      ])
                        MpPhoto(photo: p, height: null, radius: MP.rSmall),
                    ],
                  ),
                  const SizedBox(height: MP.s2),
                  const MpNotice.demo('Fotos de demonstração.'),
                  const SizedBox(height: MP.s5),
                  MpListTile(
                    key: const Key('print-photos'),
                    icon: Icons.print_rounded,
                    title: 'Fotografias impressas',
                    subtitle: 'Receba no hotel ou em casa',
                    onTap: () => push<void>(
                      context,
                      const ComposeScreen(
                        kind: 'Fotografia',
                        subject: 'Fotografias impressas',
                        hint: 'Quantas fotos, tamanho e endereço de entrega (hotel ou casa)',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transporte turístico · transfer com cotação.
class TransferQuoteScreen extends ConsumerStatefulWidget {
  const TransferQuoteScreen({super.key, required this.item});
  final Item item;
  @override
  ConsumerState<TransferQuoteScreen> createState() => _TransferState();
}

class _TransferState extends ConsumerState<TransferQuoteScreen> {
  String _from = 'Rodoviária';
  final _addr = TextEditingController();
  DateTime? _day;
  int _pax = 2;
  bool _review = false;

  @override
  void dispose() {
    _addr.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final ok = await requireLogin(
      context,
      ref,
      reason: 'Entre para pedir a cotação.',
    );
    if (!ok || !mounted) return;
    final where = _from == 'Endereço' ? _addr.text.trim() : _from;
    final t = await ref
        .read(appStoreProvider)
        .openTicketAsync(
          kind: 'Transfer',
          subject: widget.item.titulo,
          body: 'Embarque: $where · ${fmtLong(_day!)} · $_pax passageiros',
        );
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MpStatusScreen(
          title: 'Cotação pedida',
          message:
              'A empresa responde com valor e horário. Você acompanha em Atendimento. Protocolo ${t.id}.',
          primaryLabel: 'Ver atendimento',
          onPrimary: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const SupportCenterScreen(),
            ),
          ),
          secondaryLabel: 'Voltar',
          onSecondary: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    final ready =
        _day != null && (_from != 'Endereço' || _addr.text.trim().length > 5);
    if (_review) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: MP.s8),
            children: [
              MpHeader('Revise o pedido', subtitle: i.titulo),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MpCard(
                      child: Column(
                        children: [
                          MpInfoRow(
                            Icons.place_rounded,
                            'Embarque: ${_from == 'Endereço' ? _addr.text.trim() : _from}',
                          ),
                          MpInfoRow(Icons.event_rounded, fmtLong(_day!)),
                          MpInfoRow(Icons.groups_rounded, '$_pax passageiros'),
                          if (i.precoCents != null)
                            MpInfoRow(
                              Icons.payments_rounded,
                              'Referência: ${formatBrl(i.precoCents! * _pax)}',
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: MP.s3),
                    const MpNotice.demo(
                      'Revisão demonstrativa: o valor final vem na resposta da empresa.',
                    ),
                    const SizedBox(height: MP.s5),
                    MpCtaButton(
                      key: const Key('transfer-send'),
                      label: 'Pedir cotação',
                      onPressed: _send,
                    ),
                    const SizedBox(height: MP.s3),
                    OutlinedButton(
                      onPressed: () => setState(() => _review = false),
                      child: const Text('Corrigir'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    final n = DateTime.now();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            MpHeader('Pedir cotação', subtitle: i.titulo),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Onde você embarca?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: MP.s2),
RadioGroup<String>(
 groupValue: _from,
 onChanged: (v) => setState(() => _from = v!),
 child: Column(children: [
 for (final f in const [
                    ('Rodoviária', Icons.directions_bus_rounded),
                    ('Aeroporto', Icons.flight_rounded),
                    ('Endereço', Icons.home_rounded),
                  ]) RadioListTile<String>(
                      key: Key('from-${f.$1}'),
                      value: f.$1,
                      contentPadding: EdgeInsets.zero,
                      activeColor: MP.green,
                      secondary: Icon(f.$2, color: MP.navy),
                      title: Text(
                        f.$1,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
 ]),
 ),
                  if (_from == 'Endereço')
                    TextField(
                      controller: _addr,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Endereço de embarque',
                      ),
                    ),
                  const SizedBox(height: MP.s4),
                  OutlinedButton.icon(
                    key: const Key('transfer-day'),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: n,
                        lastDate: n.add(const Duration(days: 120)),
                        initialDate: n.add(const Duration(days: 1)),
                      );
                      if (d != null) setState(() => _day = d);
                    },
                    icon: const Icon(Icons.event_rounded),
                    label: Text(
                      _day == null ? 'Escolher a data' : fmtLong(_day!),
                    ),
                  ),
                  const SizedBox(height: MP.s4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Passageiros',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      MpStepper(
                        value: _pax,
                        min: 1,
                        max: 15,
                        keyPrefix: 'pax',
                        onChanged: (v) => setState(() => _pax = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: MP.s5),
                  MpCtaButton(
                    label: 'Revisar pedido',
                    onPressed: ready
                        ? () => setState(() => _review = true)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
