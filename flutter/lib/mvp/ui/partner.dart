import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content.dart';
import '../data/models.dart' show formatBrl;
import '../data/repository.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'common.dart';
import 'plates.dart';
import 'support.dart';

const _partnerName = 'Lençóis Experience';

Future<void> _decide(
  BuildContext context,
  AppStore s,
  String id,
  bool accept,
) async {
  try {
    await s.decideReservationAsync(id, accept);
    if (context.mounted)
      showMpSnack(
        context,
        accept
            ? 'Reserva confirmada. O turista vê na hora.'
            : 'Reserva recusada.',
      );
  } on MvpException catch (e) {
    if (context.mounted) showMpSnack(context, e.message);
  }
}

/// Área do parceiro (demonstração). Navegação oficial:
/// Painel · Cupons · Validar · Relatórios · Conta — Validar fica no centro.
class PartnerShell extends StatefulWidget {
  const PartnerShell({super.key});
  @override
  State<PartnerShell> createState() => _PartnerShellState();
}

class _PartnerShellState extends State<PartnerShell> {
  int _i = 0;
  void go(int i) => setState(() => _i = i);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _i,
      children: [
        _Dashboard(onGo: go),
        const _OffersTab(),
        const _ValidateTab(),
        const _ReportsTab(),
        const _AccountTab(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _i,
      onDestinationSelected: go,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: 'Painel',
        ),
        NavigationDestination(
          icon: Icon(Icons.local_activity_outlined),
          selectedIcon: Icon(Icons.local_activity_rounded),
          label: 'Cupons',
        ),
        NavigationDestination(
          icon: Icon(Icons.qr_code_scanner_rounded),
          label: 'Validar',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_rounded),
          label: 'Relatórios',
        ),
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront_rounded),
          label: 'Conta',
        ),
      ],
    ),
  );
}

class _PartnerHeader extends StatelessWidget {
  const _PartnerHeader(this.title, {this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s4, MP.pageH, MP.s3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MpBadge('ÁREA DO PARCEIRO · DEMONSTRAÇÃO', fg: MP.navy),
        const SizedBox(height: MP.s2),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (subtitle != null)
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: MP.textSecondary),
          ),
      ],
    ),
  );
}

class _Kpi extends StatelessWidget {
  const _Kpi(
    this.label,
    this.value, {
    this.icon = Icons.trending_up_rounded,
    this.color = MP.green,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => MpCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: MP.s2),
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: MP.textSecondary,
          ),
        ),
      ],
    ),
  );
}

