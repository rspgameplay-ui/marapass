import 'package:flutter/material.dart';

import 'coupon_offer_form.dart';
import 'coupon_commerce.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog_cache.dart';
import '../data/content.dart';
import '../data/models.dart' show formatBrl;
import '../data/repository.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'package:image_picker/image_picker.dart';

import 'common.dart';
import 'plates.dart';
import 'support.dart';

part 'partner_offers.dart';
part 'partner_validate.dart';
part 'partner_extra.dart';

const _partnerName = 'Lençóis Experience';

Future<void> _decide(
  BuildContext context,
  AppStore s,
  String id,
  bool accept,
) async {
  try {
    await s.decideReservationAsync(id, accept);
    if (context.mounted) {
      showMpSnack(
        context,
        accept
            ? 'Reserva confirmada. O turista vê na hora.'
            : 'Reserva recusada.',
      );
    }
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
        Consumer(
          builder: (context, ref, _) => MpBadge(
            ref.watch(appStoreProvider).remote == null
                ? 'ÁREA DO PARCEIRO · DEMONSTRAÇÃO'
                : 'ÁREA DO PARCEIRO',
            fg: MP.navy,
          ),
        ),
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
    if (s.remote != null) {
      return PartnerCouponList(
        dashboard: true,
        shortcuts: Wrap(
          children: [
            TextButton(onPressed: () => onGo(1), child: const Text('Ofertas')),
            TextButton(onPressed: () => onGo(2), child: const Text('Validar')),
            TextButton(
              onPressed: () =>
                  push<void>(context, const PartnerReservationsScreen()),
              child: const Text('Reservas'),
            ),
            TextButton(
              onPressed: () => push<void>(context, const PartnerEventsScreen()),
              child: const Text('Eventos'),
            ),
            TextButton(
              onPressed: () => push<void>(context, const SupportCenterScreen()),
              child: const Text('Atendimento'),
            ),
          ],
        ),
      );
    }
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
                            color: MP.goldText,
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
    if (ref.watch(appStoreProvider).remote != null) {
      return const SaleOfferForm();
    }
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
                  if (ok == true && context.mounted) {
                    Navigator.of(context).pop();
                  }
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

/// Foto da oferta: mostra a atual e envia uma nova da galeria (até 5 MB).
class _OfferPhoto extends ConsumerStatefulWidget {
  const _OfferPhoto({required this.offerId, required this.imageUrl});
  final String offerId;
  final String? imageUrl;
  @override
  ConsumerState<_OfferPhoto> createState() => _OfferPhotoState();
}

class _OfferPhotoState extends ConsumerState<_OfferPhoto> {
  bool _busy = false;

  Future<void> _pick() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 82);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) showMpSnack(context, 'A foto passa de 5 MB. Escolha uma menor.');
      return;
    }
    final name = file.name.toLowerCase();
    final mime = file.mimeType ??
        (name.endsWith('.png') ? 'image/png' : (name.endsWith('.webp') ? 'image/webp' : 'image/jpeg'));
    if (!const {'image/jpeg', 'image/png', 'image/webp'}.contains(mime)) {
      if (mounted) showMpSnack(context, 'Use uma foto em JPG, PNG ou WebP.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(appStoreProvider).setOfferImageAsync(widget.offerId, bytes, mime);
      if (mounted) showMpSnack(context, 'Foto atualizada. Ela já aparece no cupom.');
    } on MvpException catch (e) {
      if (mounted) showMpSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MpPhoto(
        key: const Key('offer-photo'),
        photo: widget.imageUrl,
        height: 170,
        radius: MP.rLarge,
        icon: Icons.add_photo_alternate_rounded,
      ),
      const SizedBox(height: MP.s2),
      OutlinedButton.icon(
        key: const Key('offer-photo-pick'),
        onPressed: _busy ? null : _pick,
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.photo_library_rounded),
        label: Text(widget.imageUrl == null ? 'Adicionar foto da oferta' : 'Trocar foto'),
      ),
    ],
  );
}