// ---------------- Painel (MP-P01)
class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.onGo});
  final ValueChanged<int> onGo;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    final today = DateTime.now();
    final todayVal = s.validations
        .where(
          (v) => v.ok && v.at.day == today.day && v.at.month == today.month,
        )
        .toList();
    final pending = s.reservations
        .where((r) => r.status == ResStatus.solicitada && r.customer != 'Você')
        .toList();
    final revenue = todayVal.fold<int>(0, (a, v) => a + v.amountCents);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s3, MP.pageH, 0),
            child: Row(
              children: [
                const MpBackPill(),
                const Spacer(),
                Flexible(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Modo turista',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const _PartnerHeader(
            'Olá, $_partnerName',
            subtitle: 'Resumo de hoje',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MpCtaButton(
                  key: const Key('p-validate'),
                  label: 'Validar cupom',
                  icon: Icons.qr_code_scanner_rounded,
                  onPressed: () => onGo(2),
                ),
                const SizedBox(height: MP.s4),
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Kpi(
                            'Validações hoje',
                            '${todayVal.length}',
                            icon: Icons.verified_rounded,
                          ),
                        ),
                        const SizedBox(width: MP.s3),
                        Expanded(
                          child: _Kpi(
                            'Cupons ativos',
                            '${s.partnerOffers.where((o) => o.status == 'Ativa').length}',
                            icon: Icons.local_activity_rounded,
                            color: const Color(0xffa87b00),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MP.s3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Kpi(
                            'Reservas pendentes',
                            '${pending.length}',
                            icon: Icons.pending_actions_rounded,
                            color: MP.warning,
                          ),
                        ),
                        const SizedBox(width: MP.s3),
                        Expanded(
                          child: _Kpi(
                            'Vendas com cupom',
                            formatBrl(revenue),
                            icon: Icons.payments_rounded,
                            color: MP.navy,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: MP.sectionGap),
                const MpSectionTitle('Atalhos'),
                const SizedBox(height: MP.s2),
                MpListTile(
                  icon: Icons.add_circle_rounded,
                  title: 'Criar oferta',
                  subtitle: 'Cupom, desconto ou 2x1',
                  tint: MP.tintGreen,
                  color: MP.green,
                  onTap: () => push<void>(context, const CreateOfferScreen()),
                ),
                const SizedBox(height: MP.s2),
                MpListTile(
                  key: const Key('p-reservations'),
                  icon: Icons.event_available_rounded,
                  title: 'Central de reservas',
                  subtitle: '${pending.length} aguardando sua resposta',
                  tint: MP.tintPurple,
                  color: const Color(0xff5b3fa8),
                  onTap: () =>
                      push<void>(context, const PartnerReservationsScreen()),
                ),
                const SizedBox(height: MP.s2),
                MpListTile(
                  icon: Icons.event_rounded,
                  title: 'Eventos e ingressos',
                  subtitle: 'Crie e valide eventos',
                  tint: MP.tintRed,
                  color: MP.error,
                  onTap: () => push<void>(context, const PartnerEventsScreen()),
                ),
                const SizedBox(height: MP.s2),
                MpListTile(
                  icon: Icons.inbox_rounded,
                  title: 'Atendimento',
                  subtitle: 'Mensagens de turistas',
                  onTap: () => push<void>(context, const SupportCenterScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Cupons (MP-P02)
class _OffersTab extends ConsumerWidget {
  const _OffersTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s8),
        children: [
          const _PartnerHeader(
            'Gestão de cupons',
            subtitle: 'Crie, pause e acompanhe suas ofertas.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  key: const Key('p-create-offer'),
                  onPressed: () =>
                      push<void>(context, const CreateOfferScreen()),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Criar nova oferta'),
                ),
                const SizedBox(height: MP.s4),
                for (final o in s.partnerOffers) ...[
                  MpCard(
                    onTap: () =>
                        push<void>(context, OfferManageScreen(id: o.id)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                o.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            _OfferStatus(o.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          o.benefit,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: MP.green,
                          ),
                        ),
                        const SizedBox(height: MP.s2),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(MP.rPill),
                          child: LinearProgressIndicator(
                            value: o.limit == 0
                                ? 0
                                : (o.issued / o.limit).clamp(0, 1),
                            minHeight: 8,
                            color: MP.green,
                            backgroundColor: MP.soft,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${o.issued} emitidos · ${o.used} usados · limite ${o.limit} · até ${fmtDate(o.until)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MP.s3),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferStatus extends StatelessWidget {
  const _OfferStatus(this.s);
  final String s;
  @override
  Widget build(BuildContext context) => switch (s) {
    'Ativa' => const MpBadge('Ativa', fg: MP.success),
    'Pausada' => const MpBadge('Pausada', fg: MP.warning, bg: MP.warningBg),
    'Em análise' => const MpBadge('Em análise', fg: MP.info),
    _ => MpBadge(s, fg: MP.textSecondary),
  };
}

/// MP-P02.1 · Gestão da oferta: pausar com motivo, retomar, histórico.
class OfferManageScreen extends ConsumerWidget {
  const OfferManageScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    final o = s.partnerOffers.firstWhere((e) => e.id == id);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            MpHeader(o.title, subtitle: o.benefit),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _OfferStatus(o.status),
                  ),
                  const SizedBox(height: MP.s3),
                  MpInfoRow(Icons.rule_rounded, o.rules),
                  MpInfoRow(
                    Icons.confirmation_number_rounded,
                    'Limite total: ${o.limit}',
                  ),
                  MpInfoRow(
                    Icons.event_busy_rounded,
                    'Válida até ${fmtDate(o.until)}',
                  ),
                  if (o.pauseReason != null)
                    MpInfoRow(
                      Icons.pause_circle_rounded,
                      'Pausada: ${o.pauseReason}',
                    ),
                  if (o.status == 'Ativa') ...[
                    const SizedBox(height: MP.s4),
                    OfferQrCard(cupomId: 'po:${o.id}', title: o.title),
                  ],
                  const SizedBox(height: MP.s4),
                  Row(
                    children: [
                      Expanded(child: _Kpi('Emitidos', '${o.issued}')),
                      const SizedBox(width: MP.s3),
                      Expanded(
                        child: _Kpi('Usados', '${o.used}', color: MP.navy),
                      ),
                    ],
                  ),
                  const SizedBox(height: MP.s5),
                  if (o.status == 'Ativa')
                    OutlinedButton.icon(
                      key: const Key('offer-pause'),
                      onPressed: () async {
                        const reasons = [
                          'Sem disponibilidade',
                          'Mudança de preço',
                          'Clima ou temporada',
                          'Reforma ou manutenção',
                          'Outro motivo',
                        ];
                        final r = await showModalBottomSheet<String>(
                          context: context,
                          builder: (_) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    MP.pageH,
                                    0,
                                    MP.pageH,
                                    MP.s2,
                                  ),
                                  child: Text(
                                    'Por que pausar?',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                for (final x in reasons)
                                  ListTile(
                                    minTileHeight: 60,
                                    title: Text(
                                      x,
                                      style: const TextStyle(fontSize: 17),
                                    ),
                                    onTap: () => Navigator.of(context).pop(x),
                                  ),
                              ],
                            ),
                          ),
                        );
                        if (r != null) {
                          try {
                            await s.setOfferStatusAsync(
                              o.id,
                              'Pausada',
                              reason: r,
                            );
                            if (context.mounted) {
                              showMpSnack(
                                context,
                                'Oferta pausada. Turistas não veem mais o cupom.',
                              );
                            }
                          } on MvpException catch (e) {
                            if (context.mounted)
                              showMpSnack(context, e.message);
                          }
                        }
                      },
                      icon: const Icon(Icons.pause_rounded),
                      label: const Text('Pausar oferta'),
                    ),
                  if (o.status == 'Pausada')
                    FilledButton.icon(
                      key: const Key('offer-resume'),
                      onPressed: () async {
                        try {
                          await s.setOfferStatusAsync(o.id, 'Ativa');
                          if (context.mounted)
                            showMpSnack(context, 'Oferta ativa de novo.');
                        } on MvpException catch (e) {
                          if (context.mounted) showMpSnack(context, e.message);
                        }
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Retomar oferta'),
                    ),
                  if (o.status == 'Em análise') ...[
                    const MpNotice(
                      'A equipe MaraPass confere a oferta antes de publicar. Você recebe um aviso.',
                    ),
                    if (s.online) ...[
                      const SizedBox(height: MP.s3),
                      FilledButton.icon(
                        key: const Key('offer-approve'),
                        style: FilledButton.styleFrom(
                          backgroundColor: MP.green,
                        ),
                        onPressed: () async {
                          try {
                            await s.setOfferStatusAsync(o.id, 'Ativa');
                            if (context.mounted)
                              showMpSnack(
                                context,
                                'Oferta publicada. Os turistas já podem ativar.',
                              );
                          } on MvpException catch (e) {
                            if (context.mounted)
                              showMpSnack(context, e.message);
                          }
                        },
                        icon: const Icon(Icons.verified_rounded),
                        label: const Text('Aprovar (demonstração)'),
                      ),
                    ],
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

/// MP-P03→P05 · Criar oferta em 3 etapas: oferta, regras e prévia.
class CreateOfferScreen extends ConsumerStatefulWidget {
  const CreateOfferScreen({super.key});
  @override
  ConsumerState<CreateOfferScreen> createState() => _CreateOfferState();
}

class _CreateOfferState extends ConsumerState<CreateOfferScreen> {
  int _step = 0;
  final _title = TextEditingController();
  String _type = '%';
  final _value = TextEditingController(text: '10');
  final _rules = TextEditingController(text: 'Válido de segunda a sexta.');
  int _limit = 100;
  DateTime _until = DateTime.now().add(const Duration(days: 60));

  @override
  void dispose() {
    _title.dispose();
    _value.dispose();
    _rules.dispose();
    super.dispose();
  }

  String get _benefit => switch (_type) {
    '%' => '${_value.text.trim()}% de desconto',
    r'R$' => 'R\$ ${_value.text.trim()} de desconto',
    _ => 'Compre 1, ganhe 1',
  };

  bool get _okStep0 =>
      _title.text.trim().length >= 4 &&
      (_type == '2x1' || (int.tryParse(_value.text.trim()) ?? 0) > 0);

  Future<void> _publish() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enviar para publicação?'),
        content: const Text(
          'A equipe MaraPass confere a oferta. Depois de publicada, ela aparece para os turistas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            key: const Key('offer-publish-confirm'),
            style: FilledButton.styleFrom(minimumSize: const Size(120, 52)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    try {
      await ref
          .read(appStoreProvider)
          .createOfferAsync(
            title: _title.text.trim(),
            benefit: _benefit,
            rules: _rules.text.trim(),
            limit: _limit,
            until: _until,
          );
    } on MvpException catch (e) {
      if (mounted) showMpSnack(context, e.message);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MpStatusScreen(
          icon: Icons.hourglass_top_rounded,
          color: MP.info,
          bg: MP.infoBg,
          title: 'Oferta em análise',
          message: 'Recebemos a sua oferta. Em breve ela é publicada e você recebe um aviso.',
          primaryLabel: 'Voltar aos cupons',
          onPrimary: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['Oferta', 'Regras', 'Prévia'];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            MpHeader(
              'Criar oferta',
              subtitle: 'Etapa ${_step + 1} de 3 · ${steps[_step]}',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      for (var k = 0; k < 3; k++)
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
                  if (_step == 0) ...[
                    TextField(
                      key: const Key('offer-title'),
                      controller: _title,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        labelText: 'Nome da oferta',
                        hintText: 'Ex.: Desconto no almoço',
                      ),
                    ),
                    const SizedBox(height: MP.s4),
                    Text(
                      'Tipo de benefício',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: MP.s2),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: '%', label: Text('% desconto')),
                        ButtonSegment(
                          value: r'R$',
                          label: Text(r'R$ desconto'),
                        ),
                        ButtonSegment(value: '2x1', label: Text('2x1')),
                      ],
                      selected: {_type},
                      onSelectionChanged: (v) =>
                          setState(() => _type = v.first),
                      style: SegmentedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        selectedBackgroundColor: MP.navy,
                        selectedForegroundColor: Colors.white,
                      ),
                    ),
                    if (_type != '2x1') ...[
                      const SizedBox(height: MP.s4),
                      TextField(
                        key: const Key('offer-value'),
                        controller: _value,
                        onChanged: (_) => setState(() {}),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText: _type == '%'
                              ? 'Percentual'
                              : 'Valor em reais',
                        ),
                      ),
                    ],
                  ],
                  if (_step == 1) ...[
                    TextField(
                      controller: _rules,
                      minLines: 2,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 17),
                      decoration: const InputDecoration(
                        labelText: 'Condições para o turista',
                      ),
                    ),
                    const SizedBox(height: MP.s4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Limite de cupons',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        MpStepper(
                          value: _limit,
                          min: 10,
                          max: 1000,
                          keyPrefix: 'limit',
                          onChanged: (v) => setState(() => _limit = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: MP.s2),
                    const Text(
                      'Um cupom por turista. Use o limite para controlar a sua capacidade.',
                      style: TextStyle(color: MP.textSecondary, fontSize: 15),
                    ),
                    const SizedBox(height: MP.s4),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final n = DateTime.now();
                        final d = await showDatePicker(
                          context: context,
                          firstDate: n,
                          lastDate: n.add(const Duration(days: 365)),
                          initialDate: _until,
                        );
                        if (d != null) setState(() => _until = d);
                      },
                      icon: const Icon(Icons.event_rounded),
                      label: Text('Válida até ${fmtDate(_until)}'),
                    ),
                  ],
                  if (_step == 2) ...[
                    Text(
                      'Assim o turista vai ver:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: MP.s3),
                    TicketCard(
                      cupom: Cupom(
                        id: 'preview',
                        itemId: 'lagoas',
                        parceiro: _title.text.trim(),
                        cat: Cat.passeio,
                        beneficio: _benefit,
                        detalhe: _rules.text,
                        validade: _until,
                        foto: 'lagoas',
                      ),
                      onTap: () {},
                    ),
                    const SizedBox(height: MP.s3),
                    MpInfoRow(Icons.rule_rounded, _rules.text),
                    MpInfoRow(
                      Icons.confirmation_number_rounded,
                      'Até $_limit cupons',
                    ),
                  ],
                  const SizedBox(height: MP.s6),
                  if (_step < 2)
                    FilledButton(
                      key: const Key('offer-next'),
                      onPressed: _step == 0 && !_okStep0
                          ? null
                          : () => setState(() => _step++),
                      child: const Text('Continuar'),
                    )
                  else
                    MpCtaButton(
                      key: const Key('offer-publish'),
                      label: 'Enviar para publicação',
                      onPressed: _publish,
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

// ---------------- Validar (MP-P06 → P07)
class _ValidateTab extends ConsumerStatefulWidget {
  const _ValidateTab();
  @override
  ConsumerState<_ValidateTab> createState() => _ValidateTabState();
}

class _ValidateTabState extends ConsumerState<_ValidateTab> {
  final _code = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length < 4) return;
    final s = ref.read(appStoreProvider);
    LocalCoupon? found;
    for (final c in s.coupons) {
      if (c.code == code) found = c;
    }
    // Conferência obrigatória antes de registrar o uso.
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Conferência'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Código: $code',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: MP.s2),
            Text(
              found?.cupom == null
                  ? 'Cupom não encontrado nesta demonstração.'
                  : '${found!.cupom!.parceiro}\n${found.cupom!.beneficio}',
              style: const TextStyle(fontSize: 17),
            ),
            const SizedBox(height: MP.s2),
            const Text(
              'Confira se é o titular e se a compra atende às condições.',
              style: TextStyle(color: MP.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('validate-confirm'),
            style: FilledButton.styleFrom(minimumSize: const Size(130, 52)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar uso'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final cents =
        ((double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0) * 100)
            .round();
    final bool ok;
    final String msg;
    try {
      (ok, msg) = await s.validateCodeAsync(code, cents);
    } on MvpException catch (e) {
      if (mounted) showMpSnack(context, e.message);
      return;
    }
    if (!mounted) return;
    await push<void>(
      context,
      MpStatusScreen(
        icon: ok ? Icons.check_rounded : Icons.block_rounded,
        color: ok ? MP.success : MP.error,
        bg: ok ? MP.successBg : MP.errorBg,
        title: ok ? 'Validação concluída' : 'Validação bloqueada',
        message: msg,
        details: ok
            ? MpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comprovante',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    MpInfoRow(Icons.tag_rounded, 'Código $code'),
                    MpInfoRow(
                      Icons.schedule_rounded,
                      '${fmtDate(DateTime.now())} às ${fmtTime(DateTime.now())}',
                    ),
                    if (cents > 0)
                      MpInfoRow(
                        Icons.payments_rounded,
                        'Compra de ${formatBrl(cents)}',
                      ),
                  ],
                ),
              )
            : null,
        primaryLabel: 'Validar outro cupom',
        onPrimary: () => Navigator.of(context).pop(),
      ),
    );
    _code.clear();
    _amount.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s8),
        children: [
          const _PartnerHeader(
            'Validar cupom',
            subtitle: 'Leia o QR ou digite o código do turista.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: MP.ink,
                    borderRadius: BorderRadius.circular(MP.rXl),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: MP.yellow,
                      size: 80,
                    ),
                  ),
                ),
                const SizedBox(height: MP.s2),
                const Text(
                  'A leitura pela câmera entra na versão instalada. Aqui, digite o código.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MP.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: MP.s4),
                TextField(
                  key: const Key('validate-code'),
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Código do cupom',
                    hintText: 'MP-XXXX',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: MP.s3),
                TextField(
                  key: const Key('validate-amount'),
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: r'Valor da compra (opcional)',
                    prefixText: r'R$ ',
                  ),
                ),
                const SizedBox(height: MP.s4),
                MpCtaButton(
                  key: const Key('validate-submit'),
                  label: 'Conferir cupom',
                  onPressed: _code.text.trim().length >= 4 ? _check : null,
                ),
                const SizedBox(height: MP.sectionGap),
                const MpSectionTitle('Últimas validações'),
                const SizedBox(height: MP.s2),
                if (s.validations.isEmpty)
                  const MpCard(
                    color: MP.soft,
                    child: Text(
                      'Nenhuma validação ainda.',
                      style: TextStyle(fontSize: 16, color: MP.textSecondary),
                    ),
                  ),
                for (final v in s.validations.take(8)) ...[
                  MpListTile(
                    icon: v.ok
                        ? Icons.check_circle_rounded
                        : Icons.block_rounded,
                    tint: v.ok ? MP.successBg : MP.errorBg,
                    color: v.ok ? MP.success : MP.error,
                    title: '${v.code} · ${v.title}',
                    subtitle:
                        '${fmtDate(v.at)} ${fmtTime(v.at)}${v.ok ? '' : ' · ${v.reason}'}',
                  ),
                  const SizedBox(height: MP.s2),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Relatórios (MP-P08)
class _ReportsTab extends ConsumerStatefulWidget {
  const _ReportsTab();
  @override
  ConsumerState<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<_ReportsTab> {
  int _days = 7;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    final issued = s.partnerOffers.fold<int>(0, (a, o) => a + o.issued);
    final used =
        s.partnerOffers.fold<int>(0, (a, o) => a + o.used) +
        s.validations.where((v) => v.ok).length;
    // Série de demonstração estável + validações reais do aparelho.
    final series = List.generate(
      _days == 7 ? 7 : 10,
      (k) =>
          [3, 5, 4, 8, 6, 9, 7, 5, 6, 8][k % 10] +
          (k == (_days == 7 ? 6 : 9)
              ? s.validations.where((v) => v.ok).length
              : 0),
    );
    final maxV = series.reduce((a, b) => a > b ? a : b).toDouble();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: MP.s8),
        children: [
          const _PartnerHeader(
            'Relatórios',
            subtitle: 'Faturamento, retenção e horários de pico.',
          ),
          FilterChips<int>(
            options: const [7, 30],
            selected: _days,
            label: (v) => 'Últimos $v dias',
            onSelect: (v) => setState(() => _days = v),
          ),
          const SizedBox(height: MP.s4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _Kpi('Cupons emitidos', '$issued')),
                    const SizedBox(width: MP.s3),
                    Expanded(
                      child: _Kpi(
                        'Conversão',
                        issued == 0
                            ? '0%'
                            : '${(used * 100 / issued).round()}%',
                        color: MP.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MP.s4),
                MpCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cupons usados por dia',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: MP.s4),
                      SizedBox(
                        height: 160,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var k = 0; k < series.length; k++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${series[k]}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: MP.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        height: 120 * series[k] / maxV,
                                        decoration: BoxDecoration(
                                          color: k == series.length - 1
                                              ? MP.green
                                              : MP.green.withValues(alpha: .4),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MP.s4),
                const MpCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Horários de pico',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: MP.s2),
                      MpInfoRow(
                        Icons.wb_sunny_rounded,
                        'Manhã (8h às 11h): 45% dos usos',
                      ),
                      MpInfoRow(
                        Icons.wb_twilight_rounded,
                        'Fim de tarde (16h às 19h): 35%',
                      ),
                      MpInfoRow(Icons.nights_stay_rounded, 'Noite: 20%'),
                    ],
                  ),
                ),
                const SizedBox(height: MP.s3),
                const MpNotice.demo(
                  'Números de demonstração somados às validações feitas neste aparelho.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Conta (MP-P09)
class _AccountTab extends StatelessWidget {
  const _AccountTab();
  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.only(bottom: MP.s8),
      children: [
        const _PartnerHeader('Conta do parceiro'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MP.pageH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _partnerName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Passeios · Barreirinhas - MA',
                      style: TextStyle(color: MP.textSecondary, fontSize: 16),
                    ),
                    SizedBox(height: MP.s2),
                    MpBadge(
                      'Cadastur verificado',
                      fg: MP.success,
                      icon: Icons.verified_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MP.s4),
              MpListTile(
                key: const Key('partner-plates'),
                icon: Icons.qr_code_2_rounded,
                title: 'Placas MaraPass (QR)',
                subtitle: 'Baixe e imprima a placa de check-in',
                onTap: () => push<void>(context, const PlatesScreen()),
              ),
              const SizedBox(height: MP.s2),
              MpListTile(
                icon: Icons.event_available_rounded,
                title: 'Central de reservas',
                subtitle: 'Agenda e capacidade',
                onTap: () =>
                    push<void>(context, const PartnerReservationsScreen()),
              ),
              const SizedBox(height: MP.s2),
              MpListTile(
                icon: Icons.event_rounded,
                title: 'Eventos e ingressos',
                onTap: () => push<void>(context, const PartnerEventsScreen()),
              ),
              const SizedBox(height: MP.s2),
              MpListTile(
                icon: Icons.design_services_rounded,
                title: 'Cadastrar serviço',
                subtitle: 'Passeio, experiência ou artesanato',
                onTap: () => push<void>(context, const ServiceWizardScreen()),
              ),
              const SizedBox(height: MP.s2),
              MpListTile(
                icon: Icons.inbox_rounded,
                title: 'Atendimento',
                subtitle: 'Mensagens e suporte do parceiro',
                onTap: () => push<void>(context, const SupportCenterScreen()),
              ),
              const SizedBox(height: MP.s6),
              OutlinedButton.icon(
                key: const Key('partner-exit'),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Sair da área do parceiro?'),
                      content: const Text('Você volta para o modo turista.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Ficar'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(110, 52),
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Sair'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted)
                    Navigator.of(context).pop();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sair com segurança'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

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
                    for (final k in const [
                      'Passeio',
                      'Experiência',
                      'Artesanato',
                      'Fotografia',
                    ])
                      RadioListTile<String>(
                        value: k,
                        groupValue: _kind,
                        onChanged: (v) => setState(() => _kind = v!),
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
